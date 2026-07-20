import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'memorylux_app.dart';
import 'services/firebase_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await initializeDateFormatting('en_US');

  await FirebaseBootstrap.initialize();

  runApp(const MemoryluxApp());
}
