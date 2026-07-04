import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/memory.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

// un post-it vivo: papel de color o foto custom, chincheta que brilla si es
// persistente, ligera inclinación propia y acciones rápidas
class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;

  const MemoryCard({
    super.key,
    required this.memory,
    required this.onTap,
    required this.onComplete,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final paper = AppTheme.noteColor(memory.color);
    final hasPhoto = memory.imagePath != null;
    final isCompactDevice = MediaQuery.sizeOf(context).shortestSide < 600;
    final shadowBlur = isCompactDevice ? 4.0 : 8.0;
    final glowBlur = isCompactDevice ? 8.0 : 16.0;
    final pinGlowBlur = isCompactDevice ? 4.0 : 8.0;
    final photoProvider = hasPhoto
        ? ResizeImage(
            FileImage(File(memory.imagePath!)),
            width: isCompactDevice ? 520 : 760,
          )
        : null;
    // sobre foto siempre tinta clara con velo; sobre papel, tinta oscura
    final ink = hasPhoto ? Colors.white : const Color(0xFF2B2118);
    final subtle = hasPhoto
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF2B2118).withValues(alpha: 0.65);
    final persistent = memory.priority == MemoryPriority.persistent;
    final important = memory.priority == MemoryPriority.important;

    return RepaintBoundary(
      child: Transform.rotate(
        angle: memory.rotation,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(6),
              image: hasPhoto
                  ? DecorationImage(
                      image: photoProvider!,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.42),
                        BlendMode.darken,
                      ),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: shadowBlur,
                  offset: Offset(1, isCompactDevice ? 3 : 5),
                ),
                if (persistent)
                  BoxShadow(
                    color: AppTheme.lux.withValues(alpha: 0.45),
                    blurRadius: glowBlur,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.title,
                        style: AppTheme.hand(size: 24, color: ink),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (memory.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          memory.body,
                          style: AppTheme.ui(size: 13, color: subtle),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (memory.checklist.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.pick(
                              '${memory.checklist.where((c) => c.done).length}/${memory.checklist.length} hechas',
                              '${memory.checklist.where((c) => c.done).length}/${memory.checklist.length} done'),
                          style: AppTheme.ui(
                              size: 12, color: subtle, weight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (memory.effectiveDue != null)
                            _Pill(
                              icon: memory.isOverdue
                                  ? Icons.local_fire_department
                                  : Icons.schedule,
                              label: _dueLabel(memory, context.isEn),
                              ink: memory.isOverdue
                                  ? const Color(0xFFB71C1C)
                                  : ink,
                              background: memory.isOverdue
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : ink.withValues(alpha: 0.09),
                            ),
                          if (!memory.recurrence.isNone) ...[
                            const SizedBox(width: 6),
                            _Pill(
                              icon: Icons.repeat,
                              label: memory.recurrence.labelFor(context.isEn),
                              ink: ink,
                              background: ink.withValues(alpha: 0.09),
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            tooltip: context.pick('Posponer', 'Snooze'),
                            visualDensity: VisualDensity.compact,
                            onPressed: onSnooze,
                            icon: Icon(Icons.snooze, size: 20, color: subtle),
                          ),
                          IconButton(
                            tooltip: context.pick('Hecho', 'Done'),
                            visualDensity: VisualDensity.compact,
                            onPressed: onComplete,
                            icon: Icon(Icons.check_circle_outline,
                                size: 22, color: ink),
                          ),
                        ],
                      ),
                      if (memory.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            spacing: 6,
                            children: memory.tags
                                .take(3)
                                .map((t) => Text('#$t',
                                    style: AppTheme.ui(
                                        size: 12,
                                        color: subtle,
                                        weight: FontWeight.w700)))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                // chincheta: ámbar brillante si es persistente, discreta si no
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: persistent || important
                            ? AppTheme.lux
                            : ink.withValues(alpha: 0.35),
                        boxShadow: persistent
                            ? [
                                BoxShadow(
                                  color: AppTheme.lux.withValues(alpha: 0.8),
                                  blurRadius: pinGlowBlur,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
                if (memory.snoozeCount > 0)
                  Positioned(
                    top: 4,
                    right: 6,
                    child: Text(
                      context.pick('pospuesta ×${memory.snoozeCount}',
                          'snoozed ×${memory.snoozeCount}'),
                      style: AppTheme.ui(
                          size: 10, color: subtle, weight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dueLabel(Memory m, bool en) {
    final due = m.effectiveDue!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final time = m.hasTime ? DateFormat('HH:mm').format(due) : '';

    String dayLabel;
    final diff = day.difference(today).inDays;
    if (diff == 0) {
      dayLabel = en ? 'today' : 'hoy';
    } else if (diff == 1) {
      dayLabel = en ? 'tomorrow' : 'mañana';
    } else if (diff == -1) {
      dayLabel = en ? 'yesterday' : 'ayer';
    } else if (diff > 1 && diff < 7) {
      dayLabel = DateFormat('EEEE', en ? 'en_US' : 'es').format(due);
    } else {
      dayLabel = DateFormat('d MMM', en ? 'en_US' : 'es').format(due);
    }
    return time.isEmpty ? dayLabel : '$dayLabel $time';
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color ink;
  final Color background;

  const _Pill({
    required this.icon,
    required this.label,
    required this.ink,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 4),
          Text(label,
              style:
                  AppTheme.ui(size: 12, color: ink, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
