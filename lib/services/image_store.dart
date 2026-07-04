import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// guarda las fotos que el usuario usa como fondo de sus stickers
// y ofrece la galería de fotos ya subidas para reutilizarlas
class ImageStore {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/memorylux_stickers');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // abre el selector de fotos y copia la elegida a la carpeta de la app
  static Future<String?> pickAndStore() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (picked == null) return null;

    final dir = await _dir();
    final ext = picked.path.contains('.')
        ? picked.path.split('.').last.toLowerCase()
        : 'jpg';
    final dest =
        File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await File(picked.path).copy(dest.path);
    return dest.path;
  }

  // fotos ya subidas, la más reciente primero
  static Future<List<String>> gallery() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File)
        .map((e) => e.path)
        .toList();
    files.sort((a, b) => b.compareTo(a));
    return files;
  }

  static Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
