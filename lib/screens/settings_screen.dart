import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/memory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/audio_store.dart';
import '../services/export_service.dart';
import '../services/monetization_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/lead_time_sheet.dart';
import '../l10n/lang.dart';

// ajustes: notificaciones, modo descanso, idioma, tema, sincronización y tus datos
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final memories = context.watch<MemoryProvider>();
    final scheme = Theme.of(context).colorScheme;
    final en = context.isEn;

    String hourLabel(DateTime? d) =>
        d == null ? '--:--' : DateFormat('HH:mm').format(d);

    return Scaffold(
      appBar: AppBar(title: Text(context.pick('Ajustes', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _Section(title: context.pick('Avisos', 'Alerts')),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: Text(context.pick('Notificaciones', 'Notifications')),
            subtitle: Text(context.pick(
                'Alarmas de tus recuerdos', 'Alarms for your memories')),
            value: settings.notificationsEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final allowed = await context
                    .read<NotificationService>()
                    .requestPermissions();
                if (!allowed && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(context.pick(
                      'Android tiene bloqueadas las notificaciones de Memorylux.',
                      'Android has blocked Memorylux notifications.',
                    )),
                  ));
                  return;
                }
              }
              await settingsProvider.toggleNotifications(enabled);
              if (context.mounted) {
                await context
                    .read<MemoryProvider>()
                    .rescheduleAll(settingsProvider.settings);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer),
            title: Text(context.pick('Avisar antes', 'Notify me before')),
            subtitle: Text(en
                ? '${leadTimeLabel(settings.defaultNotificationMinutes, true)} · plus always right on time'
                : '${leadTimeLabel(settings.defaultNotificationMinutes, false)} · además siempre a la hora exacta'),
            onTap: () async {
              final choice = await pickLeadTime(context,
                  en: en, current: settings.defaultNotificationMinutes);
              if (choice != null && context.mounted) {
                await settingsProvider
                    .setDefaultNotificationMinutes(choice.minutes ?? 0);
                if (context.mounted) {
                  // reprograma con la nueva antelación por defecto
                  await context
                      .read<MemoryProvider>()
                      .rescheduleAll(settingsProvider.settings);
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: Text(context.pick('Sonido por defecto', 'Default sound')),
            subtitle:
                Text(_alarmSoundLabel(context, settings.defaultAlarmSound)),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final savedSoundMessage = context.pick(
                'Sonido "{name}" guardado por defecto',
                'Sound "{name}" saved as default',
              );
              final sound = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_active),
                        title: const Text('Alarm'),
                        onTap: () => Navigator.pop(ctx, 'alarm'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.audio_file),
                        title: Text(
                            context.pick('Elegir audio...', 'Choose audio...')),
                        onTap: () => Navigator.pop(ctx, 'pick'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.volume_off),
                        title: Text(context.pick('Silencio', 'Silent')),
                        onTap: () => Navigator.pop(ctx, 'silent'),
                      ),
                    ],
                  ),
                ),
              );
              if (sound == null || !context.mounted) return;
              var value = sound;
              if (sound == 'pick') {
                final audio = await AudioStore.pickAndStore();
                if (audio == null || !context.mounted) return;
                value = audio.value;
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      savedSoundMessage.replaceAll('{name}', audio.name),
                    ),
                  ),
                );
              }
              await settingsProvider.setDefaultAlarmSound(value);
              if (context.mounted) {
                await context
                    .read<MemoryProvider>()
                    .rescheduleAll(settingsProvider.settings);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: Text(context.pick('Resumen del día', 'Daily summary')),
            subtitle: Text(settings.dailySummaryEnabled
                ? (en
                    ? 'Your day\'s tasks at ${settings.dailySummaryHour.toString().padLeft(2, '0')}:${settings.dailySummaryMinute.toString().padLeft(2, '0')}'
                    : 'Las tareas del día a las ${settings.dailySummaryHour.toString().padLeft(2, '0')}:${settings.dailySummaryMinute.toString().padLeft(2, '0')}')
                : context.pick('Desactivado', 'Disabled')),
            value: settings.dailySummaryEnabled,
            onChanged: (v) async {
              await settingsProvider.toggleDailySummary(v);
              if (context.mounted) {
                await context
                    .read<MemoryProvider>()
                    .rescheduleAll(settingsProvider.settings);
              }
            },
          ),
          if (settings.dailySummaryEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(context.pick(
                  'Cambiar hora del resumen', 'Change summary time')),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: settings.dailySummaryHour,
                      minute: settings.dailySummaryMinute),
                  helpText: context.pick('Hora del resumen', 'Summary time'),
                );
                if (time == null || !context.mounted) return;
                await settingsProvider.setDailySummaryTime(
                    time.hour, time.minute);
                if (context.mounted) {
                  await context
                      .read<MemoryProvider>()
                      .rescheduleAll(settingsProvider.settings);
                }
              },
            ),
          ListTile(
            leading:
                const Icon(Icons.local_fire_department, color: AppTheme.lux),
            title: Text(
                context.pick('Reavisos persistentes', 'Persistent reminders')),
            subtitle: Text(en
                ? 'Persistent notes remind you again every ${settings.persistentRepeatMinutes} min'
                : 'Las notas persistentes reavisan cada ${settings.persistentRepeatMinutes} min'),
            onTap: () async {
              final minutes = await showModalBottomSheet<int>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [5, 10, 15, 30, 60]
                        .map((m) => ListTile(
                              title: Text(
                                  en ? 'Every $m minutes' : 'Cada $m minutos'),
                              onTap: () => Navigator.pop(ctx, m),
                            ))
                        .toList(),
                  ),
                ),
              );
              if (minutes != null) {
                settingsProvider.setPersistentRepeatMinutes(minutes);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime),
            title: Text(context.pick('Modo descanso', 'Quiet mode')),
            subtitle: Text(settings.quietModeEnabled
                ? (en
                    ? 'Quiet from ${hourLabel(settings.quietModeStart)} to ${hourLabel(settings.quietModeEnd)}'
                    : 'Silencio de ${hourLabel(settings.quietModeStart)} a ${hourLabel(settings.quietModeEnd)}')
                : context.pick('Sin silenciar', 'Not silenced')),
            value: settings.quietModeEnabled,
            onChanged: settingsProvider.toggleQuietMode,
          ),
          if (settings.quietModeEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: Text(context.pick(
                  'Cambiar horario de descanso', 'Change quiet hours')),
              onTap: () async {
                final start = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 23, minute: 0),
                  helpText: context.pick('Inicio del descanso', 'Quiet start'),
                );
                if (start == null || !context.mounted) return;
                final end = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 8, minute: 0),
                  helpText: context.pick('Fin del descanso', 'Quiet end'),
                );
                if (end == null) return;
                final now = DateTime.now();
                settingsProvider.setQuietModeHours(
                  DateTime(
                      now.year, now.month, now.day, start.hour, start.minute),
                  DateTime(now.year, now.month, now.day, end.hour, end.minute),
                );
              },
            ),
          _Section(title: context.pick('Idioma', 'Language')),
          _ControlTile(
            leading: const Icon(Icons.translate),
            title: context.pick('Idioma de la app', 'App language'),
            subtitle: en ? 'English' : 'Español',
            control: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'es', label: Text('ES')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {settings.language},
              onSelectionChanged: (s) => settingsProvider.setLanguage(s.first),
            ),
          ),
          _Section(title: context.pick('Apariencia', 'Appearance')),
          _ControlTile(
            leading: const Icon(Icons.dark_mode),
            title: context.pick('Tema', 'Theme'),
            subtitle: switch (settings.themeMode) {
              'light' =>
                context.pick('Claro (mesa de día)', 'Light (day desk)'),
              'dark' =>
                context.pick('Oscuro (mesa de noche)', 'Dark (night desk)'),
              _ => context.pick('Según el sistema', 'Follow system'),
            },
            control: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', icon: Icon(Icons.light_mode)),
                ButtonSegment(
                    value: 'system', icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settingsProvider.setThemeMode(s.first),
            ),
          ),
          if (context.watch<MonetizationService>().isAndroid) ...[
            const _Section(title: 'Widgets'),
            const _WidgetSettingsSection(),
          ],
          _Section(title: context.pick('Nube', 'Cloud')),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync),
            title: Text(
                context.pick('Sincronizar con la nube', 'Sync with the cloud')),
            subtitle: Text(sync.lastSync == null
                ? context.pick('Todavía sin sincronizar', 'Not synced yet')
                : (en
                    ? 'Last time: ${DateFormat('d MMM, HH:mm', 'en_US').format(sync.lastSync!)}'
                    : 'Última vez: ${DateFormat('d MMM, HH:mm', 'es').format(sync.lastSync!)}')),
            value: settings.syncEnabled,
            onChanged: settingsProvider.toggleSync,
          ),
          ListTile(
            leading: Icon(sync.isOnline ? Icons.wifi : Icons.wifi_off),
            title: Text(sync.isOnline
                ? context.pick('Conectado', 'Online')
                : context.pick('Sin conexión', 'Offline')),
            subtitle: Text(context.pick(
                'Sin conexión todo sigue funcionando; se sincroniza al volver',
                'Everything still works offline; it syncs when back online')),
            trailing: sync.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    tooltip: context.pick('Sincronizar ahora', 'Sync now'),
                    icon: const Icon(Icons.sync),
                    onPressed: () => memories.syncWithCloud(settings),
                  ),
          ),
          _Section(title: context.pick('Tus datos', 'Your data')),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(context.pick('Exportar a JSON', 'Export to JSON')),
            subtitle: Text(
                context.pick('Copia de seguridad completa', 'Full backup')),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final json = ExportService.toJson(memories.memories);
              final path = await ExportService.saveToFile(json, 'json');
              await Clipboard.setData(ClipboardData(text: json));
              messenger.showSnackBar(SnackBar(
                  content: Text(en
                      ? 'Saved to $path (and copied to clipboard)'
                      : 'Guardado en $path (y copiado al portapapeles)')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: Text(context.pick('Exportar a CSV', 'Export to CSV')),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final csv = ExportService.toCsv(memories.memories);
              final path = await ExportService.saveToFile(csv, 'csv');
              messenger.showSnackBar(SnackBar(
                  content: Text(en ? 'Saved to $path' : 'Guardado en $path')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title:
                Text(context.pick('Importar desde JSON', 'Import from JSON')),
            subtitle: Text(context.pick(
                'Pega aquí el contenido de una copia', 'Paste a backup here')),
            onTap: () => _importJson(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: scheme.error),
            title: Text(
                context.pick(
                    'Borrar mis datos de la nube', 'Delete my cloud data'),
                style: TextStyle(color: scheme.error)),
            onTap: () async {
              final syncService = context.read<SyncService>();
              final userId = auth.userId;
              final messenger = ScaffoldMessenger.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.pick('¿Borrar todo de la nube?',
                      'Delete everything from the cloud?')),
                  content: Text(context.pick(
                      'Se eliminarán tus recuerdos del servidor. Los datos locales de este dispositivo se conservan.',
                      'This deletes your memories from the server. Local data on this device is kept.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.pick('Cancelar', 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.pick('Borrar', 'Delete'))),
                  ],
                ),
              );
              if (confirm == true) {
                await syncService.wipeUserData(userId);
                messenger.showSnackBar(SnackBar(
                    content: Text(context.pick(
                        'Datos de la nube eliminados', 'Cloud data deleted'))));
              }
            },
          ),
          _Section(title: context.pick('Ayuda', 'Help')),
          ListTile(
            leading: const Icon(Icons.feedback_outlined, color: AppTheme.lux),
            title: Text(context.pick('Enviar feedback / reportar un bug',
                'Send feedback / report a bug')),
            subtitle: Text(context.pick(
                'Sin registro: me llega directo al correo',
                'No sign-up: it goes straight to my inbox')),
            onTap: () => showFeedbackSheet(context),
          ),
          _Section(title: context.pick('Cuenta', 'Account')),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(auth.user?.displayName ??
                context.pick('Sin nombre', 'No name')),
            subtitle: Text(auth.user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.pick('Cerrar sesión', 'Sign out')),
            onTap: () => auth.signOut(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _importJson(BuildContext context) async {
    final controller = TextEditingController();
    final provider = context.read<MemoryProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final userId = context.read<AuthService>().userId;
    final messenger = ScaffoldMessenger.of(context);
    final en = context.isEn;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.pick('Importar copia JSON', 'Import JSON backup')),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: InputDecoration(
              hintText: context.pick('Pega aquí el JSON exportado',
                  'Paste the exported JSON here')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.pick('Cancelar', 'Cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.pick('Importar', 'Import'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final imported = ExportService.fromJson(controller.text, userId);
      // fusiona sin duplicar: los importados sustituyen a los que tengan mismo id
      final merged = {
        for (final m in provider.memories) m.id: m,
        for (final m in imported) m.id: m,
      };
      await provider.replaceAll(merged.values.toList(), settings);
      messenger.showSnackBar(SnackBar(
          content: Text(en
              ? '${imported.length} memories imported'
              : '${imported.length} recuerdos importados')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(context.pick(
              'Ese JSON no se pudo leer. ¿Es una copia de Memorylux?',
              'That JSON could not be read. Is it a Memorylux backup?'))));
    }
  }
}

String _alarmSoundLabel(BuildContext context, String sound) {
  return AudioStore.labelFor(sound, en: context.isEn);
}

class _ControlTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget control;

  const _ControlTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final label = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 48,
                  child: Align(alignment: Alignment.topLeft, child: leading)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: subtitleStyle),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Align(alignment: Alignment.centerLeft, child: control),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: label),
              const SizedBox(width: 16),
              control,
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section(
      {required this.title}); // constructor const para poder usarlo en listas constantes

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: AppTheme.hand(
              size: 24, color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

// sección de ajustes de los widgets de pantalla de inicio; la apariencia
// solo es editable con premium (los free ven las opciones bloqueadas)
class _WidgetSettingsSection extends StatefulWidget {
  const _WidgetSettingsSection();

  @override
  State<_WidgetSettingsSection> createState() => _WidgetSettingsSectionState();
}

class _WidgetSettingsSectionState extends State<_WidgetSettingsSection> {
  WidgetSettings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetSettings.load().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  // mismo patrón de gating que las fotos custom del editor
  bool _requirePremium() {
    final monetization = context.read<MonetizationService>();
    if (monetization.isAndroid && !monetization.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.pick(
          'Personalizar los widgets es una función premium.',
          'Widget customization is a premium feature.',
        )),
      ));
      return false;
    }
    return true;
  }

  Future<void> _apply(void Function(WidgetSettings s) change) async {
    final s = _settings;
    if (s == null || !_requirePremium()) return;
    setState(() => change(s));
    await s.save();
    if (!mounted) return;
    await context.read<MemoryProvider>().refreshWidgets();
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) return const SizedBox.shrink();
    final premium = context.watch<MonetizationService>().isPremium;
    final scheme = Theme.of(context).colorScheme;
    final lock = premium
        ? null
        : Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant);

    return Column(
      children: [
        ListTile(
          title: Text(context.pick('Tema del widget', 'Widget theme')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lock != null) ...[lock, const SizedBox(width: 8)],
              DropdownButton<String>(
                value: s.theme,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                      value: 'auto',
                      child: Text(context.pick('Automático', 'Auto'))),
                  DropdownMenuItem(
                      value: 'light',
                      child: Text(context.pick('Claro', 'Light'))),
                  DropdownMenuItem(
                      value: 'dark',
                      child: Text(context.pick('Oscuro', 'Dark'))),
                ],
                onChanged: (v) {
                  if (v != null) _apply((s) => s.theme = v);
                },
              ),
            ],
          ),
        ),
        ListTile(
          title: Text(context.pick(
              'Color del widget resumen', 'Summary widget color')),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                for (final hex in AppTheme.noteColors)
                  GestureDetector(
                    onTap: () => _apply((s) => s.noteColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.noteColor(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.noteColor == hex
                              ? scheme.onSurface
                              : scheme.outlineVariant,
                          width: s.noteColor == hex ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: lock,
        ),
        ListTile(
          title: Text(context.pick('Opacidad del fondo', 'Background opacity')),
          subtitle: Slider(
            value: s.opacity.toDouble(),
            min: 60,
            max: 100,
            divisions: 8,
            label: '${s.opacity}%',
            onChanged: premium
                ? (v) => setState(() => s.opacity = v.round())
                : (_) => _requirePremium(),
            onChangeEnd: (v) => _apply((s) => s.opacity = v.round()),
          ),
          trailing: lock,
        ),
        SwitchListTile(
          title: Text(context.pick('Mostrar racha', 'Show streak')),
          value: s.showStreak,
          onChanged: (v) => _apply((s) => s.showStreak = v),
          secondary: lock,
        ),
        ListTile(
          title: Text(context.pick(
              'Zona del widget tablero', 'Board widget zone')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lock != null) ...[lock, const SizedBox(width: 8)],
              DropdownButton<String>(
                value: s.zone,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                      value: 'today',
                      child: Text(context.pick('Hoy', 'Today'))),
                  DropdownMenuItem(
                      value: 'dontForget',
                      child:
                          Text(context.pick('No olvidar', "Don't forget"))),
                  DropdownMenuItem(
                      value: 'waiting',
                      child: Text(context.pick('En espera', 'Waiting'))),
                ],
                onChanged: (v) {
                  if (v != null) _apply((s) => s.zone = v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
