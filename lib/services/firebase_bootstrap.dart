import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Inicializa Firebase solo donde Memorylux lo soporta.
///
/// Si Firebase falla al arrancar, la app cae a modo local/offline para no
/// bloquear el acceso a los datos locales.
class FirebaseBootstrap {
  static bool _available = false;
  static String? _unavailableReason;

  static bool get isAvailable => _available;
  static String? get unavailableReason => _unavailableReason;

  static bool get isNativeDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  static bool get shouldTryFirebase {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static Future<void> initialize() async {
    if (!shouldTryFirebase) {
      _available = false;
      _unavailableReason =
          'Firebase no está activo en esta plataforma. Memorylux usará modo local.';
      debugPrint(_unavailableReason);
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _available = true;
      _unavailableReason = null;
    } catch (error, stackTrace) {
      _available = false;
      _unavailableReason = error.toString();
      debugPrint('Firebase no se pudo inicializar: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
