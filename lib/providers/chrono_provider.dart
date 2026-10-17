import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chrono_entry.dart';
import '../database/db_helper.dart';

class ChronoProvider extends ChangeNotifier {
  ChronoSession? _current;
  Timer? _ticker;
  List<ChronoSession> _todaySessions = [];
  bool _rollingOver = false;
  int _tickCount = 0;

  // Callback temps réel → planning se met à jour immédiatement
  Future<void> Function(String jour)? onPlanningRefresh;

  ChronoSession? get current    => _current;
  bool get isRunning => _current != null && _current!.isRunning && !_current!.isPaused;
  bool get isPaused  => _current?.isPaused ?? false;
  bool get hasActive => _current != null && _current!.isRunning;
  List<ChronoSession> get todaySessions => _todaySessions;

  Duration get elapsed {
    if (_current == null) return Duration.zero;
    if (_current!.isPaused) {
      final pauseStart = _current!.pauses.last.start;
      final raw = pauseStart.difference(_current!.startTime);
      final prevPause = Duration(
          minutes: _current!.pauses
              .take(_current!.pauses.length - 1)
              .fold(0, (s, p) => s + p.durationMinutes));
      return raw - prevPause;
    }
    return DateTime.now().difference(_current!.startTime) -
        Duration(minutes: _current!.totalPauseMinutes);
  }

  int get currentPauseSecs {
    if (!isPaused || _current!.pauses.isEmpty) return 0;
    return DateTime.now().difference(_current!.pauses.last.start).inSeconds;
  }

  int get todayWorkedMinutes {
    final done = _todaySessions
        .where((s) => s.endTime != null)
        .fold(0, (sum, s) => sum + s.workedMinutes);
    return done + (hasActive ? elapsed.inMinutes : 0);
  }

  ChronoProvider() { _loadToday(); }

  Future<void> _loadToday() async {
    final today = _dateStr(DateTime.now());
    final rows = await DBHelper.instance.getSessionsByDate(today);
    _todaySessions = [];
    for (final row in rows) {
      _todaySessions.add(_sessionFromRow(
          row, await DBHelper.instance.getPausePlagesBySession(row['id'] as int)));
    }

    final activeRow = await DBHelper.instance.getActiveSession();
    if (activeRow != null) {
      _current = _sessionFromRow(activeRow,
          await DBHelper.instance.getPausePlagesBySession(activeRow['id'] as int));
      _startTicker();
    }
    notifyListeners();
  }

  Future<void> start() async {
    final now = DateTime.now();
    final jour = _dateStr(now);
    final id = await DBHelper.instance.insertSession(jour, now.toIso8601String());
    _current = ChronoSession(id: id, date: now, startTime: now);
    _todaySessions.add(_current!);
    _startTicker();
    // ✅ Notifie le planning immédiatement
    await onPlanningRefresh?.call(jour);
    notifyListeners();
  }

  Future<void> pause() async {
    if (_current == null || !isRunning) return;
    final now = DateTime.now();
    _current!.pauses.add(PauseEntry(start: now));
    final jour = _dateStr(_current!.date);
    // Une fin à -1 indique une pause encore ouverte; 00:00 reste une vraie heure.
    await DBHelper.instance.insertPausePlage(
      _current!.id!, jour,
      now.hour * 60 + now.minute,
      -1,
    );
    await DBHelper.instance.updateSession(_current!.id!, pauseMinutes: _current!.totalPauseMinutes);
    await onPlanningRefresh?.call(jour);
    notifyListeners();
  }

  Future<void> resumePause() async {
    if (_current == null || !isPaused) return;
    final pause = _current!.pauses.last;
    pause.end = DateTime.now();
    final jour = _dateStr(_current!.date);

    // Met à jour la dernière plage de pause encore ouverte.
    final endMins = pause.end!.hour * 60 + pause.end!.minute;
    final startMins = pause.start.hour * 60 + pause.start.minute;
    await DBHelper.instance.updateLastPausePlage(_current!.id!, startMins, endMins);
    await DBHelper.instance.updateSession(_current!.id!, pauseMinutes: _current!.totalPauseMinutes);
    await onPlanningRefresh?.call(jour);
    notifyListeners();
  }

  Future<void> stop() async {
    if (_current == null) return;
    await _handleDateRollover();
    if (_current == null) return;
    if (isPaused) await resumePause();

    final now = DateTime.now();
    final jour = _dateStr(_current!.date);
    final jourFin = _dateStr(now);

    _current!.endTime = now;
    _ticker?.cancel();

    await DBHelper.instance.updateSession(_current!.id!,
        endTime: now.toIso8601String(), isActive: 0,
        pauseMinutes: _current!.totalPauseMinutes);
    await onPlanningRefresh?.call(jour);
    if (jour != jourFin) await onPlanningRefresh?.call(jourFin);

    _current = null;
    await _loadToday();
  }

  void overridePause(int minutes) {
    if (_current == null) return;
    _current!.pauses.clear();
    if (minutes > 0) {
      final fakeStart = DateTime.now().subtract(Duration(minutes: minutes));
      _current!.pauses.add(PauseEntry(start: fakeStart, end: DateTime.now()));
    }
    DBHelper.instance.updateSession(_current!.id!,
        pauseMinutes: _current!.totalPauseMinutes);
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCount++;
      _handleDateRollover();
      if (_tickCount % 60 == 0 && _current != null) {
        onPlanningRefresh?.call(_dateStr(_current!.date));
      }
      notifyListeners();
    });
  }

  Future<void> _handleDateRollover() async {
    if (_rollingOver || _current == null) return;
    final now = DateTime.now();
    if (_dateStr(now) == _dateStr(_current!.date)) return;
    _rollingOver = true;
    try {
      while (_dateStr(now) != _dateStr(_current!.date)) {
        final old = _current!;
        final midnight = DateTime(old.date.year, old.date.month, old.date.day).add(const Duration(days: 1));
        final wasPaused = old.isPaused;
        if (wasPaused) {
          final pause = old.pauses.last;
          pause.end = midnight;
          await DBHelper.instance.updateLastPausePlage(old.id!,
              pause.start.hour * 60 + pause.start.minute, 0);
        }
        await DBHelper.instance.updateSession(old.id!,
          endTime: midnight.toIso8601String(),
          pauseMinutes: old.totalPauseMinutes,
          isActive: 0,
        );
        await onPlanningRefresh?.call(_dateStr(old.date));
        final newId = await DBHelper.instance.insertSession(
            _dateStr(midnight), midnight.toIso8601String());
        final next = ChronoSession(id: newId, date: midnight, startTime: midnight);
        if (wasPaused) {
          next.pauses.add(PauseEntry(start: midnight));
          await DBHelper.instance.insertPausePlage(newId, _dateStr(midnight), 0, -1);
        }
        _current = next;
        _todaySessions = (await DBHelper.instance.getSessionsByDate(_dateStr(midnight)))
            .map((r) => _sessionFromRow(r)).toList();
      }
      await onPlanningRefresh?.call(_dateStr(_current!.date));
    } finally {
      _rollingOver = false;
    }
  }

  Future<void> reloadActiveSession(int sessionId) async {
    final row = await DBHelper.instance.getActiveSession();
    if (row != null && row['id'] == sessionId) {
      _current = _sessionFromRow(row,
          await DBHelper.instance.getPausePlagesBySession(sessionId));
      notifyListeners();
    } else if (_current?.id == sessionId) {
      _current = null;
      _ticker?.cancel();
      await _loadToday();
    }
  }

  String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);

  ChronoSession _sessionFromRow(Map<String, dynamic> row, [List<Map<String, dynamic>> pauseRows = const []]) {
    final pauses = pauseRows.map((p) {
      final day = DateTime.parse(p['jour'] as String);
      final start = day.add(Duration(minutes: p['startMinutes'] as int));
      final endMinutes = p['endMinutes'] as int;
      DateTime? end;
      if (endMinutes >= 0) {
        end = day.add(Duration(minutes: endMinutes));
        if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
      }
      return PauseEntry(start: start, end: end);
    }).toList();
    return ChronoSession(
      id: row['id'] as int?,
      date: DateTime.parse(row['jour'] as String),
      startTime: DateTime.parse(row['startTime'] as String),
      endTime: row['endTime'] != null
          ? DateTime.parse(row['endTime'] as String)
          : null,
      pauses: pauses,
    );
  }

  Future<int> weeklyMinutes(DateTime monday) async {
    final from = _dateStr(monday);
    final to   = _dateStr(monday.add(const Duration(days: 6)));
    final rows = await DBHelper.instance.getSessionsByWeek(from, to);
    int total = 0;
    for (final row in rows) {
      total += _sessionFromRow(row).workedMinutes;
    }
    return total;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
