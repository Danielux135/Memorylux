import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/memory.dart';
import '../services/notification_service.dart';
import '../services/quick_parser.dart';
import '../theme/app_theme.dart';
import '../l10n/lang.dart';

// barra para crear un recuerdo en 3 segundos: escribe en lenguaje natural
// y debajo se explica, en palabras normales, lo que Memorylux ha entendido
class QuickAddBar extends StatefulWidget {
  final void Function(QuickParseResult result) onSubmit;

  const QuickAddBar({super.key, required this.onSubmit});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _controller = TextEditingController();
  QuickParseResult? _preview;

  // ejemplos rotatorios en cada idioma
  static const _hintsEs = [
    '“dentista mañana 10:30”',
    '“comprar pan esta tarde”',
    '“reunión en 2 horas”',
    '“gimnasio cada lunes y jueves”',
    '“pagar alquiler el 1 urgente #casa”',
  ];
  static const _hintsEn = [
    '“dentist tomorrow 10:30”',
    '“buy bread this afternoon”',
    '“meeting in 2 hours”',
    '“gym every monday and thursday”',
    '“pay rent on the 1st urgent #home”',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _preview = value.trim().isEmpty ? null : QuickParser.parse(value);
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(QuickParser.parse(text));
    _controller.clear();
    setState(() => _preview = null);
  }

  // "hoy", "mañana", "el viernes", "el 25 dic"... como lo dirías tú
  String _dayInWords(DateTime due, bool en) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return en ? 'today' : 'hoy';
    if (diff == 1) return en ? 'tomorrow' : 'mañana';
    if (diff == 2) return en ? 'the day after tomorrow' : 'pasado mañana';
    if (diff > 2 && diff < 7) {
      final weekday = DateFormat('EEEE', en ? 'en_US' : 'es').format(due);
      return en ? 'on $weekday' : 'el $weekday';
    }
    final d = DateFormat('d MMM', en ? 'en_US' : 'es').format(due);
    return en ? 'on $d' : 'el $d';
  }

  // frase completa: "Lo apuntaré para mañana a las 10:30, se repite cada mes"
  String _explain(QuickParseResult p, bool en) {
    final parts = <String>[];
    if (p.dueDate != null) {
      var when = _dayInWords(p.dueDate!, en);
      if (p.hasTime) {
        final time = DateFormat('HH:mm').format(p.dueDate!);
        when += en ? ' at $time' : ' a las $time';
      }
      parts.add(en ? 'I\'ll remind you $when' : 'te avisaré $when');
    }
    if (p.notificationMinutesBefore != null) {
      final label =
          NotificationService.leadLabel(p.notificationMinutesBefore!, en);
      parts.add(en ? 'heads-up $label early' : 'con aviso $label antes');
    }
    if (!p.recurrence.isNone) {
      parts.add(en
          ? 'repeats ${_recurrenceInWords(p.recurrence, en)}'
          : 'se repite ${_recurrenceInWords(p.recurrence, en)}');
    }
    if (p.priority == MemoryPriority.persistent) {
      parts.add(en ? 'I\'ll insist until you do it 🔥' : 'insistiré hasta que lo hagas 🔥');
    } else if (p.priority == MemoryPriority.important) {
      parts.add(en ? 'I\'ll mark it important 📌' : 'lo marcaré como importante 📌');
    }
    if (p.tags.isNotEmpty) {
      parts.add(p.tags.map((t) => '#$t').join(' '));
    }
    return parts.join(' · ');
  }

  String _recurrenceInWords(Recurrence r, bool en) {
    if (r.type == RecurrenceType.weekdays && r.weekdays.isNotEmpty) {
      final names = en
          ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
          : ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
      final days = r.weekdays.map((d) => names[d - 1]).toList();
      if (days.length == 1) {
        return en ? 'every ${days.first}' : 'cada ${days.first}';
      }
      final last = days.removeLast();
      return en
          ? 'every ${days.join(', ')} and $last'
          : 'cada ${days.join(', ')} y $last';
    }
    return r.labelFor(en);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final en = context.isEn;
    // el ejemplo del hint va rotando según el día para enseñar posibilidades
    final hints = en ? _hintsEn : _hintsEs;
    final hint = hints[DateTime.now().day % hints.length];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: en ? '$hint  ·  type and go' : '$hint  ·  escribe y listo',
            prefixIcon: const Icon(Icons.edit_note),
            suffixIcon: IconButton(
              tooltip: context.pick('Añadir recuerdo', 'Add memory'),
              icon: const Icon(Icons.arrow_upward),
              color: AppTheme.lux,
              onPressed: _submit,
            ),
          ),
        ),
        if (_preview != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
            child: _preview!.dueDate != null
                ? Text(
                    '✓ “${_preview!.title}” — ${_explain(_preview!, en)}',
                    style: AppTheme.ui(
                      size: 12.5,
                      color: AppTheme.lux,
                      weight: FontWeight.w800,
                    ),
                  )
                : Text(
                    en
                        ? 'Will go to WAITING (no alert). Add a when: '
                            '“tomorrow 10:30”, “in 2 hours”, “on friday”, “every monday”…'
                        : 'Irá a EN ESPERA (sin aviso). Añade un cuándo: '
                            '“mañana 10:30”, “en 2 horas”, “el viernes”, “cada lunes”…',
                    style: AppTheme.ui(
                      size: 12,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
      ],
    );
  }
}
