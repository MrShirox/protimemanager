import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/planning_provider.dart';
import '../../providers/chrono_provider.dart';
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
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: planning.previousMonth),
                  Column(children: [
                    Text(
                      DateFormat('MMMM', 'fr_FR').format(planning.displayedMonth).toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    Text(DateFormat('yyyy').format(planning.displayedMonth),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ]),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: planning.nextMonth),
                ],
              ),
            ),
            _ShiftButtons(isDark: isDark),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: ['L','M','M','J','V','S','D'].asMap().entries.map((e) =>
                  Expanded(child: Center(child: Text(e.value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                      color: e.key >= 5
                          ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  )))).toList(),
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
        spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
        children: ShiftType.values.map((type) {
          final selected = planning.selectedShiftType == type;
          final color = type.color;
          return GestureDetector(
            onTap: () => planning.selectShiftType(selected ? null : type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: selected ? 1.0 : 0.4), width: selected ? 2 : 1),
                boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0,3))] : [],
              ),
              child: Text(type.label, style: TextStyle(
                color: selected ? Colors.white : isDark ? color : color.withValues(alpha: 0.85),
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
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, childAspectRatio: 0.82, crossAxisSpacing: 4, mainAxisSpacing: 4,
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => _DayPopup(
                date: date,
                shiftType: planning.getShiftType(date) ?? shiftType,
                sessions: sessions,
              ),
            );
          },
          child: _DayCell(
            day: dayNum, date: date, shiftType: shiftType,
            sessions: sessions, isToday: isToday,
            isWeekend: isWeekend, isDark: isDark, weekTotal: weekTotal,
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
    required this.day, required this.date, required this.shiftType,
    required this.sessions, required this.isToday, required this.isWeekend,
    required this.isDark, this.weekTotal,
  });

  String _shortLabel(ShiftType t) {
    switch (t) {
      case ShiftType.matin:     return 'MAT';
      case ShiftType.journee:   return 'JOUR';
      case ShiftType.apresMidi: return 'APM';
      case ShiftType.variable:  return 'VAR';
      case ShiftType.nuit:      return 'NUIT';
      case ShiftType.vacances:  return 'VAC';
      case ShiftType.repos:     return 'REP';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = shiftType?.color;
    final hasSession = sessions.isNotEmpty;

    Color bgColor = shiftType != null
        ? color!.withValues(alpha: isDark ? 0.28 : 0.18)
        : isDark ? const Color(0xFF1E1E2C) : Colors.white;

    Color borderColor = isToday
        ? AppTheme.primaryColor
        : shiftType != null
            ? color!.withValues(alpha: 0.45)
            : isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.15);

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
          Text('$day', style: TextStyle(
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? AppTheme.primaryColor
                : isWeekend ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700)
                : null,
            fontSize: 13,
          )),
          if (shiftType != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: color!.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
              child: Text(_shortLabel(shiftType!), style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
          if (hasSession) ...[
            const SizedBox(height: 3),
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sessions.any((s) => s.isActive)
                    ? Colors.green
                    : color?.withValues(alpha: 0.9) ?? AppTheme.primaryColor,
              ),
            ),
          ],
          if (weekTotal != null && weekTotal! > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${weekTotal! ~/ 60}h${(weekTotal! % 60).toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 7,
                color: isDark ? Colors.teal.shade300 : Colors.teal.shade700,
                fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Popup jour ───────────────────────────────────────────────────────────────
class _DayPopup extends StatefulWidget {
  final DateTime date;
  final ShiftType? shiftType;
  final List<SessionInfo> sessions;

  const _DayPopup({required this.date, required this.shiftType, required this.sessions});

  @override
  State<_DayPopup> createState() => _DayPopupState();
}

class _DayPopupState extends State<_DayPopup> {
  int _selectedSession = 0;
  late List<_SessionEdit> _edits;

  @override
  void initState() {
    super.initState();
    if (widget.sessions.isEmpty) {
      _edits = [_SessionEdit.empty()];
    } else {
      _edits = widget.sessions.map((s) => _SessionEdit.fromInfo(s)).toList();
    }
  }

  String _fmt(int mins) {
    final h = mins ~/ 60; final m = mins % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
  }

  int _toMins(String s) {
    final p = s.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: parts.length == 2 ? (int.tryParse(parts[0]) ?? 0) : 0,
        minute: parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
    );
    if (t != null) setState(() => ctrl.text =
        '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
  }

  int _workedForEdit(_SessionEdit e) {
    if (e.startCtrl.text.isEmpty || e.endCtrl.text.isEmpty) return 0;
    final s = _toMins(e.startCtrl.text);
    final end = _toMins(e.endCtrl.text);
    int total = end - s; if (total < 0) total += 24*60;
    final pause = e.pauseEdits.fold<int>(0, (sum, p) {
      if (p.startCtrl.text.isEmpty || p.endCtrl.text.isEmpty) return sum;
      final ps = _toMins(p.startCtrl.text);
      final pe = _toMins(p.endCtrl.text);
      int d = pe - ps; if (d < 0) d += 24*60;
      return sum + d;
    });
    return (total - pause).clamp(0, 24*60);
  }

  @override
  Widget build(BuildContext context) {
    final planning = context.read<PlanningProvider>();
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEEE d MMMM', 'fr_FR').format(widget.date);
    final color = widget.shiftType?.color ?? AppTheme.primaryColor;

    if (_edits.isEmpty) return const SizedBox();
    final edit = _edits[_selectedSession];

    return Padding(
      padding: EdgeInsets.only(left:20, right:20, top:20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(dateStr[0].toUpperCase() + dateStr.substring(1),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (widget.shiftType != null)
                TextButton.icon(
                  onPressed: () { planning.deleteShift(widget.date); Navigator.pop(context); },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
            ]),
            const SizedBox(height: 12),

            // Sélecteur + suppression session (toujours visible)
            if (_edits.isNotEmpty) ...[
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ..._edits.asMap().entries.map((e) {
                    final i = e.key; final sel = i == _selectedSession;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSession = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: sel ? 1.0 : 0.3)),
                        ),
                        child: Text('Session ${i+1}', style: TextStyle(
                          color: sel ? Colors.white : AppTheme.primaryColor,
                          fontWeight: FontWeight.bold, fontSize: 13,
                        )),
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une session'),
                    onPressed: () => setState(() {
                      _edits.add(_SessionEdit.empty());
                      _selectedSession = _edits.length - 1;
                    }),
                  ),
                  GestureDetector(
                    onTap: () {
                      final id = edit.sessionId;
                      if (id != null) planning.deleteSession(widget.date, id);
                      setState(() {
                        _edits.removeAt(_selectedSession);
                        if (_edits.isEmpty) _edits.add(_SessionEdit.empty());
                        if (_selectedSession >= _edits.length) _selectedSession = _edits.length - 1;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Suppr. session',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],


            // Horaires
            Text('Horaires', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TimeField(label: 'Début', ctrl: edit.startCtrl, onTap: () => _pick(edit.startCtrl))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.grey)),
              Expanded(child: _TimeField(label: 'Fin', ctrl: edit.endCtrl, onTap: () => _pick(edit.endCtrl))),
            ]),
            const SizedBox(height: 16),

            // Pauses
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pauses', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => setState(() => edit.pauseEdits.add(
                    _PauseEdit(startCtrl: TextEditingController(), endCtrl: TextEditingController()))),
                icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter'),
              ),
            ]),
            ...edit.pauseEdits.asMap().entries.map((entry) {
              final i = entry.key; final p = entry.value;
              final ps = _toMins(p.startCtrl.text);
              final pe = _toMins(p.endCtrl.text);
              int dur = pe - ps; if (dur < 0) dur += 24*60;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text('Pause ${i+1}  ', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  Expanded(child: _TimeField(label: 'Début', ctrl: p.startCtrl, onTap: () => _pick(p.startCtrl))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.orange, size: 16)),
                  Expanded(child: _TimeField(label: 'Fin', ctrl: p.endCtrl, onTap: () => _pick(p.endCtrl))),
                  if (p.startCtrl.text.isNotEmpty && p.endCtrl.text.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(left: 6),
                        child: Text('${dur}min', style: const TextStyle(color: Colors.orange, fontSize: 11))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18),
                      onPressed: () => setState(() => edit.pauseEdits.removeAt(i))),
                ]),
              );
            }),

            // Résumé
            if (edit.startCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _Chip(label: 'Travail net', value: () {
                    final w = _workedForEdit(edit);
                    return '${w ~/ 60}h${(w % 60).toString().padLeft(2,'0')}';
                  }(), color: color),
                  _Chip(label: 'Pause', value: () {
                    final p = edit.pauseEdits.fold<int>(0, (sum, p) {
                      if (p.startCtrl.text.isEmpty || p.endCtrl.text.isEmpty) return sum;
                      final ps = _toMins(p.startCtrl.text);
                      final pe = _toMins(p.endCtrl.text);
                      int d = pe - ps; if (d < 0) d += 24*60;
                      return sum + d;
                    });
                    return '${p}min';
                  }(), color: Colors.orange),
                ]),
              ),
            ],
            const SizedBox(height: 16),

            // Enregistrer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final startMins = _toMins(edit.startCtrl.text);
                  final endMins = edit.endCtrl.text.isEmpty
                      ? null : _toMins(edit.endCtrl.text);
                  final pauses = edit.pauseEdits
                      .where((p) => p.startCtrl.text.isNotEmpty)
                      .map((p) => PausePlageInfo(_toMins(p.startCtrl.text),
                          p.endCtrl.text.isEmpty ? -1 : _toMins(p.endCtrl.text)))
                      .toList();

                  if (edit.startCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Choisis une heure de début.')),
                    );
                    return;
                  }
                  await planning.updateSessionManual(
                    date: widget.date,
                    sessionId: edit.sessionId,
                    startMinutes: startMins,
                    endMinutes: endMins,
                    pauses: pauses,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modèles locaux pour l'édition
class _SessionEdit {
  final int? sessionId;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;
  final List<_PauseEdit> pauseEdits;

  _SessionEdit({this.sessionId, required this.startCtrl, required this.endCtrl, required this.pauseEdits});

  factory _SessionEdit.empty() => _SessionEdit(
    startCtrl: TextEditingController(), endCtrl: TextEditingController(), pauseEdits: [],
  );

  factory _SessionEdit.fromInfo(SessionInfo s) {
    String fmt(int m) => '${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';
    return _SessionEdit(
      sessionId: s.id,
      startCtrl: TextEditingController(text: fmt(s.startMinutes)),
      // Si session active (endMinutes == -1), champ fin vide
      endCtrl: TextEditingController(text: s.endMinutes == -1 ? '' : fmt(s.endMinutes)),
      pauseEdits: s.pauses.map((p) => _PauseEdit(
        startCtrl: TextEditingController(text: fmt(p.startMinutes)),
        // Si pause en cours (endMinutes == -1), champ fin vide
        endCtrl: TextEditingController(text: p.endMinutes < 0 ? '' : fmt(p.endMinutes)),
      )).toList(),
    );
  }
}

class _PauseEdit {
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;
  _PauseEdit({required this.startCtrl, required this.endCtrl});
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────
class _TimeField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final VoidCallback onTap;
  const _TimeField({required this.label, required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(ctrl.text.isEmpty ? '--:--' : ctrl.text,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20,
                  color: ctrl.text.isEmpty ? Colors.grey : null)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: TextStyle(color: color, fontSize: 12)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
  ]);
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
        const Text('Total semaine en cours', style: TextStyle(fontWeight: FontWeight.w500)),
        Text('${worked ~/ 60}h${(worked % 60).toString().padLeft(2,'0')}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
      ]),
    );
  }
}
