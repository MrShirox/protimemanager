import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:protimemanager/models/medication.dart';
import 'package:protimemanager/services/medication_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<int, Map<String, dynamic>> pending;
  late bool allowed;
  late DateTime now;
  late MedicationNotifications service;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    tz_data.initializeTimeZones();
    calls = [];
    pending = {};
    allowed = true;
    now = tz.TZDateTime(tz.getLocation('Europe/Paris'), 2090, 10, 17, 12);
    service = MedicationNotifications(now: () => now);
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Paris');
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'areNotificationsEnabled':
        case 'requestNotificationsPermission':
          return allowed;
        case 'pendingNotificationRequests':
          return pending.values.toList();
        case 'cancel':
          pending.remove((call.arguments as Map)['id']);
          return null;
        case 'zonedSchedule':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          pending[args['id'] as int] = {
            'id': args['id'],
            'title': args['title'],
            'body': args['body'],
            'payload': args['payload'],
          };
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  Medication item(DateTime date, {String name = 'Médicament A'}) =>
      Medication(id: 7, name: name, expiryDate: date);

  List<MethodCall> schedules() =>
      calls.where((c) => c.method == 'zonedSchedule').toList();

  test('add, edit and delete reconcile the same OS reminder id', () async {
    expect(
        await service.synchronize([item(DateTime(2090, 10, 20))],
            requestPermission: true, changedId: 7),
        isNull);
    expect(pending.keys, [-7, 7]);
    expect(
        schedules().last.arguments['scheduledDateTime'], '2090-10-20T09:00:00');
    expect(schedules().last.arguments['timeZoneName'], 'Europe/Paris');
    await service.synchronize(
        [item(DateTime(2090, 11, 3), name: 'Nouveau nom')],
        changedId: 7);
    expect(pending.length, 2);
    expect(
        schedules().last.arguments['scheduledDateTime'], '2090-11-03T09:00:00');
    expect(pending[7]!['body'], contains('Nouveau nom'));
    await service.synchronize([], changedId: 7);
    expect(pending, isEmpty);
  });

  test('today after 9 is scheduled once, including after application restart',
      () async {
    final items = [item(DateTime(2090, 10, 17))];
    await service.synchronize(items, changedId: 7);
    expect(schedules().single.arguments['scheduledDateTime'],
        '2090-10-17T12:00:05');
    pending.clear(); // Simulate delivery by the OS.
    service = MedicationNotifications(now: () => now);
    await service.synchronize(items);
    expect(schedules().length, 1);
  });

  test('denied permission keeps reminders unscheduled; granting retries',
      () async {
    allowed = false;
    final items = [item(DateTime(2090, 10, 17))];
    expect(
        await service.synchronize(items, requestPermission: true, changedId: 7),
        contains('désactivées'));
    expect(schedules(), isEmpty);
    allowed = true;
    expect(await service.synchronize(items, requestPermission: true), isNull);
    expect(schedules().length, 1);
  });

  test('expired or undated medication cancels its old reminder', () async {
    await service.synchronize([item(DateTime(2090, 10, 20))]);
    await service.synchronize([item(DateTime(2090, 10, 16))], changedId: 7);
    expect(pending, isEmpty);
    await service.synchronize([item(DateTime(2090, 10, 20))]);
    await service.synchronize([const Medication(id: 7, name: 'Ancien')]);
    expect(pending, isEmpty);
  });

  test('9 AM stays local across daylight saving changes', () {
    final paris = tz.getLocation('Europe/Paris');
    final before = tz.TZDateTime(paris, 2026, 10, 24, 12);
    final reminder =
        MedicationNotifications.reminderTime(DateTime(2026, 10, 25), before)!;
    expect(reminder.hour, 9);
    expect(reminder.timeZoneOffset, const Duration(hours: 1));
    expect(reminder.difference(before), const Duration(hours: 22));
    expect(MedicationNotifications.reminderTime(DateTime(2026, 10, 23), before),
        isNull);
  });

  test('one calendar month before expiry and expiry have separate reminders',
      () async {
    await service.synchronize([item(DateTime(2091, 3, 31))]);
    expect(schedules().map((c) => c.arguments['scheduledDateTime']),
        ['2091-02-28T09:00:00', '2091-03-31T09:00:00']);
    expect(pending[-7]!['title'], contains('bientôt'));
    expect(pending[7]!['title'], contains('péremption'));
  });

  test('late warning is caught up once and does not replace expiry alert',
      () async {
    final items = [item(DateTime(2090, 10, 20))];
    await service.synchronize(items);
    expect(schedules().first.arguments['scheduledDateTime'],
        '2090-10-17T12:00:05');
    pending.remove(-7);
    await service.synchronize(items);
    expect(schedules().where((c) => c.arguments['id'] == -7).length, 1);
    expect(pending.containsKey(7), isTrue);
  });

  test('orange begins a calendar month before; red includes expiry day', () {
    final m = item(DateTime(2028, 3, 31));
    expect(m.warningDate, DateTime(2028, 2, 29));
    expect(m.warningAt(DateTime(2028, 2, 28)), isFalse);
    expect(m.warningAt(DateTime(2028, 2, 29)), isTrue);
    expect(m.warningAt(DateTime(2028, 3, 31)), isFalse);
    expect(m.dueAt(DateTime(2028, 3, 31)), isTrue);
    expect(m.dueAt(DateTime(2028, 4, 1)), isTrue);
  });
}
