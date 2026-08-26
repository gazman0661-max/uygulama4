import 'dart:async';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/site_project.dart';
import '../services/domain_service.dart';
import '../services/hosting_service.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/pill_button.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';

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

  Future<void> _connect() async {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) return;
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
      setState(() => _errorText = e.toString());
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
      await context.read<AppState>().clearProjectDomain(widget.project.id);
      setState(() {
        _connectResult = null;
        _statusResult = null;
        _domainController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'Kopyalandı ✅'))),
    );
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

  /// Kullanıcı "Yenile" butonuna bastığında: worker'a POST
  /// /api/domains/:siteId/renew atılır (bkz. AppState.renewProjectDomain),
  /// bu istek BAŞARILI olduktan sonra 1 yıllık sayaç sıfırlanmış sayılır —
  /// süre artık worker tarafında da gerçekten uygulandığı için (bkz.
  /// cloudflare/worker/src/index.mjs > serveCustomDomainSite), istek
  /// başarısız olursa (internet yoksa vb.) burada hata gösterilir ve yerel
  /// tarih DEĞİŞMEZ — aksi halde kullanıcı "uzatıldı" görüp sitesinin hâlâ
  /// erişilemez kaldığını fark etmeyebilirdi.
  Future<void> _renew() async {
    if (_renewing) return;
    setState(() => _renewing = true);
    try {
      await context.read<AppState>().renewProjectDomain(widget.project.id);
      await _scheduleRenewalReminderFromState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, 'Domain bağlantın 1 yıl daha uzatıldı ✅')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglish(context)
                ? 'Could not extend the connection: $e'
                : 'Bağlantı uzatılamadı: $e',
          ),
        ),
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
                    if (!_isConnectedNow) _buildDomainInput(cardBg, titleColor, subtleColor),
                    if (_connectResult != null) ...[
                      const SizedBox(height: 16),
                      _buildCnameCard(cardBg, titleColor, subtleColor),
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
            t(context, 'Kayıt yayılınca (genelde birkaç dakika içinde) bu sayfa otomatik güncellenir, bir şey yapmana gerek yok.'),
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
                            ? 'Your 1-year domain connection has expired. Renew it so your site keeps working at this address.'
                            : 'Domain bağlantının 1 yıllık süresi doldu. Sitenin bu adreste çalışmaya devam etmesi için yenile.')
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
