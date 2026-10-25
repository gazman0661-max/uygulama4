import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'log_service.dart';
/// GERCEK internet kontrolu - tamamen ucretsiz, ek paket yok (sadece dart:io).
///
/// Cihazin "Wi-Fi'ye bagli" gorunmesi internet oldugu anlamina gelmez (ucak modu
/// kapali ama kota bitmis, modem internetsiz, otel/okul giris sayfasi vb.).
/// Bu yuzden gercekten bilinen halka acik sunuculara kucuk HTTPS istekleri atilir
/// ve beklenen yanit (204 / "ip=" iceren metin) gelirse internet VAR sayilir.
/// Giris sayfasi (captive portal) 204 yerine baska bir yanit dondurdugu icin
/// "internet yok" sayilir.
///
/// Yanlis alarmi azaltmak icin: uc sunucu PARALEL denenir (biri yeterli),
/// hepsi basarisiz olursa 1 kez daha denenir.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// Uygulama arka plandan donunce de kontrol edilsin mi?
  /// (Kapatmak istersen false yap: sadece acilista kontrol eder.)
  static const bool checkOnResume = true;

  static const Duration _timeout = Duration(seconds: 4);
  static const List<_Probe> _probes = <_Probe>[
    _Probe('https://www.google.com/generate_204', 204),
    _Probe('https://connectivitycheck.gstatic.com/generate_204', 204),
    _Probe('https://www.cloudflare.com/cdn-cgi/trace', 200, bodyContains: 'ip='),
  ];

  /// Splash internet kontrolunu gectikten sonra true olur (resume kontrolu ondan once calismaz).
  bool startupPassed = false;

  /// true = internet var. En kotu durumda ~9 sn surer.
  Future<bool> hasInternet() async {
    if (kIsWeb) return true;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (await _probeAny()) return true;
      if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    return false;
  }

  Future<bool> _probeAny() {
    final done = Completer<bool>();
    var pending = _probes.length;
    for (final p in _probes) {
      _probe(p).then((ok) {
        if (ok && !done.isCompleted) done.complete(true);
        pending--;
        if (pending == 0 && !done.isCompleted) done.complete(false);
      });
    }
    return done.future;
  }

  /// Hicbir zaman exception firlatmaz.
  Future<bool> _probe(_Probe p) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(Uri.parse(p.url)).timeout(_timeout);
      req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final resp = await req.close().timeout(_timeout);
      if (resp.statusCode != p.status) {
        await resp.drain<void>().timeout(_timeout);
        return false;
      }
      if (p.bodyContains == null) {
        await resp.drain<void>().timeout(_timeout);
        return true;
      }
      final body = await resp.transform(utf8.decoder).join().timeout(_timeout);
      return body.contains(p.bodyContains!);
    } catch (err) {
      AppLog.w('connectivity_service._probe', 'yutulan hata', err);
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

class _Probe {
  final String url;
  final int status;
  final String? bodyContains;
  const _Probe(this.url, this.status, {this.bodyContains});
}
