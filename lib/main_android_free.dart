import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'memorylux_app.dart';
import 'services/firebase_bootstrap.dart';
import 'widgets/memorylux_ad_slot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await initializeDateFormatting('en_US');

  await FirebaseBootstrap.initialize();
  await MobileAds.instance.initialize();

  runApp(const MemoryluxApp(adSlot: MemoryluxAdSlot()));
}
