import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Short technical reason shown under user-facing errors, so a screenshot is
/// enough to diagnose a problem on a phone without a debugger.
String errorDetail(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 180 ? '${text.substring(0, 180)}…' : text;
}

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static Future<Database>? _opening;
  DBHelper._init();

  /// Every caller shares one opening attempt; a failure can be retried.
  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      return _database = await (_opening ??= _initDB('protimemanager.db'));
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openAt(path);
  }

  // The factory is injectable so migrations can be verified against real SQLite.
  Future<Database> openAt(String path, {DatabaseFactory? factory}) =>
      (factory ?? databaseFactory).openDatabase(path,
          options: OpenDatabaseOptions(
            version: 8,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onOpen: _repairSchemaSafely,
          ));

  /// Columns the app needs per table. An empty definition marks a column that
  /// cannot be added afterwards (no sensible default value).
  static const _expectedColumns = <String, Map<String, String>>{
    'shifts': {'id': '', 'jour': '', 'type': ''},
    'chrono_sessions': {
      'id': '',
      'jour': '',
      'startTime': '',
      'endTime': 'TEXT',
      'pauseMinutes': 'INTEGER DEFAULT 0',
      'isActive': 'INTEGER DEFAULT 1',
      'revision': 'INTEGER NOT NULL DEFAULT 0',
    },
    'pause_plages': {
      'id': '',
      'sessionId': '',
      'jour': '',
      'startMinutes': '',
      'endMinutes': '',
      'startTime': 'TEXT',
      'endTime': 'TEXT',
      'scheduled': 'INTEGER NOT NULL DEFAULT 0',
      'deductionMinutes': 'INTEGER',
    },
    'constantes': {
      'id': '',
      'titre': '',
      'champs': '',
      'createdAt': '',
      'updatedAt': 'TEXT',
    },
    'materiels': {
      'id': '',
      'nom': '',
      'categorie': 'TEXT',
      'disponible': 'INTEGER DEFAULT 1',
      'quantite': 'INTEGER DEFAULT 1',
      'quantiteMin': 'INTEGER DEFAULT 1',
      'datePeremption': 'TEXT',
      'note': 'TEXT',
    },
    'medications': {
      'id': '',
      'nom': '',
      'dosage': 'TEXT',
      'quantite': 'INTEGER NOT NULL DEFAULT 1',
      'datePeremption': 'TEXT',
      'note': 'TEXT',
    },
  };

  Future<void> _repairSchemaSafely(Database db) async {
    try {
      await repairSchema(db);
    } catch (e) {
      debugPrint('Schema repair failed: $e');
    }
  }

  /// A database left by an older build can miss tables or columns even though
  /// its version number is current. Add what is missing; a table that is
  /// unusable is kept as "<table>_ancien" and recreated, so nothing is erased.
  @visibleForTesting
  Future<void> repairSchema(Database db) async {
    final tables = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'] as String)
        .toSet();
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      for (final entry in _expectedColumns.entries) {
        final table = entry.key;
        if (!tables.contains(table)) {
          await db.execute(_createSql[table]!);
          continue;
        }
        final existing = (await db.rawQuery('PRAGMA table_info($table)'))
            .map((r) => r['name'] as String)
            .toSet();
        final missing = entry.value.entries
            .where((c) => !existing.contains(c.key))
            .toList();
        if (missing.isEmpty) continue;
        if (missing.any((c) => c.value.isEmpty)) {
          var backup = '${table}_ancien';
          for (var i = 2; tables.contains(backup); i++) {
            backup = '${table}_ancien$i';
          }
          await db.execute('CREATE TABLE $backup AS SELECT * FROM $table');
          await db.execute('DROP TABLE $table');
          await db.execute(_createSql[table]!);
          tables.add(backup);
          continue;
        }
        for (final column in missing) {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN ${column.key} ${column.value}');
        }
      }
      await _backfillPauseTimes(db);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// Rebuild exact pause instants from the legacy day/minute columns.
  Future<void> _backfillPauseTimes(DatabaseExecutor db) async {
    final pauses = await db.query('pause_plages', where: 'startTime IS NULL');
    for (final pause in pauses) {
      try {
        final day = DateTime.parse(pause['jour'] as String);
        final startMinutes = pause['startMinutes'] as int;
        final endMinutes = pause['endMinutes'] as int;
        final start = DateTime(day.year, day.month, day.day, startMinutes ~/ 60,
            startMinutes % 60);
        DateTime? end;
        if (endMinutes >= 0) {
          end = DateTime(
              day.year, day.month, day.day, endMinutes ~/ 60, endMinutes % 60);
          if (end.isBefore(start)) {
            end = DateTime(day.year, day.month, day.day + 1, endMinutes ~/ 60,
                endMinutes % 60);
          }
        }
        await db.update(
            'pause_plages',
            {
              'startTime': start.toIso8601String(),
              'endTime': end?.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [pause['id']]);
      } catch (e) {
        debugPrint('Pause ${pause['id']} could not be converted: $e');
      }
    }
  }

  static const _createSql = <String, String>{
    'shifts': '''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL
      )''',
    'chrono_sessions': '''
      CREATE TABLE chrono_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        pauseMinutes INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        revision INTEGER NOT NULL DEFAULT 0
      )''',
    'pause_plages': '''
      CREATE TABLE pause_plages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        jour TEXT NOT NULL,
        startMinutes INTEGER NOT NULL,
        endMinutes INTEGER NOT NULL,
        startTime TEXT,
        endTime TEXT,
        scheduled INTEGER NOT NULL DEFAULT 0,
        deductionMinutes INTEGER,
        FOREIGN KEY (sessionId) REFERENCES chrono_sessions(id) ON DELETE CASCADE
      )''',
    'constantes': '''
      CREATE TABLE constantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        champs TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )''',
    'materiels': '''
      CREATE TABLE materiels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        categorie TEXT,
        disponible INTEGER DEFAULT 1,
        quantite INTEGER DEFAULT 1,
        quantiteMin INTEGER DEFAULT 1,
        datePeremption TEXT,
        note TEXT
      )''',
    'medications': '''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        dosage TEXT,
        quantite INTEGER NOT NULL DEFAULT 1,
        datePeremption TEXT,
        note TEXT
      )''',
  };

  Future<void> _createDB(Database db, int version) async {
    for (final sql in _createSql.values) {
      await db.execute(sql);
    }
  }

  Future<void> _upgradeDB(Database db, int oldV, int newV) async {
    // Keep the user's existing planning, sessions, constants, and inventory.
    // Earlier upgrades dropped every table and therefore erased all data.
    // Missing tables and columns are added by repairSchema when the database
    // opens, which also converts pre-v6 pauses (no startTime) to instants.
    if (oldV < 5) {
      // In v4, zero meant "pause still running". Use -1 so a real 00:00 end
      // can be represented without ambiguity.
      try {
        await db.execute('''
          UPDATE pause_plages SET endMinutes = -1
          WHERE endMinutes = 0
            AND sessionId IN (SELECT id FROM chrono_sessions WHERE isActive = 1)
        ''');
      } catch (e) {
        debugPrint('v5 pause conversion skipped: $e');
      }
    }
  }

  // ── SHIFTS (couleurs) ─────────────────────────────────────────────────────
  Future<int> upsertShiftType(String jour, String type) async {
    final db = await database;
    final existing =
        await db.query('shifts', where: 'jour = ?', whereArgs: [jour]);
    if (existing.isEmpty) {
      return await db.insert('shifts', {'jour': jour, 'type': type});
    } else {
      await db.update('shifts', {'type': type},
          where: 'jour = ?', whereArgs: [jour]);
      return existing.first['id'] as int;
    }
  }

  Future<List<Map<String, dynamic>>> getShiftsByMonth(
      int year, int month) async {
    final db = await database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to = '$year-${month.toString().padLeft(2, '0')}-31';
    return await db.query('shifts',
        where: 'jour >= ? AND jour <= ?', whereArgs: [from, to]);
  }

  Future<void> deleteShift(String jour) async {
    final db = await database;
    await db.delete('shifts', where: 'jour = ?', whereArgs: [jour]);
    await db.delete('pause_plages',
        where: 'sessionId IN (SELECT id FROM chrono_sessions WHERE jour = ?)',
        whereArgs: [jour]);
    await db.delete('chrono_sessions', where: 'jour = ?', whereArgs: [jour]);
  }

  // ── SESSIONS CHRONO ───────────────────────────────────────────────────────
  Future<int> insertSession(String jour, String startTime) async {
    final db = await database;
    return await db.insert('chrono_sessions', {
      'jour': jour,
      'startTime': startTime,
      'endTime': null,
      'pauseMinutes': 0,
      'isActive': 1,
    });
  }

  Future<void> updateSession(int id,
      {String? jour,
      String? startTime,
      String? endTime,
      int? pauseMinutes,
      int? isActive,
      bool clearEndTime = false}) async {
    final db = await database;
    final map = <String, dynamic>{};
    if (jour != null) map['jour'] = jour;
    if (startTime != null) map['startTime'] = startTime;
    if (endTime != null) map['endTime'] = endTime;
    if (clearEndTime) map['endTime'] = null;
    if (pauseMinutes != null) map['pauseMinutes'] = pauseMinutes;
    if (isActive != null) map['isActive'] = isActive;
    if (map.isNotEmpty) {
      await db.update('chrono_sessions', map, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await database;
    final res = await db.query('chrono_sessions',
        where: 'isActive = 1', orderBy: 'startTime DESC', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getSessionsByDate(String jour) async {
    final db = await database;
    return await db.query('chrono_sessions',
        where: 'jour = ?', whereArgs: [jour], orderBy: 'startTime ASC');
  }

  Future<List<Map<String, dynamic>>> getSessionsByWeek(
      String from, String to) async {
    final db = await database;
    return await db.query('chrono_sessions',
        where: 'jour >= ? AND jour <= ? AND isActive = 0',
        whereArgs: [from, to]);
  }

  Future<void> deleteSessionsByDate(String jour) async {
    final db = await database;
    await db.delete('chrono_sessions', where: 'jour = ?', whereArgs: [jour]);
  }

  Future<void> deleteSession(int id) async {
    final db = await database;
    await db.delete('pause_plages', where: 'sessionId = ?', whereArgs: [id]);
    await db.delete('chrono_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertClosedSession(String jour, String startTime, String endTime,
      {int pauseMinutes = 0}) async {
    final db = await database;
    return db.insert('chrono_sessions', {
      'jour': jour,
      'startTime': startTime,
      'endTime': endTime,
      'pauseMinutes': pauseMinutes,
      'isActive': 0,
    });
  }

  // ── PLAGES DE PAUSE ───────────────────────────────────────────────────────
  Future<int> insertPausePlage(
      int sessionId, String jour, int startMin, int endMin) async {
    final db = await database;
    return await db.insert('pause_plages', {
      'sessionId': sessionId,
      'jour': jour,
      'startMinutes': startMin,
      'endMinutes': endMin,
    });
  }

  Future<List<Map<String, dynamic>>> getPausePlagesByDate(String jour) async {
    final db = await database;
    return await db.query('pause_plages',
        where: 'jour = ?', whereArgs: [jour], orderBy: 'startMinutes ASC');
  }

  Future<List<Map<String, dynamic>>> getPausePlagesBySession(
      int sessionId) async {
    final db = await database;
    return db.query('pause_plages',
        where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'id ASC');
  }

  Future<void> deletePausePlagesBySession(int sessionId) async {
    final db = await database;
    await db
        .delete('pause_plages', where: 'sessionId = ?', whereArgs: [sessionId]);
  }

  Future<void> deletePausePlagesByDate(String jour) async {
    final db = await database;
    await db.delete('pause_plages', where: 'jour = ?', whereArgs: [jour]);
  }

  // Met à jour une pause en cours (endMinutes=-1 est le marqueur ouvert).
  Future<void> updateLastPausePlage(
      int sessionId, int startMins, int endMins) async {
    final db = await database;
    await db.update(
      'pause_plages',
      {'endMinutes': endMins},
      where: 'sessionId = ? AND startMinutes = ? AND endMinutes = -1',
      whereArgs: [sessionId, startMins],
    );
  }

  // ── CONSTANTES ────────────────────────────────────────────────────────────
  Future<int> insertConstante(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('constantes', row);
  }

  Future<List<Map<String, dynamic>>> getAllConstantes() async {
    final db = await database;
    return await db.query('constantes', orderBy: 'createdAt DESC');
  }

  Future<int> updateConstante(Map<String, dynamic> row) async {
    final db = await database;
    return await db
        .update('constantes', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteConstante(int id) async {
    final db = await database;
    return await db.delete('constantes', where: 'id = ?', whereArgs: [id]);
  }

  // ── MATERIEL ──────────────────────────────────────────────────────────────
  Future<int> insertMateriel(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('materiels', row);
  }

  Future<List<Map<String, dynamic>>> getAllMateriels() async {
    final db = await database;
    return await db.query('materiels', orderBy: 'nom ASC');
  }

  Future<int> updateMateriel(Map<String, dynamic> row) async {
    final db = await database;
    return await db
        .update('materiels', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteMateriel(int id) async {
    final db = await database;
    return await db.delete('materiels', where: 'id = ?', whereArgs: [id]);
  }

  // ── MEDICAMENTS ───────────────────────────────────────────────────────────
  Future<int> insertMedication(Map<String, dynamic> row) async {
    final db = await database;
    return db.insert('medications', row);
  }

  Future<List<Map<String, dynamic>>> getAllMedications() async {
    final db = await database;
    return db.query('medications',
        orderBy: 'datePeremption ASC, nom COLLATE NOCASE ASC');
  }

  Future<int> updateMedication(Map<String, dynamic> row) async {
    final db = await database;
    return db
        .update('medications', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteMedication(int id) async {
    final db = await database;
    return db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}
