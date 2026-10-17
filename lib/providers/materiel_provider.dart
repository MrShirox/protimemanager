import 'package:flutter/material.dart';
import '../models/materiel.dart';
import '../database/db_helper.dart';

class MaterielProvider extends ChangeNotifier {
  List<Materiel> _materiels = [];
  List<Materiel> get materiels => _materiels;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _showManquantOnly = false;
  bool get showManquantOnly => _showManquantOnly;

  MaterielProvider() {
    loadAll();
  }

  List<Materiel> get filtered {
    return _materiels.where((m) {
      final matchSearch = m.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.categorie?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchManquant = !_showManquantOnly || m.isManquant || !m.disponible;
      return matchSearch && matchManquant;
    }).toList();
  }

  List<Materiel> get alertesPeremption {
    return _materiels.where((m) => m.perimetionProche || m.isPerime).toList();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleManquantFilter() {
    _showManquantOnly = !_showManquantOnly;
    notifyListeners();
  }

  Future<void> loadAll() async {
    final rows = await DBHelper.instance.getAllMateriels();
    _materiels = rows.map((r) => Materiel.fromMap(r)).toList();
    notifyListeners();
  }

  Future<void> add(Materiel materiel) async {
    final id = await DBHelper.instance.insertMateriel(materiel.toMap());
    _materiels.add(materiel.copyWith(id: id));
    _materiels.sort((a, b) => a.nom.compareTo(b.nom));
    notifyListeners();
  }

  Future<void> update(Materiel materiel) async {
    await DBHelper.instance.updateMateriel(materiel.toMap());
    final idx = _materiels.indexWhere((m) => m.id == materiel.id);
    if (idx != -1) _materiels[idx] = materiel;
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await DBHelper.instance.deleteMateriel(id);
    _materiels.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}