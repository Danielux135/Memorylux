import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/memory_card.dart';
import '../widgets/snooze_sheet.dart';
import '../l10n/lang.dart';
import 'memory_editor.dart';

// vista de calendario: los recuerdos con fecha, día a día
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final dayMemories = provider.memoriesForDate(_selected);

    return Scaffold(
      appBar: AppBar(title: Text(context.pick('Calendario', 'Calendar'))),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TableCalendar(
              locale: context.pick('es_ES', 'en_US'),
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
              focusedDay: _focused,
              selectedDayPredicate: (day) => isSameDay(day, _selected),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              eventLoader: provider.memoriesForDate,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.lux.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.lux,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Color(0xFF2B2118)),
                markerDecoration: BoxDecoration(
                  color: scheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                    AppTheme.hand(size: 24, color: scheme.onSurface),
              ),
            ),
          ),
          Expanded(
            child: dayMemories.isEmpty
                ? Center(
                    child: Text(
                      context.pick(
                          'Nada apuntado para este día', 'Nothing planned for this day'),
                      style: AppTheme.hand(
                          size: 22,
                          color: scheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    final columns =
                        (constraints.maxWidth / 260).floor().clamp(1, 4);
                    final width = (constraints.maxWidth -
                            32 -
                            (columns - 1) * 14) /
                        columns;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 18,
                        children: dayMemories
                            .map((m) => SizedBox(
                                  width: width,
                                  child: MemoryCard(
                                    memory: m,
                                    onTap: () => MemoryEditor.open(context,
                                        memory: m),
                                    onComplete: () => provider.complete(
                                        m,
                                        context
                                            .read<SettingsProvider>()
                                            .settings),
                                    onSnooze: () async {
                                      final settings = context
                                          .read<SettingsProvider>()
                                          .settings;
                                      final until = await showSnoozeSheet(
                                          context, settings);
                                      if (until != null) {
                                        await provider.snooze(
                                            m, until, settings);
                                      }
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}
