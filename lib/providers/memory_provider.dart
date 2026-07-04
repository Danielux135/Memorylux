import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory.dart';
import '../models/user_settings.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

// estado central: todas las memorias, el tablero, posponer, completar y migrar
class MemoryProvider extends ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService;
  final SyncService _syncService;

  List<Memory> _memories = [];
  StreamSubscription<NotificationResponse>? _notificationSubscription;
  bool _isLoading = false;
  String _searchQuery = '';
  String? _tagFilter;

  List<Memory> get memories => _memories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get tagFilter => _tagFilter;

  MemoryProvider({
    required AuthService authService,
    required NotificationService notificationService,
    required SyncService syncService,
  })  : _authService = authService,
        _notificationService = notificationService,
        _syncService = syncService {
    _notificationSubscription =
        _notificationService.responses.listen(_handleNotificationResponse);
  }

  // ------- vistas del tablero -------

  List<Memory> _visible(Iterable<Memory> source) {
    var list = source.where((m) => !m.isCompleted);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) =>
          m.title.toLowerCase().contains(q) ||
          m.body.toLowerCase().contains(q) ||
          m.tags.any((t) => t.contains(q)));
    }
    if (_tagFilter != null) {
      list = list.where((m) => m.tags.contains(_tagFilter));
    }
    return list.toList();
  }

  // una nota "sube" a NO OLVIDAR si venció o la has pospuesto varias veces
  bool _promoted(Memory m) => m.isOverdue || m.snoozeCount >= 2;

  // HOY: todo lo de la zona hoy que no haya sido promocionado.
  // Importante: aunque la fecha sea futura se muestra igual (con su pastilla
  // de "mañana", "viernes"...), para que nada guardado quede invisible.
  List<Memory> get todayMemories {
    return _visible(
        _memories.where((m) => m.zone == BoardZone.today && !_promoted(m)))
      ..sort(_byOrder);
  }

  // NO OLVIDAR: lo marcado por el usuario más lo vencido/pospuesto de HOY
  List<Memory> get dontForgetMemories {
    return _visible(_memories.where((m) {
      if (m.zone == BoardZone.dontForget) return true;
      return m.zone == BoardZone.today && _promoted(m);
    }))
      // el orden manual manda, también sobre las persistentes
      ..sort(_byOrder);
  }

  // EN ESPERA: sin fecha o aparcadas a propósito
  List<Memory> get waitingMemories =>
      _visible(_memories.where((m) => m.zone == BoardZone.waiting))
        ..sort(_byOrder);

  int _byOrder(Memory a, Memory b) => a.order.compareTo(b.order);

  List<Memory> get completedMemories => _memories
      .where((m) => m.isCompleted)
      .toList()
    ..sort((a, b) =>
        (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));

  int _byDue(Memory a, Memory b) {
    final da = a.effectiveDue;
    final db = b.effectiveDue;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final m in _memories.where((m) => !m.isCompleted)) {
      tags.addAll(m.tags);
    }
    final list = tags.toList()..sort();
    return list;
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _tagFilter = tag;
    notifyListeners();
  }

  // ------- calendario -------

  List<Memory> memoriesForDate(DateTime date) => _memories
      .where((m) =>
          m.dueDate != null &&
          m.dueDate!.year == date.year &&
          m.dueDate!.month == date.month &&
          m.dueDate!.day == date.day)
      .toList()
    ..sort(_byDue);

  // ------- estadísticas -------

  int get completedToday {
    final now = DateTime.now();
    return _memories
        .where((m) =>
            m.isCompleted &&
            m.completedAt != null &&
            m.completedAt!.year == now.year &&
            m.completedAt!.month == now.month &&
            m.completedAt!.day == now.day)
        .length;
  }

  int get completedThisWeek {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _memories
        .where((m) =>
            m.isCompleted &&
            m.completedAt != null &&
            !m.completedAt!.isBefore(weekStart))
        .length;
  }

  // racha: días seguidos (hasta hoy o ayer) con al menos una memoria completada
  int get bestStreak {
    final days = _memories
        .where((m) => m.isCompleted && m.completedAt != null)
        .map((m) => DateTime(
            m.completedAt!.year, m.completedAt!.month, m.completedAt!.day))
        .toSet()
        .toList()
      ..sort();
    var best = 0;
    var current = 0;
    DateTime? prev;
    for (final d in days) {
      current =
          (prev != null && d.difference(prev).inDays == 1) ? current + 1 : 1;
      if (current > best) best = current;
      prev = d;
    }
    return best;
  }

  int get currentStreak {
    final days = _memories
        .where((m) => m.isCompleted && m.completedAt != null)
        .map((m) => DateTime(
            m.completedAt!.year, m.completedAt!.month, m.completedAt!.day))
        .toSet();
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) {
      day = day
          .subtract(const Duration(days: 1)); // la racha sobrevive hasta ayer
      if (!days.contains(day)) return 0;
    }
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ------- mutaciones -------

  // mantiene al día el resumen matinal cada vez que cambian las memorias
  Future<void> _refreshDailySummary(UserSettings settings) =>
      _notificationService.scheduleDailySummary(_memories, settings);

  Future<void> addMemory(Memory memory, UserSettings settings) async {
    _memories.add(memory);
    notifyListeners();
    await _saveToLocal();
    await _notificationService.scheduleMemory(memory, settings);
    await _refreshDailySummary(settings);
    if (settings.syncEnabled) {
      await _syncService.pushMemory(
          userId: _authService.userId, memory: memory);
    }
  }

  Future<void> updateMemory(Memory memory, UserSettings settings) async {
    final index = _memories.indexWhere((m) => m.id == memory.id);
    if (index == -1) return;
    _memories[index] = memory;
    notifyListeners();
    await _saveToLocal();
    await _notificationService.scheduleMemory(memory, settings);
    await _refreshDailySummary(settings);
    if (settings.syncEnabled) {
      await _syncService.pushMemory(
          userId: _authService.userId, memory: memory);
    }
  }

  // completar: si tiene repetición, genera la siguiente aparición.
  // primero se actualiza la UI y después, en segundo plano, disco y alarmas
  Future<void> complete(Memory memory, UserSettings settings) async {
    final index = _memories.indexWhere((m) => m.id == memory.id);
    if (index == -1) return;

    _memories[index] = memory.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      snoozeCount: 0,
      snoozedUntil: null,
    );
    notifyListeners();
    await _notificationService.cancelMemory(memory);

    if (!memory.recurrence.isNone && memory.dueDate != null) {
      final next = memory.recurrence.nextAfter(memory.dueDate!);
      if (next != null) {
        final copy = Memory(
          userId: memory.userId,
          title: memory.title,
          body: memory.body,
          checklist:
              memory.checklist.map((c) => ChecklistItem(text: c.text)).toList(),
          color: memory.color,
          imagePath: memory.imagePath,
          tags: List.of(memory.tags),
          dueDate: next,
          hasTime: memory.hasTime,
          recurrence: memory.recurrence,
          priority: memory.priority,
          zone: Memory.zoneForDate(next),
          notificationMinutesBefore: memory.notificationMinutesBefore,
        );
        _memories.add(copy);
        await _notificationService.scheduleMemory(copy, settings);
      }
    }

    await _saveToLocal();
    notifyListeners();
    await _refreshDailySummary(settings);
    if (settings.syncEnabled) {
      await _syncService.pushMemory(
        userId: _authService.userId,
        memory: _memories[index],
      );
    }
  }

  Future<void> uncomplete(Memory memory, UserSettings settings) async {
    final index = _memories.indexWhere((m) => m.id == memory.id);
    if (index == -1) return;
    _memories[index] = memory.copyWith(isCompleted: false, completedAt: null);
    notifyListeners();
    await _saveToLocal();
    await _notificationService.scheduleMemory(_memories[index], settings);
    await _refreshDailySummary(settings);
  }

  Future<void> snooze(
      Memory memory, DateTime until, UserSettings settings) async {
    final index = _memories.indexWhere((m) => m.id == memory.id);
    if (index == -1) return;
    final updated = memory.copyWith(
      snoozedUntil: until,
      snoozeCount: memory.snoozeCount + 1,
    );
    _memories[index] = updated;
    notifyListeners();
    await _saveToLocal();
    await _notificationService.scheduleMemory(updated, settings);
    await _refreshDailySummary(settings);
    if (settings.syncEnabled) {
      await _syncService.pushMemory(
          userId: _authService.userId, memory: updated);
    }
  }

  Future<void> _handleNotificationResponse(
      NotificationResponse response) async {
    final memoryId = response.payload;
    if (memoryId == null || memoryId.isEmpty) return;

    final index = _memories.indexWhere((m) => m.id == memoryId);
    if (index == -1) return;

    final settings = UserSettings(userId: _authService.userId);
    final memory = _memories[index];
    switch (response.actionId) {
      case 'snooze_10':
        await snooze(
            memory, DateTime.now().add(const Duration(minutes: 10)), settings);
      case 'complete':
        await complete(memory, settings);
      default:
        break;
    }
  }

  Future<void> moveToZone(
      Memory memory, BoardZone zone, UserSettings settings) async {
    await updateMemory(memory.copyWith(zone: zone), settings);
  }

  // reordena `moved` dentro de una lista de la zona `zone` ya ordenada por
  // posición, colocándolo antes o después de `target` según `insertBefore`
  // (o al final si target es null). También fija la zona, así que sirve
  // igual para reordenar dentro de una zona o para mover entre zonas.
  Future<void> reorder(BoardZone zone, List<Memory> zoneOrder, Memory moved,
      Memory? target, bool insertBefore, UserSettings settings) async {
    final rest = zoneOrder.where((m) => m.id != moved.id).toList();
    final insertAt = target == null
        ? rest.length
        : () {
            final i = rest.indexWhere((m) => m.id == target.id);
            if (i == -1) return rest.length;
            return insertBefore ? i : i + 1;
          }();

    final beforeOrder = insertAt > 0 ? rest[insertAt - 1].order : null;
    final afterOrder = insertAt < rest.length ? rest[insertAt].order : null;

    double newOrder;
    if (beforeOrder != null && afterOrder != null) {
      newOrder = (beforeOrder + afterOrder) / 2;
    } else if (beforeOrder != null) {
      newOrder = beforeOrder + 1000;
    } else if (afterOrder != null) {
      newOrder = afterOrder - 1000;
    } else {
      newOrder = DateTime.now().millisecondsSinceEpoch.toDouble();
    }

    await updateMemory(moved.copyWith(order: newOrder, zone: zone), settings);
  }

  Future<void> deleteMemory(String id, {UserSettings? settings}) async {
    final index = _memories.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final memory = _memories[index];
    _memories.removeAt(index);
    notifyListeners();
    await _notificationService.cancelMemory(memory);
    if (settings != null) await _refreshDailySummary(settings);
    await _saveToLocal();
    await _syncService.deleteMemory(userId: _authService.userId, memoryId: id);
  }

  // reprograma todos los avisos y el resumen diario con los ajustes dados
  Future<void> rescheduleAll(UserSettings settings) async {
    await _notificationService.rescheduleAll(_memories, settings);
  }

  Future<void> replaceAll(List<Memory> memories, UserSettings settings) async {
    _memories = memories;
    await _saveToLocal();
    await _notificationService.rescheduleAll(_memories, settings);
    notifyListeners();
  }

  // ------- persistencia local y migración -------

  Future<void> loadMemories() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('memories');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _memories = list
          .map((e) => Memory.fromMap({
                ...Map<String, dynamic>.from(e),
                'userId': _authService.userId,
              }))
          .toList();
    } else {
      await _migrateLegacyLocal(prefs);
    }

    _isLoading = false;
    notifyListeners();
  }

  // convierte los datos de la versión 1 (reminders + sticky_notes) en memorias
  Future<void> _migrateLegacyLocal(SharedPreferences prefs) async {
    final migrated = <Memory>[];

    final remindersData = prefs.getString('reminders');
    if (remindersData != null) {
      for (final e in jsonDecode(remindersData) as List) {
        final map = Map<String, dynamic>.from(e);
        final time =
            map['time'] != null ? DateTime.parse(map['time'] as String) : null;
        final date = DateTime.parse(map['date'] as String);
        migrated.add(Memory(
          id: map['id'] as String?,
          userId: _authService.userId,
          title: (map['title'] as String?) ?? '',
          body: (map['description'] as String?) ?? '',
          dueDate: time ?? DateTime(date.year, date.month, date.day, 9, 0),
          hasTime: time != null,
          isCompleted: (map['isCompleted'] as bool?) ?? false,
          tags: map['category'] != null ? [map['category'] as String] : [],
          notificationMinutesBefore: map['notificationMinutesBefore'] as int?,
        ));
      }
    }

    final notesData = prefs.getString('sticky_notes');
    if (notesData != null) {
      for (final e in jsonDecode(notesData) as List) {
        final map = Map<String, dynamic>.from(e);
        migrated.add(Memory(
          id: map['id'] as String?,
          userId: _authService.userId,
          title: (map['content'] as String?) ?? '',
          color: (map['color'] as String?) ?? '#FFE082',
          zone: BoardZone.waiting,
          priority: (map['isPinned'] as bool?) == true
              ? MemoryPriority.important
              : MemoryPriority.normal,
        ));
      }
    }

    if (migrated.isNotEmpty) {
      _memories = migrated;
      await _saveToLocal();
    }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'memories', jsonEncode(_memories.map((m) => m.toMap()).toList()));
  }

  Future<void> syncWithCloud(UserSettings settings) async {
    if (!settings.syncEnabled) return;

    // primera sincronización: arrastra también lo antiguo de la nube
    if (_memories.isEmpty) {
      final legacyReminders =
          await _syncService.fetchLegacy(_authService.userId, 'reminders');
      for (final map in legacyReminders) {
        try {
          final time = map['time'] != null
              ? DateTime.parse(map['time'] as String)
              : null;
          final date = DateTime.parse(map['date'] as String);
          _memories.add(Memory(
            id: map['id'] as String?,
            userId: _authService.userId,
            title: (map['title'] as String?) ?? '',
            body: (map['description'] as String?) ?? '',
            dueDate: time ?? DateTime(date.year, date.month, date.day, 9, 0),
            hasTime: time != null,
            isCompleted: (map['isCompleted'] as bool?) ?? false,
          ));
        } catch (_) {}
      }
    }

    await _syncService.syncMemories(
      userId: _authService.userId,
      localMemories: _memories,
      onUpdate: (merged) {
        // conserva las rutas de imagen locales que la nube no conoce
        final localImages = {
          for (final m in _memories)
            if (m.imagePath != null) m.id: m.imagePath
        };
        _memories = merged.map((m) {
          if (m.imagePath == null && localImages[m.id] != null) {
            return m.copyWith(imagePath: localImages[m.id]);
          }
          return m;
        }).toList();
        _saveToLocal();
        notifyListeners();
      },
    );
    await _notificationService.rescheduleAll(_memories, settings);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
