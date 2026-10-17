import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('protimemanager.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 5,
        onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Couleurs planning
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL
      )
    ''');

    // Sessions chrono (une par plage de travail)
    await db.execute('''
      CREATE TABLE chrono_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jour TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        pauseMinutes INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Plages de pause (liées à une session)
    await db.execute('''
      CREATE TABLE pause_plages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        jour TEXT NOT NULL,
        startMinutes INTEGER NOT NULL,
        endMinutes INTEGER NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES chrono_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE constantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titre TEXT NOT NULL,
        champs TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE materiels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        categorie TEXT,
        disponible INTEGER DEFAULT 1,
        quantite INTEGER DEFAULT 1,
        quantiteMin INTEGER DEFAULT 1,
        datePeremption TEXT,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        dosage TEXT,
        quantite INTEGER NOT NULL DEFAULT 1,
        datePeremption TEXT,
        note TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldV, int newV) async {
    // Keep the user's existing planning, sessions, constants, and inventory.
    // Earlier upgrades dropped every table and therefore erased all data.
    if (oldV < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS medications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nom TEXT NOT NULL,
          dosage TEXT,
          quantite INTEGER NOT NULL DEFAULT 1,
          datePeremption TEXT,
          note TEXT
        )
      ''');
      // In v4, zero meant "pause still running". Use -1 so a real 00:00 end
      // can be represented without ambiguity.
      await db.execute('''
        UPDATE pause_plages SET endMinutes = -1
        WHERE endMinutes = 0
          AND sessionId IN (SELECT id FROM chrono_sessions WHERE isActive = 1)
      ''');
    }
  }

  // ── SHIFTS (couleurs) ─────────────────────────────────────────────────────
  Future<int> upsertShiftType(String jour, String type) async {
    final db = await database;
    final existing = await db.query('shifts', where: 'jour = ?', whereArgs: [jour]);
    if (existing.isEmpty) {
      return await db.insert('shifts', {'jour': jour, 'type': type});
    } else {
      await db.update('shifts', {'type': type}, where: 'jour = ?', whereArgs: [jour]);
      return existing.first['id'] as int;
    }
  }

  Future<List<Map<String, dynamic>>> getShiftsByMonth(int year, int month) async {
    final db = await database;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to   = '$year-${month.toString().padLeft(2, '0')}-31';
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

  Future<void> updateSession(int id, {String? jour, String? startTime, String? endTime, int? pauseMinutes, int? isActive, bool clearEndTime = false}) async {
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

  Future<List<Map<String, dynamic>>> getSessionsByWeek(String from, String to) async {
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
  Future<int> insertPausePlage(int sessionId, String jour, int startMin, int endMin) async {
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

  Future<List<Map<String, dynamic>>> getPausePlagesBySession(int sessionId) async {
    final db = await database;
    return db.query('pause_plages', where: 'sessionId = ?', whereArgs: [sessionId], orderBy: 'id ASC');
  }

  Future<void> deletePausePlagesBySession(int sessionId) async {
    final db = await database;
    await db.delete('pause_plages', where: 'sessionId = ?', whereArgs: [sessionId]);
  }

  Future<void> deletePausePlagesByDate(String jour) async {
    final db = await database;
    await db.delete('pause_plages', where: 'jour = ?', whereArgs: [jour]);
  }

  // Met à jour une pause en cours (endMinutes=-1 est le marqueur ouvert).
  Future<void> updateLastPausePlage(int sessionId, int startMins, int endMins) async {
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
    return await db.update('constantes', row,
        where: 'id = ?', whereArgs: [row['id']]);
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
    return await db.update('materiels', row,
        where: 'id = ?', whereArgs: [row['id']]);
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
    return db.query('medications', orderBy: 'datePeremption ASC, nom COLLATE NOCASE ASC');
  }

  Future<int> updateMedication(Map<String, dynamic> row) async {
    final db = await database;
    return db.update('medications', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteMedication(int id) async {
    final db = await database;
    return db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}
    if (startTime != null) map['startTime'] = startTime;
    if (jour != null) map['jour'] = jour;
