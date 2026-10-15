import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ad_service.dart';
import '../services/legal_consent_service.dart';

/// GECICI reklam teshis ekrani (Ayarlar > Reklam Teshisi).
/// Reklamlar neden gelmiyor sorusunu uygulamanin icinden cevaplamak icin.
/// Sorun cozulunce bu dosya ve Ayarlar'daki butonu silebilirsin.
class AdDebugScreen extends StatefulWidget {
  const AdDebugScreen({super.key});

  @override
  State<AdDebugScreen> createState() => _AdDebugScreenState();
}

class _AdDebugScreenState extends State<AdDebugScreen> {
  final ad = AdService.instance;
  Timer? _timer;
  bool? _internet;
  bool _rewardedLoaded = false;
  bool _interstitialLoaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final net = await ad.debugHasInternet();
    final r = await ad.debugIsLoaded(true);
    final i = await ad.debugIsLoaded(false);
    if (!mounted) return;
    setState(() {
      _internet = net;
      _rewardedLoaded = r;
      _interstitialLoaded = i;
    });
  }

  Widget _row(String k, String v, {bool? good}) {
    final color = good == null ? null : (good ? Colors.green.shade700 : Colors.red.shade700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(k, style: const TextStyle(fontSize: 14))),
          Expanded(
            flex: 6,
            child: Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _showStrict() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ad.showRewarded(context, strict: true);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Reklam izlendi, odul hakki var' : 'Reklam gosterilemedi / izlenmedi (odul yok)')),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final log = ad.debugLog.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Reklam Teşhisi (geçici)')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _row('Paket adı (build.gradle)', 'com.sitora.ai'),
          _row('App Key', ad.appKeyMasked),
          _row('SDK yapılandırıldı', ad.configured ? 'evet' : 'HAYIR', good: ad.configured),
          _row('Hukuki onay verildi', LegalConsentService.instance.accepted ? 'evet' : 'HAYIR (SDK başlamaz)',
              good: LegalConsentService.instance.accepted),
          _row('SDK başladı', ad.sdkInitialized ? 'evet' : 'HAYIR', good: ad.sdkInitialized),
          _row('Appodeal init sonucu', ad.initResult),
          _row('Test modu', ad.testingActive ? 'AÇIK (test reklamı)' : 'kapalı (gerçek reklam)'),
          _row('İnternet', _internet == null ? '...' : (_internet! ? 'var' : 'YOK'), good: _internet),
          _row('Ödüllü reklam yüklü', _rewardedLoaded ? 'evet' : 'hayır', good: _rewardedLoaded),
          _row('Geçiş reklamı yüklü', _interstitialLoaded ? 'evet' : 'hayır', good: _interstitialLoaded),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _refresh, child: const Text('Yenile')),
              FilledButton(
                onPressed: () async {
                  await ad.preload();
                  _refresh();
                },
                child: const Text('Ödüllü yükle'),
              ),
              FilledButton(
                onPressed: () async {
                  await ad.preloadInterstitial();
                  _refresh();
                },
                child: const Text('Geçiş yükle'),
              ),
              FilledButton(onPressed: _busy ? null : _showStrict, child: const Text('Ödüllü göster (sıkı)')),
              OutlinedButton(
                onPressed: () async {
                  await ad.debugReinit();
                  _refresh();
                },
                child: const Text('SDK yeniden başlat'),
              ),
              OutlinedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: [
                    'key=${ad.appKeyMasked} sdk=${ad.sdkInitialized} init=${ad.initResult} test=${ad.testingActive}',
                    'internet=$_internet rewardedLoaded=$_rewardedLoaded interstitialLoaded=$_interstitialLoaded',
                    ...ad.debugLog,
                  ].join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log panoya kopyalandı')));
                },
                child: const Text('Logu kopyala'),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Test modu (test reklamı)'),
            subtitle: const Text('Değiştirince uygulamayı tamamen kapatıp aç'),
            value: ad.testingActive,
            onChanged: AdService.testingMode
                ? null
                : (v) async {
                    await ad.setDebugTesting(v);
                    if (mounted) setState(() {});
                  },
          ),
          const Divider(),
          const Text('Olay günlüğü (en yeni üstte)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (log.isEmpty)
            const Text('Henüz kayıt yok. SDK başlamadıysa "SDK başladı: HAYIR" satırına bak.')
          else
            for (final l in log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
              ),
        ],
      ),
    );
  }
}
