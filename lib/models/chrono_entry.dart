class PauseEntry {
  final DateTime start;
  DateTime? end;
  PauseEntry({required this.start, this.end});
  int get durationMinutes {
    if (end == null) return 0;
    return end!.difference(start).inMinutes;
  }
}

class ChronoSession {
  final int? id;
  final DateTime date;
  final DateTime startTime;
  DateTime? endTime;
  final List<PauseEntry> pauses;

  ChronoSession({
    this.id,
    required this.date,
    required this.startTime,
    this.endTime,
    List<PauseEntry>? pauses,
  }) : pauses = pauses ?? [];

  bool get isRunning => endTime == null;
  bool get isPaused  => pauses.isNotEmpty && pauses.last.end == null;

  int get totalPauseMinutes =>
      pauses.fold(0, (s, p) => s + p.durationMinutes);

  int get workedMinutes {
    final end = endTime ?? DateTime.now();
    final total = end.difference(startTime).inMinutes;
    return (total - totalPauseMinutes).clamp(0, 24 * 60);
  }

  ChronoSession copyWith({int? id, DateTime? endTime, List<PauseEntry>? pauses}) =>
      ChronoSession(
        id: id ?? this.id,
        date: date,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
        pauses: pauses ?? this.pauses,
      );
}
