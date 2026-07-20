import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/memory_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/monetization_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';

class MemoryluxApp extends StatelessWidget {
  final Widget? adSlot;

  const MemoryluxApp({
    super.key,
    this.adSlot,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()..init()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => MonetizationService()..load()),
        ChangeNotifierProxyProvider<AuthService, MemoryProvider>(
          create: (ctx) => MemoryProvider(
            authService: ctx.read<AuthService>(),
            notificationService: ctx.read<NotificationService>(),
            syncService: ctx.read<SyncService>(),
            monetizationService: ctx.read<MonetizationService>(),
          ),
          update: (ctx, auth, previous) {
            if (auth.userId.isNotEmpty) {
              ctx.read<MonetizationService>().bindToUser(auth.userId);
            }
            return previous!;
          },
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
          // mantiene al servicio de widgets al día de idioma y premium
          final monetization = context.watch<MonetizationService>();
          WidgetService.instance.configure(
            isAndroid: monetization.isAndroid,
            isPremium: monetization.isPremium,
            isEn: settings.settings.language == 'en',
          );

          final themeMode = switch (settings.settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };

          return MaterialApp(
            title: 'Memorylux',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            locale: Locale(settings.settings.language),
            supportedLocales: const [
              Locale('es'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: auth.isAuthenticated
                ? HomeScreen(adSlot: adSlot)
                : const AuthScreen(),
          );
        },
      ),
    );
  }
}
