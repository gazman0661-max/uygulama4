import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
/// SUNUCU SAATİ SAPMASI (CLOCK SKEW) DÜZELTMESİ — 06.09.2026 eklendi.
/// ============================================================================
/// SORUN: `SiteProject.isDomainExpired` / `isMiniPackageExpired` (bkz.
/// models/site_project.dart) doğrudan `DateTime.now()` (CİHAZ saati)
/// kullanıyordu. Worker zaten `domain_connected_at`/`mini_package_activated_at`
/// gibi tarihleri KENDİ saatiyle (D1) tutuyor ve asıl kesme (barındırılan
/// sitenin gerçekten servis edilip edilmeyeceği) SERVER tarafında oluyor —
/// yani gerçek gelir/erişim güvenliği zaten sağlam. AMA cihazdaki bu yerel
/// hesaplama, `LocalGenerationHelper`'daki çok-sayfa üretim KİLİDİ gibi
/// TAMAMEN yerel/offline çalışan kontroller için tek referanstı: kullanıcı
/// telefonun saatini geriye alırsa (ör. mini paketin 30 günü çoktan dolmuş
/// olsa bile) yerel `isMiniPackageExpired` hep `false` dönmeye devam eder ve
/// sınırsız süreyle "hâlâ mini paket aktifmiş gibi" çok sayfa üretilebilir.
///
/// ÇÖZÜM: Worker'a atılan HER isteğin HTTP yanıtı zaten standart bir `Date`
/// header'ı taşır (worker'ın kendi çalıştığı Cloudflare edge saatidir, bu
/// yüzden kullanıcı cihazından bağımsız güvenilir bir referans). Bu servis
/// her başarılı worker cevabından bu header'ı okuyup
/// `sunucu_saati - cihaz_saati` farkını (skew) hesaplar, SharedPreferences'a
/// kalıcı olarak yazar ve `ServerTimeService.now()` bundan sonra HER YERDE
/// `DateTime.now()` yerine kullanılabilir: cihaz saati ileri/geri oynatılsa
/// bile, en son bilinen sapma uygulanmaya devam eder (elbette kullanıcı hem
/// interneti kapatıp HEM saatini oynatıp HİÇ worker'a bağlanmazsa bu da
/// aşılabilir — ama bu, "hosting/worker'a hiç konuşmadan sonsuza dek
/// offline çok sayfa üretmek" gibi çok daha dar/değersiz bir senaryoya
/// indirger, mevcut "tek satırlık saat değişikliği" açığını kapatır).
///
/// KASITLI SINIRLAMA: Bu bir NTP istemcisi değil — ekstra bir ağ isteği
/// ATMIYORUZ, zaten yapılan isteklerin yanıtına "otostopla" biniyoruz. Bu
/// yüzden skew, ancak uygulama worker'la konuştuğunda güncellenir; hiç
/// worker'a bağlanmamış taze bir kurulumda skew sıfırdır (yani cihaz
/// saatine güvenilir, mevcut davranışla AYNI — regresyon yok).
class ServerTimeService {
  ServerTimeService._();

  static const _prefsKey = 'server_time_skew_ms';

  /// sunucu_saati - cihaz_saati (milisaniye). Varsayılan 0 = cihaz saatine
  /// güven (worker'la hiç konuşulmamışsa mevcut davranışla birebir aynı).
  static Duration _skew = Duration.zero;
  static bool _loaded = false;

  /// main.dart açılışında (Firebase/Billing init ile AYNI yerde) bir kere
  /// çağrılmalı — önceki oturumdan kalan sapmayı SharedPreferences'tan
  /// okur. Çağrılmazsa (ör. eski/atlanmış bir main.dart) skew baştan 0
  /// kabul edilir, sadece o oturum için worker'dan taze bir yanıt gelene
  /// kadar cihaz saatine güvenilmiş olur — güvenli tarafta kalır.
  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_prefsKey);
      if (ms != null) _skew = Duration(milliseconds: ms);
    } catch (_) {
      // SharedPreferences erişilemezse sessizce cihaz saatine düş —
      // uygulamanın geri kalanını asla bloklamaz/çökertmez (diğer tüm
      // servislerle AYNI "iskelet" deseni).
    }
  }

  /// [response] worker'dan (ya da herhangi bir HTTP kaynağından) dönen
  /// yanıt — varsa `Date` header'ından skew'i günceller. Header yoksa ya da
  /// parse edilemezse SESSİZCE hiçbir şey yapmaz (mevcut skew korunur).
  /// TÜM worker çağrılarının (domain/mini-paket/satın-alma doğrulama)
  /// yanıtından sonra çağrılması amaçlanır (bkz. domain_service.dart,
  /// mini_package_service.dart, billing_service.dart, hosting_service.dart).
  static void updateFromResponse(http.Response response) {
    final dateHeader = response.headers['date'];
    if (dateHeader == null) return;
    try {
      final serverTime = HttpDate.parse(dateHeader);
      final deviceTime = DateTime.now();
      final newSkew = serverTime.difference(deviceTime);
      // Küçük ağ gecikmeleri yüzünden her istekte birkaç yüz milisaniyelik
      // gürültü olur — bu normal, sorun değil (30 günlük/365 günlük süre
      // kontrolleri için önemsiz). Yine de saçma/bozuk bir header'a karşı
      // (ör. saatlerce/günlerce sapma) makul bir üst sınır koyuyoruz: worker
      // ile cihaz arasında 1 yıldan fazla bir fark varsa header'ı GÜVENSİZ
      // sayıp yok sayıyoruz (parse hatası/bozuk veri ihtimaline karşı).
      if (newSkew.abs() > const Duration(days: 366)) return;
      _skew = newSkew;
      unawaited(_persist());
    } catch (_) {
      // Beklenmeyen header formatı — sessizce yok say, mevcut skew korunur.
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, _skew.inMilliseconds);
    } catch (_) {
      // Yazılamazsa bu oturum için bellekteki _skew yine de doğru kullanılır
      // — sadece bir sonraki uygulama açılışında kaybolur, kritik değil.
    }
  }

  /// `DateTime.now()` yerine kullanılacak, sunucu sapması uygulanmış zaman.
  /// `init()` hiç çağrılmadıysa ya da worker'la hiç konuşulmadıysa
  /// `DateTime.now()` ile birebir aynı sonucu verir (skew=0) — mevcut
  /// davranışla tam geriye dönük uyumlu.
  static DateTime now() => DateTime.now().add(_skew);
}
