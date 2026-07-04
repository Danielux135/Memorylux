class UserSettings {
  final String userId;
  bool notificationsEnabled;
  DateTime? quietModeStart; // hora de inicio del modo descanso
  DateTime? quietModeEnd; // hora de fin del modo descanso
  bool quietModeEnabled;
  int defaultNotificationMinutes;
  bool syncEnabled;
  String themeMode; // 'light', 'dark', 'system'
  int persistentRepeatMinutes; // cada cuánto reavisa una nota persistente
  int persistentMaxAlerts; // cuántos reavisos programa por alarma
  String language; // 'es' o 'en'
  bool dailySummaryEnabled; // resumen de tareas al empezar el día
  int dailySummaryHour; // hora del resumen diario
  int dailySummaryMinute; // minuto del resumen diario

  UserSettings({
    required this.userId,
    this.notificationsEnabled = true,
    this.quietModeStart,
    this.quietModeEnd,
    this.quietModeEnabled = false,
    this.defaultNotificationMinutes = 30,
    this.syncEnabled = true,
    this.themeMode = 'dark',
    this.persistentRepeatMinutes = 10,
    this.persistentMaxAlerts = 3,
    this.language = 'es',
    this.dailySummaryEnabled = true,
    this.dailySummaryHour = 8,
    this.dailySummaryMinute = 0,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'notificationsEnabled': notificationsEnabled,
        'quietModeStart': quietModeStart?.toIso8601String(),
        'quietModeEnd': quietModeEnd?.toIso8601String(),
        'quietModeEnabled': quietModeEnabled,
        'defaultNotificationMinutes': defaultNotificationMinutes,
        'syncEnabled': syncEnabled,
        'themeMode': themeMode,
        'persistentRepeatMinutes': persistentRepeatMinutes,
        'persistentMaxAlerts': persistentMaxAlerts,
        'language': language,
        'dailySummaryEnabled': dailySummaryEnabled,
        'dailySummaryHour': dailySummaryHour,
        'dailySummaryMinute': dailySummaryMinute,
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        userId: (map['userId'] as String?) ?? '',
        notificationsEnabled: (map['notificationsEnabled'] as bool?) ?? true,
        quietModeStart: map['quietModeStart'] != null
            ? DateTime.parse(map['quietModeStart'] as String)
            : null,
        quietModeEnd: map['quietModeEnd'] != null
            ? DateTime.parse(map['quietModeEnd'] as String)
            : null,
        quietModeEnabled: (map['quietModeEnabled'] as bool?) ?? false,
        defaultNotificationMinutes:
            (map['defaultNotificationMinutes'] as int?) ?? 30,
        syncEnabled: (map['syncEnabled'] as bool?) ?? true,
        themeMode: (map['themeMode'] as String?) ?? 'dark',
        persistentRepeatMinutes:
            (map['persistentRepeatMinutes'] as int?) ?? 10,
        persistentMaxAlerts: (map['persistentMaxAlerts'] as int?) ?? 3,
        language: (map['language'] as String?) ?? 'es',
        dailySummaryEnabled: (map['dailySummaryEnabled'] as bool?) ?? true,
        dailySummaryHour: (map['dailySummaryHour'] as int?) ?? 8,
        dailySummaryMinute: (map['dailySummaryMinute'] as int?) ?? 0,
      );

  bool get isInQuietMode {
    if (!quietModeEnabled || quietModeStart == null || quietModeEnd == null) {
      return false;
    }
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = quietModeStart!.hour * 60 + quietModeStart!.minute;
    final endMinutes = quietModeEnd!.hour * 60 + quietModeEnd!.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // cruza medianoche
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  // fin del modo descanso como DateTime para "posponer hasta salir del descanso"
  DateTime? get quietModeEndToday {
    if (quietModeEnd == null) return null;
    final now = DateTime.now();
    var end = DateTime(
        now.year, now.month, now.day, quietModeEnd!.hour, quietModeEnd!.minute);
    if (end.isBefore(now)) end = end.add(const Duration(days: 1));
    return end;
  }
}
