import 'package:flutter_test/flutter_test.dart';
import 'package:memorylux/models/memory.dart';
import 'package:memorylux/services/quick_parser.dart';

void main() {
  group('QuickParser', () {
    test('entiende "dentista mañana 10:30"', () {
      final r = QuickParser.parse('dentista mañana 10:30');
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(r.title, 'dentista');
      expect(r.hasTime, isTrue);
      expect(r.dueDate!.day, tomorrow.day);
      expect(r.dueDate!.hour, 10);
      expect(r.dueDate!.minute, 30);
    });

    test('entiende "comprar leche esta tarde"', () {
      final r = QuickParser.parse('comprar leche esta tarde');
      expect(r.title, 'comprar leche');
      expect(r.dueDate!.hour, 17);
    });

    test('entiende "reunión en 2 horas"', () {
      final r = QuickParser.parse('reunión en 2 horas');
      final expected = DateTime.now().add(const Duration(hours: 2));
      expect(r.title, 'reunión');
      expect(r.hasTime, isTrue);
      expect(r.dueDate!.difference(expected).inMinutes.abs(), lessThan(2));
    });

    test('entiende "a las 5 y media de la tarde"', () {
      final r = QuickParser.parse('recoger paquete a las 5 y media de la tarde');
      expect(r.title, 'recoger paquete');
      expect(r.dueDate!.hour, 17);
      expect(r.dueDate!.minute, 30);
    });

    test('entiende "cada lunes y jueves"', () {
      final r = QuickParser.parse('gimnasio cada lunes y jueves');
      expect(r.title, 'gimnasio');
      expect(r.recurrence.type, RecurrenceType.weekdays);
      expect(r.recurrence.weekdays, [1, 4]);
      expect(r.dueDate, isNotNull); // empieza el primer día que toque
    });

    test('entiende "urgente" como prioridad persistente', () {
      final r = QuickParser.parse('pagar alquiler el 1 urgente #casa');
      expect(r.priority, MemoryPriority.persistent);
      expect(r.tags, ['casa']);
      expect(r.title, 'pagar alquiler');
      expect(r.dueDate!.day, 1);
    });

    test('extrae etiquetas y repetición', () {
      final r = QuickParser.parse('pagar factura cada mes #casa');
      expect(r.tags, ['casa']);
      expect(r.recurrence.type, RecurrenceType.monthly);
      expect(r.title, 'pagar factura');
    });

    test('tolera mayúsculas y falta de acentos', () {
      final r = QuickParser.parse('Dentista MANANA 10:30');
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(r.title, 'Dentista');
      expect(r.dueDate!.day, tomorrow.day);
      expect(r.dueDate!.hour, 10);
    });

    test('entiende español de Latam "en la tarde"', () {
      final r = QuickParser.parse('llamar al banco a las 4 en la tarde');
      expect(r.title, 'llamar al banco');
      expect(r.dueDate!.hour, 16);
    });

    test('tolera faltas de ortografía en días', () {
      final r = QuickParser.parse('yoga cada juebes');
      expect(r.recurrence.type, RecurrenceType.weekdays);
      expect(r.recurrence.weekdays, [4]);
    });
  });

  group('QuickParser (english)', () {
    test('understands "dentist tomorrow 10:30"', () {
      final r = QuickParser.parse('dentist tomorrow 10:30');
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(r.title, 'dentist');
      expect(r.hasTime, isTrue);
      expect(r.dueDate!.day, tomorrow.day);
      expect(r.dueDate!.hour, 10);
      expect(r.dueDate!.minute, 30);
    });

    test('understands "buy milk this afternoon"', () {
      final r = QuickParser.parse('buy milk this afternoon');
      expect(r.title, 'buy milk');
      expect(r.dueDate!.hour, 17);
    });

    test('understands "meeting in 2 hours"', () {
      final r = QuickParser.parse('meeting in 2 hours');
      final expected = DateTime.now().add(const Duration(hours: 2));
      expect(r.title, 'meeting');
      expect(r.hasTime, isTrue);
      expect(r.dueDate!.difference(expected).inMinutes.abs(), lessThan(2));
    });

    test('understands "at half past 5 in the evening"', () {
      final r = QuickParser.parse('pick up package at half past 5 in the evening');
      expect(r.title, 'pick up package');
      expect(r.dueDate!.hour, 17);
      expect(r.dueDate!.minute, 30);
    });

    test('understands "at 5pm"', () {
      final r = QuickParser.parse('call mom at 5pm');
      expect(r.title, 'call mom');
      expect(r.dueDate!.hour, 17);
      expect(r.dueDate!.minute, 0);
    });

    test('understands "every monday and thursday"', () {
      final r = QuickParser.parse('gym every monday and thursday');
      expect(r.title, 'gym');
      expect(r.recurrence.type, RecurrenceType.weekdays);
      expect(r.recurrence.weekdays, [1, 4]);
      expect(r.dueDate, isNotNull);
    });

    test('understands "urgent" as persistent priority', () {
      final r = QuickParser.parse('pay rent on the 1st urgent #home');
      expect(r.priority, MemoryPriority.persistent);
      expect(r.tags, ['home']);
      expect(r.title, 'pay rent');
      expect(r.dueDate!.day, 1);
    });

    test('understands "every month" and tags', () {
      final r = QuickParser.parse('pay bill every month #home important');
      expect(r.tags, ['home']);
      expect(r.recurrence.type, RecurrenceType.monthly);
      expect(r.priority, MemoryPriority.important);
      expect(r.title, 'pay bill');
    });

    test('tolerates misspellings like "tommorow" and "wensday"', () {
      final r1 = QuickParser.parse('doctor tommorow');
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(r1.title, 'doctor');
      expect(r1.dueDate!.day, tomorrow.day);

      final r2 = QuickParser.parse('class every wensday');
      expect(r2.recurrence.type, RecurrenceType.weekdays);
      expect(r2.recurrence.weekdays, [3]);
    });

    test('understands "next friday" and "in half an hour"', () {
      final r1 = QuickParser.parse('dinner next friday');
      expect(r1.title, 'dinner');
      expect(r1.dueDate!.weekday, 5);

      final r2 = QuickParser.parse('check oven in half an hour');
      final expected = DateTime.now().add(const Duration(minutes: 30));
      expect(r2.title, 'check oven');
      expect(r2.dueDate!.difference(expected).inMinutes.abs(), lessThan(2));
    });

    test('understands "daily" and "tonight"', () {
      final r1 = QuickParser.parse('take pills daily');
      expect(r1.recurrence.type, RecurrenceType.daily);

      final r2 = QuickParser.parse('take out trash tonight');
      expect(r2.title, 'take out trash');
      expect(r2.dueDate!.hour, 21);
    });
  });

  group('Recurrence', () {
    test('cada día genera el día siguiente', () {
      const rec = Recurrence(type: RecurrenceType.daily);
      final next = rec.nextAfter(DateTime(2026, 7, 2, 9));
      expect(next, DateTime(2026, 7, 3, 9));
    });

    test('días concretos salta al siguiente marcado', () {
      const rec =
          Recurrence(type: RecurrenceType.weekdays, weekdays: [1, 3, 5]);
      // 2026-07-02 es jueves; el siguiente marcado es el viernes 3
      final next = rec.nextAfter(DateTime(2026, 7, 2, 9));
      expect(next!.weekday, 5);
    });

    test('respeta la fecha límite', () {
      final rec = Recurrence(
          type: RecurrenceType.daily, until: DateTime(2026, 7, 2));
      expect(rec.nextAfter(DateTime(2026, 7, 2, 9)), isNull);
    });
  });
}
