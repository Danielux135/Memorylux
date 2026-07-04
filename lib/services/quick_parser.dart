import '../models/memory.dart';

// resultado del parseo rápido: título limpio + todo lo que se ha entendido
class QuickParseResult {
  final String title;
  final DateTime? dueDate;
  final bool hasTime;
  final List<String> tags;
  final Recurrence recurrence;
  final MemoryPriority priority;
  final int? notificationMinutesBefore; // antelación pedida en el texto

  QuickParseResult({
    required this.title,
    this.dueDate,
    this.hasTime = false,
    this.tags = const [],
    this.recurrence = const Recurrence(),
    this.priority = MemoryPriority.normal,
    this.notificationMinutesBefore,
  });
}

// parser bilingüe (español y english) tolerante a acentos y faltas comunes.
// Ejemplos que entiende:
//   "dentista mañana 10:30"          "dentist tomorrow 10:30"
//   "comprar leche esta tarde"        "buy milk this afternoon"
//   "reunión en 2 horas"              "meeting in 2 hours"
//   "gimnasio cada lunes y jueves"    "gym every monday and thursday"
//   "pagar factura cada mes urgente"  "pay bill every month urgent"
//   "a las 5 y media de la tarde"     "at half past 5 in the evening"
// El matching se hace sobre una copia normalizada (minúsculas y sin acentos)
// pero el título conserva el texto original tal cual lo escribió el usuario.
class QuickParser {
  // días completos, con faltas de ortografía habituales en ambos idiomas
  static const _weekdayNames = {
    // español (ya normalizado: sin acentos)
    'lunes': 1,
    'martes': 2,
    'miercoles': 3,
    'mierocles': 3,
    'jueves': 4,
    'juebes': 4,
    'viernes': 5,
    'biernes': 5,
    'sabado': 6,
    'savado': 6,
    'domingo': 7,
    // english
    'monday': 1,
    'tuesday': 2,
    'teusday': 2,
    'wednesday': 3,
    'wensday': 3,
    'wednsday': 3,
    'thursday': 4,
    'thurday': 4,
    'friday': 5,
    'saturday': 6,
    'sunday': 7,
  };

  // abreviaturas inglesas: solo se aceptan con contexto (every/on/next...)
  // para no confundir palabras normales como "sat" o "sun"
  static const _weekdayAbbrev = {
    'mon': 1,
    'tue': 2,
    'tues': 2,
    'wed': 3,
    'weds': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'fri': 5,
    'sat': 6,
    'sun': 7,
  };

  // minúsculas y sin acentos/diéresis, misma longitud que el original
  static String _normalize(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', '’': "'",
    };
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      b.write(map[c] ?? c);
    }
    return b.toString();
  }

  static QuickParseResult parse(String input) {
    // se mantienen dos copias alineadas: original (para el título) y
    // normalizada (para el matching); se borran rangos en las dos a la vez
    var text = ' ${input.trim()} ';
    var norm = _normalize(text);
    final now = DateTime.now();
    DateTime? date;
    int? hour;
    int? minute;
    var recurrence = const Recurrence();
    var priority = MemoryPriority.normal;

    void blank(int start, int end) {
      final spaces = ' ' * (end - start);
      text = text.replaceRange(start, end, spaces);
      norm = norm.replaceRange(start, end, spaces);
    }

    void consume(Match m) => blank(m.start, m.end);

    Match? find(String pattern) => RegExp(pattern).firstMatch(norm);

    // busca y consume en un solo paso; devuelve null si no hay match
    Match? take(String pattern) {
      final m = find(pattern);
      if (m != null) consume(m);
      return m;
    }

    // ---- etiquetas: #casa #trabajo #home ----
    final tags = <String>[];
    for (final m in RegExp(r'#(\w+)').allMatches(norm).toList()) {
      tags.add(m.group(1)!);
    }
    for (final m in RegExp(r'#(\w+)').allMatches(norm).toList()) {
      blank(m.start, m.end);
    }

    // ---- urgencia ----
    // "urgente"/"urgent" → persistente; "importante"/"important" → importante
    if (take(r'\b(urgente|urjente|urgentisimo|ya mismo|ahorita mismo|'
            r'urgent|urgente?ly|asap|right now)\b') !=
        null) {
      priority = MemoryPriority.persistent;
    } else if (take(r'\b(importante|inportante|no olvidar|prioridad|'
            r"important|priority|don'?t forget|dont forget)\b") !=
        null) {
      priority = MemoryPriority.important;
    }

    // ---- repetición ----
    // "cada 3 horas" / "every 3 hours"
    final everyHours =
        take(r'\b(?:cada|every|each) (\d+) (?:horas?|oras?|hours?|hrs?)\b');
    if (everyHours != null) {
      recurrence = Recurrence(
          type: RecurrenceType.everyXHours,
          everyHours: int.parse(everyHours.group(1)!));
    } else {
      // "cada lunes y jueves" / "every monday and thursday" / "todos los lunes"
      final allDays = [..._weekdayNames.keys, ..._weekdayAbbrev.keys]
        ..sort((a, b) => b.length.compareTo(a.length));
      final dayPattern = allDays.join('|');
      final everyDays = take(
          '\\b(?:cada|todos los|todos|every|each)\\s+((?:$dayPattern)s?'
          '(?:\\s*(?:,|y|e|and|&)\\s*(?:$dayPattern)s?)*)\\b');
      if (everyDays != null) {
        final found = <int>{};
        final captured = everyDays.group(1)!;
        for (final entry in {..._weekdayNames, ..._weekdayAbbrev}.entries) {
          if (RegExp('\\b${entry.key}s?\\b').hasMatch(captured)) {
            found.add(entry.value);
          }
        }
        if (found.isNotEmpty) {
          recurrence = Recurrence(
              type: RecurrenceType.weekdays, weekdays: found.toList()..sort());
        }
      } else if (take(r'\bcada dia\b|\btodos los dias\b|\ba diario\b|'
              r'\bevery ?day\b|\bdaily\b') !=
          null) {
        recurrence = const Recurrence(type: RecurrenceType.daily);
      } else if (take(r'\bcada semana\b|\bsemanalmente\b|'
              r'\bevery week\b|\bweekly\b') !=
          null) {
        recurrence = const Recurrence(type: RecurrenceType.weekly);
      } else if (take(r'\bcada mes\b|\bmensualmente\b|'
              r'\bevery month\b|\bmonthly\b') !=
          null) {
        recurrence = const Recurrence(type: RecurrenceType.monthly);
      }
    }

    // ---- antelación del aviso ----
    // "con 20 minutos de antelación", "3 horas antes", "20 minutes before",
    // "1 day before", "with 2 hours notice"; debe ir antes del bloque
    // relativo "en X" para que "20 minutos antes" no se coma a medias
    int? minutesBefore;
    final lead = take(
        r'\b(?:con |with )?(\d+|una?|un|dos|tres|media|one|two|three|an?|half)\s*'
        r'(minutos?|minutes?|mins?|horas?|oras?|hours?|hrs?|h|dias?|days?)\s+'
        r'(?:de\s+)?(?:antelacion|antelasion|anticipacion|adelanto|antes|'
        r'before|earlier|in advance|ahead|notice)\b');
    if (lead != null) {
      final rawAmount = lead.group(1)!;
      final isHalf = rawAmount == 'media' || rawAmount == 'half';
      final amount = switch (rawAmount) {
        'un' || 'una' || 'one' || 'a' || 'an' => 1,
        'dos' || 'two' => 2,
        'tres' || 'three' => 3,
        'media' || 'half' => 1,
        _ => int.parse(rawAmount),
      };
      final unit = lead.group(2)!;
      if (unit.startsWith('min')) {
        minutesBefore = amount;
      } else if (unit.startsWith('h') || unit.startsWith('or')) {
        minutesBefore = isHalf ? 30 : amount * 60;
      } else {
        minutesBefore = amount * 1440;
      }
    }
    // verbos de aviso que sobran en el título: "avísame", "remind me"…
    take(r'\b(avisame de|avisame|avisadme|avisarme|recuerdame|recordarme|'
        r'remind me to|remind me|warn me|notify me|alert me)\b');

    // ---- "en X minutos/horas/días" / "in X minutes/hours/days" ----
    final relative = take(
        r'\b(?:en|in|dentro de) (\d+|una?|dos|tres|media|one|two|three|'
        r'an?|half an|half)\s*'
        r'(minutos?|mins?|horas?|oras?|hours?|hrs?|h\b|dias?|days?|'
        r'semanas?|weeks?|wks?)');
    if (relative != null) {
      final rawAmount = relative.group(1)!;
      final isHalf = rawAmount == 'media' || rawAmount.startsWith('half');
      final amount = switch (rawAmount) {
        'un' || 'una' || 'one' || 'a' || 'an' => 1,
        'dos' || 'two' => 2,
        'tres' || 'three' => 3,
        'media' || 'half' || 'half an' => 0, // "en media hora"/"in half an hour"
        _ => int.parse(rawAmount),
      };
      final unit = relative.group(2)!;
      Duration delta;
      var isTime = true;
      if (unit.startsWith('min')) {
        delta = Duration(minutes: amount);
      } else if (unit.startsWith('h') || unit.startsWith('or')) {
        delta = isHalf ? const Duration(minutes: 30) : Duration(hours: amount);
      } else if (unit.startsWith('d')) {
        delta = Duration(days: amount);
        isTime = false;
      } else {
        delta = Duration(days: amount * 7);
        isTime = false;
      }
      final target = now.add(delta);
      date = target;
      if (isTime) {
        hour = target.hour;
        minute = target.minute;
      }
    }

    // ---- hora explícita ----
    String? ampm;
    if (hour == null) {
      // "10:30", "a las 10:30", "at 10:30pm", "10.30"
      final timeMatch = take(
          r'\b(?:a las? |at )?(\d{1,2})[:.](\d{2})\s*(am|pm|a\.m\.|p\.m\.)?\b');
      if (timeMatch != null) {
        hour = int.parse(timeMatch.group(1)!);
        minute = int.parse(timeMatch.group(2)!);
        ampm = timeMatch.group(3);
      } else {
        // "a las 5", "a las 5 y media/cuarto" / "at 5", "at 5pm"
        final hourOnly = take(
            r'\b(?:a las? |at )(\d{1,2})(?:\s+y\s+(media|cuarto))?'
            r'\s*(am|pm|a\.m\.|p\.m\.)?\b');
        if (hourOnly != null) {
          hour = int.parse(hourOnly.group(1)!);
          minute = switch (hourOnly.group(2)) {
            'media' => 30,
            'cuarto' => 15,
            _ => 0,
          };
          ampm = hourOnly.group(3);
        } else {
          // "half past 5", "quarter past 5"
          final past = take(r'\b(half|quarter) past (\d{1,2})'
              r'\s*(am|pm|a\.m\.|p\.m\.)?\b');
          if (past != null) {
            hour = int.parse(past.group(2)!);
            minute = past.group(1) == 'half' ? 30 : 15;
            ampm = past.group(3);
          } else {
            // "5pm", "11am" sueltos
            final bare = take(r'\b(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)\b');
            if (bare != null) {
              hour = int.parse(bare.group(1)!);
              minute = 0;
              ampm = bare.group(2);
            } else if (take(r'\ba? ?mediodia\b|\b(?:at )?noon\b|\bmidday\b') !=
                null) {
              hour = 12;
              minute = 0;
            } else if (take(
                    r'\ba? ?medianoche\b|\b(?:at )?midnight\b') !=
                null) {
              hour = 23;
              minute = 59;
            }
          }
        }
      }

      // am/pm pegado a la hora ("5pm") o en palabras ("de la tarde",
      // "en la noche" (Latam), "in the evening", "at night")
      if (hour != null && hour <= 12) {
        if (ampm != null) {
          final isPm = ampm.startsWith('p');
          if (isPm && hour < 12) hour = hour + 12;
          if (!isPm && hour == 12) hour = 0;
        } else {
          final pm = take(r'\b(?:de|en|por) la (tarde|noche)\b|'
              r'\bin the (afternoon|evening)\b|\bat night\b|\bpm\b');
          if (pm != null) {
            if (hour < 12) hour = hour + 12;
          } else {
            take(r'\b(?:de|en|por) la manana\b|\bin the morning\b|\bam\b');
          }
        }
      }
    }

    // ---- fecha ----
    if (date == null) {
      if (take(r'\bpasado manana\b|\bday after tomorrow\b') != null) {
        date = now.add(const Duration(days: 2));
      } else if (take(r'\bmanana\b|\btomorrow\b|\btommorr?ow\b|'
              r'\btomorow\b|\btmrw?\b') !=
          null) {
        date = now.add(const Duration(days: 1));
      } else if (take(r'\besta tarde\b|\bthis afternoon\b') != null) {
        date = now;
        hour ??= 17;
        minute ??= 0;
      } else if (take(r'\besta noche\b|\btonight\b|\bthis evening\b') !=
          null) {
        date = now;
        hour ??= 21;
        minute ??= 0;
      } else if (take(r'\bhoy\b|\btoday\b') != null) {
        date = now;
      } else if (take(r'\beste finde\b|\beste fin de semana\b|'
              r'\bthis weekend\b') !=
          null) {
        var d = now;
        while (d.weekday != DateTime.saturday) {
          d = d.add(const Duration(days: 1));
        }
        date = d;
      } else if (recurrence.isNone) {
        // día de la semana: "el domingo", "next monday", "this friday"
        // (si hay recurrencia por días no lo tratamos como fecha única)
        Match? dayMatch;
        int? dayValue;
        for (final entry in _weekdayNames.entries) {
          final m = find('\\b(?:el |del |este |on |this )?(?:proximo |next )?'
              '${entry.key}\\b');
          if (m != null) {
            dayMatch = m;
            dayValue = entry.value;
            break;
          }
        }
        if (dayMatch == null) {
          // abreviaturas inglesas: solo con contexto delante
          for (final entry in _weekdayAbbrev.entries) {
            final m =
                find('\\b(?:on|next|this|el|este|proximo) ${entry.key}\\b');
            if (m != null) {
              dayMatch = m;
              dayValue = entry.value;
              break;
            }
          }
        }
        if (dayMatch != null) {
          var d = now.add(const Duration(days: 1));
          while (d.weekday != dayValue) {
            d = d.add(const Duration(days: 1));
          }
          date = d;
          consume(dayMatch);
        }
      }

      // fecha explícita: "25/12", "25/12/2026"
      if (date == null) {
        final dm = take(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
        if (dm != null) {
          final day = int.parse(dm.group(1)!);
          final month = int.parse(dm.group(2)!);
          var year = dm.group(3) != null ? int.parse(dm.group(3)!) : now.year;
          if (year < 100) year += 2000;
          var candidate = DateTime(year, month, day);
          if (dm.group(3) == null && candidate.isBefore(now)) {
            candidate = DateTime(year + 1, month, day);
          }
          date = candidate;
        } else {
          // "el 25", "el día 3" / "on the 25th", "the 3rd" → este mes o el que viene
          final dayOnly = take(r'\bel (?:dia )?(\d{1,2})\b|'
              r'\b(?:on )?the (\d{1,2})(?:st|nd|rd|th)?(?: day)?\b|'
              r'\b(\d{1,2})(?:st|nd|rd|th)\b');
          if (dayOnly != null) {
            final raw =
                dayOnly.group(1) ?? dayOnly.group(2) ?? dayOnly.group(3)!;
            final day = int.parse(raw);
            if (day >= 1 && day <= 31) {
              var candidate = DateTime(now.year, now.month, day);
              if (candidate
                  .isBefore(DateTime(now.year, now.month, now.day))) {
                candidate = DateTime(now.year, now.month + 1, day);
              }
              date = candidate;
            }
          }
        }
      }
    }

    // repetición sin fecha inicial: empieza hoy (o el primer día marcado)
    if (date == null && !recurrence.isNone) {
      if (recurrence.type == RecurrenceType.weekdays &&
          recurrence.weekdays.isNotEmpty) {
        var d = now;
        while (!recurrence.weekdays.contains(d.weekday)) {
          d = d.add(const Duration(days: 1));
        }
        date = d;
      } else {
        date = now;
      }
    }

    // si hay hora pero no fecha: hoy, o mañana si esa hora ya pasó
    if (date == null && hour != null) {
      var candidate = DateTime(now.year, now.month, now.day, hour, minute ?? 0);
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      date = candidate;
    }

    DateTime? due;
    var hasTime = false;
    if (date != null) {
      if (hour != null) {
        due = DateTime(date.year, date.month, date.day, hour, minute ?? 0);
        hasTime = true;
        // hora ya pasada hoy sin fecha explícita en el mismo día → mañana
        if (due.isBefore(now) &&
            date.day == now.day &&
            date.month == now.month) {
          due = due.add(const Duration(days: 1));
        }
      } else {
        // sin hora: por defecto a las 9 de la mañana
        due = DateTime(date.year, date.month, date.day, 9, 0);
      }
    }

    // limpiar restos: espacios y conectores sueltos al final en ambos idiomas
    final title = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,;.])'), r'$1')
        .trim()
        .replaceAll(RegExp(r'[,;]+$'), '')
        .replaceAll(
            RegExp(
                r'\s+(a|el|la|los|las|de|del|en|para|por|y|'
                r'at|on|in|the|to|for|and|by)$',
                caseSensitive: false),
            '')
        .trim();

    return QuickParseResult(
      title: title.isEmpty ? input.trim() : title,
      dueDate: due,
      hasTime: hasTime,
      tags: tags,
      recurrence: recurrence,
      priority: priority,
      notificationMinutesBefore: minutesBefore,
    );
  }
}
