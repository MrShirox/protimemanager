import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/planning_provider.dart';
import '../../models/chrono_entry.dart';
import '../../widgets/session_editor.dart';
import '../../models/shift.dart';
import '../../theme/app_theme.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlanningView();
}

class _PlanningView extends StatefulWidget {
  const _PlanningView();
  @override
  State<_PlanningView> createState() => _PlanningViewState();
}

class _PlanningViewState extends State<_PlanningView> {
  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header mois ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: planning.previousMonth),
                  Column(children: [
                    Text(
                      DateFormat('MMMM', 'fr_FR')
                          .format(planning.displayedMonth)
                          .toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    Text(DateFormat('yyyy').format(planning.displayedMonth),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey)),
                  ]),
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: planning.nextMonth),
                ],
              ),
            ),
            _ShiftButtons(isDark: isDark),
            if (planning.error != null || planning.store.loadError != null)
              Text(planning.error ?? planning.store.loadError!,
                  style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                            child: Center(
                                child: Text(
                          e.value,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: e.key >= 5
                                  ? (isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue.shade700)
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600)),
                        ))))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _CalendarGrid(isDark: isDark)),
            _WeekSummary(),
          ],
        ),
      ),
    );
  }
}

// ── Boutons shift ────────────────────────────────────────────────────────────
class _ShiftButtons extends StatelessWidget {
  final bool isDark;
  const _ShiftButtons({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: ShiftType.values.map((type) {
          final selected = planning.selectedShiftType == type;
          final color = type.color;
          return GestureDetector(
            onTap: () => planning.selectShiftType(selected ? null : type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? color
                    : color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: color.withValues(alpha: selected ? 1.0 : 0.4),
                    width: selected ? 2 : 1),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Text(type.label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : isDark
                            ? color
                            : color.withValues(alpha: 0.85),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Grille calendrier ────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final bool isDark;
  const _CalendarGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final month = planning.displayedMonth;
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.60,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
        final date = DateTime(month.year, month.month, dayNum);
        final shiftType = planning.getShiftType(date);
        final sessions = planning.getSessions(date);
        final isToday = _isToday(date);
        final isWeekend = date.weekday >= 6;
        int? weekTotal;
        if (date.weekday == DateTime.sunday) {
          final monday = date.subtract(Duration(days: date.weekday - 1));
          weekTotal = planning.weeklyWorkedMinutes(monday);
        }
        return GestureDetector(
          onTap: () {
            if (planning.selectedShiftType != null) {
              planning.setShiftType(date, planning.selectedShiftType!);
            }
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => _DayPopup(
                date: date,
              ),
            );
          },
          child: _DayCell(
            day: dayNum,
            date: date,
            shiftType: shiftType,
            sessions: sessions,
            isToday: isToday,
            isWeekend: isWeekend,
            isDark: isDark,
            weekTotal: weekTotal,
          ),
        );
      },
    );
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }
}

// ── Cellule jour ─────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final int day;
  final DateTime date;
  final ShiftType? shiftType;
  final List<SessionInfo> sessions;
  final bool isToday, isWeekend, isDark;
  final int? weekTotal;

  const _DayCell({
    required this.day,
    required this.date,
    required this.shiftType,
    required this.sessions,
    required this.isToday,
    required this.isWeekend,
    required this.isDark,
    this.weekTotal,
  });

  String _shortLabel(ShiftType t) {
    switch (t) {
      case ShiftType.matin:
        return 'MAT';
      case ShiftType.journee:
        return 'JOUR';
      case ShiftType.apresMidi:
        return 'APM';
      case ShiftType.variable:
        return 'VAR';
      case ShiftType.nuit:
        return 'NUIT';
      case ShiftType.vacances:
        return 'VAC';
      case ShiftType.repos:
        return 'REP';
    }
  }

  String _hour(int minutes) => minutes < 0
      ? '…'
      : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = shiftType?.color;
    final hasSession = sessions.isNotEmpty;

    Color bgColor = shiftType != null
        ? color!.withValues(alpha: isDark ? 0.28 : 0.18)
        : isDark
            ? const Color(0xFF1E1E2C)
            : Colors.white;

    Color borderColor = isToday
        ? AppTheme.primaryColor
        : shiftType != null
            ? color!.withValues(alpha: 0.45)
            : isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.15);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: isToday ? 2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? AppTheme.primaryColor
                    : isWeekend
                        ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                        : null,
                fontSize: 13,
              )),
          if (shiftType != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                  color: color!.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(_shortLabel(shiftType!),
                  style: const TextStyle(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
          if (hasSession) ...[
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sessions.any((s) => s.isActive)
                    ? Colors.green
                    : color?.withValues(alpha: 0.9) ?? AppTheme.primaryColor,
              ),
            ),
          ],
          for (final session in sessions.take(2))
            Text('${_hour(session.startMinutes)}–${_hour(session.endMinutes)}',
                style: const TextStyle(fontSize: 8), maxLines: 1),
          if (sessions.length > 2)
            Text('+${sessions.length - 2}',
                style: const TextStyle(fontSize: 8)),
          if (weekTotal != null) ...[
            const SizedBox(height: 2),
            Text(
              'Σ ${weekTotal! ~/ 60}h${(weekTotal! % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.teal.shade300 : Colors.teal.shade700,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

// Daily portions keep the id of their complete work session.
class _DayPopup extends StatelessWidget {
  final DateTime date;
  const _DayPopup({required this.date});

  String _time(int minutes) => minutes < 0
      ? 'En cours'
      : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  String _duration(int minutes) =>
      '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _delete(BuildContext context, SessionInfo info) async {
    final provider = context.read<PlanningProvider>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Supprimer cette session ?'),
              content: const Text(
                  'La session entière et ses pauses seront supprimées, y compris les heures des autres jours pour une nuit.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Supprimer')),
              ],
            ));
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.deleteSession(info.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Suppression impossible. Réessaie.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final sessions = planning.getSessions(date);
    return SafeArea(
        child: ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date),
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  'Total travaillé : ${_duration(planning.dayWorkedMinutes(date))}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (planning.getShiftType(date) != null)
                TextButton(
                    onPressed: () async {
                      try {
                        await planning.clearShiftType(date);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Modification impossible.')));
                        }
                      }
                    },
                    child: const Text('Retirer la couleur de journée')),
              if (sessions.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune plage enregistrée.')),
              for (final info in sessions)
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${_time(info.startMinutes)} → ${_time(info.endMinutes)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                            'Travail : ${_duration(info.workedMinutes)} • Pauses : ${info.pauseMinutes} min'),
                        Text(
                            'Session du ${DateFormat('dd/MM à HH:mm').format(info.session.startTime)}'
                            '${info.session.endTime == null ? ' — en cours' : ' au ${DateFormat('dd/MM à HH:mm').format(info.session.endTime!)}'}'),
                        for (final p in info.portion.pauses)
                          Text(
                              'Pause : ${DateFormat('HH:mm').format(p.start)} → ${p.end == null ? 'en cours' : p.end == nextDay(date) ? '24:00' : DateFormat('HH:mm').format(p.end!)}'),
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              onPressed: planning.isBusy
                                  ? null
                                  : () => showSessionEditor(context,
                                      day: date, session: info.session),
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier la session')),
                          TextButton.icon(
                              onPressed: planning.isBusy
                                  ? null
                                  : () => _delete(context, info),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Supprimer')),
                        ]),
                      ]),
                )),
              FilledButton.icon(
                  onPressed: planning.isBusy
                      ? null
                      : () => showSessionEditor(context, day: date),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une session')),
            ],
          )),
    ));
  }
}

class _WeekSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final planning = context.watch<PlanningProvider>();
    final monday = planning.currentWeekMonday;
    final worked = planning.weeklyWorkedMinutes(monday);
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Expanded(
            child: Text('Total semaine en cours',
                style: TextStyle(fontWeight: FontWeight.w500))),
        const SizedBox(width: 8),
        Text('${worked ~/ 60}h${(worked % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.primaryColor)),
      ]),
    );
  }
}
