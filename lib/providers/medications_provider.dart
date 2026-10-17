import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/medication.dart';

class MedicationsProvider extends ChangeNotifier {
  List<Medication> _items = [];
  List<Medication> get items => List.unmodifiable(_items);

  MedicationsProvider() { load(); }

  Future<void> load() async {
    final rows = await DBHelper.instance.getAllMedications();
    _items = rows.map(Medication.fromMap).toList();
    _sort();
    notifyListeners();
  }

  Future<void> save(Medication item) async {
    if (item.id == null) {
      final id = await DBHelper.instance.insertMedication(item.toMap());
      _items.add(Medication(
        id: id, name: item.name, dosage: item.dosage,
        quantity: item.quantity, expiryDate: item.expiryDate, note: item.note,
      ));
    } else {
      await DBHelper.instance.updateMedication(item.toMap());
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index != -1) _items[index] = item;
    }
    _sort();
    notifyListeners();
  }

  void _sort() => _items.sort((a, b) {
    if (a.expiryDate == null && b.expiryDate == null) return a.name.compareTo(b.name);
    if (a.expiryDate == null) return 1;
    if (b.expiryDate == null) return -1;
    return a.expiryDate!.compareTo(b.expiryDate!);
  });

  Future<void> delete(int id) async {
    await DBHelper.instance.deleteMedication(id);
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  List<Medication> get expiringToday => _items.where((m) => m.expiresToday).toList();
}
