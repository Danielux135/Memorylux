import 'package:uuid/uuid.dart';

// zona del tablero donde vive la memoria
enum BoardZone { today, dontForget, waiting }

// nivel de insistencia de una memoria
enum MemoryPriority { normal, important, persistent }

// tipo de repetición del recordatorio
enum RecurrenceType { none, daily, weekly, monthly, weekdays, everyXHours }

class ChecklistItem {
  String text;
  bool done;

  ChecklistItem({required this.text, this.done = false});

  Map<String, dynamic> toMap() => {'text': text, 'done': done};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        text: (map['text'] as String?) ?? '',
        done: (map['done'] as bool?) ?? false,
      );
}

// regla de repetición: tipo + días concretos + intervalo de horas + fecha límite
class Recurrence {
  final RecurrenceType type;
  final List<int> weekdays; // 1=lunes ... 7=domingo, solo para type=weekdays
  final int everyHours; // solo para type=everyXHours
  final DateTime? until; // repetir hasta esta fecha (inclusive)

  const Recurrence({
    this.type = RecurrenceType.none,
    this.weekdays = const [],
    this.everyHours = 1,
    this.until,
  });

  bool get isNone => type == RecurrenceType.none;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'weekdays': weekdays,
        'everyHours': everyHours,
        'until': until?.toIso8601String(),
      };

  factory Recurrence.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const Recurrence();
    return Recurrence(
      type: RecurrenceType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => RecurrenceType.none,
      ),
      weekdays: ((map['weekdays'] as List?) ?? []).cast<int>(),
      everyHours: (map['everyHours'] as int?) ?? 1,
      until:
          map['until'] != null ? DateTime.parse(map['until'] as String) : null,
    );
  }

  // siguiente aparición a partir de una fecha con hora ya resuelta
  DateTime? nextAfter(DateTime current) {
    DateTime? next;
    switch (type) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        next = current.add(const Duration(days: 1));
      case RecurrenceType.weekly:
        next = current.add(const Duration(days: 7));
      case RecurrenceType.monthly:
        final month = current.month == 12 ? 1 : current.month + 1;
        final year = current.month == 12 ? current.year + 1 : current.year;
        final lastDay = DateTime(year, month + 1, 0).day;
        next = DateTime(year, month,
            current.day > lastDay ? lastDay : current.day, current.hour, current.minute);
      case RecurrenceType.weekdays:
        if (weekdays.isEmpty) return null;
        var candidate = current.add(const Duration(days: 1));
        for (var i = 0; i < 7; i++) {
          if (weekdays.contains(candidate.weekday)) break;
          candidate = candidate.add(const Duration(days: 1));
        }
        next = candidate;
      case RecurrenceType.everyXHours:
        next = current.add(Duration(hours: everyHours < 1 ? 1 : everyHours));
    }
    if (until != null && next.isAfter(until!.add(const Duration(days: 1)))) {
      return null;
    }
    return next;
  }

  // etiqueta corta para mostrar en la tarjeta (español o inglés)
  String get label => labelFor(false);

  String labelFor(bool en) {
    switch (type) {
      case RecurrenceType.none:
        return '';
      case RecurrenceType.daily:
        return en ? 'daily' : 'cada día';
      case RecurrenceType.weekly:
        return en ? 'weekly' : 'cada semana';
      case RecurrenceType.monthly:
        return en ? 'monthly' : 'cada mes';
      case RecurrenceType.weekdays:
        final names = en
            ? ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su']
            : ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
        final days = weekdays.map((d) => names[d - 1]).join('·');
        return days;
      case RecurrenceType.everyXHours:
        return en ? 'every ${everyHours}h' : 'cada ${everyHours}h';
    }
  }
}

// una memoria: nota adhesiva y recordatorio en un solo objeto
class Memory {
  final String id;
  final String userId;
  String title;
  String body;
  List<ChecklistItem> checklist;
  String color; // hex del post-it
  String? imagePath; // foto de fondo del sticker (ruta local)
  List<String> tags;
  DateTime? dueDate; // fecha con hora si tiene alarma
  bool hasTime; // si dueDate incluye hora concreta
  Recurrence recurrence;
  MemoryPriority priority;
  BoardZone zone;
  bool isCompleted;
  DateTime? completedAt;
  int snoozeCount; // veces pospuesta desde la última alarma
  DateTime? snoozedUntil;
  int? notificationMinutesBefore;
  double rotation; // inclinación fija del post-it en el tablero
  double order; // orden manual dentro de su zona (arrastrar y soltar)
  final DateTime createdAt;
  DateTime updatedAt;

  Memory({
    String? id,
    required this.userId,
    required this.title,
    this.body = '',
    List<ChecklistItem>? checklist,
    this.color = '#FFE082',
    this.imagePath,
    List<String>? tags,
    this.dueDate,
    this.hasTime = false,
    this.recurrence = const Recurrence(),
    this.priority = MemoryPriority.normal,
    this.zone = BoardZone.today,
    this.isCompleted = false,
    this.completedAt,
    this.snoozeCount = 0,
    this.snoozedUntil,
    this.notificationMinutesBefore,
    double? rotation,
    double? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        checklist = checklist ?? [],
        tags = tags ?? [],
        rotation = rotation ?? _rotationFor(id),
        order = order ?? DateTime.now().millisecondsSinceEpoch.toDouble(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // zona a la que debería ir una memoria según su fecha: sin fecha → en
  // espera, hoy → hoy, cualquier otro día (pasado o futuro) → no olvidar
  static BoardZone zoneForDate(DateTime? date) {
    if (date == null) return BoardZone.waiting;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.isAtSameMomentAs(today) ? BoardZone.today : BoardZone.dontForget;
  }

  // rotación estable derivada del id para que cada nota tenga su propia inclinación
  static double _rotationFor(String? id) {
    final h = (id ?? const Uuid().v4()).hashCode;
    return ((h % 100) / 100.0 - 0.5) * 0.06; // entre -0.03 y 0.03 radianes
  }

  bool get isOverdue =>
      !isCompleted &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      (snoozedUntil == null || snoozedUntil!.isBefore(DateTime.now()));

  // fecha efectiva para la próxima alarma teniendo en cuenta el posponer
  DateTime? get effectiveDue {
    if (snoozedUntil != null && dueDate != null) {
      return snoozedUntil!.isAfter(dueDate!) ? snoozedUntil : dueDate;
    }
    return snoozedUntil ?? dueDate;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'checklist': checklist.map((c) => c.toMap()).toList(),
        'color': color,
        'imagePath': imagePath,
        'tags': tags,
        'dueDate': dueDate?.toIso8601String(),
        'hasTime': hasTime,
        'recurrence': recurrence.toMap(),
        'priority': priority.name,
        'zone': zone.name,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'snoozeCount': snoozeCount,
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'notificationMinutesBefore': notificationMinutesBefore,
        'rotation': rotation,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Memory.fromMap(Map<String, dynamic> map) => Memory(
        id: map['id'] as String?,
        userId: (map['userId'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        checklist: ((map['checklist'] as List?) ?? [])
            .map((c) => ChecklistItem.fromMap(Map<String, dynamic>.from(c)))
            .toList(),
        color: (map['color'] as String?) ?? '#FFE082',
        imagePath: map['imagePath'] as String?,
        tags: ((map['tags'] as List?) ?? []).cast<String>(),
        dueDate: map['dueDate'] != null
            ? DateTime.parse(map['dueDate'] as String)
            : null,
        hasTime: (map['hasTime'] as bool?) ?? false,
        recurrence: Recurrence.fromMap(map['recurrence'] != null
            ? Map<String, dynamic>.from(map['recurrence'])
            : null),
        priority: MemoryPriority.values.firstWhere(
          (p) => p.name == map['priority'],
          orElse: () => MemoryPriority.normal,
        ),
        zone: BoardZone.values.firstWhere(
          (z) => z.name == map['zone'],
          orElse: () => BoardZone.today,
        ),
        isCompleted: (map['isCompleted'] as bool?) ?? false,
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        snoozeCount: (map['snoozeCount'] as int?) ?? 0,
        snoozedUntil: map['snoozedUntil'] != null
            ? DateTime.parse(map['snoozedUntil'] as String)
            : null,
        notificationMinutesBefore: map['notificationMinutesBefore'] as int?,
        rotation: (map['rotation'] as num?)?.toDouble(),
        order: (map['order'] as num?)?.toDouble() ??
            (map['createdAt'] != null
                ? DateTime.parse(map['createdAt'] as String)
                    .millisecondsSinceEpoch
                    .toDouble()
                : null),
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : null,
        updatedAt: map['updatedAt'] != null
            ? DateTime.parse(map['updatedAt'] as String)
            : null,
      );

  Memory copyWith({
    String? title,
    String? body,
    List<ChecklistItem>? checklist,
    String? color,
    Object? imagePath = _sentinel,
    List<String>? tags,
    Object? dueDate = _sentinel,
    bool? hasTime,
    Recurrence? recurrence,
    MemoryPriority? priority,
    BoardZone? zone,
    bool? isCompleted,
    Object? completedAt = _sentinel,
    int? snoozeCount,
    Object? snoozedUntil = _sentinel,
    Object? notificationMinutesBefore = _sentinel,
    double? order,
  }) =>
      Memory(
        id: id,
        userId: userId,
        title: title ?? this.title,
        body: body ?? this.body,
        checklist: checklist ?? this.checklist,
        color: color ?? this.color,
        imagePath:
            imagePath == _sentinel ? this.imagePath : imagePath as String?,
        tags: tags ?? this.tags,
        dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
        hasTime: hasTime ?? this.hasTime,
        recurrence: recurrence ?? this.recurrence,
        priority: priority ?? this.priority,
        zone: zone ?? this.zone,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt == _sentinel
            ? this.completedAt
            : completedAt as DateTime?,
        snoozeCount: snoozeCount ?? this.snoozeCount,
        snoozedUntil: snoozedUntil == _sentinel
            ? this.snoozedUntil
            : snoozedUntil as DateTime?,
        notificationMinutesBefore: notificationMinutesBefore == _sentinel
            ? this.notificationMinutesBefore
            : notificationMinutesBefore as int?,
        rotation: rotation,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  static const _sentinel = Object();
}
