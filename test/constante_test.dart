import 'package:flutter_test/flutter_test.dart';
import 'package:protimemanager/models/constante.dart';

void main() {
  test('FR acetone and notes preserve punctuation through save and reload', () {
    final value = Constante(titre: 'Fiche', champs: [
      ConstanteChamp(label: 'FR', valeur: '18 /min'),
      ConstanteChamp(label: 'Acétone', valeur: 'Trace'),
      ConstanteChamp(label: 'Observations neurologiques', valeur: 'A::B || C'),
    ]);
    final reloaded = Constante.fromMap(value.toMap());
    expect(reloaded.champs.map((c) => c.valeur),
        ['18 /min', 'Trace', 'A::B || C']);
    expect(reloaded.toMessage(), contains('FR : 18 /min'));
  });
  test('legacy constants stay readable and are upgraded on next save', () {
    final old = Constante.fromMap({
      'titre': 'Ancienne',
      'createdAt': '2026-10-18',
      'champs': 'Pouls::72 bpm||Remarques::note::détail'
    });
    final updated = Constante.fromMap(old.toMap());
    expect(updated.champs.last.valeur, 'note::détail');
    expect(updated.champs.first.valeur, '72 bpm');
  });
}
