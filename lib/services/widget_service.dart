import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory.dart';

// configuración visual de los widgets de pantalla de inicio; se guarda en
// las prefs de flutter y se replica a las prefs nativas en cada sync
class WidgetSettings {
  String theme; // auto | light | dark
  String noteColor; // hex del post-it del widget compacto
  int opacity; // 60..100, porcentaje de opacidad del fondo
  bool showStreak;
  String zone; // zona del widget tablero: today | dontForget | waiting

  WidgetSettings({
    this.theme = 'auto',
    this.noteColor = '#FFE082',
    this.opacity = 100,
    this.showStreak = true,
    this.zone = 'today',
  });

  // valores por defecto que ve un usuario free (sin personalización)
  factory WidgetSettings.defaults() => WidgetSettings();

  Map<String, dynamic> toMap() => {
        'theme': theme,
        'noteColor': noteColor,
        'opacity': opacity,
        'showStreak': showStreak,
        'zone': zone,
      };

  factory WidgetSettings.fromMap(Map<String, dynamic> map) => WidgetSettings(
        theme: (map['theme'] as String?) ?? 'auto',
        noteColor: (map['noteColor'] as String?) ?? '#FFE082',
        opacity: (map['opacity'] as int?) ?? 100,
        showStreak: (map['showStreak'] as bool?) ?? true,
        zone: (map['zone'] as String?) ?? 'today',
      );

  static const _prefsKey = 'widget_settings';

  static Future<WidgetSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return WidgetSettings();
    try {
      return WidgetSettings.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return WidgetSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toMap()));
  }
}

// puente entre el estado de la app y los widgets nativos de android:
// serializa memorias + config a las prefs de home_widget y pide el repintado
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  // nombres de los providers kotlin registrados en el manifest
  static const _providers = [
    'CompactWidgetProvider',
    'ListWidgetProvider',
    'BoardWidgetProvider',
  ];

  bool _isAndroid = false;
  bool _isPremium = false;
  bool _isEn = false;

  // la app llama a esto al arrancar y cuando cambian idioma o premium
  void configure({bool? isAndroid, bool? isPremium, bool? isEn}) {
    _isAndroid = isAndroid ?? _isAndroid;
    _isPremium = isPremium ?? _isPremium;
    _isEn = isEn ?? _isEn;
  }

  String _pick(String es, String en) => _isEn ? en : es;

  // misma regla de promoción que el tablero: vencida o pospuesta 2+ veces
  bool _promoted(Memory m) => m.isOverdue || m.snoozeCount >= 2;

  List<Memory> _forZone(List<Memory> memories, String zone) {
    final pending = memories.where((m) => !m.isCompleted);
    Iterable<Memory> list;
    switch (zone) {
      case 'dontForget':
        list = pending.where((m) =>
            m.zone == BoardZone.dontForget ||
            (m.zone == BoardZone.today && _promoted(m)));
      case 'waiting':
        list = pending.where((m) => m.zone == BoardZone.waiting);
      default:
        list = pending.where((m) => m.zone == BoardZone.today && !_promoted(m));
    }
    return list.toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  String _zoneTitle(String zone) {
    switch (zone) {
      case 'dontForget':
        return _pick('No olvidar', "Don't forget");
      case 'waiting':
        return _pick('En espera', 'Waiting');
      default:
        return _pick('Hoy', 'Today');
    }
  }

  Map<String, dynamic> _itemMap(Memory m) => {
        'id': m.id,
        'title': m.title,
        'time': m.hasTime && m.effectiveDue != null
            ? DateFormat.Hm().format(m.effectiveDue!)
            : '',
        'dueEpoch': m.effectiveDue?.millisecondsSinceEpoch ?? 0,
        'hasTime': m.hasTime,
        'color': m.color,
        'priority': m.priority.name,
        'overdue': m.isOverdue,
      };

  // vuelca el estado actual a las prefs nativas y repinta todos los widgets.
  // nunca lanza: un fallo aquí no debe romper el guardado de memorias
  Future<void> sync(List<Memory> memories, int currentStreak) async {
    if (!_isAndroid) return;
    try {
      // sin premium se fuerzan los valores por defecto (un downgrade
      // devuelve los widgets a su apariencia básica)
      final settings =
          _isPremium ? await WidgetSettings.load() : WidgetSettings.defaults();

      final today = _forZone(memories, 'today');
      final board = _forZone(memories, settings.zone);
      final locale = _isEn ? 'en_US' : 'es';
      final dateLabel =
          DateFormat('EEE d MMM', locale).format(DateTime.now());

      await Future.wait([
        HomeWidget.saveWidgetData<String>('widget_today_json',
            jsonEncode(today.take(20).map(_itemMap).toList())),
        HomeWidget.saveWidgetData<String>('widget_board_json',
            jsonEncode(board.take(40).map(_itemMap).toList())),
        HomeWidget.saveWidgetData<int>('widget_pending_count', today.length),
        HomeWidget.saveWidgetData<int>('widget_streak', currentStreak),
        HomeWidget.saveWidgetData<String>('widget_date_label', dateLabel),
        HomeWidget.saveWidgetData<String>(
            'widget_today_title', _zoneTitle('today')),
        HomeWidget.saveWidgetData<String>(
            'widget_board_title', _zoneTitle(settings.zone)),
        HomeWidget.saveWidgetData<String>('widget_pending_label',
            _pick('pendientes hoy', 'pending today')),
        HomeWidget.saveWidgetData<String>('widget_empty_label',
            _pick('Todo hecho ✓', 'All done ✓')),
        HomeWidget.saveWidgetData<String>(
            'widget_add_label', _pick('Nueva nota', 'New note')),
        HomeWidget.saveWidgetData<String>('widget_streak_label',
            _pick('días de racha', 'day streak')),
        HomeWidget.saveWidgetData<String>('widget_theme', settings.theme),
        HomeWidget.saveWidgetData<String>(
            'widget_note_color', settings.noteColor),
        HomeWidget.saveWidgetData<int>('widget_opacity', settings.opacity),
        HomeWidget.saveWidgetData<bool>(
            'widget_show_streak', settings.showStreak),
      ]);

      for (final provider in _providers) {
        // nombre totalmente cualificado: el applicationId lleva sufijo de
        // flavor (.free/.paid) pero las clases viven en el namespace base
        await HomeWidget.updateWidget(
            qualifiedAndroidName:
                'com.danielux135.memorylux.widgets.$provider');
      }
    } catch (e) {
      debugPrint('WidgetService sync error: $e');
    }
  }
}
