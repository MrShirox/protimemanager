import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:protimemanager/database/db_helper.dart';
import 'package:protimemanager/models/chrono_entry.dart';
import 'package:protimemanager/services/work_sessions.dart';
import 'package:protimemanager/providers/planning_provider.dart';
import 'package:protimemanager/providers/chrono_provider.dart';
import 'package:protimemanager/screens/planning/planning_screen.dart';
import 'package:protimemanager/screens/chrono/chrono_screen.dart';
import 'package:protimemanager/widgets/session_editor.dart';

void main() {
  sqfliteFfiInit();

  testWidgets(
      'calendar shows Sunday total and two Tuesday night portions on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    late Database db;
    late WorkSessions store;
    late PlanningProvider planning;
    await tester.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      dir = await Directory.systemTemp.createTemp('protime-ui-');
      db = await DBHelper.instance
          .openAt('${dir.path}/test.db', factory: databaseFactoryFfi);
      store = WorkSessions(
          database: () async => db,
          clock: () => DateTime(2026, 10, 15, 8),
          startTicker: false);
      await store.ready;
      for (var d = 12; d <= 14; d++) {
        await store.save(ChronoSession(
            startTime: DateTime(2026, 10, d, 20),
            endTime: DateTime(2026, 10, d + 1, 5)));
      }
      planning = PlanningProvider(store, loadShifts: false);
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: planning, child: const MaterialApp(home: PlanningScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Σ 27h00'), findsOneWidget);
    await tester.tap(find.text('13'));
    await tester.pumpAndSettle();
    expect(find.text('Total travaillé : 9h00'), findsOneWidget);
    expect(find.text('00:00 → 05:00'), findsOneWidget);
    expect(find.text('20:00 → 24:00'), findsOneWidget);
    await tester.tap(find.text('Modifier la session').first);
    await tester.pumpAndSettle();
    expect(find.byType(SessionEditor), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);
    expect(find.text('13/10/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      planning.dispose();
      store.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });
  });

  testWidgets(
      'editing active start with the time picker updates chrono immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    late Database db;
    late WorkSessions store;
    late PlanningProvider planning;
    late ChronoProvider chrono;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('protime-editor-');
      db = await DBHelper.instance
          .openAt('${dir.path}/test.db', factory: databaseFactoryFfi);
      store = WorkSessions(
          database: () async => db,
          clock: () => DateTime(2026, 10, 12, 9),
          startTicker: false);
      await store.ready;
      await store.start();
      planning = PlanningProvider(store, loadShifts: false);
      chrono = ChronoProvider(store);
    });
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: planning),
          ChangeNotifierProvider.value(value: chrono),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => Column(children: [
                          Consumer<ChronoProvider>(
                              builder: (_, c, __) =>
                                  Text('Travail ${c.elapsed.inMinutes} min')),
                          ElevatedButton(
                              onPressed: () => showSessionEditor(context,
                                  day: store.now(), session: store.active),
                              child: const Text('Corriger')),
                        ]))))));
    await tester.tap(find.text('Corriger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '8');
    await tester.enterText(find.byType(TextField).last, '00');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Enregistrer'));
      while (store.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(SessionEditor), findsNothing);
    expect(find.text('Travail 60 min'), findsOneWidget);
    expect(chrono.isRunning, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: planning),
      ChangeNotifierProvider.value(value: chrono),
    ], child: const MaterialApp(home: ChronoScreen())));
    await tester.pumpAndSettle();
    expect(find.text('01:00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      chrono.dispose();
      planning.dispose();
      store.dispose();
      await db.close();
      await dir.delete(recursive: true);
    });
  });
}
