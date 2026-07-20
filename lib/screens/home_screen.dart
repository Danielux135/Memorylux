import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import 'board_screen.dart';
import 'calendar_screen.dart';
import 'memory_editor.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final Widget? adSlot;

  const HomeScreen({
    super.key,
    this.adSlot,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _initialSyncPending = true;
  StreamSubscription<Uri?>? _widgetClicks;

  static const _screens = [
    BoardScreen(),
    CalendarScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final memories = context.read<MemoryProvider>();
      final settings = context.read<SettingsProvider>();
      final notifications = context.read<NotificationService>();
      await settings.loadSettings();
      await memories.loadMemories();
      unawaited(notifications.requestPermissions());
      unawaited(() async {
        try {
          await settings.syncWithCloud();
          await memories.syncWithCloud(settings.settings);
        } finally {
          if (mounted) {
            setState(() => _initialSyncPending = false);
          }
        }
      }());

      // deep links de los widgets de pantalla de inicio: al arrancar desde
      // uno y mientras la app siga viva
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initial != null) _handleWidgetUri(initial);
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    });
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null || !mounted) return;
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>();
    final id = uri.queryParameters['id'];

    switch (uri.host) {
      case 'new':
        MemoryEditor.open(context);
      case 'done':
        if (id == null) return;
        final memory =
            provider.memories.where((m) => m.id == id).firstOrNull;
        if (memory != null && !memory.isCompleted) {
          await provider.complete(memory, settings.settings);
        }
      case 'open':
        if (id == null) return;
        final memory =
            provider.memories.where((m) => m.id == id).firstOrNull;
        if (memory != null && mounted) {
          MemoryEditor.open(context, memory: memory);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    final memories = context.watch<MemoryProvider>();
    final sync = context.watch<SyncService>();
    final adSlot = widget.adSlot ?? const SizedBox.shrink();
    final screen = _InitialSyncOverlay(
      show: _initialSyncPending &&
          memories.memories.isEmpty &&
          (memories.isLoading || sync.isSyncing || sync.firebaseAvailable),
      child: _screens[_index],
    );

    final destinations = [
      (
        Icons.dashboard_outlined,
        Icons.dashboard,
        context.pick('Panel', 'Board'),
      ),
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        context.pick('Calendario', 'Calendar'),
      ),
      (
        Icons.emoji_events_outlined,
        Icons.emoji_events,
        context.pick('No olvidado', 'Not forgotten'),
      ),
      (
        Icons.settings_outlined,
        Icons.settings,
        context.pick('Ajustes', 'Settings'),
      ),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(d.$3),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: screen),
                  adSlot,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: screen,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          adSlot,
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: destinations
                .map((d) => NavigationDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: d.$3,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _InitialSyncOverlay extends StatelessWidget {
  final bool show;
  final Widget child;

  const _InitialSyncOverlay({
    required this.show,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.72),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        context.pick(
                          'Sincronizando tu mesa...',
                          'Syncing your board...',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
