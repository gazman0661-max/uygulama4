import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import '../services/ads_service.dart';

/// Ekranın en altına sabitlenen, kullanıcıyı rahatsız etmeyecek banner
/// reklam şeridi (bkz. main.dart > MaterialApp.builder — TÜM ekranların
/// altına, Navigator'ın DIŞINDA eklenir ki ekran geçişlerinde kaybolmasın).
///
/// Reklam yüklenene kadar ve yüklenemezse YER KAPLAMAZ (yükseklik 0) —
/// boş/gri bir kutu göstermek yerine, reklam gerçekten hazır olduğunda
/// yumuşak bir animasyonla belirir. Böylece reklam ağı boşsa (özellikle
/// test modunda sık görülür) alt tarafta kullanılamaz boşluk kalmaz.
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({super.key});

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Appodeal.setBannerCallbacks(
      onBannerLoaded: (isPrecache) {
        if (mounted) setState(() => _loaded = true);
      },
      onBannerFailedToLoad: () {
        if (mounted) setState(() => _loaded = false);
      },
      onBannerShown: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsService.instance.isAvailable) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _loaded
          ? SafeArea(
              top: false,
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: AppodealBanner(
                  adSize: AppodealBannerSize.BANNER,
                  placement: 'default',
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
