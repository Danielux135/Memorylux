import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

import '../models/memory.dart';
import '../models/user_settings.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationResponse> _responses =
      StreamController<NotificationResponse>.broadcast();
  bool _initialized = false;

  bool get initialized => _initialized;
  Stream<NotificationResponse> get responses => _responses.stream;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      windows: WindowsInitializationSettings(
        appName: 'Memorylux',
        appUserModelId: 'com.danielux135.memorylux',
        guid: 'd8b110aa-2a35-49a2-9e0d-9f2e1b6f7c11',
      ),
    );

    // si el plugin falla en alguna plataforma, la app sigue funcionando sin avisos
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _responses.add,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
    }
    notifyListeners();
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final notificationsAllowed =
            await android.requestNotificationsPermission() ??
                await android.areNotificationsEnabled() ??
                false;
        final canScheduleExact =
            await android.canScheduleExactNotifications() ?? false;
        if (!canScheduleExact) {
          await android.requestExactAlarmsPermission();
        }
        if (!notificationsAllowed) return false;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        await ios.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('No se pudieron pedir permisos de notificación: $e');
    }
    return true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'memorylux_memories_v2',
      'Recuerdos',
      channelDescription: 'Alarmas de tus memorias en Memorylux',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      actions: [
        AndroidNotificationAction(
          'snooze_10',
          'Posponer 10 min',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'complete',
          'Hecho',
          showsUserInterface: true,
          semanticAction: SemanticAction.markAsRead,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _persistentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'memorylux_persistent_v2',
      'Recuerdos persistentes',
      channelDescription:
          'Reavisos de memorias importantes que siguen pendientes',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      playSound: true,
      actions: [
        AndroidNotificationAction(
          'snooze_10',
          'Posponer 10 min',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'complete',
          'Hecho',
          showsUserInterface: true,
          semanticAction: SemanticAction.markAsRead,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _summaryDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'memorylux_summary_v2',
      'Resumen del día',
      channelDescription: 'Resumen matinal con las tareas del día',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  // id fijo reservado para el resumen diario
  static const _dailySummaryId = 1;

  // ids derivados del id de la memoria: base para la alarma a la hora exacta,
  // +1..+5 para reavisos, +6 para el aviso previo con antelación
  int _baseId(Memory m) => m.id.hashCode & 0x3FFFFFFF;

  // etiqueta corta de una antelación en minutos: "30 min", "2 h", "1 día"
  static String leadLabel(int minutes, bool en) {
    if (minutes % 1440 == 0) {
      final d = minutes ~/ 1440;
      return en ? '$d day${d > 1 ? 's' : ''}' : '$d día${d > 1 ? 's' : ''}';
    }
    if (minutes % 60 == 0) return '${minutes ~/ 60} h';
    return '$minutes min';
  }

  // programa la alarma a la hora exacta, el aviso previo con antelación y,
  // si es persistente, los reavisos escalonados
  Future<void> scheduleMemory(Memory memory, UserSettings settings) async {
    if (!_initialized) return;
    // solo cancela lo pendiente de esta memoria: así reprogramar no borra
    // los avisos que ya están en la bandeja del sistema
    await _cancelPending(memory);
    if (!settings.notificationsEnabled) return;
    if (memory.isCompleted) return;

    final due = memory.effectiveDue;
    if (due == null) return;

    final en = settings.language == 'en';
    final base = _baseId(memory);
    if (due.isAfter(DateTime.now())) {
      await _schedule(
        id: base,
        title: memory.title,
        body: memory.body.isEmpty
            ? (en
                ? 'You have a pending memory'
                : 'Tienes un recuerdo pendiente')
            : memory.body,
        when: due,
        details: _details,
        payload: memory.id,
      );
    }

    // aviso previo con antelación, solo para memorias con hora concreta
    final minutesBefore =
        memory.notificationMinutesBefore ?? settings.defaultNotificationMinutes;
    if (memory.hasTime && minutesBefore > 0) {
      final early = due.subtract(Duration(minutes: minutesBefore));
      if (early.isAfter(DateTime.now())) {
        final label = leadLabel(minutesBefore, en);
        await _schedule(
          id: base + 6,
          title:
              en ? 'In $label: ${memory.title}' : 'En $label: ${memory.title}',
          body: memory.body.isEmpty
              ? (en ? 'Get ready, it\'s coming up' : 'Prepárate, que se acerca')
              : memory.body,
          when: early,
          details: _details,
          payload: memory.id,
        );
      }
    }

    // Reavisos para que una alarma no desaparezca si se desliza.
    final repeats = memory.priority == MemoryPriority.important
        ? 1
        : settings.persistentMaxAlerts;
    for (var i = 1; i <= repeats; i++) {
      final followUp =
          due.add(Duration(minutes: settings.persistentRepeatMinutes * i));
      if (followUp.isAfter(DateTime.now())) {
        await _schedule(
          id: base + i,
          title: '¿Sigue pendiente? ${memory.title}',
          body: 'Hazlo ahora, pospónlo o descártalo.',
          when: followUp,
          details: memory.priority == MemoryPriority.persistent
              ? _persistentDetails
              : _details,
          payload: memory.id,
        );
      }
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required NotificationDetails details,
    String? payload,
  }) async {
    final scheduledDate = tz.TZDateTime.from(when, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      if (e.toString().contains('exact_alarms_not_permitted')) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
          debugPrint(
            'Notificación programada sin alarma exacta porque Android no dio permiso.',
          );
          return;
        } catch (fallbackError) {
          debugPrint(
            'No se pudo programar la notificación sin alarma exacta: $fallbackError',
          );
        }
      } else {
        debugPrint('No se pudo programar la notificación: $e');
      }
    }
  }

  // cancela solo las alarmas aún no lanzadas de esta memoria
  Future<void> _cancelPending(Memory memory) async {
    final base = _baseId(memory);
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= base && p.id <= base + 6) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('No se pudieron leer las alarmas pendientes: $e');
    }
  }

  // cancela todo lo de esta memoria, incluida la notificación ya mostrada
  // (para cuando se completa o se borra)
  Future<void> cancelMemory(Memory memory) async {
    if (!_initialized) return;
    final base = _baseId(memory);
    try {
      for (var i = 0; i <= 6; i++) {
        await _plugin.cancel(id: base + i);
      }
    } catch (e) {
      debugPrint('No se pudo cancelar la notificación: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('No se pudieron cancelar las notificaciones: $e');
    }
  }

  // reprograma las pendientes sin tocar las notificaciones ya mostradas:
  // programar con el mismo id sustituye la alarma anterior
  Future<void> rescheduleAll(
    List<Memory> memories,
    UserSettings settings,
  ) async {
    for (final memory in memories) {
      if (!memory.isCompleted) {
        await scheduleMemory(memory, settings);
      }
    }
    await scheduleDailySummary(memories, settings);
  }

  // resumen matinal con las tareas del día, en la próxima ocurrencia de la
  // hora configurada; se refresca cada vez que cambian memorias o ajustes
  Future<void> scheduleDailySummary(
    List<Memory> memories,
    UserSettings settings,
  ) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _dailySummaryId);
    } catch (_) {}
    if (!settings.notificationsEnabled || !settings.dailySummaryEnabled) {
      return;
    }

    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, settings.dailySummaryHour,
        settings.dailySummaryMinute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    final day = DateTime(when.year, when.month, when.day);
    final todays = memories.where((m) {
      if (m.isCompleted) return false;
      final due = m.effectiveDue;
      if (due == null) return false;
      final d = DateTime(due.year, due.month, due.day);
      return d.isAtSameMomentAs(day);
    }).toList()
      ..sort((a, b) => (a.effectiveDue!).compareTo(b.effectiveDue!));
    if (todays.isEmpty) return;

    final en = settings.language == 'en';
    final titles = todays.take(4).map((m) => '• ${m.title}').toList();
    if (todays.length > 4) {
      titles.add(en
          ? '…and ${todays.length - 4} more'
          : '…y ${todays.length - 4} más');
    }
    await _schedule(
      id: _dailySummaryId,
      title: en
          ? 'Your day: ${todays.length} task${todays.length > 1 ? 's' : ''}'
          : 'Tu día: ${todays.length} tarea${todays.length > 1 ? 's' : ''}',
      body: titles.join('\n'),
      when: when,
      details: _summaryDetails,
    );
  }
}
