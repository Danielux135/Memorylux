import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/memory.dart';
import '../models/user_settings.dart';
import 'firebase_bootstrap.dart';

// Sincronizacion con Firestore: las notas mandan; las fotos se suben y bajan
// alrededor para que un fallo de hosting no rompa la sincronizacion principal.
class SyncService extends ChangeNotifier {
  static const String _uploadEndpoint =
      'http://api.danielux.es/memorylux/memorylux-upload.php';

  FirebaseFirestore? _firestore;
  bool _isSyncing = false;
  bool _isOnline = true;
  DateTime? _lastSync;
  bool _firebaseAvailable = false;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSync => _lastSync;
  bool get firebaseAvailable => _firebaseAvailable;

  SyncService() {
    _initializeFirebase();
    _isOnline = true;
  }

  void _initializeFirebase() {
    if (!FirebaseBootstrap.isAvailable) {
      _firebaseAvailable = false;
      return;
    }

    try {
      _firestore = FirebaseFirestore.instance;
      _firebaseAvailable = true;
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint('SyncService sin Firebase: $e');
    }
  }

  String _normalizeHostedImageUrl(String url) {
    return url
        .replaceFirst(
          'https://api.danielux.es/uploads/',
          'http://api.danielux.es/memorylux/uploads/',
        )
        .replaceFirst(
          'http://api.danielux.es/uploads/',
          'http://api.danielux.es/memorylux/uploads/',
        )
        .replaceFirst(
          'https://api.danielux.es/memorylux/uploads/',
          'http://api.danielux.es/memorylux/uploads/',
        );
  }

  Future<String?> _uploadImage({
    required String userId,
    required Memory memory,
  }) async {
    final localPath = memory.imagePath;
    if (localPath == null || localPath.isEmpty) return null;

    final file = File(localPath);
    if (!await file.exists()) return null;

    final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));
    request.fields['token'] = userId;
    request.fields['memoryId'] = memory.id;
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: 'image${p.extension(localPath).isNotEmpty ? p.extension(localPath) : '.jpg'}',
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed: ${response.statusCode} $body');
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final uploadedUrl = decoded['url'] as String?;
    return uploadedUrl == null ? null : _normalizeHostedImageUrl(uploadedUrl);
  }

  Future<String?> _downloadImage({
    required String remoteUrl,
    required String memoryId,
  }) async {
    final normalizedUrl = _normalizeHostedImageUrl(remoteUrl);
    final response = await http.get(Uri.parse(normalizedUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/memorylux_stickers');
    if (!await dir.exists()) await dir.create(recursive: true);

    var ext = p.extension(Uri.parse(normalizedUrl).path);
    if (ext.isEmpty) ext = '.jpg';
    final file = File('${dir.path}/synced_${memoryId.hashCode}$ext');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<void> deleteHostedImage({
    required String userId,
    required String? remoteUrl,
  }) async {
    if (userId.isEmpty || remoteUrl == null || remoteUrl.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_uploadEndpoint),
        body: {
          'action': 'delete',
          'token': userId,
          'url': _normalizeHostedImageUrl(remoteUrl),
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('No se pudo borrar la imagen remota: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error borrando imagen remota: $e');
    }
  }

  Future<void> syncMemories({
    required String userId,
    required List<Memory> localMemories,
    required Function(List<Memory>) onUpdate,
  }) async {
    if (!_firebaseAvailable || _firestore == null || _isSyncing || userId.isEmpty) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final collection =
          _firestore!.collection('users').doc(userId).collection('memories');
      final snapshot = await collection.get();

      final localImages = {
        for (final memory in localMemories)
          if (memory.imagePath != null && memory.imagePath!.isNotEmpty)
            memory.id: memory.imagePath,
      };
      final merged = <String, Memory>{
        for (final memory in localMemories) memory.id: memory,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cloudMemory = Memory.fromMap({
          ...data,
          'id': doc.id,
          'userId': userId,
        });
        final localMemory = merged[cloudMemory.id];
        final shouldUseCloud = localMemory == null ||
            cloudMemory.updatedAt.isAfter(localMemory.updatedAt);

        var nextMemory = shouldUseCloud ? cloudMemory : localMemory;
        final remoteUrl = cloudMemory.imageRemotePath;
        if ((nextMemory.imagePath == null || nextMemory.imagePath!.isEmpty) &&
            localImages[cloudMemory.id] != null) {
          nextMemory = nextMemory.copyWith(imagePath: localImages[cloudMemory.id]);
        }
        if ((nextMemory.imagePath == null || nextMemory.imagePath!.isEmpty) &&
            remoteUrl != null &&
            remoteUrl.isNotEmpty) {
          try {
            final localPath =
                await _downloadImage(remoteUrl: remoteUrl, memoryId: cloudMemory.id);
            if (localPath != null) {
              nextMemory = nextMemory.copyWith(imagePath: localPath);
            }
          } catch (e) {
            debugPrint('No se pudo descargar la imagen sincronizada: $e');
          }
        }
        merged[cloudMemory.id] = nextMemory;
      }

      final batch = _firestore!.batch();
      for (final memory in merged.values) {
        final map = memory.toMap()..remove('imagePath');
        batch.set(collection.doc(memory.id), map, SetOptions(merge: true));
      }
      await batch.commit();

      onUpdate(merged.values.toList());
      _lastSync = DateTime.now();
    } catch (e) {
      debugPrint('Error de sincronizacion: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> deleteMemory({
    required String userId,
    required String memoryId,
  }) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return;

    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('memories')
          .doc(memoryId)
          .delete();
    } catch (e) {
      debugPrint('Error al borrar memoria: $e');
    }
  }

  Future<String?> pushMemory({
    required String userId,
    required Memory memory,
    required bool accountPremium,
  }) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return null;

    var remoteUrl = memory.imageRemotePath;
    try {
      final map = memory.toMap()..remove('imagePath');
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('memories')
          .doc(memory.id)
          .set(map, SetOptions(merge: true));

      if (accountPremium &&
          (remoteUrl == null || remoteUrl.isEmpty) &&
          memory.imagePath != null &&
          memory.imagePath!.isNotEmpty) {
        try {
          remoteUrl = await _uploadImage(userId: userId, memory: memory);
          if (remoteUrl != null) {
            await _firestore!
                .collection('users')
                .doc(userId)
                .collection('memories')
                .doc(memory.id)
                .set({'imageRemotePath': remoteUrl}, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('No se pudo subir la imagen, nota guardada igualmente: $e');
        }
      }
      return remoteUrl;
    } catch (e) {
      debugPrint('Error al subir memoria: $e');
      return remoteUrl;
    }
  }

  Future<void> migrateLegacyImages({
    required String userId,
    required List<Memory> memories,
    required bool accountPremium,
  }) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return;
    if (!accountPremium) return;

    for (final memory in memories) {
      final hasLocalImage = memory.imagePath != null && memory.imagePath!.isNotEmpty;
      final hasRemoteImage = memory.imageRemotePath?.isNotEmpty == true;
      if (!hasLocalImage || hasRemoteImage) continue;

      final remoteUrl = await pushMemory(
        userId: userId,
        memory: memory,
        accountPremium: accountPremium,
      );
      if (remoteUrl != null) {
        memory.imageRemotePath = remoteUrl;
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchLegacy(
    String userId,
    String collectionName,
  ) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return [];

    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .get();
      return snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> syncSettings({
    required String userId,
    required UserSettings localSettings,
    required Function(UserSettings) onUpdate,
  }) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return;

    try {
      final docRef = _firestore!
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences');
      final doc = await docRef.get();
      if (doc.exists) {
        onUpdate(UserSettings.fromMap({
          ...doc.data() as Map<String, dynamic>,
          'userId': userId,
        }));
      } else {
        await docRef.set(localSettings.toMap());
      }
    } catch (e) {
      debugPrint('Error al sincronizar ajustes: $e');
    }
  }

  Future<void> pushSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return;

    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences')
          .set(settings.toMap());
    } catch (e) {
      debugPrint('Error al subir ajustes: $e');
    }
  }

  Future<void> wipeUserData(String userId) async {
    if (!_firebaseAvailable || _firestore == null || userId.isEmpty) return;

    try {
      for (final name in ['memories', 'reminders', 'sticky_notes']) {
        final snapshot = await _firestore!
            .collection('users')
            .doc(userId)
            .collection(name)
            .get();
        final batch = _firestore!.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error al borrar datos: $e');
    }
  }
}
