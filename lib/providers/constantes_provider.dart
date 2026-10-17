import 'package:flutter/material.dart';
import '../models/constante.dart';
import '../database/db_helper.dart';

class ConstantesProvider extends ChangeNotifier {
  List<Constante> _constantes = [];
  List<Constante> get constantes => _constantes;

  ConstantesProvider() {
    loadAll();
  }

  Future<void> loadAll() async {
    final rows = await DBHelper.instance.getAllConstantes();
    _constantes = rows.map((r) => Constante.fromMap(r)).toList();
    notifyListeners();
  }

  Future<void> add(Constante constante) async {
    final id = await DBHelper.instance.insertConstante(constante.toMap());
    _constantes.insert(0, constante.copyWith(id: id));
    notifyListeners();
  }

  Future<void> update(Constante constante) async {
    await DBHelper.instance.updateConstante(
      constante.copyWith(updatedAt: DateTime.now()).toMap(),
    );
    final idx = _constantes.indexWhere((c) => c.id == constante.id);
    if (idx != -1) {
      _constantes[idx] = constante.copyWith(updatedAt: DateTime.now());
    }
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await DBHelper.instance.deleteConstante(id);
    _constantes.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}