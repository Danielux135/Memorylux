import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/memory.dart';
import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/quick_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/memory_card.dart';
import '../widgets/quick_add_bar.dart';
import '../widgets/snooze_sheet.dart';
import '../l10n/lang.dart';
import 'memory_editor.dart';

// el Memory Board: tu mesa de trabajo con tres zonas de post-its
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  bool _searching = false;

  Future<void> _quickAdd(QuickParseResult result) async {
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final userId = context.read<AuthService>().userId;
    await provider.addMemory(
      Memory(
        userId: userId,
        title: result.title,
        dueDate: result.dueDate,
        hasTime: result.hasTime,
        tags: result.tags,
        recurrence: result.recurrence,
        priority: result.priority,
        zone: Memory.zoneForDate(result.dueDate),
        notificationMinutesBefore: result.notificationMinutesBefore,
      ),
      settings,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.pick('“${result.title}” apuntado en tu panel',
                '“${result.title}” added to your board'))),
      );
    }
  }

  Future<void> _complete(Memory memory) async {
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    await provider.complete(memory, settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.pick('Hecho: ${memory.title}', 'Done: ${memory.title}')),
          action: SnackBarAction(
            label: context.pick('Deshacer', 'Undo'),
            onPressed: () => provider.uncomplete(
                memory.copyWith(isCompleted: true), settings),
          ),
        ),
      );
    }
  }

  Future<void> _snooze(Memory memory) async {
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final until = await showSnoozeSheet(context, settings);
    if (until != null) {
      await provider.snooze(memory, until, settings);
    }
  }

  Future<void> _reorder(BoardZone zone, List<Memory> zoneOrder, Memory moved,
      Memory? target, bool insertBefore) async {
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    await provider.reorder(
        zone, zoneOrder, moved, target, insertBefore, settings);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MemoryProvider>();
    final wide = MediaQuery.of(context).size.width > 900;

    final zones = <(BoardZone, String, String, String, List<Memory>)>[
      (
        BoardZone.today,
        'HOY',
        context.pick('HOY', 'TODAY'),
        context.pick('Lo que toca hoy', 'What\'s due today'),
        provider.todayMemories
      ),
      (
        BoardZone.dontForget,
        'NO OLVIDAR',
        context.pick('NO OLVIDAR', 'DON\'T FORGET'),
        context.pick('Sigue aquí hasta que lo resuelvas',
            'Stays here until you handle it'),
        provider.dontForgetMemories
      ),
      (
        BoardZone.waiting,
        'EN ESPERA',
        context.pick('EN ESPERA', 'WAITING'),
        context.pick(
            'Ideas y pendientes sin prisa', 'Ideas and no-rush pending items'),
        provider.waitingMemories
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                    hintText:
                        context.pick('Buscar recuerdos…', 'Search memories…')),
                onChanged: provider.setSearch,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/logo/memorylux_logo.svg',
                    height: 26,
                  ),
                  const SizedBox(width: 10),
                  const Text('Memorylux'),
                ],
              ),
        actions: [
          IconButton(
            tooltip: _searching
                ? context.pick('Cerrar búsqueda', 'Close search')
                : context.pick('Buscar', 'Search'),
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) provider.setSearch('');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MemoryEditor.open(context),
        icon: const Icon(Icons.note_add),
        label: Text(context.pick('Recuerdo', 'Memory')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: QuickAddBar(onSubmit: _quickAdd),
          ),
          if (provider.allTags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final tag in provider.allTags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#$tag'),
                        selected: provider.tagFilter == tag,
                        onSelected: (v) =>
                            provider.setTagFilter(v ? tag : null),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: zones
                        .map((z) => Expanded(
                              child: _ZoneColumn(
                                zone: z.$1,
                                zoneKey: z.$2,
                                title: z.$3,
                                subtitle: z.$4,
                                memories: z.$5,
                                onComplete: _complete,
                                onSnooze: _snooze,
                                onReorder: _reorder,
                              ),
                            ))
                        .toList(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final z = zones[index];
                      return _ZoneSection(
                        zone: z.$1,
                        zoneKey: z.$2,
                        title: z.$3,
                        subtitle: z.$4,
                        memories: z.$5,
                        onComplete: _complete,
                        onSnooze: _snooze,
                        onReorder: _reorder,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// etiqueta de zona estilo cinta adhesiva
class _ZoneLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _ZoneLabel(
      {required this.title, required this.subtitle, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Transform.rotate(
            angle: -0.02,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$title · $count',
                style: AppTheme.ui(
                    size: 13,
                    weight: FontWeight.w800,
                    color: scheme.onSurface.withValues(alpha: 0.8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              style: AppTheme.hand(
                  size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneSection extends StatelessWidget {
  final BoardZone zone;
  final String zoneKey;
  final String title;
  final String subtitle;
  final List<Memory> memories;
  final Future<void> Function(Memory) onComplete;
  final Future<void> Function(Memory) onSnooze;
  final Future<void> Function(BoardZone, List<Memory>, Memory, Memory?, bool)
      onReorder;

  const _ZoneSection({
    required this.zone,
    required this.zoneKey,
    required this.title,
    required this.subtitle,
    required this.memories,
    required this.onComplete,
    required this.onSnooze,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoneLabel(title: title, subtitle: subtitle, count: memories.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _NoteGrid(
              zone: zone,
              memories: memories,
              emptyText: zoneKey == 'HOY'
                  ? context.pick(
                      'Nada por hoy. Apunta algo arriba en 3 segundos.',
                      'Nothing for today. Add something above in 3 seconds.')
                  : context.pick('Vacío. Buena señal.', 'Empty. Good sign.'),
              onComplete: onComplete,
              onSnooze: onSnooze,
              onReorder: onReorder),
        ),
      ],
    );
  }
}

class _ZoneColumn extends StatelessWidget {
  final BoardZone zone;
  final String zoneKey;
  final String title;
  final String subtitle;
  final List<Memory> memories;
  final Future<void> Function(Memory) onComplete;
  final Future<void> Function(Memory) onSnooze;
  final Future<void> Function(BoardZone, List<Memory>, Memory, Memory?, bool)
      onReorder;

  const _ZoneColumn({
    required this.zone,
    required this.zoneKey,
    required this.title,
    required this.subtitle,
    required this.memories,
    required this.onComplete,
    required this.onSnooze,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoneLabel(title: title, subtitle: subtitle, count: memories.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: _NoteGrid(
                zone: zone,
                memories: memories,
                emptyText:
                    context.pick('Vacío. Buena señal.', 'Empty. Good sign.'),
                onComplete: onComplete,
                onSnooze: onSnooze,
                onReorder: onReorder),
          ),
        ),
      ],
    );
  }
}

// rejilla de post-its adaptativa, arrastrable para reordenar a placer y
// mover entre zonas
class _NoteGrid extends StatelessWidget {
  final BoardZone zone;
  final List<Memory> memories;
  final String emptyText;
  final Future<void> Function(Memory) onComplete;
  final Future<void> Function(Memory) onSnooze;
  final Future<void> Function(BoardZone, List<Memory>, Memory, Memory?, bool)
      onReorder;

  const _NoteGrid({
    required this.zone,
    required this.memories,
    required this.emptyText,
    required this.onComplete,
    required this.onSnooze,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return DragTarget<Memory>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) =>
            onReorder(zone, const [], details.data, null, false),
        builder: (context, candidateData, rejectedData) => Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          decoration: candidateData.isNotEmpty
              ? BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          alignment: Alignment.centerLeft,
          child: Text(
            emptyText,
            style: AppTheme.hand(
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / 230).floor().clamp(1, 4);
      final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
      final cards = <Widget>[
        for (final m in memories)
          SizedBox(
            width: width,
            // builder para capturar el contexto de esta tarjeta concreta:
            // el context del LayoutBuilder mediría toda la rejilla
            child: Builder(builder: (cardContext) {
              return DragTarget<Memory>(
                onWillAcceptWithDetails: (details) => details.data.id != m.id,
                onAcceptWithDetails: (details) {
                  final box = cardContext.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(details.offset);
                  final before = local.dy < box.size.height / 2;
                  onReorder(zone, memories, details.data, m, before);
                },
                builder: (context, candidateData, rejectedData) {
                  final card = MemoryCard(
                    memory: m,
                    onTap: () => MemoryEditor.open(context, memory: m),
                    onComplete: () => onComplete(m),
                    onSnooze: () => onSnooze(m),
                  );
                  return LongPressDraggable<Memory>(
                    data: m,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    delay: const Duration(milliseconds: 280),
                    feedback: SizedBox(
                      width: width,
                      child: Opacity(opacity: 0.85, child: card),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: card),
                    child: candidateData.isNotEmpty
                        ? Opacity(opacity: 0.6, child: card)
                        : card,
                  );
                },
              );
            }),
          ),
        // zona de destino al final de la lista, para soltar al final
        DragTarget<Memory>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) =>
              onReorder(zone, memories, details.data, null, false),
          builder: (context, candidateData, rejectedData) => SizedBox(
            width: width,
            height: candidateData.isNotEmpty ? 40 : 4,
          ),
        ),
      ];
      return Wrap(
        spacing: 14,
        runSpacing: 18,
        children: cards,
      );
    });
  }
}
