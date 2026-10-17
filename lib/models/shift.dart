import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ShiftType {
  matin,
  journee,
  apresMidi,
  variable,
  nuit,
  vacances,
  repos,
}

extension ShiftTypeExtension on ShiftType {
  String get label {
    switch (this) {
      case ShiftType.matin:     return 'Matin';
      case ShiftType.journee:   return 'Journée';
      case ShiftType.apresMidi: return 'Après-midi';
      case ShiftType.variable:  return 'Variable';
      case ShiftType.nuit:      return 'Nuit';
      case ShiftType.vacances:  return 'Vacances';
      case ShiftType.repos:     return 'Repos';
    }
  }

  Color get color {
    switch (this) {
      case ShiftType.matin:     return AppTheme.shiftMatin;
      case ShiftType.journee:   return AppTheme.shiftJournee;
      case ShiftType.apresMidi: return AppTheme.shiftApresMidi;
      case ShiftType.variable:  return AppTheme.shiftVariable;
      case ShiftType.nuit:      return AppTheme.shiftNuit;
      case ShiftType.vacances:  return AppTheme.shiftVacances;
      case ShiftType.repos:     return AppTheme.shiftRepos;
    }
  }
}