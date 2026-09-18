import 'dart:async';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/site_project.dart';
import '../services/domain_service.dart';
import '../services/hosting_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../constants/billing_constants.dart';
import '../services/billing_service.dart';
import '../widgets/pill_button.dart';
import '../widgets/domain_purchase_sheet.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';

/// "Kendi domainimi bağla" ekranı.
///
/// Akış:
///  1) Domain hiç bağlı değilse -> input + "Bağla" butonu.
///  2) Bağlama isteği atılınca -> worker'ın döndürdüğü CNAME kaydı bir
///     kopyala-yapıştır kartında gösterilir, arka planda periyodik olarak
///     [DomainService.status] ile durum sorgulanır (polling).
///  3) Durum 'active' olunca -> yeşil "✅ Bağlandı" chip'i + kaldır butonu.
///
/// Bu ekran [HostingConfig.isConfigured] false iken de açılabilir (worker
/// henüz deploy edilmemişse) — bu durumda net bir bilgi mesajı gösterir,
/// hiçbir ağ isteği atmaz.
class DomainConnectScreen extends StatefulWidget {
  final SiteProject project;
  const DomainConnectScreen({super.key, required this.project});

  @override
  State<DomainConnectScreen> createState() => _DomainConnectScreenState();
}

class _DomainConnectScreenState extends State<DomainConnectScreen> {
  final _domainController = TextEditingController();
  Timer? _pollTimer;

  bool _connecting = false;
  bool _disconnecting = false;
  bool _renewing = false;
  String? _errorText;

  DomainConnectResult? _connectResult;
  DomainStatusResult? _statusResult;

  @override
  void initState() {
    super.initState();
    // 05.09.2026 eklendi — bu ekran açıldığında, süresi çoktan dolmuş bir
    // domain paketi varsa rozetin geri gelmesini burada da tetikle (kanka
    // kararı: uygulama yeniden açılmadan da, kullanıcı bu ekranı ziyaret
    // ettiğinde durum güncellensin). bkz. AppState.revertExpiredDomainWatermarks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().revertExpiredDomainWatermarks();
    });
    final existingDomain = widget.project.customDomain;
    if (existingDomain != null && existingDomain.trim().isNotEmpty) {
      _domainController.text = existingDomain;
      _statusResult = DomainStatusResult(
        domain: existingDomain,
        status: widget.project.domainStatus ?? 'pending',
      );
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _domainController.dispose();
    super.dispose();
  }

  bool get _isConnectedNow =>
      (_statusResult?.isConnected ?? false) || (_connectResult?.status == 'active');

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final siteId = widget.project.id;
    try {
      final result = await DomainService.status(siteId: siteId);
      if (!mounted) return;
      // 05.09.2026 eklendi — worker tarafındaki günlük domainCleanupSweep
      // (bkz. cloudflare/worker/src/index.mjs), 1 yıl + 7 günlük yenileme
      // penceresini de kaçırmış bir bağlantıyı Cloudflare'dan VE D1'den
      // TAMAMEN sökebilir. Bu durumda status() artık 'not_connected' döner
      // (custom_domain NULL olduğu için) — ekran hâlâ eski 'active'/'error'
      // durumunu göstermeye devam etmesin, "hiç bağlanmamış" haline sıfırlanıp
      // AppState'teki yerel kayıt da (isPremium zaten anında düşmüştü, ama
      // customDomain/domainStatus alanları hâlâ eski değeri taşıyordu) temizlensin.
      if (result.status == 'not_connected') {
        _pollTimer?.cancel();
        await context.read<AppState>().clearProjectDomain(siteId);
        unawaited(NotificationService.instance.cancelDomainPendingReminder(siteId));
        unawaited(NotificationService.instance.cancelDomainRenewalReminder(siteId));
        setState(() {
          _connectResult = null;
          _statusResult = null;
          _domainController.clear();
        });
        if (mounted) {
          showAppPopup(
            context,
            message: isEnglish(context)
                ? 'Your domain connection was not renewed within 7 days of expiring, so it was fully removed. You can connect it again anytime.'
                : 'Domain bağlantın süresi dolduktan sonraki 7 gün içinde yenilenmediği için tamamen kaldırıldı. İstediğin zaman tekrar bağlayabilirsin.',
            icon: 'ℹ️',
          );
        }
        return;
      }
      setState(() => _statusResult = result);
      if (result.isConnected) {
        _pollTimer?.cancel();
        await context.read<AppState>().markProjectDomainStatus(
              id: siteId,
              domain: result.domain ?? _domainController.text.trim(),
              status: result.status,
            );
        // Domain doğrulanıp aktif olduğu için bekleyen "hâlâ bekliyor"
        // hatırlatmasına artık gerek yok.
        unawaited(NotificationService.instance.cancelDomainPendingReminder(siteId));
        await _scheduleRenewalReminderFromState();
      } else if (result.isError) {
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Sessiz geç — bir sonraki polling turunda tekrar dener.
    }
  }

  /// 05.09.2026 eklendi — "Kendi domainimi bağla" artık ÜCRETSİZ değil:
  /// worker'a hiç istek atmadan ÖNCE kProductConnectDomain'i (bkz.
  /// billing_constants.dart) satın almak GEREKİYOR. Sheet `false` dönerse
  /// (kullanıcı vazgeçti ya da mağaza hatası) worker'a HİÇ istek atılmadan
  /// sessizce geri dönülür — DomainService.connect'e hiç ulaşılmaz, yani
  /// ödeme yapmadan bir CNAME/Cloudflare kaydı asla oluşmaz.
  ///
  /// ÇİFTE ÖDEME KORUMASI: ödeme başarıyla alınır alınmaz (worker'a HENÜZ
  /// istek atmadan) AppState.markDomainConnectPurchased ile "ödendi"
  /// bilgisi hemen persist edilir. Bu sayede DomainService.connect
  /// çağrısı bir ağ hatasıyla başarısız olursa (ya da kullanıcı bu
  /// aradayken uygulamayı kapatırsa), "Bağla"ya bir sonraki basışta
  /// AppState.hasPendingDomainConnectPurchase true döndüğü için satın
  /// alma sheet'i TEKRAR AÇILMAZ — doğrudan bağlanma tekrar denenir,
  /// kullanıcı ikinci kez ücret ödemez (bkz.
  /// SiteProject.domainConnectPurchasePending dokümantasyonu). Bu hak,
  /// ancak DomainService.connect worker'a GERÇEKTEN ulaşıp
  /// AppState.markProjectDomainStatus çağrıldığında "tüketilmiş" sayılır.
  Future<void> _connect() async {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) return;
    final appState = context.read<AppState>();

    // 16.09.2026 eklendi (kanka isteği — "domainQuota kullanılmıyor" fix'i).
    // Hesabın aktif bir aboneliği VE boş bir domain kota slotu varsa (ya da
    // bu proje zaten o kotaya atanmışsa — bkz. AppState.canConnectDomainViaSubscription),
    // ödeme sheet'i HİÇ AÇILMADAN doğrudan bağlanılır. assignDomainQuota
    // false dönerse (yarış durumu: kontrol ile atama arasında kota doldu)
    // aşağıdaki normal ücretli akışa sessizce düşülür.
    var skipPaywall = false;
    if (appState.canConnectDomainViaSubscription(widget.project)) {
      skipPaywall = await appState.assignDomainQuota(widget.project.id);
      if (!mounted) return;
    }

    if (!skipPaywall && !appState.hasPendingDomainConnectPurchase(widget.project.id)) {
      final purchased = await showDomainPurchaseSheet(context, project: widget.project);
      if (!purchased || !mounted) return;
      await appState.markDomainConnectPurchased(widget.project.id);
      if (!mounted) return;
    }
    setState(() {
      _connecting = true;
      _errorText = null;
    });
    try {
      final result = await DomainService.connect(siteId: widget.project.id, domain: domain);
      if (!mounted) return;
      setState(() {
        _connectResult = result;
        _statusResult = DomainStatusResult(domain: result.domain, status: result.status);
      });
      await context.read<AppState>().markProjectDomainStatus(
            id: widget.project.id,
            domain: result.domain,
            status: result.status,
          );
      if (result.status != 'active') {
        // Kullanıcı ekrandan çıkıp DNS kaydını eklemeyi unutabilir — birkaç
        // gün sonra hâlâ doğrulanmadıysa bir hatırlatma bildirimi kur.
        unawaited(NotificationService.instance.scheduleDomainPendingReminder(
          projectId: widget.project.id,
          domain: result.domain,
        ));
      } else {
        // Nadiren connect() doğrudan 'active' dönebilir — bu durumda da
        // 1 yıllık yenileme hatırlatmasını hemen kur.
        await _scheduleRenewalReminderFromState();
      }
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = t(context, e.toString()));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _disconnecting = true);
    try {
      await DomainService.disconnect(siteId: widget.project.id);
      _pollTimer?.cancel();
      unawaited(NotificationService.instance.cancelDomainPendingReminder(widget.project.id));
      unawaited(NotificationService.instance.cancelDomainRenewalReminder(widget.project.id));
      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.clearProjectDomain(widget.project.id);
      // 16.09.2026 eklendi — bu domain abonelik kotasıyla ÜCRETSİZ
      // bağlanmıştı ise, kullanıcı kendi isteğiyle bağlantıyı kaldırınca
      // slotu da BOŞALTMALIYIZ (yoksa başka bir siteye domain bağlayamaz
      // kalır) — disconnect zaten yukarıda yapıldığı için alsoDisconnect:
      // false (tekrar sökmeye gerek yok, sadece kota bayrağını temizle).
      if (widget.project.domainViaSubscription) {
        unawaited(appState.unassignDomainQuota(widget.project.id, alsoDisconnect: false));
      }
      setState(() {
        _connectResult = null;
        _statusResult = null;
        _domainController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = t(context, e.toString()));
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showAppPopup(context, message: t(context, 'Kopyalandı ✅'), icon: '✅');
  }

  /// AppState'teki GÜNCEL proje kaydından (domainConnectedAt/domainExpiresAt
  /// az önce set edildi) 1 yıllık yenileme hatırlatma bildirimlerini kurar.
  /// markProjectDomainStatus/renewProjectDomain her ikisi de senkron olarak
  /// notifyListeners() çağırdığı için buradan hemen okumak güvenli.
  Future<void> _scheduleRenewalReminderFromState() async {
    if (!mounted) return;
    final projects = context.read<AppState>().projects;
    final idx = projects.indexWhere((p) => p.id == widget.project.id);
    final live = idx == -1 ? null : projects[idx];
    final expiresAt = live?.domainExpiresAt;
    final domain = live?.customDomain;
    if (expiresAt == null || domain == null) return;
    await NotificationService.instance.scheduleDomainRenewalReminder(
      projectId: widget.project.id,
      domain: domain,
      expiresAt: expiresAt,
    );
  }

  /// Kullanıcı "Yenile" butonuna bastığında: 05.09.2026 GÜNCELLENDİ (kanka
  /// kararı) — artık ÜCRETSİZ değil. _connect'teki ÇİFTE ÖDEME KORUMASI
  /// deseninin AYNISI: `hasPendingDomainRenewPurchase` false ise ÖNCE
  /// showDomainPurchaseSheet(isRenewal:true) açılır, `true` dönerse
  /// markDomainRenewPurchased ile ödeme HEMEN persist edilir, ANCAK ondan
  /// SONRA AppState.renewProjectDomain çağrılıp worker'a POST
  /// /api/domains/:siteId/renew atılır (bkz. AppState.renewProjectDomain).
  /// Bu istek BAŞARILI olduktan sonra 1 yıllık sayaç sıfırlanmış sayılır —
  /// süre artık worker tarafında da gerçekten uygulandığı için (bkz.
  /// cloudflare/worker/src/index.mjs > serveCustomDomainSite), istek
  /// başarısız olursa (internet yoksa vb.) burada hata gösterilir ve yerel
  /// tarih DEĞİŞMEZ — aksi halde kullanıcı "uzatıldı" görüp sitesinin hâlâ
  /// erişilemez kaldığını fark etmeyebilirdi. Bu durumda ödeme KAYBOLMAZ:
  /// domainRenewPurchasePending true kalır, bir sonraki "Uzat" denemesinde
  /// satın alma sheet'i TEKRAR AÇILMAZ, doğrudan renew tekrar denenir.
  Future<void> _renew() async {
    if (_renewing) return;
    final appState = context.read<AppState>();

    // 17.09.2026 eklendi (kanka isteği — "yenileme de kota kontrolü
    // yapmalı" fix'i). _connect'teki AYNI mantık: hesabın aktif bir
    // aboneliği VE bu proje zaten o kotaya atanmışsa (domainViaSubscription)
    // YA DA hesabın boş bir domain slotu varsa, ödeme sheet'i HİÇ
    // AÇILMADAN doğrudan yenilenir. Öncesinde bu kontrol eksikti: kota
    // dahilinde ücretsiz bağlanan bir domain, 1 yıl sonra yenilenirken
    // yine de kProductConnectDomain ile parayla ödetiliyordu — abonelik
    // "domain dahil" vaadini bir yıl sonra bozan bir açıktı. assignDomainQuota
    // false dönerse (yarış durumu: kontrol ile atama arasında kota doldu,
    // ya da domainViaSubscription artık false) aşağıdaki normal ücretli
    // akışa sessizce düşülür.
    var skipPaywall = false;
    if (appState.canConnectDomainViaSubscription(widget.project)) {
      skipPaywall = await appState.assignDomainQuota(widget.project.id);
      if (!mounted) return;
    }

    if (!skipPaywall && !appState.hasPendingDomainRenewPurchase(widget.project.id)) {
      final purchased = await showDomainPurchaseSheet(
        context,
        project: widget.project,
        isRenewal: true,
      );
      if (!purchased || !mounted) return;
      await appState.markDomainRenewPurchased(widget.project.id);
      if (!mounted) return;
    }
    setState(() => _renewing = true);
    try {
      await context.read<AppState>().renewProjectDomain(widget.project.id);
      await _scheduleRenewalReminderFromState();
      if (!mounted) return;
      showAppPopup(context, message: t(context, 'Domain bağlantın 1 yıl daha uzatıldı ✅'), icon: '✅');
    } catch (e) {
      if (!mounted) return;
      showAppPopup(
        context,
        message: isEnglish(context)
            ? 'Could not extend the connection: $e'
            : 'Bağlantı uzatılamadı: $e',
        icon: '⚠️',
      );
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final isDark = context.watch<ThemeController>().isDark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkBubbleBg : AppColors.lightBubbleBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtleColor = (isDark ? Colors.white : Colors.black).withOpacity(0.55);
    // Domain bağlama 1 yıl süreli olduğu için kalan gün/bitiş bilgisini
    // AppState'teki GÜNCEL proje kaydından okuyoruz (widget.project sadece
    // ekran ilk açıldığındaki anlık kopya — 1 yıllık sayaç ilerledikçe
    // veya "Yenile" sonrası burada güncel kalması lazım).
    final liveProjects = context.watch<AppState>().projects;
    final liveIdx = liveProjects.indexWhere((p) => p.id == widget.project.id);
    final liveProject = liveIdx == -1 ? widget.project : liveProjects[liveIdx];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          t(context, 'Kendi Domainimi Bağla'),
          style: TextStyle(
            color: titleColor,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
      // AppConfig.domainConnectEnabled: worker'a hiç istek atmadan, buton
      // tıklanır tıklanmaz "şu an aktif değil" ekranını gösterir (bkz.
      // app_config.dart). HostingConfig.isConfigured ayrıca kontrol edilir
      // çünkü o worker'ın hiç deploy edilmediği durumu (baseUrl boş)
      // kapsıyor — iki kontrol farklı şeyleri koruyor, biri diğerinin
      // yerine geçmiyor.
      body: (!AppConfig.domainConnectEnabled || !HostingConfig.isConfigured)
          ? _buildNotConfigured(subtleColor)
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isConnectedNow) ...[
                      _buildEmailVerificationNotice(cardBg, subtleColor),
                      const SizedBox(height: 12),
                      _buildDomainInput(cardBg, titleColor, subtleColor),
                    ],
                    if (_connectResult != null) ...[
                      const SizedBox(height: 16),
                      _buildCnameCard(cardBg, titleColor, subtleColor),
                      const SizedBox(height: 12),
                      _buildProviderGuides(cardBg, titleColor, subtleColor),
                    ],
                    if (_statusResult != null) ...[
                      const SizedBox(height: 16),
                      _buildStatusChip(cardBg, titleColor, subtleColor, liveProject),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotConfigured(Color subtleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 44, color: subtleColor),
            const SizedBox(height: 12),
            Text(
              t(context, 'Kendi Domainimi Bağla'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtleColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'Bu özellik şu an aktif değil.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text(
              t(context, 'Siten şu anda kendi ücretsiz alt alan adından yayında kalmaya devam ediyor.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 06.09.2026 eklendi (kanka isteği) — domain bağlama destek taleplerinin
  /// büyük kısmı burdan geliyor: kullanıcı domaini YENİ aldıysa, kayıt
  /// firmasının attığı doğrulama mailini onaylamadan CNAME'i doğru girse
  /// bile domain çalışmaz (ICANN kuralı — 15 gün içinde onaylanmazsa domain
  /// askıya bile alınabilir). Bu ekranda hiçbir teknik kontrolümüz yok
  /// (kullanıcının mail kutusuna erişimimiz yok), o yüzden sadece UYARIYORUZ.
  Widget _buildEmailVerificationNotice(Color cardBg, Color subtleColor) {
    final amber = Colors.amber.shade600;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                context,
                'Domainini yeni aldıysan önce şunu kontrol et: kayıt firmasının (Natro, GoDaddy vb.) sana attığı "e-posta doğrulama / kimlik doğrulama" mailini onayladın mı? Onaylamazsan domain askıya alınır ve CNAME\'i doğru girsen bile hiçbir şekilde çalışmaz. Bu, MySitora dışında, tamamen domain firmasının/ICANN\'ın kuralı.',
              ),
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainInput(Color cardBg, Color titleColor, Color subtleColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'Kendi domainini bu siteye bağla'),
            style: TextStyle(
              color: titleColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t(context, 'Örn: ahmetkuafor.com — domain sağlayıcının panelinde bir CNAME kaydı ekleyeceksin, başka bir şey gerekmiyor.'),
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 6),
          // 05.09.2026 eklendi — bu artık ücretsiz bir işlem değil (bkz.
          // widgets/domain_purchase_sheet.dart); kullanıcı "Bağla"ya
          // basmadan ÖNCE burada 1 yıllık/tek seferlik olduğunu ve
          // (biliniyorsa) fiyatını görsün, mağaza ekranında sürpriz olmasın.
          Text(
            '🔒 ${t(context, "1 yıllık, tek seferlik satın alma")} '
            '(${BillingService.instance.products[kProductConnectDomain]?.price ?? '—'})',
            style: TextStyle(
              color: AppColors.accentBlue,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _domainController,
            enableInteractiveSelection: true,
            keyboardType: TextInputType.url,
            style: TextStyle(color: titleColor, fontFamily: 'monospace', fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'ahmetkuafor.com',
              hintStyle: TextStyle(color: subtleColor, fontFamily: 'monospace'),
              filled: true,
              fillColor: subtleColor.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: _connecting ? 'Bağlanıyor…' : 'Bağla',
              borderColor: AppColors.accentBlue,
              textColor: AppColors.accentBlue,
              filled: true,
              height: 44,
              onTap: _connecting ? null : _connect,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCnameCard(Color cardBg, Color titleColor, Color subtleColor) {
    final result = _connectResult!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'Domain sağlayıcının panelinde şu CNAME kaydını ekle:'),
            style: TextStyle(
              color: titleColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          _recordRow(t(context, 'Ad (Name/Host)'), result.cnameRecord.name, titleColor, subtleColor),
          const SizedBox(height: 8),
          _recordRow(t(context, 'Hedef (Value/Target)'), result.cnameRecord.value, titleColor, subtleColor),
          if (result.apexWarning) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentOrange.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEnglish(context)
                          ? 'Root domains (${result.domain}) cannot use a CNAME record. Most providers instead recommend connecting ${result.suggestedDomain} and redirecting the root domain to it.'
                          : '${result.domain} gibi kök (apex) domainlere CNAME eklenemez. Bunun yerine ${result.suggestedDomain} adresini bağlayıp kök domaini ona yönlendirmen önerilir.',
                      style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result.sslValidationRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              t(context, 'SSL doğrulaması için ek kayıt:'),
              style: TextStyle(
                color: titleColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 8),
            for (final r in result.sslValidationRecords) ...[
              _recordRow('${r.type} — Ad', r.name, titleColor, subtleColor),
              const SizedBox(height: 6),
              _recordRow('${r.type} — Değer', r.value, titleColor, subtleColor),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _recordRow(String label, String value, Color titleColor, Color subtleColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11)),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  color: titleColor,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, size: 18, color: subtleColor),
          tooltip: t(context, 'Kopyala'),
          onPressed: () => _copy(value),
        ),
      ],
    );
  }

  /// 06.09.2026 eklendi (kanka isteği) — domain bağlamayı hiç bilmeyen
  /// kullanıcılardan destek talebi çok geldiği için, en yaygın domain
  /// sağlayıcılarına özel kısa "nereye tıkla" rehberi. Yukarıdaki CNAME
  /// kartındaki Ad/Hedef değerlerine referans verir, tekrar yazmaz.
  Widget _buildProviderGuides(Color cardBg, Color titleColor, Color subtleColor) {
    final providers = <(String, List<String>, String)>[
      (
        'Natro',
        [
          t(context, '"Hesabım" → "Domain Yönetimi" → domainine tıkla'),
          t(context, '"DNS Ayarları" / "DNS Yönetimi" sekmesine geç'),
          t(context, '"Yeni Kayıt Ekle" → Tür: CNAME seç'),
          t(context, 'Yukarıdaki Ad ve Hedef değerlerini ilgili kutulara yapıştır, kaydet'),
        ],
        'https://www.natro.com/hemendestek/bilgibankasi/natrositede-olusturdugum-web-sitemin-dns-yonetimini-nereden-gorebilirim-',
      ),
      (
        'İsimtescil',
        [
          t(context, '"Domainlerim" → domainine tıkla → "DNS Yönetimi"'),
          t(context, '"Kayıt Ekle" → Tür: CNAME seç'),
          t(context, 'Yukarıdaki Ad ve Hedef değerlerini gir, "Ekle"ye bas'),
        ],
        'https://www.isimtescil.net/bilgibankasi/domain-dns-yonlendirme',
      ),
      (
        'Turhost',
        [
          t(context, '"Hizmetlerim" → "Domainler" → domainine tıkla'),
          t(context, '"DNS Yönetimi" → "Kayıt Ekle" → CNAME seç'),
          t(context, 'Yukarıdaki Ad ve Hedef değerlerini yapıştır, kaydet'),
        ],
        'https://destek.turhost.com/dns-kayitlari-yonetimi/',
      ),
      (
        'GoDaddy',
        [
          t(context, '"My Products" → domainin yanındaki "DNS" butonuna tıkla'),
          t(context, '"Add New Record" → Type: CNAME seç'),
          t(context, 'Yukarıdaki Ad değerini "Name/Host", Hedef değerini "Value" alanına yapıştır, kaydet'),
        ],
        'https://www.godaddy.com/help/add-a-cname-record-19236',
      ),
      (
        'Namecheap',
        [
          t(context, '"Domain List" → domainin yanındaki "Manage" butonuna tıkla'),
          t(context, '"Advanced DNS" sekmesine geç → "Add New Record" → CNAME seç'),
          t(context, 'Yukarıdaki Ad ve Hedef değerlerini gir, yeşil onay işaretine tıkla'),
        ],
        'https://www.namecheap.com/support/knowledgebase/article.aspx/9646/2237/how-to-create-a-cname-record-for-your-domain/',
      ),
    ];

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: subtleColor,
          collapsedIconColor: subtleColor,
          title: Text(
            t(context, 'Domainin nereden alındı? Adım adım göster'),
            style: TextStyle(
              color: titleColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          children: [
            for (final (name, steps, helpUrl) in providers) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  style: TextStyle(color: titleColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 4),
              for (final step in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Text(
                    '• $step',
                    style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => unawaited(
                  launchUrl(Uri.parse(helpUrl), mode: LaunchMode.externalApplication),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new, size: 13, color: subtleColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isEnglish(context)
                              ? 'Open $name\'s official help page'
                              : 'Resmi yardım sayfasını aç ($name)',
                          style: TextStyle(
                            color: subtleColor,
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Text(
              t(context, 'Sağlayıcın listede yok mu? Panelinde "DNS Ayarları" veya "DNS Yönetimi" bölümünü ara, adı ve mantığı hep aynı.'),
              style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    Color cardBg,
    Color titleColor,
    Color subtleColor,
    SiteProject liveProject,
  ) {
    final status = _statusResult!.status;
    final connected = status == 'active';
    final errored = status == 'error';
    final color = connected
        ? AppColors.accentGreenLink
        : errored
            ? AppColors.danger
            : AppColors.accentOrange;
    final label = connected
        ? t(context, '✅ Bağlandı')
        : errored
            ? t(context, '⚠️ Doğrulama başarısız')
            : t(context, '⏳ DNS kaydı bekleniyor…');

    // --- 1 yıllık bağlantı süresi göstergesi (sadece bağlıyken anlamlı) ---
    final daysRemaining = connected ? liveProject.domainDaysRemaining : null;
    final isExpired = connected && liveProject.isDomainExpired;
    // Süresi dolmuşsa ya da dolmasına 30 günden az kaldıysa "Yenile"yi
    // öne çıkarıyoruz (renk uyarı rengine döner).
    final isNearExpiry =
        !isExpired && daysRemaining != null && daysRemaining <= 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!connected && !errored)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                ),
              if (!connected && !errored) const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        if (_statusResult!.domain != null) ...[
          const SizedBox(height: 6),
          Text(
            _statusResult!.domain!,
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 12),
          ),
        ],
        if (!connected && !errored) ...[
          const SizedBox(height: 6),
          Text(
            t(context, 'Kayıt yayılınca (genelde birkaç dakika içinde, bazı sağlayıcılarda 24 saate kadar sürebilir) bu sayfa otomatik güncellenir, bir şey yapmana gerek yok. Uygulamayı kapatıp daha sonra tekrar açabilirsin.'),
            style: TextStyle(color: subtleColor, fontFamily: 'monospace', fontSize: 11.5),
          ),
        ],
        if (connected && daysRemaining != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isExpired || isNearExpiry
                      ? AppColors.accentOrange
                      : subtleColor)
                  .withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 16,
                  color: isExpired || isNearExpiry ? AppColors.accentOrange : subtleColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpired
                        ? (isEnglish(context)
                            ? 'Your 1-year domain connection has expired. Your site stopped working at this address, and Premium features (like the Request Inbox) are locked again — renew to restore both.'
                            : 'Domain bağlantının 1 yıllık süresi doldu. Siten bu adreste çalışmaz oldu, Premium özellikler de (Talep Kutusu gibi) tekrar kilitlendi — ikisini de geri açmak için bağlantını uzat.')
                        : (isEnglish(context)
                            ? 'Domain connection is valid for 1 year — $daysRemaining days remaining.'
                            : 'Domain bağlantısı 1 yıl süreyle geçerli — $daysRemaining gün kaldı.'),
                    style: TextStyle(
                      color: isExpired || isNearExpiry ? AppColors.accentOrange : subtleColor,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpired || isNearExpiry) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: PillButton(
                label: t(context, _renewing ? 'Uzatılıyor…' : 'Bağlantıyı 1 Yıl Uzat'),
                borderColor: AppColors.accentGreenLink,
                textColor: AppColors.accentGreenLink,
                filled: true,
                height: 40,
                onTap: _renewing ? null : _renew,
              ),
            ),
          ],
        ],
        const SizedBox(height: 14),
        PillButton(
          label: _disconnecting ? 'Kaldırılıyor…' : 'Domaini Kaldır',
          borderColor: AppColors.danger,
          textColor: AppColors.danger,
          height: 40,
          onTap: _disconnecting ? null : _disconnect,
        ),
      ],
    );
  }
}
