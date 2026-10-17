import 'package:flutter/material.dart';
import '../models/shift.dart';
import '../models/chrono_entry.dart';
import '../database/db_helper.dart';
import '../services/work_sessions.dart';

class SessionInfo {
  final ChronoSession session;
  final ChronoSession portion;
  final DateTime day;
  final DateTime now;
  SessionInfo(this.session, this.portion, this.day, this.now);
  int get id => session.id!;
  int get startMinutes =>
      portion.startTime.hour * 60 + portion.startTime.minute;
  int get endMinutes => portion.endTime == null
      ? -1
      : !portion.endTime!.isBefore(nextDay(day))
          ? 1440
          : portion.endTime!.hour * 60 + portion.endTime!.minute;
  bool get isActive => portion.isRunning;
  int get workedMinutes => portion.workedDuration(now).inMinutes;
  int get pauseMinutes =>
      ((portion.endTime ?? now).difference(portion.startTime) -
              portion.workedDuration(now))
          .inMinutes;
}

class PlanningProvider extends ChangeNotifier {
  final WorkSessions store;
  final DBHelper _db;
  DateTime _displayedMonth;
  DateTime get displayedMonth => _displayedMonth;
  final Map<String, String> _shiftTypes = {};
  ShiftType? _selectedShiftType;
  ShiftType? get selectedShiftType => _selectedShiftType;
  bool get isBusy => store.busy;
  String? error;
  bool _disposed = false;

  PlanningProvider(this.store, {DBHelper? db, bool loadShifts = true})
      : _db = db ?? DBHelper.instance,
        _displayedMonth = store.now() {
    store.addListener(_changed);
    if (loadShifts) loadMonth(_displayedMonth);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ShiftType? getShiftType(DateTime date) {
    final type = _shiftTypes[dayKey(date)];
    if (type == null) return null;
    return ShiftType.values
        .firstWhere((s) => s.name == type, orElse: () => ShiftType.variable);
  }

  List<SessionInfo> getSessions(DateTime date) {
    final now = store.now();
    return store.sessions
        .map((session) {
          final portion = session.portion(date, now);
          return portion == null
              ? null
              : SessionInfo(session, portion, date, now);
        })
        .whereType<SessionInfo>()
        .toList();
  }

  int dayWorkedMinutes(DateTime date) => store.dayMinutes(date);
  int weeklyWorkedMinutes(DateTime monday) => store.weekMinutes(monday);
  DateTime get currentWeekMonday {
    final now = store.now();
    return DateTime(now.year, now.month, now.day - now.weekday + 1);
  }

  void selectShiftType(ShiftType? type) {
    _selectedShiftType = type;
    _changed();
  }

  Future<void> loadMonth(DateTime month) async {
    _displayedMonth = DateTime(month.year, month.month);
    _changed();
    try {
      final rows = await _db.getShiftsByMonth(month.year, month.month);
      final prefix = dayKey(month).substring(0, 7);
      _shiftTypes.removeWhere((key, _) => key.startsWith(prefix));
      for (final row in rows) {
        _shiftTypes[row['jour'] as String] = row['type'] as String;
      }
      error = null;
    } catch (_) {
      error = 'Impossible de charger les couleurs du planning.';
    }
    _changed();
  }

  Future<void> setShiftType(DateTime date, ShiftType type) async {
    try {
      await _db.upsertShiftType(dayKey(date), type.name);
      _shiftTypes[dayKey(date)] = type.name;
      error = null;
    } catch (_) {
      error = 'Impossible d’enregistrer le type de journée.';
    }
    _changed();
  }

  // Removing a colour must never silently erase recorded work hours.
  Future<void> clearShiftType(DateTime date) async {
    final db = await _db.database;
    await db.delete('shifts', where: 'jour = ?', whereArgs: [dayKey(date)]);
    _shiftTypes.remove(dayKey(date));
    _changed();
  }

  Future<void> saveSession(ChronoSession session) => store.save(session);
  Future<void> deleteSession(int id) => store.delete(id);
  void previousMonth() =>
      loadMonth(DateTime(_displayedMonth.year, _displayedMonth.month - 1));
  void nextMonth() =>
      loadMonth(DateTime(_displayedMonth.year, _displayedMonth.month + 1));

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_changed);
    super.dispose();
  }
}
