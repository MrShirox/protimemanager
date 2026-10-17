import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/chrono_entry.dart';

class WorkTimeException implements Exception {
  final String message;
  const WorkTimeException(this.message);
  @override
  String toString() => message;
}

/// Shared source of truth for both screens. Midnight never writes/splits rows.
class WorkSessions extends ChangeNotifier with WidgetsBindingObserver {
  final Future<Database> Function() _database;
  final DateTime Function() now;
  List<ChronoSession> _sessions = [];
  List<ChronoSession> get sessions => List.unmodifiable(_sessions);
  late final Future<void> ready;
  Future<void> _tail = Future.value();
  Timer? _ticker;
  int _pending = 0;
  bool _disposed = false;
  bool loading = true;
  String? loadError;
  bool get busy => loading || _pending > 0;

  WorkSessions(
      {Future<Database> Function()? database,
      DateTime Function()? clock,
      bool startTicker = true})
      : _database = database ?? (() => DBHelper.instance.database),
        now = clock ?? DateTime.now {
    ready = _load();
    if (startTicker) {
      WidgetsBinding.instance.addObserver(this);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<List<ChronoSession>> _read(DatabaseExecutor db) async {
    final rows = await db.query('chrono_sessions', orderBy: 'startTime ASC');
    final pauseRows =
        await db.query('pause_plages', orderBy: 'startTime ASC, id ASC');
    return rows.map((row) {
      final start = DateTime.parse(row['startTime'] as String).toLocal();
      final end = row['endTime'] == null
          ? null
          : DateTime.parse(row['endTime'] as String).toLocal();
      final pauses =
          pauseRows.where((p) => p['sessionId'] == row['id']).map((p) {
        return PauseEntry(
            start: DateTime.parse(p['startTime'] as String).toLocal(),
            end: p['endTime'] == null
                ? null
                : DateTime.parse(p['endTime'] as String).toLocal());
      }).toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      // Preserve old manually entered totals that had no pause intervals.
      // Their actual position is unknown; place them at the beginning.
      final oldMinutes = row['pauseMinutes'] as int? ?? 0;
      if (pauses.isEmpty && oldMinutes > 0) {
        var pauseEnd = start.add(Duration(minutes: oldMinutes));
        if (pauseEnd.isAfter(end ?? now())) pauseEnd = end ?? now();
        pauses.add(PauseEntry(start: start, end: pauseEnd));
      }
      return ChronoSession(
          id: row['id'] as int,
          revision: row['revision'] as int,
          startTime: start,
          endTime: end,
          pauses: pauses);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _load() async {
    try {
      final db = await _database();
      _sessions = await db.transaction((txn) => _read(txn));
      loadError = null;
    } catch (_) {
      loadError =
          'Impossible de charger les horaires. Réessaie avant de démarrer.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> reload() => _enqueue(() async {
        await _load();
      });

  Future<void> _enqueue(Future<void> Function() action) {
    _pending++;
    _notify();
    final result = _tail.then((_) async {
      await ready;
      try {
        await action();
      } finally {
        _pending--;
        _notify();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _change(
          Future<void> Function(Transaction, List<ChronoSession>) action) =>
      _enqueue(() async {
        final db = await _database();
        final updated = await db.transaction((txn) async {
          final rows = await _read(txn);
          await action(txn, rows);
          return _read(txn);
        });
        _sessions = updated;
        loadError = null;
      });

  ChronoSession? get active {
    final active = _sessions.where((s) => s.isRunning);
    return active.isEmpty ? null : active.last;
  }

  static ChronoSession? _active(List<ChronoSession> rows) {
    final active = rows.where((s) => s.isRunning).toList();
    if (active.length > 1) {
      throw const WorkTimeException(
          'Plusieurs anciennes sessions sont actives. Termine ou supprime les doublons dans le planning.');
    }
    return active.isEmpty ? null : active.single;
  }

  Future<void> start() => _change((db, rows) async {
        if (_active(rows) != null) return;
        final session = ChronoSession(startTime: now());
        _validate(session, rows);
        await _write(db, session);
      });

  Future<void> pause() => _change((db, rows) async {
        final current = _active(rows);
        if (current == null || current.isPaused) return;
        final updated = current
            .copyWith(pauses: [...current.pauses, PauseEntry(start: now())]);
        _validate(updated, rows);
        await _write(db, updated);
      });

  Future<void> resume() => _change((db, rows) async {
        final current = _active(rows);
        if (current == null || !current.isPaused) return;
        final updated = current.copyWith(
            pauses: current.pauses
                .map((p) =>
                    p.end == null ? PauseEntry(start: p.start, end: now()) : p)
                .toList());
        _validate(updated, rows);
        await _write(db, updated);
      });

  Future<void> stop() => _change((db, rows) async {
        final current = _active(rows);
        if (current == null) return;
        final end = now();
        final updated = current.copyWith(
            endTime: end,
            pauses: current.pauses
                .map((p) =>
                    p.end == null ? PauseEntry(start: p.start, end: end) : p)
                .toList());
        _validate(updated, rows);
        await _write(db, updated);
      });

  Future<void> save(ChronoSession session) => _change((db, rows) async {
        if (session.id != null) {
          final existing = rows.where((s) => s.id == session.id).toList();
          if (existing.isEmpty ||
              existing.single.revision != session.revision) {
            throw const WorkTimeException(
                'Cette session a changé. Ferme cette fenêtre et rouvre-la avant de modifier.');
          }
        } else if (session.isRunning) {
          throw const WorkTimeException(
              'Pour ajouter une session manuelle, renseigne aussi sa fin.');
        }
        _validate(session, rows);
        await _write(db, session);
      });

  void _validate(ChronoSession session, List<ChronoSession> rows) {
    final clock = now();
    final end = session.endTime ?? clock;
    if (session.startTime.isAfter(clock) ||
        end.isBefore(session.startTime) ||
        end.isAfter(clock)) {
      throw const WorkTimeException(
          'Vérifie les dates : la fin doit suivre le début et les horaires travaillés ne peuvent pas être dans le futur.');
    }
    for (final other
        in rows.where((s) => s.id != session.id || session.id == null)) {
      if (session.isRunning && other.isRunning) {
        throw const WorkTimeException('Une seule session peut être en cours.');
      }
      if (session.startTime.isBefore(other.endTime ?? clock) &&
          other.startTime.isBefore(end)) {
        throw const WorkTimeException(
            'Ces horaires chevauchent une autre session.');
      }
    }
    final pauses = [...session.pauses]
      ..sort((a, b) => a.start.compareTo(b.start));
    DateTime? previousEnd;
    for (var i = 0; i < pauses.length; i++) {
      final p = pauses[i];
      final pe = p.end ?? clock;
      if (p.start.isBefore(session.startTime) ||
          pe.isBefore(p.start) ||
          pe.isAfter(end) ||
          p.start.isAfter(clock) ||
          (p.end == null && (!session.isRunning || i != pauses.length - 1))) {
        throw const WorkTimeException(
            'Chaque pause doit être comprise dans la session. Seule la dernière pause d’une session en cours peut rester ouverte.');
      }
      if (previousEnd != null && p.start.isBefore(previousEnd)) {
        throw const WorkTimeException(
            'Deux pauses ne peuvent pas se chevaucher.');
      }
      previousEnd = pe;
    }
  }

  Future<void> _write(Transaction db, ChronoSession session) async {
    final values = <String, Object?>{
      'jour': dayKey(session.startTime),
      'startTime': session.startTime.toUtc().toIso8601String(),
      'endTime': session.endTime?.toUtc().toIso8601String(),
      'pauseMinutes': session.totalPauseMinutes,
      'isActive': session.isRunning ? 1 : 0,
      'revision': session.revision + 1,
    };
    final id = session.id ?? await db.insert('chrono_sessions', values);
    if (session.id != null) {
      await db
          .update('chrono_sessions', values, where: 'id = ?', whereArgs: [id]);
      await db.delete('pause_plages', where: 'sessionId = ?', whereArgs: [id]);
    }
    for (final pause in session.pauses) {
      await db.insert('pause_plages', {
        'sessionId': id,
        'jour': dayKey(pause.start),
        'startMinutes': pause.start.hour * 60 + pause.start.minute,
        'endMinutes':
            pause.end == null ? -1 : pause.end!.hour * 60 + pause.end!.minute,
        'startTime': pause.start.toUtc().toIso8601String(),
        'endTime': pause.end?.toUtc().toIso8601String(),
      });
    }
  }

  Future<void> delete(int id) => _change((db, _) async {
        await db
            .delete('pause_plages', where: 'sessionId = ?', whereArgs: [id]);
        await db.delete('chrono_sessions', where: 'id = ?', whereArgs: [id]);
      });

  List<ChronoSession> portions(DateTime day) => _sessions
      .map((s) => s.portion(day, now()))
      .whereType<ChronoSession>()
      .toList();

  int dayMinutes(DateTime day) => _sessions
      .fold<Duration>(
          Duration.zero,
          (sum, s) =>
              sum +
              s.workedDuration(now(), from: dayStart(day), to: nextDay(day)))
      .inMinutes;

  int weekMinutes(DateTime monday) {
    var total = 0;
    for (var i = 0; i < 7; i++) {
      total += dayMinutes(DateTime(monday.year, monday.month, monday.day + i));
    }
    return total;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reload());
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
