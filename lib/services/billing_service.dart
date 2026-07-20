import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'firebase_bootstrap.dart';
import 'monetization_service.dart';

// compra unica "premium" via Google Play Billing; al confirmarse, marca
// la cuenta como premium en Firestore (users/{uid}.premium) para que
// MonetizationService lo detecte en cualquier plataforma
class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  String? _userId;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  void start(String userId) {
    _userId = userId;
    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) => debugPrint('BillingService error: $e'),
    );
  }

  void stop() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  Future<void> buyPremium() async {
    if (!await isAvailable()) return;

    final response = await _iap
        .queryProductDetails({MonetizationService.premiumProductId});
    if (response.productDetails.isEmpty) return;

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != MonetizationService.premiumProductId) {
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _markAccountPremium();
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _markAccountPremium() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty || !FirebaseBootstrap.isAvailable) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'premium': true,
        'premiumSince': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo marcar la cuenta como premium: $e');
    }
  }

  void dispose() {
    stop();
  }
}
