import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // Convertit index app (0-4) en index barre (0-4, avec 2 = espace vide)
  int _toBarIndex(int appIndex) {
    if (appIndex == 0) return 0; // Accueil → on met 0 par défaut (caché)
    if (appIndex == 1) return 0; // Planning
    if (appIndex == 2) return 1; // Chrono
    if (appIndex == 3) return 3; // Constantes
    if (appIndex == 4) return 4; // Médicaments
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        BottomNavigationBar(
          currentIndex: _toBarIndex(currentIndex),
          onTap: (i) {
            // i=0→Planning, i=1→Chrono, i=2→espace, i=3→Constantes, i=4→Médicaments
            if (i == 0) onTap(1);
            else if (i == 1) onTap(2);
            else if (i == 2) return; // espace central, rien
            else if (i == 3) onTap(3);
            else if (i == 4) onTap(4);
          },
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month,
                  color: currentIndex == 1 ? AppTheme.primaryColor : Colors.grey),
              label: 'Planning',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_rounded,
                  color: currentIndex == 2 ? AppTheme.primaryColor : Colors.grey),
              label: 'Chrono',
            ),
            const BottomNavigationBarItem(
              icon: SizedBox(width: 48),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded,
                  color: currentIndex == 3 ? AppTheme.primaryColor : Colors.grey),
              label: 'Constantes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_outlined,
                  color: currentIndex == 4 ? AppTheme.primaryColor : Colors.grey),
              label: 'Médicaments',
            ),
          ],
        ),

        // Bouton Accueil central
        Positioned(
          top: -24,
          child: GestureDetector(
            onTap: () => onTap(0),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentIndex == 0
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.home_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
