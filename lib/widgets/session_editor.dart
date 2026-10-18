import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chrono_entry.dart';
import '../providers/planning_provider.dart';
import '../services/work_sessions.dart';

Future<void> showSessionEditor(BuildContext context,
        {required DateTime day, ChronoSession? session}) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SessionEditor(day: day, session: session));

class SessionEditor extends StatefulWidget {
  final DateTime day;
  final ChronoSession? session;
  const SessionEditor({super.key, required this.day, this.session});
  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  late DateTime _start;
  DateTime? _end;
  late List<PauseEntry> _pauses;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = widget.session?.startTime ??
        DateTime(widget.day.year, widget.day.month, widget.day.day, 8);
    _end = widget.session != null
        ? widget.session!.endTime
        : DateTime(widget.day.year, widget.day.month, widget.day.day, 17);
    _pauses = [...?widget.session?.pauses];
  }

  Widget _dateTime(String label, DateTime value, ValueChanged<DateTime> change,
          {DateTime? after}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('dd/MM/yyyy').format(value)),
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: dayStart(value),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2200));
                      if (picked != null && mounted) {
                        setState(() => change(DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            value.hour,
                            value.minute,
                            value.second,
                            value.millisecond,
                            value.microsecond)));
                      }
                    },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule, size: 16),
              label: Text(DateFormat('HH:mm').format(value)),
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(value));
                      if (picked != null && mounted) {
                        var result = DateTime(value.year, value.month,
                            value.day, picked.hour, picked.minute);
                        // Selecting 05:00 after a 20:00 start means the following day.
                        if (after != null &&
                            dayStart(result) == dayStart(after) &&
                            result.isBefore(after)) {
                          result = DateTime(result.year, result.month,
                              result.day + 1, result.hour, result.minute);
                        }
                        setState(() => change(result));
                      }
                    },
            ),
          ]),
        ]),
      );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = ChronoSession(
          id: widget.session?.id,
          revision: widget.session?.revision ?? 0,
          startTime: _start,
          endTime: _end,
          pauses: _pauses
              .map((p) => _end != null &&
                      (p.end == null || (p.scheduled && p.end!.isAfter(_end!)))
                  ? PauseEntry(start: p.start, end: _end)
                  : p)
              .toList());
      await context.read<PlanningProvider>().saveSession(session);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } on WorkTimeException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sauvegarde impossible. Réessaie.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(widget.session == null
              ? 'Ajouter une session'
              : 'Modifier la session'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Les horaires de la session complète sont modifiés. Les heures et pauses sont réparties automatiquement à minuit.'),
                  _dateTime('Début', _start, (v) => _start = v),
                  if (_end != null)
                    _dateTime('Fin', _end!, (v) => _end = v, after: _start)
                  else
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Session en cours — sans heure de fin')),
                  if (widget.session?.isRunning == true)
                    TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _end = _end == null
                                      ? context
                                          .read<PlanningProvider>()
                                          .store
                                          .now()
                                      : null;
                                }),
                        child: Text(_end == null
                            ? 'Renseigner une fin'
                            : 'Conserver le chrono en cours')),
                  const Divider(),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pauses',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      final start = _pauses.isEmpty
                                          ? _start
                                          : (_pauses.last.end ??
                                              _pauses.last.start);
                                      _pauses.add(
                                          PauseEntry(start: start, end: start));
                                    }),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter')),
                      ]),
                  for (var i = 0; i < _pauses.length; i++) ...[
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pause ${i + 1}'),
                          IconButton(
                              tooltip: 'Supprimer la pause',
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _pauses.removeAt(i)),
                              icon: const Icon(Icons.close)),
                        ]),
                    _dateTime(
                        'Début de pause',
                        _pauses[i].start,
                        (v) => _pauses[i] = PauseEntry(
                            start: v,
                            end: _pauses[i].end,
                            scheduled: _pauses[i].scheduled)),
                    if (_pauses[i].end != null)
                      _dateTime(
                          'Fin de pause',
                          _pauses[i].end!,
                          (v) => _pauses[i] = PauseEntry(
                              start: _pauses[i].start,
                              end: v,
                              scheduled: _pauses[i].scheduled),
                          after: _pauses[i].start)
                    else
                      const Text('Pause en cours'),
                    if (_end == null && i == _pauses.length - 1)
                      TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                    final p = _pauses[i];
                                    _pauses[i] = PauseEntry(
                                        start: p.start,
                                        end: p.end == null
                                            ? context
                                                .read<PlanningProvider>()
                                                .store
                                                .now()
                                            : null);
                                  }),
                          child: Text(_pauses[i].end == null
                              ? 'Renseigner la fin de pause'
                              : 'Laisser la pause en cours')),
                    const Divider(),
                  ],
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
          ],
        ),
      );
}
