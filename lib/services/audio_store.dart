import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class StoredAudio {
  final String value;
  final String name;

  const StoredAudio({required this.value, required this.name});
}

class AudioStore {
  static const _prefix = 'file:';
  static const _folder = 'alarm_sounds';
  static const _labelSeparator = '::';
  static const _channel = MethodChannel('memorylux/notification_sound');

  static bool isCustom(String? value) => value?.startsWith(_prefix) ?? false;

  // uri/ruta que se le pasa al plugin de notificaciones (sin la etiqueta)
  static String? pathFromValue(String? value) {
    if (!isCustom(value)) return null;
    final raw = value!.substring(_prefix.length);
    final sep = raw.indexOf(_labelSeparator);
    return sep < 0 ? raw : raw.substring(0, sep);
  }

  static String labelFor(String? value, {required bool en}) {
    if (value == null) return en ? 'default' : 'por defecto';
    if (value == 'silent') return en ? 'silent' : 'silencio';
    if (value == 'alarm') return 'Alarm';
    if (!isCustom(value)) return 'Alarm';
    final raw = value.substring(_prefix.length);
    final sep = raw.indexOf(_labelSeparator);
    if (sep >= 0) return raw.substring(sep + _labelSeparator.length);
    return 'Alarm';
  }

  static Future<StoredAudio?> pickAndStore() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return null;

    final extension = _extensionOf(picked.name);
    final name = _cleanName(picked.name, extension);
    final displayName = '$name$extension';
    final bytes = picked.bytes ?? await _readPath(picked.path);
    if (bytes == null || bytes.isEmpty) return null;

    final dir = await _soundsDir();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$displayName';
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsBytes(bytes, flush: true);

    // en Android, un file:// a la carpeta privada de la app no lo puede leer
    // el proceso del sistema; lo registramos en MediaStore para conseguir
    // una content:// pública que sí es reproducible como sonido de alarma
    final uri = await _registerInMediaStore(target.path, displayName);
    final soundRef = uri ?? target.path;

    return StoredAudio(
      value: '$_prefix$soundRef$_labelSeparator$displayName',
      name: displayName,
    );
  }

  static Future<String?> _registerInMediaStore(
      String sourcePath, String displayName) async {
    if (!Platform.isAndroid) return null;
    try {
      final uri = await _channel.invokeMethod<String>('registerSound', {
        'sourcePath': sourcePath,
        'displayName': displayName,
        'mimeType': _mimeTypeOf(displayName),
      });
      return uri;
    } catch (e) {
      debugPrint('No se pudo registrar el sonido en MediaStore: $e');
      return null;
    }
  }

  static String _mimeTypeOf(String name) {
    if (name.endsWith('.wav')) return 'audio/wav';
    if (name.endsWith('.ogg')) return 'audio/ogg';
    if (name.endsWith('.m4a')) return 'audio/mp4';
    return 'audio/mpeg';
  }

  static Future<Directory> _soundsDir() async {
    final external =
        Platform.isAndroid ? await getExternalStorageDirectory() : null;
    final base = external ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Uint8List?> _readPath(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.mp3';
    final ext = name.substring(dot).toLowerCase();
    return ['.mp3', '.wav', '.ogg', '.m4a'].contains(ext) ? ext : '.mp3';
  }

  static String _cleanName(String name, String extension) {
    final base = name.toLowerCase().endsWith(extension)
        ? name.substring(0, name.length - extension.length)
        : name;
    final clean = base
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return clean.isEmpty ? 'alarm_sound' : clean;
  }
}
