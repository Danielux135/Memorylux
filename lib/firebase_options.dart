// Firebase options de Memorylux.
//
// Android y Windows usan el proyecto Firebase actual de Memorylux.
// Para iOS/Web, lo ideal es ejecutar `flutterfire configure` cuando tengas
// Flutter instalado y quieras añadir esas plataformas.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase no está configurado para Web. Ejecuta flutterfire configure cuando quieras publicar Web/PWA.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase no está configurado para iOS. Ejecuta flutterfire configure en un Mac cuando vayas a compilar iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'Firebase no está configurado para macOS.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase no está activo en Linux nativo. Memorylux usa modo local en Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Firebase no está soportado en Fuchsia.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgQMTiAEeqIQWsfESWA-kuh7BdYZX0rOw',
    appId: '1:294865674964:android:a648599541ffd6da5e5141',
    messagingSenderId: '294865674964',
    projectId: 'memorylux-cf1b4',
    storageBucket: 'memorylux-cf1b4.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCgQMTiAEeqIQWsfESWA-kuh7BdYZX0rOw',
    appId: '1:294865674964:android:a648599541ffd6da5e5141',
    messagingSenderId: '294865674964',
    projectId: 'memorylux-cf1b4',
    storageBucket: 'memorylux-cf1b4.firebasestorage.app',
  );
}
