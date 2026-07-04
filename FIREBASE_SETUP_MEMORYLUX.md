# Firebase setup para Memorylux

Este proyecto ya está preparado para usar Firebase con este identificador:

- Android package name: `com.danielux135.memorylux`
- iOS Bundle ID: `com.danielux135.memorylux`

## 1. Instala las herramientas

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

Si Windows no reconoce `flutterfire`, añade el binario de Pub al PATH:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

## 2. Conecta el proyecto Flutter a Firebase

Desde la carpeta raíz de Memorylux:

```powershell
flutter pub get
flutterfire configure
```

Selecciona tu proyecto Firebase `Memorylux` y marca estas plataformas:

- Android
- iOS
- Web

Para Windows nativo, Firebase lo trata principalmente como entorno de desarrollo. Para versión PC pública, lo más limpio es compilar Memorylux como Web/PWA.

Al terminar, la CLI debe reemplazar `lib/firebase_options.dart` por la configuración real.

## 3. Firebase Console

### Authentication

Ve a:

```text
Build / Compilación > Authentication > Sign-in method
```

Activa:

```text
Email/Password
```

### Firestore Database

Ve a:

```text
Build / Compilación > Firestore Database > Crear base de datos
```

Elige una región europea si puedes, por ejemplo `eur3`/Europa, y empieza en modo producción.

Después ve a la pestaña `Rules` y pega el contenido de `firestore.rules`.

## 4. Probar

```powershell
flutter clean
flutter pub get
flutter run
```

Crea una cuenta desde la app. Debe aparecer en:

```text
Firebase Console > Authentication > Users
```

Y sus datos deben aparecer en Firestore así:

```text
users/{uid}
users/{uid}/reminders/{reminderId}
users/{uid}/sticky_notes/{noteId}
users/{uid}/settings/preferences
```

## 5. iOS

Para iOS necesitas macOS con Xcode. En Mac:

```bash
flutter pub get
flutterfire configure
flutter run -d ios
```

Para publicar:

```bash
flutter build ipa --release
```
