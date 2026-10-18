import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:protimemanager/database/db_helper.dart';
import 'package:protimemanager/services/work_sessions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final version in [4, 5]) {
    test(
        'migration v$version preserves inventory, constants, sessions and midnight pauses',
        () async {
      final dir = await Directory.systemTemp.createTemp('protime-migration-');
      final path = '${dir.path}/legacy.db';
      var db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE chrono_sessions (id INTEGER PRIMARY KEY, jour TEXT, startTime TEXT, endTime TEXT, pauseMinutes INTEGER, isActive INTEGER)');
              await db.execute(
                  'CREATE TABLE pause_plages (id INTEGER PRIMARY KEY, sessionId INTEGER, jour TEXT, startMinutes INTEGER, endMinutes INTEGER)');
              await db.execute(
                  'CREATE TABLE constantes (id INTEGER PRIMARY KEY, titre TEXT, champs TEXT, createdAt TEXT, updatedAt TEXT)');
              await db.execute(
                  'CREATE TABLE materiels (id INTEGER PRIMARY KEY, nom TEXT)');
              await db.execute(
                  'CREATE TABLE shifts (id INTEGER PRIMARY KEY, jour TEXT UNIQUE, type TEXT)');
              if (version == 5) {
                await db.execute(
                    'CREATE TABLE medications (id INTEGER PRIMARY KEY, nom TEXT, dosage TEXT, quantite INTEGER, datePeremption TEXT, note TEXT)');
                await db.insert('medications', {
                  'id': 8,
                  'nom': 'Médicament conservé',
                  'quantite': 3,
                  'datePeremption': '2027-01-01'
                });
              }
            },
          ));
      await db.insert('constantes', {
        'id': 4,
        'titre': 'Fiche conservée',
        'champs': 'Pouls::72 bpm',
        'createdAt': '2026-10-12'
      });
      await db.insert('materiels', {'id': 5, 'nom': 'Ancien inventaire'});
      await db
          .insert('shifts', {'id': 6, 'jour': '2026-10-12', 'type': 'nuit'});
      await db.insert('chrono_sessions', {
        'id': 1,
        'jour': '2026-10-12',
        'startTime': '2026-10-12T20:00:00',
        'endTime': '2026-10-13T05:00:00',
        'pauseMinutes': 30,
        'isActive': 0
      });
      await db.insert('pause_plages', {
        'id': 1,
        'sessionId': 1,
        'jour': '2026-10-12',
        'startMinutes': 1430,
        'endMinutes': 20
      });
      await db.insert('chrono_sessions', {
        'id': 2,
        'jour': '2026-10-14',
        'startTime': '2026-10-14T21:00:00',
        'endTime': null,
        'pauseMinutes': 0,
        'isActive': 1
      });
      await db.insert('pause_plages', {
        'id': 2,
        'sessionId': 2,
        'jour': '2026-10-14',
        'startMinutes': 1320,
        'endMinutes': version == 4 ? 0 : -1
      });
      await db.insert('chrono_sessions', {
        'id': 3,
        'jour': '2026-10-10',
        'startTime': '2026-10-10T10:00:00',
        'endTime': '2026-10-10T11:00:00',
        'pauseMinutes': 0,
        'isActive': 0
      });
      await db.insert('pause_plages', {
        'id': 3,
        'sessionId': 3,
        'jour': '2026-10-10',
        'startMinutes': 610,
        'endMinutes': 610
      });
      await db.close();
      db = await DBHelper.instance.openAt(path, factory: databaseFactoryFfi);
      final store = WorkSessions(
          database: () async => db,
          clock: () => DateTime(2026, 10, 15, 1),
          startTicker: false);
      try {
        await store.ready;
        expect(store.loadError, isNull);
        expect(await db.getVersion(), 7);
        expect(store.sessions.length, 3);
        expect(store.dayMinutes(DateTime(2026, 10, 12)), 230);
        expect(store.dayMinutes(DateTime(2026, 10, 13)), 280);
        expect(store.dayMinutes(DateTime(2026, 10, 10)), 60);
        expect(store.active!.id, 2);
        expect(store.active!.isPaused, isTrue);
        expect(
            store.active!.workedDuration(DateTime(2026, 10, 15, 1)).inMinutes,
            60);
        expect(
            (await db.query('constantes')).single['champs'], 'Pouls::72 bpm');
        expect(
            (await db.query('materiels')).single['nom'], 'Ancien inventaire');
        expect((await db.query('shifts')).single['type'], 'nuit');
        expect((await db.query('medications')).length, version == 5 ? 1 : 0);
      } finally {
        store.dispose();
        await db.close();
        await dir.delete(recursive: true);
      }
    });
  }
}
