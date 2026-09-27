import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crash_service.dart';

/// ============================================================================
/// SITORA — UYGULAMA İÇİ DEĞERLENDİRME (IN-APP REVIEW)
/// ============================================================================
/// Google Play'in resmi, ücretsiz "In-App Review" API'sini sarmalar
/// (`in_app_review` paketi). AMAÇ: kullanıcı bir siteyi BAŞARIYLA
/// yayınladığı anda (bkz. publish_sheet.dart > _publish başarı dalı) —
/// yani ürünle en mutlu olduğu anda — native 5 yıldız popup'ını göstermek.
///
/// ÖNEMLİ — Play'in KENDİ kotası zaten var: `requestReview()` her
/// çağrıldığında popup göstereceğinin garantisi YOKTUR; Google, bir
/// hesaba günde/haftada kaç kez gerçek popup gösterileceğini kendi
/// tarafında sınırlar (biz bunu göremeyiz/kontrol edemeyiz). Yani
/// [maybeRequestReview] her başarılı yayında çağrılsa bile kullanıcı
/// popup'ı HER SEFERİNDE görmez.
///
/// BUNA RAĞMEN kendi tarafımızda AYRICA throttle uyguluyoruz — sırf Play
/// izin veriyor diye "her yayında iste" mantığı ileride Play'in politikası
/// gevşer/değişirse bile kullanıcıyı rahatsız etmesin diye:
///   1) Toplamda en fazla [_maxLifetimeRequests] kez tetiklenir (hesap/
///      cihaz ömrü boyunca) — kullanıcı "yorum yap" isteğine defalarca
///      maruz kalmaz.
///   2) İki istek arasında en az [_minGapBetweenRequests] geçmeli.
///   3) İLK yayın da dahil — kullanıcı "mutluluk anı"nı ilk başarılı
///      yayınında da yaşar, bu yüzden ilk yayından itibaren tetiklenir
///      (bir sonraki yayına kadar beklemiyoruz).
///
/// HATA YÖNETİMİ: AnalyticsService/CrashService ile AYNI desende — bu
/// servis ASLA yayınlama akışını bloklamaz/çökertmez. `isAvailable()`
/// false dönerse (ör. cihazda Play Store yoksa, emülatörse, iOS'ta
/// App Store review kotası dolmuşsa) veya herhangi bir hata olursa
/// sessizce hiçbir şey yapmadan çıkar.
/// ============================================================================
class ReviewService {
  ReviewService._();

  static final InAppReview _inAppReview = InAppReview.instance;

  static const _requestCountPrefsKey = 'review_request_count';
  static const _lastRequestAtPrefsKey = 'review_last_requested_at_ms';

  /// Hesap/cihaz ömrü boyunca en fazla kaç kez popup TETİKLENMEYE
  /// ÇALIŞILIR (gerçekten gösterilip gösterilmediği Play'in kotasına
  /// bağlı, bkz. dosya başı not).
  static const int _maxLifetimeRequests = 3;

  /// İki tetikleme denemesi arasında beklenmesi gereken minimum süre.
  static const Duration _minGapBetweenRequests = Duration(days: 30);

  /// Bir site YENİ başarıyla yayınlandığında çağrılır (bkz.
  /// publish_sheet.dart > _publish). Kendi throttle kurallarımız
  /// (yukarı bkz.) geçilirse [InAppReview.requestReview] çağrılır.
  ///
  /// `await` edilmeye GEREK YOKTUR — çağıran taraf `unawaited(...)` ile
  /// fire-and-forget kullanabilir, herhangi bir sonuca göre dallanma
  /// gerekmez (kullanıcı popup'ı görse de görmese de yayınlama akışı
  /// zaten tamamlanmıştır).
  static Future<void> maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_requestCountPrefsKey) ?? 0;
      if (count >= _maxLifetimeRequests) return;

      final lastMs = prefs.getInt(_lastRequestAtPrefsKey);
      if (lastMs != null) {
        final elapsed = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastMs),
        );
        if (elapsed < _minGapBetweenRequests) return;
      }

      final available = await _inAppReview.isAvailable();
      if (!available) return;

      // Sayaç/timestamp, GERÇEKTEN gösterilip gösterilmediğinden BAĞIMSIZ
      // olarak burada güncellenir — Play API'si bunu bize bildirmiyor
      // (privacy sebebiyle "gösterildi mi" bilgisi uygulamaya sızdırılmaz).
      // Yani bu "en fazla N popup gösterildi" değil, "en fazla N kez
      // istek TETİKLEMEYE ÇALIŞILDI" garantisidir — amaca yeterli, çünkü
      // asıl risk olan "arka arkaya/sık sık isteme" davranışını engeller.
      await prefs.setInt(_requestCountPrefsKey, count + 1);
      await prefs.setInt(
        _lastRequestAtPrefsKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      await _inAppReview.requestReview();
    } catch (e, st) {
      CrashService.record(e, st, context: 'ReviewService.maybeRequestReview');
    }
  }
}
