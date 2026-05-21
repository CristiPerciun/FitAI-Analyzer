import 'package:flutter/material.dart';

/// Widget opzionale mostrato in Home sotto i 4 pilastri longevità.
enum HomeWidgetType {
  nutritionRings(
    'Obiettivi nutrizione',
    'Anelli calorie e macro settimanali',
    Icons.donut_large,
  ),
  caloricDeficit(
    'Bilancio calorico',
    'Assunzione vs obiettivo e surplus',
    Icons.bar_chart,
  ),
  weeklyMacros(
    'Macro settimanali',
    'Proteine, carboidrati e grassi per giorno',
    Icons.stacked_bar_chart,
  ),
  activityCalendar(
    'Calendario attività',
    'Giorni con allenamenti del mese',
    Icons.calendar_month,
  ),
  activityBurn(
    'Calorie bruciate',
    'Energia da attività settimana o mese',
    Icons.local_fire_department,
  );

  const HomeWidgetType(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;

  static HomeWidgetType? fromStorageKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final value in HomeWidgetType.values) {
      if (value.name == key) return value;
    }
    return null;
  }
}
