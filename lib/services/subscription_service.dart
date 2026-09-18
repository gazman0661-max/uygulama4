import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hosting_service.dart';
import 'server_time_service.dart';

/// ============================================================================
/// AYLIK ABONELİK — DURUM SORGULAMA. 15.09.2026 eklendi (kanka isteği).
/// ============================================================================
/// BillingService, satın alma ANINDA worker'ı zaten `/api/verify-subscription`
/// ile tetikleyip D1'i günceller (bkz. billing_service.dart >
/// _verifySubscriptionServerSide). BU servis ise TERS yönde çalışır: hesabın
/// O AN D1'de kayıtlı olan abonelik durumunu OKUR — satın alma anı dışında
/// (uygulama açılışı, giriş yapıldığında) AppState'in yerel önbelleği
/// (activeSubscriptionProductId/activeSubscriptionExpiresAt) tazelemesi için
/// kullanılır (bkz. AppState.refreshSubscriptionStatus).
///
/// GÜVENLİ TARAF farkı DomainService/MiniPackageService'den: buradaki hata
/// durumunda İSTEMCİ YEREL DURUMU DEĞİŞTİRMEMELİ — bir ağ hatasında hesabın
/// aboneliği "yokmuş" gibi davranmak kullanıcının GERÇEKTEN aktif bir
/// aboneliği varken premium kaybetmesine yol açar. Bu yüzden [fetchStatus]
/// ağ/sunucu hatasında `null` döner ("bilinmiyor, dokunma"); sadece worker
/// GERÇEKTEN 200 ile bir cevap verdiğinde kesin bir [SubscriptionStatus]
/// döner (aktif ya da değil, ikisi de KESİN bilgi).
class SubscriptionStatus {
  final bool active;
  final String? productId;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.active,
    this.productId,
    this.expiresAt,
  });

  static const SubscriptionStatus inactive = SubscriptionStatus(active: false);
}

class SubscriptionService {
  /// [uid] Firebase Auth uid — abonelik HESAP bazlı olduğu için (bkz.
  /// billing_constants.dart dosya başı) her zaman bununla sorgulanır, site
  /// id'siyle DEĞİL. Giriş yapılmamışsa çağıran taraf (AppState) bu metodu
  /// hiç çağırmamalı.
  static Future<SubscriptionStatus?> fetchStatus(String uid) async {
    if (!HostingConfig.isConfigured) return null;
    http.Response res;
    try {
      res = await http.get(
        Uri.parse('${HostingConfig.baseUrl}/api/subscription-status?uid=$uid'),
      );
    } catch (_) {
      // İnternet yok — GÜVENLİ TARAF: bilinmiyor, mevcut yerel durumu koru.
      return null;
    }
    // 06.09.2026'daki AYNI desen — bkz. server_time_service.dart.
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode != 200) {
      // Sunucu hatası — AYNI gerekçe: mevcut yerel durumu koru.
      return null;
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['active'] != true) {
        return SubscriptionStatus.inactive;
      }
      return SubscriptionStatus(
        active: true,
        productId: data['productId'] as String?,
        expiresAt: data['expiryAt'] != null
            ? DateTime.tryParse(data['expiryAt'] as String)
            : null,
      );
    } catch (_) {
      // Beklenmeyen bir yanıt formatı — AYNI gerekçe: dokunma.
      return null;
    }
  }
}
