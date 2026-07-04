import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

// hoja de posponer con atajos rápidos y opciones inteligentes
Future<DateTime?> showSnoozeSheet(
    BuildContext context, UserSettings settings) {
  final now = DateTime.now();
  // read, no watch: se llama desde un event handler, fuera del build
  final en = context.read<SettingsProvider>().settings.language == 'en';
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final options = <(String, IconData, DateTime?)>[
        (en ? '+10 minutes' : '+10 minutos', Icons.snooze,
            now.add(const Duration(minutes: 10))),
        (en ? '+30 minutes' : '+30 minutos', Icons.snooze,
            now.add(const Duration(minutes: 30))),
        (en ? '+1 hour' : '+1 hora', Icons.schedule,
            now.add(const Duration(hours: 1))),
        (
          en ? 'This afternoon (17:00)' : 'Esta tarde (17:00)',
          Icons.wb_twilight,
          DateTime(now.year, now.month, now.day, 17)
                  .isAfter(now)
              ? DateTime(now.year, now.month, now.day, 17)
              : DateTime(now.year, now.month, now.day + 1, 17)
        ),
        (
          en ? 'Tomorrow morning (9:00)' : 'Mañana por la mañana (9:00)',
          Icons.light_mode,
          DateTime(now.year, now.month, now.day + 1, 9)
        ),
        if (settings.quietModeEnabled && settings.quietModeEndToday != null)
          (
            en ? 'When quiet mode ends' : 'Cuando salga del modo descanso',
            Icons.bedtime,
            settings.quietModeEndToday
          ),
        (en ? 'Pick date and time…' : 'Elegir fecha y hora…', Icons.event, null),
      ];

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  en ? 'How long do you want to snooze it?' : '¿Hasta cuándo lo pospongo?',
                  style: AppTheme.hand(
                      size: 26,
                      color: Theme.of(ctx).colorScheme.onSurface)),
            ),
            ...options.map(
              (o) => ListTile(
                leading: Icon(o.$2, color: AppTheme.lux),
                title: Text(o.$1),
                onTap: () async {
                  if (o.$3 != null) {
                    Navigator.pop(ctx, o.$3);
                    return;
                  }
                  // selector manual de fecha y hora
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365 * 3)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(now),
                  );
                  if (time == null || !ctx.mounted) return;
                  Navigator.pop(
                      ctx,
                      DateTime(date.year, date.month, date.day, time.hour,
                          time.minute));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          ),
        ),
      );
    },
  );
}
