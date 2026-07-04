import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/auth_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'providers/memory_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await initializeDateFormatting('en_US');

  // Importante: no dejamos que Firebase tire la app.
  // Android/iOS/Web intentan inicializar Firebase; Windows/Linux arrancan en modo local.
  await FirebaseBootstrap.initialize();

  runApp(const MemoryluxApp());
}

class MemoryluxApp extends StatelessWidget {
  const MemoryluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()..init()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProxyProvider<AuthService, MemoryProvider>(
          create: (ctx) => MemoryProvider(
            authService: ctx.read<AuthService>(),
            notificationService: ctx.read<NotificationService>(),
            syncService: ctx.read<SyncService>(),
          ),
          update: (ctx, auth, previous) => previous!,
        ),
        ChangeNotifierProxyProvider<AuthService, SettingsProvider>(
          create: (ctx) => SettingsProvider(
            authService: ctx.read<AuthService>(),
            syncService: ctx.read<SyncService>(),
          ),
          update: (ctx, auth, previous) => previous!,
        ),
      ],
      child: Consumer2<AuthService, SettingsProvider>(
        builder: (context, auth, settings, _) {
          final mode = switch (settings.settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            title: 'Memorylux',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            locale: Locale(settings.settings.language),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: auth.isAuthenticated ? const HomeScreen() : const AuthScreen(),
          );
        },
      ),
    );
  }
}
