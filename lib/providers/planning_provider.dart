import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../database/db_helper.dart';

// Structure légère pour une session affichée dans le calendrier
class SessionInfo {
  final int id;
  final int startMinutes;
  final int endMinutes;
  final int pauseMinutes;
  final bool isActive;
  final List<PausePlageInfo> pauses;

  SessionInfo({
    required this.id,
    required this.startMinutes,
    required this.endMinutes,
    required this.pauseMinutes,
    required this.isActive,
    required this.pauses,
  });

  int get workedMinutes {
    if (endMinutes == -1) {
      // Session active : calcul en temps réel
      final nowMins = DateTime.now().hour * 60 + DateTime.now().minute;
      int total = nowMins - startMinutes;
      if (total < 0) total += 24 * 60;
      return (total - pauseMinutes).clamp(0, 24 * 60);
    }
    int total = endMinutes - startMinutes;
    if (total < 0) total += 24 * 60;
    return (total - pauseMinutes).clamp(0, 24 * 60);
  }
}

class PausePlageInfo {
  final int startMinutes;
  final int endMinutes;
  PausePlageInfo(this.startMinutes, this.endMinutes);
  int get durationMinutes {
    int d = endMinutes - startMinutes;
    return d < 0 ? d + 24 * 60 : d;
  }
}

class PlanningProvider extends ChangeNotifier {
  Future<void> Function(int sessionId)? onSessionChanged;
  DateTime _displayedMonth = DateTime.now();
  DateTime get displayedMonth => _displayedMonth;

  // Type de shift (couleur) par jour
  final Map<String, String> _shiftTypes = {};

  // Sessions par jour (depuis BDD, persistées)
  final Map<String, List<SessionInfo>> _sessions = {};

  ShiftType? _selectedShiftType;
  ShiftType? get selectedShiftType => _selectedShiftType;

  PlanningProvider() { loadMonth(_displayedMonth); }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  ShiftType? getShiftType(DateTime date) {
    final t = _shiftTypes[_key(date)];
    if (t == null) return null;
    return ShiftType.values.firstWhere((s) => s.name == t,
        orElse: () => ShiftType.variable);
  }

  List<SessionInfo> getSessions(DateTime date) =>
      _sessions[_key(date)] ?? [];

  void selectShiftType(ShiftType? type) {
    _selectedShiftType = type;
    notifyListeners();
  }

  Future<void> loadMonth(DateTime month) async {
    _displayedMonth = month;
    final rows = await DBHelper.instance.getShiftsByMonth(month.year, month.month);
    for (final row in rows) {
      _shiftTypes[row['jour'] as String] = row['type'] as String;
    }
    // Charge les sessions du mois
    for (int d = 1; d <= 31; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.month != month.month) break;
      await _loadSessionsForDate(date);
    }
    final monday = currentWeekMonday;
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      if (date.month != month.month || date.year != month.year) {
        await _loadSessionsForDate(date);
      }
    }
    notifyListeners();
  }

  // ✅ Charge depuis BDD les sessions + pauses d'un jour
  Future<void> _loadSessionsForDate(DateTime date) async {
    final jour = _key(date);
    final sessionRows = await DBHelper.instance.getSessionsByDate(jour);
    final pauseRows = await DBHelper.instance.getPausePlagesByDate(jour);

    _sessions[jour] = sessionRows.map((row) {
      final id = row['id'] as int;
      final start = DateTime.parse(row['startTime'] as String);
      final isActive = (row['isActive'] as int) == 1;
      // Si actif, pas de fin → on met -1 pour signaler "en cours"
      final endMins = isActive
          ? -1
          : row['endTime'] != null
              ? DateTime.parse(row['endTime'] as String).hour * 60 +
                DateTime.parse(row['endTime'] as String).minute
              : -1;

      // Pauses liées à cette session (pause en cours = endMinutes 0)
      final sessionPauses = pauseRows
          .where((p) => p['sessionId'] == id)
          .map((p) => PausePlageInfo(
              p['startMinutes'] as int,
              p['endMinutes'] as int))
          .toList();

      return SessionInfo(
        id: id,
        startMinutes: start.hour * 60 + start.minute,
        endMinutes: endMins,
        pauseMinutes: row['pauseMinutes'] as int,
        isActive: isActive,
        pauses: sessionPauses,
      );
    }).toList();
  }

  // ✅ Appelé par le chrono en temps réel
  Future<void> refreshDay(String jour) async {
    final date = DateTime.parse(jour);
    await _loadSessionsForDate(date);
    notifyListeners();
  }

  // Colorier une case
  Future<void> setShiftType(DateTime date, ShiftType type) async {
    final jour = _key(date);
    await DBHelper.instance.upsertShiftType(jour, type.name);
    _shiftTypes[jour] = type.name;
    notifyListeners();
  }

  // Supprimer shift + sessions
  Future<void> deleteShift(DateTime date) async {
    final jour = _key(date);
    await DBHelper.instance.deleteShift(jour);
    _shiftTypes.remove(jour);
    _sessions.remove(jour);
    notifyListeners();
  }

  // Mise à jour manuelle d'une session depuis le popup
  Future<void> updateSessionManual({
    required DateTime date,
    required int? sessionId,
    required int startMinutes,
    required int? endMinutes,
    required List<PausePlageInfo> pauses,
  }) async {
    final jour = _key(date);
    final startDt = DateTime(date.year, date.month, date.day,
        startMinutes ~/ 60, startMinutes % 60);
    DateTime? endDt;
    if (endMinutes != null) {
      endDt = DateTime(date.year, date.month, date.day,
          endMinutes ~/ 60, endMinutes % 60);
      if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));
    }

    if (sessionId == null && endDt == null) return;
    final pauseIntervals = pauses.map((p) {
      var ps = DateTime(date.year, date.month, date.day,
          p.startMinutes ~/ 60, p.startMinutes % 60);
      while (ps.isBefore(startDt)) ps = ps.add(const Duration(days: 1));
      var pe = DateTime(date.year, date.month, date.day,
          p.endMinutes < 0 ? 0 : p.endMinutes ~/ 60,
          p.endMinutes < 0 ? 0 : p.endMinutes % 60);
      if (p.endMinutes < 0) pe = endDt ?? ps;
      while (!pe.isAfter(ps)) pe = pe.add(const Duration(days: 1));
      return (start: ps, end: pe);
    }).toList();

    int? savedId = sessionId;
    if (endDt == null) {
      // Une séance active conserve son identifiant et reste active.
      final pauseTotal = pauses.fold<int>(0,
          (sum, p) => sum + (p.endMinutes < 0 ? 0 : p.durationMinutes));
      await DBHelper.instance.updateSession(savedId!, jour: jour,
        startTime: startDt.toIso8601String(), clearEndTime: true,
        pauseMinutes: pauseTotal, isActive: 1);
      await DBHelper.instance.deletePausePlagesBySession(savedId);
      for (final p in pauses) {
        await DBHelper.instance.insertPausePlage(savedId, jour, p.startMinutes, p.endMinutes);
      }
    } else {
      var segmentStart = startDt;
      var isFirst = true;
      while (segmentStart.isBefore(endDt)) {
        final midnight = DateTime(segmentStart.year, segmentStart.month, segmentStart.day)
            .add(const Duration(days: 1));
        final segmentEnd = endDt.isBefore(midnight) ? endDt : midnight;
        final segmentJour = _key(segmentStart);
        final cuts = pauseIntervals.map((p) {
          final a = p.start.isAfter(segmentStart) ? p.start : segmentStart;
          final b = p.end.isBefore(segmentEnd) ? p.end : segmentEnd;
          return (start: a, end: b);
        }).where((p) => p.end.isAfter(p.start)).toList();
        final pauseForChunk = cuts.fold<int>(0, (sum, p) => sum + p.end.difference(p.start).inMinutes);
        if (isFirst && savedId != null) {
          await DBHelper.instance.updateSession(savedId,
            jour: segmentJour, startTime: segmentStart.toIso8601String(),
            endTime: segmentEnd.toIso8601String(), pauseMinutes: pauseForChunk,
            isActive: 0);
          await DBHelper.instance.deletePausePlagesBySession(savedId);
        } else {
          savedId = await DBHelper.instance.insertClosedSession(
            segmentJour, segmentStart.toIso8601String(), segmentEnd.toIso8601String(),
            pauseMinutes: pauseForChunk);
        }
        for (final p in cuts) {
          await DBHelper.instance.insertPausePlage(savedId!, segmentJour,
            p.start.hour * 60 + p.start.minute,
            p.end.hour * 60 + p.end.minute);
        }
        segmentStart = segmentEnd;
        isFirst = false;
      }
    }
    if (endDt == null) {
      await _loadSessionsForDate(date);
    } else {
      for (var d = DateTime(date.year, date.month, date.day);
          !d.isAfter(endDt); d = d.add(const Duration(days: 1))) {
        await _loadSessionsForDate(d);
      }
    }
    if (sessionId != null) await onSessionChanged?.call(sessionId);
    notifyListeners();
  }

  Future<void> deleteSession(DateTime date, int sessionId) async {
    await DBHelper.instance.deleteSession(sessionId);
    await _loadSessionsForDate(date);
    await onSessionChanged?.call(sessionId);
    notifyListeners();
  }

  void previousMonth() =>
      loadMonth(DateTime(_displayedMonth.year, _displayedMonth.month - 1));
  void nextMonth() =>
      loadMonth(DateTime(_displayedMonth.year, _displayedMonth.month + 1));

  // Total heures semaine
  int weeklyWorkedMinutes(DateTime monday) {
    int total = 0;
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final sessions = getSessions(day);
      if (sessions.isEmpty) continue;

      for (final s in sessions) {
        // Les séances sont rattachées au jour où elles commencent. Une nuit
        // du dimanche au lundi ne compte donc ici que jusqu'à minuit.
        final minutesBeforeMidnight = 24 * 60 - s.startMinutes;
        total += (s.workedMinutes < minutesBeforeMidnight
            ? s.workedMinutes
            : minutesBeforeMidnight).clamp(0, 24 * 60);
      }
    }
    return total;
  }

  DateTime get currentWeekMonday {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }
}
