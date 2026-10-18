import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';

/// A non-repeating reminder per medication, identified by its SQLite id.
class MedicationNotifications {
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _now;
  bool _initialized = false;

  MedicationNotifications(
      {FlutterLocalNotificationsPlugin? plugin, DateTime Function()? now})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _now = now ?? DateTime.now;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_medication_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      _initialized = true;
    }
    tz.setLocalLocation(await _localLocation());
  }

  /// Some phones report a zone name missing from the timezone database
  /// (e.g. "GMT+02:00"); fall back instead of failing every reminder.
  Future<tz.Location> _localLocation() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(zone.identifier);
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      final paris = tz.getLocation('Europe/Paris');
      if (tz.TZDateTime.now(paris).timeZoneOffset == offset) return paris;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
          return location;
        }
      }
      return tz.UTC;
    }
  }

  Future<bool> _permission(bool request) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      if (request) await android.requestNotificationsPermission();
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (request) await ios?.requestPermissions(alert: true, sound: true);
    return (await ios?.checkPermissions())?.isAlertEnabled ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'medication_expiry',
      'Péremption des médicaments',
      channelDescription:
          'Rappels au début du mois précédent et du mois de péremption',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// Reconcile SQLite with OS reminders on launch and after CRUD.
  /// Returns a user-facing warning, or null when scheduling is available.
  Future<String?> synchronize(List<Medication> items,
      {bool requestPermission = false, int? changedId}) async {
    if (!supported) {
      return 'Les rappels de péremption sont disponibles sur Android et iPhone.';
    }
    await _initialize();
    final allowed = await _permission(requestPermission);
    final now = tz.TZDateTime.from(_now(), tz.local);
    final today = DateTime(now.year, now.month);
    final eligible = items.where((m) {
      final d = m.expiryMonth;
      return m.id != null &&
          d != null &&
          !DateTime(d.year, d.month, d.day).isBefore(today);
    }).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    // Each phase has its own stable id. Existing expiry ids are preserved.
    final plans = <({Medication item, int id, DateTime date, bool warning})>[];
    for (final item in eligible) {
      plans.add(
          (item: item, id: item.id!, date: item.expiryMonth!, warning: false));
      if (item.expiryMonth!.isAfter(today)) {
        plans.add((
          item: item,
          id: -item.id!,
          date: item.warningDate!,
          warning: true
        ));
      }
    }
    plans.sort((a, b) => a.date.compareTo(b.date));
    final limit = defaultTargetPlatform == TargetPlatform.iOS ? 64 : 450;
    final selected = plans.take(limit).toList();
    final prefs = await SharedPreferences.getInstance();
    final pending = await _plugin.pendingNotificationRequests();
    final selectedIds = selected.map((m) => m.id).toSet();
    for (final p in pending) {
      if (p.payload?.startsWith('medication:') == true &&
          !selectedIds.contains(p.id)) {
        await _plugin.cancel(p.id);
      }
    }
    // Also clear an already displayed notification for an edited/deleted item.
    if (changedId != null) {
      await _plugin.cancel(changedId);
      await _plugin.cancel(-changedId);
      await prefs.remove('medication.reminder.${-changedId}');
      await prefs.remove('medication.reminder.$changedId');
    }
    if (!allowed) {
      return 'Notifications désactivées. Autorise-les pour ProTimeManager dans les réglages du téléphone.';
    }
    for (final plan in selected) {
      final item = plan.item;
      final morning = tz.TZDateTime(
          tz.local, plan.date.year, plan.date.month, plan.date.day, 9);
      final when =
          morning.isAfter(now) ? morning : now.add(const Duration(seconds: 5));
      final key = 'medication.reminder.${plan.id}';
      final dateKey =
          'month:${item.expiryDate!.year}-${item.expiryDate!.month}';
      // Avoid repeat alerts on every launch after 09:00. Keep any pending one.
      if (!morning.isAfter(now) && prefs.getString(key) == dateKey) continue;
      await _plugin.zonedSchedule(
        plan.id,
        plan.warning
            ? 'Médicament à remplacer bientôt'
            : 'Médicament à péremption',
        plan.warning
            ? '${item.name} : péremption ${item.expiryDate!.month}/${item.expiryDate!.year}. Prévois son remplacement.'
            : '${item.name} : le mois de péremption est atteint (${item.expiryDate!.month}/${item.expiryDate!.year}).',
        when,
        _details,
        payload: 'medication:${item.id}',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await prefs.setString(key, dateKey);
    }
    if (plans.length > limit) {
      return 'Les $limit prochaines péremptions sont programmées. Ouvre régulièrement l’application pour programmer les suivantes.';
    }
    return null;
  }

  /// Local 09:00, or shortly after saving later on the expiry day.
  @visibleForTesting
  static tz.TZDateTime? reminderTime(DateTime expiry, tz.TZDateTime now) {
    final day =
        tz.TZDateTime(now.location, expiry.year, expiry.month, expiry.day);
    final today = tz.TZDateTime(now.location, now.year, now.month, now.day);
    if (day.isBefore(today)) return null;
    final morning =
        tz.TZDateTime(now.location, expiry.year, expiry.month, expiry.day, 9);
    return morning.isAfter(now) ? morning : now.add(const Duration(seconds: 5));
  }
}
