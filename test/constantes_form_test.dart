import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:protimemanager/models/constante.dart';
import 'package:protimemanager/providers/constantes_provider.dart';
import 'package:protimemanager/screens/constantes/constantes_screen.dart';
import 'package:protimemanager/widgets/expiry_month_picker.dart';

class MemoryConstants extends ConstantesProvider {
  Constante? saved;
  @override
  Future<void> loadAll() async {}
  @override
  Future<void> update(Constante value) async {
    saved = Constante.fromMap(value.toMap());
  }
}

void main() {
  testWidgets(
      'FAST choices are exclusive and save with legacy notes and acetone intact',
      (tester) async {
    await initializeDateFormatting('fr_FR');
    final provider = MemoryConstants();
    final existing = Constante(id: 1, titre: 'Fiche', champs: [
      ConstanteChamp(label: 'FAST FACE', valeur: 'OK'),
      ConstanteChamp(label: 'Glycémie', valeur: '5.4 mmol/L — 10:00'),
      ConstanteChamp(label: 'Acétone', valeur: '0.2 mmol/L'),
      ConstanteChamp(
          label: 'Observations neurologiques', valeur: 'Note historique'),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<ConstantesProvider>.value(
        value: provider,
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
          builder: (context) => TextButton(
              onPressed: () => showConstanteDialog(context, existing),
              child: const Text('Modifier')),
        )))));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    final faceRow =
        find.ancestor(of: find.text('FACE'), matching: find.byType(Row));
    final boxes = find.descendant(of: faceRow, matching: find.byType(Checkbox));
    await tester.ensureVisible(boxes.last);
    expect(tester.widget<Checkbox>(boxes.first).value, isTrue);
    await tester.tap(boxes.last);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(boxes.first).value, isFalse);
    expect(tester.widget<Checkbox>(boxes.last).value, isTrue);
    expect(find.text('ARM'), findsOneWidget);
    expect(find.text('SPEECH'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.indexWhere((f) => f.controller?.text == '0.2 mmol/L'),
        greaterThan(fields.indexWhere((f) => f.controller?.text == '5.4')));
    await tester.ensureVisible(find.text('ENREGISTRER'));
    await tester.tap(find.text('ENREGISTRER'));
    await tester.pumpAndSettle();
    final values = {for (final c in provider.saved!.champs) c.label: c.valeur};
    expect(values['FAST FACE'], 'NON');
    expect(values.containsKey('FAST ARM'), isFalse);
    expect(values['Acétone'], '0.2 mmol/L');
    expect(values['Observations neurologiques'], 'Note historique');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('expiry picker selects month and year without a day',
      (tester) async {
    await initializeDateFormatting('fr_FR');
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      picked = await showExpiryMonthPicker(
                          context, DateTime(2027, 1, 12));
                    },
                    child: const Text('Choisir'))))));
    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    await tester.tap(find.text('janvier').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('février').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2027, 2));
  });
}
