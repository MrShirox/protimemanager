import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chrono_provider.dart';
import '../../providers/planning_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/session_editor.dart';
import '../../widgets/work_controls.dart';

class ChronoScreen extends StatelessWidget {
  const ChronoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chrono = context.watch<ChronoProvider>();
    final planning = context.watch<PlanningProvider>();
    final theme = Theme.of(context);
    final monday = planning.currentWeekMonday;
    final weekMin = planning.weeklyWorkedMinutes(monday);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Chronomètre',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),

              if (chrono.error != null || chrono.loadError != null) ...[
                Text(chrono.error ?? chrono.loadError!,
                    style: TextStyle(color: theme.colorScheme.error)),
                TextButton(
                    onPressed: chrono.isBusy ? null : chrono.retry,
                    child: const Text('Réessayer')),
              ],
              if (chrono.isBusy) const LinearProgressIndicator(),

              // ── Grand affichage ──
              _ChronoRing(chrono: chrono),
              const SizedBox(height: 20),

              // ── Temps de pause en défilement ──
              if (chrono.hasActive) _PauseDisplay(chrono: chrono),
              const SizedBox(height: 16),

              // ── Total semaine ──
              _StatBar(
                icon: Icons.date_range_rounded,
                label: 'Total semaine',
                value: _fmt(weekMin),
                color: AppTheme.accentColor,
              ),
              const SizedBox(height: 28),

              // ── Boutons ──
              AbsorbPointer(
                absorbing: chrono.isBusy || chrono.loadError != null,
                child: Opacity(
                    opacity: chrono.isBusy ? .5 : 1,
                    child: const WorkControls()),
              ),
              const SizedBox(height: 20),

              // ── Sessions du jour ──
              if (chrono.todaySessions.isNotEmpty)
                _SessionsList(chrono: chrono),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}

// ── Anneau chrono ─────────────────────────────────────────────────────────────
class _ChronoRing extends StatelessWidget {
  final ChronoProvider chrono;
  const _ChronoRing({required this.chrono});

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = chrono.elapsed;
    final isPaused = chrono.isPaused;
    final isRunning = chrono.isRunning;

    Color color;
    if (isPaused) {
      color = Colors.orange;
    } else if (isRunning) {
      color = AppTheme.primaryColor;
    } else {
      color = Colors.grey.shade600;
    }

    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        color: color.withValues(alpha: 0.07),
        boxShadow: isRunning && !isPaused
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _fmtDuration(elapsed),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPaused
                ? '⏸ En pause'
                : isRunning
                    ? '▶ En cours'
                    : '⏹ Arrêté',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Affichage pause en temps réel ─────────────────────────────────────────────
class _PauseDisplay extends StatelessWidget {
  final ChronoProvider chrono;
  const _PauseDisplay({required this.chrono});

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isPaused = chrono.isPaused;
    final current = chrono.current;
    if (current == null) return const SizedBox();

    final now = chrono.store.now();
    final pausesSaved = current.pauses
        .where((p) => p.end != null && !p.end!.isAfter(now))
        .toList();
    final deducted =
        now.difference(current.startTime) - current.workedDuration(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.pause_circle_outline,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  isPaused
                      ? 'Pause en cours'
                      : 'Pauses : ${deducted.inMinutes}min',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ]),
              GestureDetector(
                onTap: () => _editPause(context),
                child: const Icon(Icons.edit, color: Colors.orange, size: 18),
              ),
            ],
          ),
          // Plages de pause déjà enregistrées
          if (pausesSaved.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...pausesSaved.map((p) => Text(
                  p.deductionMinutes != null
                      ? '${p.durationMinutes} min déduites — ajout à ${_fmtTime(p.start)}'
                      : '  ${_fmtTime(p.start)} → ${_fmtTime(p.end!)}  (${p.durationMinutes}min)',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                )),
          ],
        ],
      ),
    );
  }

  void _editPause(BuildContext context) {
    if (chrono.current == null || chrono.isBusy) return;
    showSessionEditor(context,
        day: chrono.current!.date, session: chrono.current);
  }
}

// ── Boutons contrôle ──────────────────────────────────────────────────────────
class _SessionsList extends StatelessWidget {
  final ChronoProvider chrono;
  const _SessionsList({required this.chrono});

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final sessions = chrono.todaySessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sessions du jour',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...sessions.asMap().entries.map((e) {
          final i = e.key + 1;
          final s = e.value;
          final isActive = s.endTime == null;
          final endStr = isActive ? 'En cours...' : _fmtTime(s.endTime!);
          final worked = s.workedMinutes;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session $i',
                    style: TextStyle(
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                        fontWeight: FontWeight.bold)),
                Text('${_fmtTime(s.startTime)} → $endStr'),
                if (!isActive)
                  Text(
                    '${worked ~/ 60}h${(worked % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
                  ),
                if (s.totalPauseMinutes > 0)
                  Text('⏸ ${s.totalPauseMinutes}min',
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ]),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
