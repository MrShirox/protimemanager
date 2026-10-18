import 'dart:async';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/medication.dart';
import '../services/medication_notifications.dart';

class MedicationsProvider extends ChangeNotifier with WidgetsBindingObserver {
  final MedicationNotifications _notifications = MedicationNotifications();
  List<Medication> _items = [];
  List<Medication> get items => List.unmodifiable(_items);
  bool isLoading = true;
  bool isBusy = false;
  String? error;
  String? notificationWarning;
  bool _disposed = false;
  Timer? _dayTimer;

  MedicationsProvider() {
    WidgetsBinding.instance.addObserver(this);
    load();
    _refreshAtMidnight();
  }

  void _refreshAtMidnight() {
    final now = DateTime.now();
    _dayTimer =
        Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      _notify();
      if (!_disposed) _refreshAtMidnight();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (isBusy) return;
    isLoading = true;
    error = null;
    _notify();
    try {
      final rows = await DBHelper.instance.getAllMedications();
      _items = rows.map(Medication.fromMap).toList();
      _sort();
      await _syncNotifications();
    } catch (e) {
      error =
          'Impossible de charger les médicaments. Réessaie.\nDétail : ${errorDetail(e)}';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> _syncNotifications(
      {bool request = false, int? changedId}) async {
    try {
      notificationWarning = await _notifications.synchronize(_items,
          requestPermission: request, changedId: changedId);
    } catch (e) {
      debugPrint('Medication reminders failed: $e');
      notificationWarning =
          'Les données sont sauvegardées, mais les rappels n’ont pas pu être programmés. Appuie sur Réessayer.\nDétail : ${errorDetail(e)}';
    }
  }

  Future<void> enableNotifications() async {
    if (isBusy || isLoading || error != null) return;
    isBusy = true;
    _notify();
    try {
      await _syncNotifications(request: true);
    } finally {
      isBusy = false;
      _notify();
    }
  }

  Future<void> save(Medication item) async {
    if (isBusy || isLoading) throw StateError('Chargement en cours');
    if (item.name.trim().isEmpty ||
        item.quantity < 0 ||
        item.expiryDate == null) {
      throw ArgumentError('Nom, quantité et péremption requis');
    }
    isBusy = true;
    _notify();
    try {
      final id =
          item.id ?? await DBHelper.instance.insertMedication(item.toMap());
      if (item.id != null) {
        await DBHelper.instance.updateMedication(item.toMap());
      }
      final saved = Medication(
          id: id,
          name: item.name,
          dosage: item.dosage,
          quantity: item.quantity,
          expiryDate: item.expiryDate,
          note: item.note);
      final index = _items.indexWhere((e) => e.id == id);
      if (index < 0) {
        _items.add(saved);
      } else {
        _items[index] = saved;
      }
      _sort();
      await _syncNotifications(request: true, changedId: id);
    } finally {
      isBusy = false;
      _notify();
    }
  }

  void _sort() => _items.sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) {
          return a.name.compareTo(b.name);
        }
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });

  Future<void> delete(int id) async {
    if (isBusy || isLoading) throw StateError('Chargement en cours');
    isBusy = true;
    _notify();
    try {
      await DBHelper.instance.deleteMedication(id);
      _items.removeWhere((item) => item.id == id);
      await _syncNotifications(changedId: id);
    } finally {
      isBusy = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isLoading && !isBusy) load();
  }

  List<Medication> get expiringThisMonth =>
      _items.where((m) => m.expiresThisMonth).toList();

  @override
  void dispose() {
    _disposed = true;
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
