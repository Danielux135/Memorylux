import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import 'board_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import '../l10n/lang.dart';

// carcasa de navegación: rail lateral en escritorio, barra inferior en móvil
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [
    BoardScreen(),
    CalendarScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Carga local primero; permisos y nube van en segundo plano para no hacer
    // pesado el primer render en móvil.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final memories = context.read<MemoryProvider>();
      final settings = context.read<SettingsProvider>();
      final notifications = context.read<NotificationService>();
      await settings.loadSettings();
      await memories.loadMemories();
      unawaited(notifications.requestPermissions());
      unawaited(() async {
        await settings.syncWithCloud();
        await memories.syncWithCloud(settings.settings);
      }());
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;

    final destinations = [
      (
        Icons.dashboard_outlined,
        Icons.dashboard,
        context.pick('Panel', 'Board')
      ),
      (
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        context.pick('Calendario', 'Calendar')
      ),
      (
        Icons.emoji_events_outlined,
        Icons.emoji_events,
        context.pick('No olvidado', 'Not forgotten')
      ),
      (
        Icons.settings_outlined,
        Icons.settings,
        context.pick('Ajustes', 'Settings')
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
            Expanded(child: _screens[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
