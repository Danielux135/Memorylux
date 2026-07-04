import 'package:flutter/material.dart';

// sistema de diseño "mesa de trabajo": fondo de escritorio cálido,
// post-its de papel con tipografía manuscrita y acento ámbar (lux)
class AppTheme {
  // acento lux: el brillo de las chinchetas y de lo importante
  static const Color lux = Color(0xFFFFB300);

  // mesa de noche (tema oscuro)
  static const Color darkDesk = Color(0xFF1B1620);
  static const Color darkSurface = Color(0xFF262029);
  static const Color darkLine = Color(0xFF3A3140);

  // mesa de día (tema claro): madera clara, no blanco de plantilla
  static const Color lightDesk = Color(0xFFEDE3D2);
  static const Color lightSurface = Color(0xFFF7F1E5);
  static const Color lightLine = Color(0xFFD8CBB4);

  // paleta de post-its
  static const List<String> noteColors = [
    '#FFE082', // amarillo clásico
    '#FFAB91', // coral
    '#A5D6A7', // menta
    '#90CAF9', // cielo
    '#CE93D8', // lila
    '#FFF8E1', // papel
  ];

  static Color noteColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return const Color(0xFFFFE082);
    return Color(0xFF000000 | value);
  }

  // tipografías: Caveat manuscrita para lo personal, Nunito redonda para la interfaz
  static TextStyle hand({double size = 22, Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: 'Caveat',
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w600,
      );

  static TextStyle ui({double size = 14, Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        color: color,
        fontWeight: weight,
      );

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final desk = dark ? darkDesk : lightDesk;
    final surface = dark ? darkSurface : lightSurface;
    final line = dark ? darkLine : lightLine;
    final ink = dark ? const Color(0xFFF2EBDF) : const Color(0xFF2B2118);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: lux,
      onPrimary: const Color(0xFF2B2118),
      secondary: dark ? const Color(0xFFCE93D8) : const Color(0xFF8E6BA8),
      onSecondary: dark ? const Color(0xFF2B2118) : Colors.white,
      error: const Color(0xFFE57373),
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      outline: line,
    );

    final textTheme =
        (dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
            .apply(fontFamily: 'Nunito', bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: desk,
      textTheme: textTheme.copyWith(
        headlineMedium: hand(size: 34, weight: FontWeight.w700, color: ink),
        titleLarge: hand(size: 28, weight: FontWeight.w600, color: ink),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: hand(size: 30, weight: FontWeight.w700, color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: line),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lux,
        foregroundColor: Color(0xFF2B2118),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: ui(color: ink.withValues(alpha: 0.45)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lux, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lux,
          foregroundColor: const Color(0xFF2B2118),
          elevation: 0,
          textStyle: ui(weight: FontWeight.w800, size: 15),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: line),
        labelStyle: ui(color: ink, size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: line),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            dark ? const Color(0xFF332B38) : const Color(0xFF3A2E22),
        contentTextStyle: ui(color: const Color(0xFFF2EBDF)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get lightTheme => _base(Brightness.light);
  static ThemeData get darkTheme => _base(Brightness.dark);
}
