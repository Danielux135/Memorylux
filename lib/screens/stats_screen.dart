import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

// historial: lo que no has olvidado, con una recompensa suave
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final completed = provider.completedMemories;
    final en = context.isEn;

    return Scaffold(
      appBar: AppBar(title: Text(context.pick('No olvidado', 'Not forgotten'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatNote(
                color: '#FFE082',
                value: '${provider.completedToday}',
                label: context.pick('recuerdos hechos hoy', 'memories done today'),
              ),
              const SizedBox(width: 12),
              _StatNote(
                color: '#A5D6A7',
                value: '${provider.completedThisWeek}',
                label: context.pick(
                    'esta semana no olvidaste', 'not forgotten this week'),
              ),
              const SizedBox(width: 12),
              _StatNote(
                color: '#90CAF9',
                value: '${provider.currentStreak}',
                label: provider.currentStreak == 1
                    ? context.pick('día de racha', 'day streak')
                    : context.pick('días de racha', 'day streak'),
                footer: provider.bestStreak > 0
                    ? context.pick(
                        'récord: ${provider.bestStreak}', 'best: ${provider.bestStreak}')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(context.pick('Historial', 'History'),
              style: AppTheme.hand(size: 26, color: scheme.onSurface)),
          const SizedBox(height: 8),
          if (completed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.pick('Cuando completes tu primer recuerdo aparecerá aquí.',
                    'Once you complete your first memory it will show up here.'),
                style: AppTheme.hand(
                    size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
            )
          else
            ...completed.take(60).map((m) => ListTile(
                  leading: Icon(Icons.check_circle,
                      color: AppTheme.noteColor(m.color)),
                  title: Text(m.title,
                      style: const TextStyle(
                          decoration: TextDecoration.lineThrough)),
                  subtitle: m.completedAt != null
                      ? Text(DateFormat('EEE d MMM, HH:mm', en ? 'en_US' : 'es')
                          .format(m.completedAt!))
                      : null,
                  trailing: IconButton(
                    tooltip: context.pick('Recuperar', 'Restore'),
                    icon: const Icon(Icons.restore),
                    onPressed: () => provider.uncomplete(
                        m, context.read<SettingsProvider>().settings),
                  ),
                )),
        ],
      ),
    );
  }
}

// mini post-it de estadística
class _StatNote extends StatelessWidget {
  final String color;
  final String value;
  final String label;
  final String? footer;

  const _StatNote({
    required this.color,
    required this.value,
    required this.label,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Transform.rotate(
        angle: -0.015,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.noteColor(color),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTheme.hand(
                      size: 40, color: const Color(0xFF2B2118))),
              Text(label,
                  style: AppTheme.ui(
                      size: 12,
                      color: const Color(0xFF2B2118).withValues(alpha: 0.7),
                      weight: FontWeight.w700)),
              if (footer != null)
                Text(footer!,
                    style: AppTheme.ui(
                        size: 11,
                        color:
                            const Color(0xFF2B2118).withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
    );
  }
}
