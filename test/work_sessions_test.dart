import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:protimemanager/database/db_helper.dart';
import 'package:protimemanager/models/chrono_entry.dart';
import 'package:protimemanager/services/work_sessions.dart';
import 'package:protimemanager/providers/chrono_provider.dart';
import 'package:protimemanager/providers/planning_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late Database db;
  late WorkSessions store;
  late ChronoProvider chrono;
  late PlanningProvider planning;
  late DateTime clock;

  Future<void> open() async {
    db = await DBHelper.instance.openAt(path, factory: databaseFactoryFfi);
    store = WorkSessions(
        database: () async => db, clock: () => clock, startTicker: false);
    await store.ready;
    expect(store.loadError, isNull);
    chrono = ChronoProvider(store);
    planning = PlanningProvider(store, loadShifts: false);
  }

  Future<void> close() async {
    chrono.dispose();
    planning.dispose();
    store.dispose();
    await db.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('protime-work-test-');
    path = '${directory.path}/test.db';
    clock = DateTime(2026, 10, 12, 20);
    await open();
  });
  tearDown(() async {
    await close();
    await directory.delete(recursive: true);
  });

  test('three nights are separate sessions, Tuesday and Wednesday have 9 hours',
      () async {
    for (var day = 12; day <= 14; day++) {
      clock = DateTime(2026, 10, day, 20);
      await chrono.start();
      clock = DateTime(2026, 10, day + 1, 5);
      await chrono.stop();
    }
    expect(store.sessions.length, 3);
    expect(store.sessions.map((s) => s.id).toSet().length, 3);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 12)), 240);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 13)), 540);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 14)), 540);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 15)), 300);
    final tuesday = planning.getSessions(DateTime(2026, 10, 13));
    expect(tuesday.map((s) => s.startMinutes), [0, 1200]);
    expect(tuesday.map((s) => s.endMinutes), [300, 1440]);
    expect(planning.weeklyWorkedMinutes(DateTime(2026, 10, 12)), 27 * 60);
    await close();
    await open();
    expect(store.sessions.length, 3);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 13)), 540);
  });

  test('editing 09:00 to 08:00 immediately updates active chrono and totals',
      () async {
    clock = DateTime(2026, 10, 12, 9);
    await chrono.start();
    final id = chrono.current!.id;
    await planning.saveSession(
        chrono.current!.copyWith(startTime: DateTime(2026, 10, 12, 8)));
    expect(chrono.current!.id, id);
    expect(chrono.elapsed, const Duration(hours: 1));
    expect(chrono.todayWorkedMinutes, 60);
    expect(planning.dayWorkedMinutes(clock), 60);
    clock = DateTime(2026, 10, 12, 10);
    await chrono.pause();
    clock = DateTime(2026, 10, 12, 10, 15);
    await chrono.resumePause();
    clock = DateTime(2026, 10, 12, 10, 30);
    await chrono.pause();
    clock = DateTime(2026, 10, 12, 10, 45);
    await chrono.resumePause();
    clock = DateTime(2026, 10, 12, 11);
    await chrono.stop();
    expect(store.sessions.single.pauses.length, 2);
    expect(chrono.todayWorkedMinutes, 150);
    expect(planning.dayWorkedMinutes(clock), 150);
    await planning.saveSession(store.sessions.single
        .copyWith(endTime: DateTime(2026, 10, 12, 10, 50)));
    expect(chrono.todayWorkedMinutes, 140);
    await close();
    await open();
    expect(chrono.todayWorkedMinutes, 140);
  });

  test('an open pause survives restart and is split exactly across midnight',
      () async {
    await chrono.start();
    clock = DateTime(2026, 10, 12, 23, 50);
    await chrono.pause();
    clock = DateTime(2026, 10, 13, 0, 10);
    await close();
    await open();
    expect(chrono.isPaused, isTrue);
    expect(chrono.elapsed.inMinutes, 230);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 12)), 230);
    expect(chrono.todayWorkedMinutes, 0);
    clock = DateTime(2026, 10, 13, 0, 20);
    await chrono.resumePause();
    clock = DateTime(2026, 10, 13, 5);
    await chrono.stop();
    expect(store.sessions.length, 1);
    expect(store.sessions.single.workedMinutes, 510);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 12)), 230);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 13)), 280);
  });

  test('Sunday night contributes to two different weekly totals', () async {
    clock = DateTime(2026, 10, 18, 20);
    await chrono.start();
    clock = DateTime(2026, 10, 19, 5);
    await chrono.stop();
    expect(planning.weeklyWorkedMinutes(DateTime(2026, 10, 12)), 240);
    expect(planning.weeklyWorkedMinutes(DateTime(2026, 10, 19)), 300);
    expect(chrono.todayWorkedMinutes, 300);
  });

  test('week spanning month boundary includes previous month', () async {
    clock = DateTime(2026, 10, 31, 20);
    await chrono.start();
    clock = DateTime(2026, 11, 1, 5);
    await chrono.stop();
    expect(
        planning.getSessions(DateTime(2026, 11, 1)).single.workedMinutes, 300);
    expect(planning.weeklyWorkedMinutes(DateTime(2026, 10, 26)), 540);
  });

  test('rapid repeated commands cannot duplicate sessions or pauses', () async {
    await Future.wait([store.start(), store.start()]);
    expect(store.sessions.length, 1);
    clock = clock.add(const Duration(hours: 1));
    await Future.wait([store.pause(), store.pause()]);
    expect(store.active!.pauses.length, 1);
    clock = clock.add(const Duration(minutes: 1));
    await Future.wait([store.stop(), store.stop()]);
    expect(store.sessions.length, 1);
    expect(store.active, isNull);
    await store.start();
    expect(store.sessions.length, 2);
  });

  test('deleting an active overnight session clears both screens and pauses',
      () async {
    await store.start();
    clock = DateTime(2026, 10, 12, 23);
    await store.pause();
    clock = DateTime(2026, 10, 13, 1);
    await planning.deleteSession(store.active!.id!);
    expect(chrono.hasActive, isFalse);
    expect(chrono.todayWorkedMinutes, 0);
    expect(planning.getSessions(DateTime(2026, 10, 12)), isEmpty);
    expect(await db.query('pause_plages'), isEmpty);
  });

  test('overlap and out-of-session pauses are rejected without changing SQLite',
      () async {
    await store.start();
    clock = DateTime(2026, 10, 13, 5);
    await store.stop();
    final original = store.sessions.single;
    await expectLater(
        store.save(ChronoSession(
            startTime: DateTime(2026, 10, 13, 4),
            endTime: DateTime(2026, 10, 13, 5))),
        throwsA(isA<WorkTimeException>()));
    await expectLater(
        store.save(original.copyWith(pauses: [
          PauseEntry(
              start: DateTime(2026, 10, 12, 19),
              end: DateTime(2026, 10, 12, 20)),
        ])),
        throwsA(isA<WorkTimeException>()));
    expect(store.sessions.single.revision, original.revision);
    expect(await db.query('pause_plages'), isEmpty);
    expect((await db.query('chrono_sessions')).length, 1);
  });

  test('a SQLite failure rolls back session and pause changes together',
      () async {
    await store.start();
    clock = DateTime(2026, 10, 12, 22);
    await store.stop();
    final original = store.sessions.single;
    await db.execute(
        "CREATE TRIGGER reject_pause BEFORE INSERT ON pause_plages BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(
        store.save(
            original.copyWith(startTime: DateTime(2026, 10, 12, 19), pauses: [
          PauseEntry(
              start: DateTime(2026, 10, 12, 21),
              end: DateTime(2026, 10, 12, 21, 15))
        ])),
        throwsA(isA<DatabaseException>()));
    await store.reload();
    expect(store.sessions.single.startTime, original.startTime);
    expect(store.sessions.single.revision, original.revision);
    expect(store.sessions.single.pauses, isEmpty);
  });

  test('stale editor cannot overwrite a newly started pause', () async {
    await store.start();
    final snapshot = store.active!;
    clock = DateTime(2026, 10, 12, 21);
    await store.pause();
    await expectLater(
        store.save(snapshot.copyWith(startTime: DateTime(2026, 10, 12, 19))),
        throwsA(isA<WorkTimeException>()));
    expect(chrono.isPaused, isTrue);
  });

  test('short pauses keep their seconds across reload, not 24 hours', () async {
    clock = DateTime(2026, 10, 12, 10, 0, 5);
    await store.start();
    clock = DateTime(2026, 10, 12, 10, 0, 10);
    await store.pause();
    clock = DateTime(2026, 10, 12, 10, 0, 20);
    await store.resume();
    clock = DateTime(2026, 10, 12, 11, 0, 5);
    await store.stop();
    await close();
    await open();
    expect(store.sessions.single.workedDuration(clock),
        const Duration(minutes: 59, seconds: 50));
  });

  test('a complete midnight-to-midnight day counts 24 hours, never zero',
      () async {
    clock = DateTime(2026, 10, 12);
    await store.start();
    clock = DateTime(2026, 10, 14);
    await store.stop();
    expect(store.sessions.length, 1);
    expect(store.dayMinutes(DateTime(2026, 10, 12)), 1440);
    expect(store.dayMinutes(DateTime(2026, 10, 13)), 1440);
    expect(store.dayMinutes(DateTime(2026, 10, 14)), 0);
    expect(
        planning.getSessions(DateTime(2026, 10, 13)).single.endMinutes, 1440);
    expect(
        store.sessions.single.workedDuration(clock), const Duration(hours: 48));
  });

  test('editing a night replaces its daily portions without duplicating rows',
      () async {
    await store.start();
    clock = DateTime(2026, 10, 13, 6);
    await store.stop();
    await planning.saveSession(store.sessions.single.copyWith(
        startTime: DateTime(2026, 10, 12, 19),
        endTime: DateTime(2026, 10, 13, 4)));
    expect(store.sessions.length, 1);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 12)), 300);
    expect(planning.dayWorkedMinutes(DateTime(2026, 10, 13)), 240);
    expect(chrono.todayWorkedMinutes, 240);
    await planning.saveSession(
        store.sessions.single.copyWith(endTime: DateTime(2026, 10, 12, 23)));
    expect(planning.getSessions(DateTime(2026, 10, 13)), isEmpty);
    expect(chrono.todayWorkedMinutes, 0);
  });
  for (final times in [
    ('2026-03-28T20:00:00+01:00', '2026-03-29T05:00:00+02:00', 8),
    ('2026-10-24T20:00:00+02:00', '2026-10-25T05:00:00+01:00', 10),
  ]) {
    test(
        'night duration survives daylight saving and reopening: ${times.$3} hours',
        () async {
      clock = DateTime.parse(times.$1);
      await store.start();
      clock = DateTime.parse(times.$2);
      await store.stop();
      await close();
      await open();
      expect(store.sessions.single.workedDuration(clock).inHours, times.$3);
      expect(store.sessions.single.startTime.toUtc(), DateTime.parse(times.$1));
      expect(store.sessions.single.endTime!.toUtc(), DateTime.parse(times.$2));
    });
  }
}
