import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

// idioma de la interfaz: 'es' o 'en'. context.pick(es, en) elige según ajustes.
extension LocalizedContext on BuildContext {
  bool get isEn => read<SettingsProvider>().settings.language == 'en';
  String pick(String es, String en) => isEn ? en : es;
  String get localeCode => isEn ? 'en_US' : 'es';
}
