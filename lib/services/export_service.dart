import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/memory.dart';

// exportar e importar memorias en JSON y CSV para copias de seguridad
class ExportService {
  static String toJson(List<Memory> memories) => const JsonEncoder.withIndent(
        '  ',
      ).convert(memories.map((m) => m.toMap()).toList());

  static String toCsv(List<Memory> memories) {
    final buffer = StringBuffer(
        'titulo,nota,fecha,hora,zona,prioridad,etiquetas,completada,creada\n');
    for (final m in memories) {
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      final date = m.dueDate != null
          ? '${m.dueDate!.year}-${m.dueDate!.month.toString().padLeft(2, '0')}-${m.dueDate!.day.toString().padLeft(2, '0')}'
          : '';
      final time = m.hasTime && m.dueDate != null
          ? '${m.dueDate!.hour.toString().padLeft(2, '0')}:${m.dueDate!.minute.toString().padLeft(2, '0')}'
          : '';
      buffer.writeln([
        esc(m.title),
        esc(m.body),
        date,
        time,
        m.zone.name,
        m.priority.name,
        esc(m.tags.join(' ')),
        m.isCompleted ? 'sí' : 'no',
        m.createdAt.toIso8601String().split('T')[0],
      ].join(','));
    }
    return buffer.toString();
  }

  // guarda el contenido en la carpeta de documentos y devuelve la ruta
  static Future<String> saveToFile(String content, String extension) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/memorylux_$stamp.$extension');
    await file.writeAsString(content);
    return file.path;
  }

  static List<Memory> fromJson(String json, String userId) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => Memory.fromMap(
            {...Map<String, dynamic>.from(e), 'userId': userId}))
        .toList();
  }
}
