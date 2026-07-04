# Memorylux

> Smart sticky notes that do not disappear until the important stuff gets done.

Memorylux is a visual, music-reactive productivity app built with Flutter. It mixes sticky notes, persistent reminders, a board-style workspace, and cloud sync so your tasks feel alive instead of hidden in a plain list.

## English

### What Memorylux is

Memorylux is not a classic to-do app. It is a visual memory board designed to help you:

- capture tasks in seconds
- keep important notes visible
- receive persistent reminders
- sync data across devices
- stay organized without losing the playful, tactile feel of real sticky notes

### Main features

- **Memory Board**: a board-style workspace with sections such as Today, Do Not Forget, and Waiting.
- **Quick add**: write natural phrases like `dentist tomorrow 10:30 #health` or `pay bill every month #home`.
- **Persistent reminders**: important items keep resurfacing until you deal with them.
- **Custom sticky note themes**: use colors, styles, and image-based sticker backgrounds.
- **Calendar view**: review tasks and reminders by date.
- **Stats and progress**: track what has been completed and what is still pending.
- **Cloud sync**: your account can sync across supported devices with Firebase.
- **Multilingual UI**: Spanish, Valencian, and English interface text.

### Platforms

Memorylux is built for:

- Android
- iOS
- Web
- Windows desktop

Important note: Windows desktop now initializes Firebase with the Memorylux project options. If Firebase is unavailable at startup, the app keeps the Windows-safe local fallback.

### Tech stack

- Flutter
- Provider
- Firebase Auth
- Cloud Firestore
- flutter_local_notifications
- connectivity_plus
- table_calendar
- shared_preferences

### Project structure

```text
lib/
  main.dart                 App entry point, providers, theme, routing
  models/                   Core data models
  providers/                State management for memories and settings
  screens/                  Main app screens
  services/                 Auth, sync, notifications, export, image storage
  widgets/                  Reusable UI pieces
  visuals/                  Visual systems and backgrounds
  l10n/                     Language and translation helpers
```

### Getting started

```bash
flutter pub get
flutter run
```

To run on a specific platform:

```bash
flutter run -d chrome
flutter run -d android
flutter run -d windows
```

### Firebase setup

If you want cloud sync, configure Firebase for the platforms you need.

```bash
flutterfire configure
```

Then enable:

- Authentication with email and password
- Cloud Firestore

Apply the rules from `firestore.rules` if you want to keep the same data model.

### Build commands

```bash
flutter build apk
flutter build windows
flutter build web
```

### Why the app feels different

Memorylux is intentionally designed to feel more like a physical desk covered in notes than a generic task manager. The UI leans into:

- neon/glassmorphism styling
- animated, music-reactive visuals
- tactile sticky-note cards
- a more playful, game-like productivity experience

### Troubleshooting

- If Windows crashes on startup, check the Firebase initialization path in `lib/main.dart` and `lib/firebase_options.dart`.
- If the project folder becomes huge, delete generated folders like `build/` and `.dart_tool/`.
- If notifications do not appear on desktop, verify platform support for the notification plugin.

### License

MIT

## Español

### Que es Memorylux

Memorylux no es una lista de tareas clasica. Es un panel visual de memoria pensado para que:

- apuntes cosas en segundos
- mantengas lo importante siempre a la vista
- recibas recordatorios persistentes
- sincronices tus datos entre dispositivos
- uses una interfaz mas viva, tactil y divertida que un gestor de tareas normal

### Funciones principales

- **Memory Board**: un tablero visual con zonas tipo Hoy, No olvidar y En espera.
- **Alta rapida**: escribe frases naturales como `dentista manana 10:30 #salud` o `pagar factura cada mes #casa`.
- **Recordatorios persistentes**: si ignoras algo importante, vuelve a avisar hasta que lo resuelvas.
- **Temas para notas adhesivas**: colores, estilos e imagenes personalizadas para cada post-it.
- **Vista de calendario**: revisa tareas y recordatorios por fecha.
- **Estadisticas y progreso**: controla lo completado y lo pendiente.
- **Sincronizacion en la nube**: la cuenta puede sincronizarse con Firebase en dispositivos compatibles.
- **Interfaz multilenguaje**: textos en espanol, valenciano e ingles.

### Plataformas

Memorylux esta preparado para:

- Android
- iOS
- Web
- Windows de escritorio

Nota importante: Windows de escritorio ahora inicializa Firebase con la configuracion del proyecto Memorylux. Si Firebase no esta disponible al arrancar, la app mantiene el modo local seguro para Windows.

### Tecnologias

- Flutter
- Provider
- Firebase Auth
- Cloud Firestore
- flutter_local_notifications
- connectivity_plus
- table_calendar
- shared_preferences

### Estructura del proyecto

```text
lib/
  main.dart                 Punto de entrada, providers, tema y navegacion
  models/                   Modelos de datos
  providers/                Estado de memorias y ajustes
  screens/                  Pantallas principales
  services/                 Auth, sync, notificaciones, exportacion, imagenes
  widgets/                  Piezas reutilizables de UI
  visuals/                  Sistemas visuales y fondos
  l10n/                     Ayuda para idiomas y traducciones
```

### Como arrancarlo

```bash
flutter pub get
flutter run
```

Para una plataforma concreta:

```bash
flutter run -d chrome
flutter run -d android
flutter run -d windows
```

### Configuracion de Firebase

Si quieres sincronizacion en la nube, configura Firebase para las plataformas que necesites.

```bash
flutterfire configure
```

Despues activa:

- Authentication con correo y contrasena
- Cloud Firestore

Si quieres mantener el mismo modelo de datos, aplica las reglas de `firestore.rules`.

### Comandos de compilacion

```bash
flutter build apk
flutter build windows
flutter build web
```

### Por que la app se siente diferente

Memorylux esta pensada para parecer mas una mesa de trabajo llena de notas que un gestor de tareas clasico. La interfaz usa:

- estilo neon y glassmorphism
- visuales animados y reactivos a la musica
- tarjetas tipo post-it con tacto fisico
- una experiencia de productividad mas ludica y menos seca

### Solucion de problemas

- Si Windows falla al arrancar, revisa la inicializacion de Firebase en `lib/main.dart` y `lib/firebase_options.dart`.
- Si la carpeta del proyecto crece demasiado, borra directorios generados como `build/` y `.dart_tool/`.
- Si las notificaciones no aparecen en escritorio, revisa la compatibilidad del plugin con la plataforma.

### Licencia

MIT
