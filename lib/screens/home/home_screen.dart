import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import '../../providers/chrono_provider.dart';
import '../../providers/planning_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/work_controls.dart';
import '../../theme/app_theme.dart';
import '../planning/planning_screen.dart';
import '../chrono/chrono_screen.dart';
import '../constantes/constantes_screen.dart';
import '../medications/medications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late Timer _clockTimer;
  String _currentTime = '';
  void selectTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('HH:mm:ss', 'fr_FR').format(DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return const _HomeTab();
      case 1:
        return const PlanningScreen();
      case 2:
        return const ChronoScreen();
      case 3:
        return const ConstantesScreen();
      case 4:
        return const MedicationsScreen();
      default:
        return const _HomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTime,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, theme, _) => IconButton(
              icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => theme.toggleTheme(),
            ),
          ),
        ],
      ),
      body: _buildScreen(),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Onglet Accueil ────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final chrono = context.watch<ChronoProvider>();
    final planning = context.watch<PlanningProvider>();
    final monday = planning.currentWeekMonday;
    final theme = Theme.of(context);

    const int targetMin = 35 * 60;
    final int todayMin = chrono.todayWorkedMinutes;
    final int weekMin = planning.weeklyWorkedMinutes(monday);
    final double progress = (weekMin / targetMin).clamp(0.0, 1.0);
    final int suppMin = (weekMin - targetMin).clamp(0, 999 * 60);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now()),
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          const Card(
              child:
                  Padding(padding: EdgeInsets.all(16), child: WorkControls())),
          const SizedBox(height: 16),
          // ── Cartes stats ──
          Row(children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today_rounded,
                label: "Aujourd'hui",
                value: _fmt(todayMin),
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.date_range_rounded,
                label: 'Semaine',
                value: _fmt(weekMin),
                color: AppTheme.accentColor,
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Barre 35h ──
          Text('Progression semaine',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 18,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                weekMin >= targetMin ? Colors.orange : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(weekMin),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('35h00', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),

          if (suppMin > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up, color: Colors.orange),
                const SizedBox(width: 10),
                Text(
                  'Heures supp : +${_fmt(suppMin)}',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // ── Raccourcis ──
          Text('Accès rapide',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _ShortcutCard(
                icon: Icons.calendar_month,
                label: 'Planning',
                color: AppTheme.shiftJournee,
                onTap: () => _navigate(context, 1),
              ),
              _ShortcutCard(
                icon: Icons.timer_rounded,
                label: 'Chrono',
                color: AppTheme.shiftMatin,
                onTap: () => _navigate(context, 2),
              ),
              _ShortcutCard(
                icon: Icons.tune_rounded,
                label: 'Constantes',
                color: AppTheme.shiftApresMidi,
                onTap: () => _navigate(context, 3),
              ),
              _ShortcutCard(
                icon: Icons.medication_outlined,
                label: 'Médicaments',
                color: AppTheme.shiftVariable,
                onTap: () => _navigate(context, 4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    state?.selectTab(index);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
