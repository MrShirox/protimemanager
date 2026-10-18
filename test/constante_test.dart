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
  test('message is grouped by section and summarises FAST', () {
    final message = Constante(titre: '14:32  –  18/10/2026', champs: [
      ConstanteChamp(label: 'Remarques', valeur: 'Patient calme'),
      ConstanteChamp(label: 'SpO2', valeur: '98 %'),
      for (final n in ['FACE', 'ARM', 'SPEECH', 'TIME'])
        ConstanteChamp(label: 'FAST $n', valeur: 'OK'),
      ConstanteChamp(label: 'Pouls', valeur: '72 bpm'),
      ConstanteChamp(label: 'Rythme', valeur: 'Régulier'),
      ConstanteChamp(label: 'Perception', valeur: 'Bien perçu'),
    ]).toMessage();
    expect(message, contains('• Pouls : 72 bpm (régulier, bien perçu)'));
    expect(message, contains('• FAST : OK ✅'));
    expect(message, isNot(contains('FACE')));
    expect(message.indexOf('CARDIAQUE'),
        lessThan(message.indexOf('RESPIRATOIRE')));
    expect(message.indexOf('RESPIRATOIRE'), lessThan(message.indexOf('NEURO')));
    expect(message.trimRight(), endsWith('Patient calme'));
  });

  test('FAST lists only what is not OK', () {
    final message = Constante(titre: 'Fiche', champs: [
      ConstanteChamp(label: 'FAST FACE', valeur: 'OK'),
      ConstanteChamp(label: 'FAST ARM', valeur: 'NON'),
      ConstanteChamp(label: 'FAST SPEECH', valeur: 'NON'),
      ConstanteChamp(label: 'FAST TIME', valeur: 'OK'),
    ]).toMessage();
    expect(message, contains('FAST : ⚠️ ARM NON · SPEECH NON'));
    expect(message, isNot(contains('FACE')));
    expect(message, isNot(contains('CARDIAQUE')));
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
