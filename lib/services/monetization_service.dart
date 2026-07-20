import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

class MonetizationService extends ChangeNotifier {
  static const edition = String.fromEnvironment(
    'MEMORYLUX_EDITION',
    defaultValue: 'free',
  );

  static const admobAppId = String.fromEnvironment(
    'MEMORYLUX_ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-7763753421792663~3812360296',
  );

  static const bannerAdUnitId = String.fromEnvironment(
    'MEMORYLUX_ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-7763753421792663/3170232008',
  );

  static const premiumProductId = String.fromEnvironment(
    'MEMORYLUX_PREMIUM_PRODUCT_ID',
    defaultValue: 'memorylux_premium',
  );

  FirebaseFirestore? _firestore;
  bool _accountPremium = false;
  String? _boundUserId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _premiumSub;

  // premium real = build de pago (dev/testing) o cuenta marcada como
  // comprada en Firestore (compra hecha desde la app de pago de Android)
  bool get isPremium => isPaidBuild || _accountPremium;
  bool get isPaidBuild => edition == 'paid';
  bool get isFreeBuild => edition != 'paid';
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get adsEnabled => isAndroid && isFreeBuild && !isPremium;

  Future<void> load() async {
    if (FirebaseBootstrap.isAvailable) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        debugPrint('MonetizationService sin Firebase: $e');
      }
    }
    notifyListeners();
  }

  // escucha el estado de compra de la cuenta indicada en Firestore
  // (users/{uid}.premium), para que cualquier plataforma sepa si esa
  // cuenta ya compró el programa, sin depender del build ni del dispositivo
  void bindToUser(String userId) {
    if (_firestore == null || userId.isEmpty || _boundUserId == userId) return;

    _premiumSub?.cancel();
    _boundUserId = userId;
    _premiumSub = _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      // firestore dispara snapshots aunque solo cambie la metadata (ej. de
      // caché a servidor); si el valor no cambia de verdad no hay que
      // reconstruir toda la pantalla (y menos recrear el banner de anuncio)
      final premium = doc.data()?['premium'] == true;
      if (premium == _accountPremium) return;
      _accountPremium = premium;
      notifyListeners();
    }, onError: (e) {
      debugPrint('MonetizationService error escuchando premium: $e');
    });
  }

  void unbind() {
    _premiumSub?.cancel();
    _premiumSub = null;
    _boundUserId = null;
    _accountPremium = false;
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    await load();
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    super.dispose();
  }
}
