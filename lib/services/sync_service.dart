import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/memory.dart';
import '../models/user_settings.dart';
import 'firebase_bootstrap.dart';

// Sincronización con Firestore: fusiona local y nube por updatedAt (gana el más reciente).
// Si Firebase no está disponible, el servicio se queda en modo no-op y la app usa datos locales.
class SyncService extends ChangeNotifier {
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
    _monitorConnectivity();
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

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }

  Future<void> syncMemories({
    required String userId,
    required List<Memory> localMemories,
    required Function(List<Memory>) onUpdate,
  }) async {
    if (!_firebaseAvailable ||
        _firestore == null ||
        _isSyncing ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }
    _isSyncing = true;
    notifyListeners();

    try {
      final collection =
          _firestore!.collection('users').doc(userId).collection('memories');
      final snapshot = await collection.get();

      final cloud = <Memory>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        cloud.add(Memory.fromMap({...data, 'userId': userId}));
      }

      final merged = <String, Memory>{};
      for (final m in localMemories) {
        merged[m.id] = m;
      }
      for (final m in cloud) {
        final existing = merged[m.id];
        if (existing == null || m.updatedAt.isAfter(existing.updatedAt)) {
          merged[m.id] = m;
        }
      }

      final batch = _firestore!.batch();
      for (final m in merged.values) {
        final map = m.toMap()..remove('imagePath');
        batch.set(collection.doc(m.id), map, SetOptions(merge: true));
      }
      await batch.commit();

      onUpdate(merged.values.toList());
      _lastSync = DateTime.now();
    } catch (e) {
      debugPrint('Error de sincronización: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> deleteMemory({
    required String userId,
    required String memoryId,
  }) async {
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('memories')
          .doc(memoryId)
          .delete();
    } catch (e) {
      debugPrint('Error al borrar en la nube: $e');
    }
  }

  Future<void> pushMemory({
    required String userId,
    required Memory memory,
  }) async {
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }
    try {
      final map = memory.toMap()..remove('imagePath');
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('memories')
          .doc(memory.id)
          .set(map, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error al subir memoria: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLegacy(
      String userId, String collectionName) async {
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return [];
    }
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
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }

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
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }

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
    if (!_firebaseAvailable ||
        _firestore == null ||
        !_isOnline ||
        userId.isEmpty) {
      return;
    }
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
