import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/chrono_provider.dart';

/// The home screen and stopwatch use exactly the same commands and state.
class WorkControls extends StatelessWidget {
  const WorkControls({super.key});

  @override
  Widget build(BuildContext context) {
    final chrono = context.watch<ChronoProvider>();
    final disabled = chrono.isBusy || chrono.loadError != null;
    final session = chrono.current;
    final last =
        chrono.store.sessions.isEmpty ? null : chrono.store.sessions.last;
    final pauseEnd = chrono.isPaused ? session!.pauses.last.end : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (session == null && last?.endTime != null)
        Text(
            'Dernière fin de journée : ${DateFormat('dd/MM HH:mm').format(last!.endTime!)}'),
      if (session != null)
        Text(
            'Début de journée : ${DateFormat('dd/MM HH:mm').format(session.startTime)}'),
      if (chrono.isPaused)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
              pauseEnd == null
                  ? 'Pause en cours'
                  : 'Pause — reprise automatique à ${DateFormat('HH:mm').format(pauseEnd)}',
              style: const TextStyle(color: Colors.orange)),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (!chrono.hasActive)
          FilledButton.icon(
              onPressed: disabled ? null : chrono.start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Début de journée')),
        if (chrono.isPaused)
          OutlinedButton(
              onPressed: disabled ? null : chrono.resumePause,
              child: const Text('Reprendre maintenant')),
        if (chrono.hasActive)
          FilledButton.icon(
              onPressed: disabled
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                  title: const Text('Fin de journée ?'),
                                  content: const Text(
                                      'L’heure de fin et le temps travaillé seront enregistrés.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Annuler')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Terminer'))
                                  ]));
                      if (confirmed == true) await chrono.stop();
                    },
              icon: const Icon(Icons.stop),
              label: const Text('Fin de journée')),
      ]),
      if (chrono.isRunning) ...[
        const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('Déduire une pause (le chrono continue)')),
        Wrap(spacing: 6, children: [
          for (final minutes in [20, 30, 45, 50, 60])
            OutlinedButton(
                onPressed:
                    disabled ? null : () => chrono.pause(minutes: minutes),
                child: Text(minutes == 60 ? '1 h' : '$minutes min'))
        ]),
      ],
      if (chrono.error != null || chrono.loadError != null)
        Text(chrono.error ?? chrono.loadError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
