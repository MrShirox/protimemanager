DateTime dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);
String dayKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class PauseEntry {
  final DateTime start;
  final DateTime? end;
  final bool scheduled;
  const PauseEntry({required this.start, this.end, this.scheduled = false});
  bool activeAt(DateTime now) =>
      !start.isAfter(now) && (end == null || end!.isAfter(now));
  int get durationMinutes => end == null ? 0 : end!.difference(start).inMinutes;
}

class ChronoSession {
  final int? id;
  final int revision;
  final DateTime startTime;
  final DateTime? endTime;
  final List<PauseEntry> pauses;
  DateTime get date => dayStart(startTime);

  ChronoSession(
      {this.id,
      this.revision = 0,
      required this.startTime,
      this.endTime,
      List<PauseEntry> pauses = const []})
      : pauses = List.unmodifiable(pauses);

  bool get isRunning => endTime == null;
  bool get isPaused => isPausedAt(DateTime.now());
  bool isPausedAt(DateTime now) =>
      isRunning && pauses.any((p) => p.activeAt(now));
  int get totalPauseMinutes => pauses
      .fold<Duration>(Duration.zero,
          (total, p) => total + (p.end?.difference(p.start) ?? Duration.zero))
      .inMinutes;
  int get workedMinutes => workedDuration(DateTime.now()).inMinutes;

  Duration workedDuration(DateTime now, {DateTime? from, DateTime? to}) {
    var start = startTime;
    var end = endTime ?? now;
    if (from != null && from.isAfter(start)) start = from;
    if (to != null && to.isBefore(end)) end = to;
    if (!end.isAfter(start)) return Duration.zero;
    // Merge intersections defensively, including overlapping legacy pauses.
    final intervals = pauses
        .map((pause) {
          final a = pause.start.isAfter(start) ? pause.start : start;
          final pauseEnd = pause.end ?? now;
          final b = pauseEnd.isBefore(end) ? pauseEnd : end;
          return (start: a, end: b);
        })
        .where((p) => p.end.isAfter(p.start))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    Duration deducted = Duration.zero;
    DateTime? lastStart, lastEnd;
    for (final p in intervals) {
      if (lastEnd == null || p.start.isAfter(lastEnd)) {
        if (lastEnd != null) deducted += lastEnd.difference(lastStart!);
        lastStart = p.start;
        lastEnd = p.end;
      } else if (p.end.isAfter(lastEnd)) {
        lastEnd = p.end;
      }
    }
    if (lastEnd != null) deducted += lastEnd.difference(lastStart!);
    return end.difference(start) - deducted;
  }

  ChronoSession? portion(DateTime day, DateTime now) {
    final from = dayStart(day);
    final to = nextDay(day);
    final end = endTime ?? now;
    if (!startTime.isBefore(to) || !end.isAfter(from)) return null;
    final a = startTime.isAfter(from) ? startTime : from;
    final b = end.isBefore(to) ? end : to;
    final open = isRunning && now.isBefore(to);
    return ChronoSession(
        id: id,
        revision: revision,
        startTime: a,
        endTime: open ? null : b,
        pauses: pauses
            .map((p) {
              final ps = p.start.isAfter(a) ? p.start : a;
              final pe = (p.end ?? now).isBefore(b) ? (p.end ?? now) : b;
              return PauseEntry(
                  start: ps, end: p.end == null && open ? null : pe);
            })
            .where((p) => (p.end ?? now).isAfter(p.start))
            .toList());
  }

  ChronoSession copyWith(
          {int? id,
          int? revision,
          DateTime? startTime,
          DateTime? endTime,
          bool clearEnd = false,
          List<PauseEntry>? pauses}) =>
      ChronoSession(
          id: id ?? this.id,
          revision: revision ?? this.revision,
          startTime: startTime ?? this.startTime,
          endTime: clearEnd ? null : endTime ?? this.endTime,
          pauses: pauses ?? this.pauses);
}
