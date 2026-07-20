import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../services/monetization_service.dart';

enum _AdSlotKind { portrait, landscape }

class MemoryluxAdSlot extends StatefulWidget {
  const MemoryluxAdSlot({super.key});

  @override
  State<MemoryluxAdSlot> createState() => _MemoryluxAdSlotState();
}

class _MemoryluxAdSlotState extends State<MemoryluxAdSlot> {
  static final Map<_AdSlotKind, BannerAd> _sessionAds = {};
  static final Set<_AdSlotKind> _sessionLoading = {};
  static final Set<_AdSlotKind> _sessionFailed = {};
  static final Set<_MemoryluxAdSlotState> _mountedSlots = {};

  @override
  void initState() {
    super.initState();
    _mountedSlots.add(this);
  }

  @override
  void dispose() {
    _mountedSlots.remove(this);
    super.dispose();
  }

  static void _notifyMountedSlots() {
    for (final slot in _mountedSlots.toList()) {
      if (slot.mounted) slot.setState(() {});
    }
  }

  static void _disposeSessionAds() {
    for (final ad in _sessionAds.values) {
      ad.dispose();
    }
    _sessionAds.clear();
    _sessionLoading.clear();
    _sessionFailed.clear();
  }

  void _ensureSessionAdsLoaded() {
    final monetization = context.read<MonetizationService>();
    if (!monetization.adsEnabled) return;

    _loadSessionAdOnce(_AdSlotKind.portrait);
    _loadSessionAdOnce(_AdSlotKind.landscape);
  }

  static void _loadSessionAdOnce(_AdSlotKind kind) {
    if (_sessionAds.containsKey(kind) ||
        _sessionLoading.contains(kind) ||
        _sessionFailed.contains(kind)) {
      return;
    }

    _sessionLoading.add(kind);
    final ad = BannerAd(
      adUnitId: MonetizationService.bannerAdUnitId,
      size: kind == _AdSlotKind.portrait ? AdSize.banner : AdSize.fullBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _sessionAds[kind] = ad as BannerAd;
          _sessionLoading.remove(kind);
          _notifyMountedSlots();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _sessionLoading.remove(kind);
          _sessionFailed.add(kind);
          _notifyMountedSlots();
        },
      ),
    );

    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final monetization = context.watch<MonetizationService>();
    if (!monetization.adsEnabled) {
      _disposeSessionAds();
      return const SizedBox.shrink();
    }

    if (_sessionAds.length + _sessionLoading.length + _sessionFailed.length <
        2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureSessionAdsLoaded();
      });
    }

    final orientation = MediaQuery.orientationOf(context);
    final kind = orientation == Orientation.landscape
        ? _AdSlotKind.landscape
        : _AdSlotKind.portrait;
    final ad = _sessionAds[kind];
    final waiting = _sessionLoading.contains(kind);
    final failed = _sessionFailed.contains(kind);
    final scheme = Theme.of(context).colorScheme;

    final child = ad != null
        ? SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          )
        : SizedBox(
            height: kind == _AdSlotKind.landscape ? 60 : 50,
            child: Center(
              child: Text(
                waiting || !failed
                    ? context.pick('Cargando anuncio...', 'Loading ad...')
                    : context.pick('Espacio publicitario', 'Ad space'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          );

    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 62),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}
