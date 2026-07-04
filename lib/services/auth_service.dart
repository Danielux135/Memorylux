import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_bootstrap.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _firebaseAvailable = false;
  bool _isOfflineSession = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get firebaseAvailable => _firebaseAvailable;
  bool get isOfflineSession => _isOfflineSession;
  bool get isAuthenticated => _user != null || _isOfflineSession;
  String? get error => _error;

  /// En modo local usamos un id estable para SharedPreferences.
  /// No se sincroniza con la nube, pero la app puede abrir y guardar datos locales.
  String get userId => _user?.uid ?? (_isOfflineSession ? 'local_memorylux_user' : '');

  AuthService() {
    _initializeFirebase();
  }

  void _initializeFirebase() {
    if (!FirebaseBootstrap.isAvailable) {
      _firebaseAvailable = false;
      _error = null;
      return;
    }

    try {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _firebaseAvailable = true;

      _authSubscription = _auth!.authStateChanges().listen((User? user) {
        _user = user;
        _isOfflineSession = false;
        notifyListeners();
        if (user != null) {
          unawaited(_syncUserProfile(user));
        }
      });
    } catch (e) {
      _firebaseAvailable = false;
      _error = 'Firebase no está disponible en esta plataforma';
      debugPrint('AuthService sin Firebase: $e');
    }
  }

  Future<void> continueOffline() async {
    _isOfflineSession = true;
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signUp(String email, String password, String name) async {
    if (!_firebaseAvailable || _auth == null || _firestore == null) {
      _error = 'Firebase no está configurado. Puedes entrar en modo local.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final trimmedName = name.trim();
      await credential.user?.updateDisplayName(trimmedName);
      await credential.user?.reload();
      _user = _auth!.currentUser;

      await _firestore!
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': trimmedName,
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth signUp error: ${e.code} - ${e.message}');
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'No se pudo crear la cuenta: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (!_firebaseAvailable || _auth == null) {
      _error = 'Firebase no está configurado. Puedes entrar en modo local.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth signIn error: ${e.code} - ${e.message}');
      _error = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'No se pudo iniciar sesión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    if (_firebaseAvailable && _auth != null) {
      await _auth!.signOut();
    }
    _user = null;
    _isOfflineSession = false;
    notifyListeners();
  }

  Future<void> _syncUserProfile(User user) async {
    if (_firestore == null) return;

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return;

    try {
      final doc = await _firestore!.collection('users').doc(user.uid).get();
      final data = doc.data();
      final name = data?['name'];
      if (name is! String || name.trim().isEmpty) return;

      await user.updateDisplayName(name.trim());
      await user.reload();
      _user = _auth?.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo sincronizar el perfil de usuario: $e');
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    final code = error.code;
    final message = error.message?.trim();
    final normalizedMessage = message?.toLowerCase();

    if (normalizedMessage?.contains('configuration_not_found') ?? false) {
      return 'Firebase Authentication no está activado para este proyecto. Activa Email/Password en Firebase Console.';
    }

    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed':
        return 'No se pudo conectar con Firebase. Revisa la conexión e inténtalo de nuevo';
      case 'operation-not-allowed':
        return 'El registro con correo y contraseña no está activado en Firebase';
      case 'invalid-api-key':
      case 'app-not-authorized':
      case 'api-key-not-valid':
        return 'Firebase no acepta la configuración de esta app Android';
      case 'unknown':
        if (message != null && message.isNotEmpty) {
          return 'Error de autenticación: $message';
        }
        return 'Error de autenticación desconocido. Revisa Logcat para ver el detalle de Firebase';
      default:
        if (message != null && message.isNotEmpty) {
          return 'Error de autenticación: $message';
        }
        return 'Error de autenticación: $code';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
