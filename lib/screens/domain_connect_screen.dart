import 'dart:async';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/site_project.dart';
import '../services/domain_input.dart';
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
  bool _checking = false;
  String? _errorText;
  DomainCheckResult? _checkResult;

  DomainConnectResult? _connectResult;
  DomainStatusResult? _statusResult;

  @override
  void initState() {
    super.initState();
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
        unawaited(NotificationService.instance.cancelDomainPendingReminder(siteId));
        await _scheduleRenewalReminderFromState();
      } else if (result.isError) {
        _pollTimer?.cancel();
      }
    } catch (_) {
    }
  }

  Future<void> _connect() async {
    final domain = normalizeDomainInput(_domainController.text);
    if (domain.isEmpty) return;
    _domainController.text = domain;
    final appState = context.read<AppState>();

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
      final result = await DomainService.connect(siteId: widget.project.id, domain: domain, ownerToken: widget.project.ownerToken);
      if (!mounted) return;
      setState(() {
        _connectResult = result;
        _checkResult = null;
        _statusResult = DomainStatusResult(domain: result.domain, status: result.status);
      });
      await context.read<AppState>().markProjectDomainStatus(
            id: widget.project.id,
            domain: result.domain,
            status: result.status,
          );
      if (result.status != 'active') {
        unawaited(NotificationService.instance.scheduleDomainPendingReminder(
          projectId: widget.project.id,
          domain: result.domain,
        ));
      } else {
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
      await DomainService.disconnect(siteId: widget.project.id, ownerToken: widget.project.ownerToken);
      _pollTimer?.cancel();
      unawaited(NotificationService.instance.cancelDomainPendingReminder(widget.project.id));
      unawaited(NotificationService.instance.cancelDomainRenewalReminder(widget.project.id));
      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.clearProjectDomain(widget.project.id);
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

  String _tx(String tr, String en) => isEnglish(context) ? en : tr;

  Future<void> _runCheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _errorText = null;
    });
    try {
      final result = await DomainService.check(siteId: widget.project.id);
      if (!mounted) return;
      setState(() => _checkResult = result);
      if (result.isActive) await _refreshStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = t(context, e.toString()));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  (String, Color) _checkMessage(DomainCheckResult r) {
    final found = r.found.isEmpty ? '—' : r.found.first;
    final expected = r.expected ?? '—';
    switch (r.code) {
      case 'active':
        return (_tx('Domainin bağlandı ✅', 'Your domain is connected ✅'), AppColors.accentGreenLink);
      case 'waiting_ssl':
        return (
          _tx(
            'CNAME kaydın doğru ✅ Güvenlik sertifikası (SSL) hazırlanıyor, birkaç dakika sürebilir. Bu sayfa kendiliğinden güncellenir.',
            'Your CNAME record is correct ✅ The security certificate (SSL) is being prepared, this can take a few minutes. This page updates by itself.',
          ),
          AppColors.accentOrange
        );
      case 'wrong_target':
        return (
          _tx(
            'CNAME kaydı var ama yanlış adrese gidiyor.\nŞu an: $found\nOlması gereken: $expected\nKaydı yukarıdaki Hedef değerle değiştir.',
            'A CNAME record exists but it points to the wrong address.\nCurrently: $found\nShould be: $expected\nReplace it with the Target value above.',
          ),
          AppColors.danger
        );
      case 'has_a_record':
        return (
          _tx(
            'Bu domain için CNAME değil, başka bir kayıt (A/AAAA) görünüyor. Eski A kaydını sil ve yukarıdaki CNAME kaydını ekle. Cloudflare kullanıyorsan kaydın yanındaki turuncu bulutu gri (DNS only) yap.',
            'This domain has a different record (A/AAAA) instead of a CNAME. Delete the old A record and add the CNAME record above. If you use Cloudflare, switch the orange cloud next to the record to grey (DNS only).',
          ),
          AppColors.danger
        );
      case 'no_record':
        return (
          _tx(
            'Bu domain için henüz hiçbir kayıt görünmüyor. Domain sağlayıcının panelinde yukarıdaki CNAME kaydını ekleyip kaydettin mi? Ekledikten sonra birkaç dakika bekleyip tekrar kontrol et.',
            'No record is visible for this domain yet. Did you add and save the CNAME record above in your domain provider\'s panel? After adding it, wait a few minutes and check again.',
          ),
          AppColors.accentOrange
        );
      case 'apex_not_supported':
        return (
          _tx(
            'Kök domaine (örn. ahmetkuafor.com) CNAME eklenemez. www ile başlayan adresi bağla; kök domaini ise sağlayıcının "yönlendirme" özelliğiyle www adresine yönlendir.',
            'A CNAME cannot be added to a root domain (e.g. ahmetkuafor.com). Connect the www address instead and use your provider\'s "redirect" feature to send the root domain to it.',
          ),
          AppColors.danger
        );
      case 'verification_failed':
        return (
          _tx(
            'Doğrulama başarısız oldu. CNAME kaydını kontrol et; düzelmezse domaini kaldırıp tekrar bağlamayı dene.',
            'Verification failed. Check your CNAME record; if it doesn\'t help, remove the domain and connect it again.',
          ),
          AppColors.danger
        );
      case 'lookup_failed':
        return (
          _tx('Şu an DNS kontrol edilemedi, biraz sonra tekrar dene.', 'DNS could not be checked right now, please try again shortly.'),
          AppColors.accentOrange
        );
      default:
        return (
          _tx('Durum şu an anlaşılamadı, biraz sonra tekrar dene.', 'The status could not be determined, please try again shortly.'),
          AppColors.accentOrange
        );
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showAppPopup(context, message: t(context, 'Kopyalandı ✅'), icon: '✅');
  }

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

  Future<void> _renew() async {
    if (_renewing) return;
    final appState = context.read<AppState>();

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
          Text(
            '🔒 ${t(context, "1 yıllık, tek seferlik satın alma + 1 ek site yayın hakkı")} '
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
            onChanged: (_) => setState(() {}),
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
          if (isApexDomainInput(cleanDomainInput(_domainController.text))) ...[
            const SizedBox(height: 8),
            Text(
              _tx(
                '${cleanDomainInput(_domainController.text)} yerine www.${cleanDomainInput(_domainController.text)} bağlanacak. Kök domain CNAME kabul etmez. İstersen sağlayıcının panelinde kök domaini www adresine yönlendirebilirsin.',
                'www.${cleanDomainInput(_domainController.text)} will be connected instead of ${cleanDomainInput(_domainController.text)}. Root domains don\'t accept a CNAME. If you like, you can redirect the root domain to the www address in your provider\'s panel.',
              ),
              style: TextStyle(color: AppColors.accentOrange, fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
            ),
          ],
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

  Widget _buildProviderGuides(Color cardBg, Color titleColor, Color subtleColor) {
    final providers = <(String, List<String>, String?)>[
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
      (
        'Cloudflare',
        [
          t(context, '\"DNS\" → \"Records\" sayfasını aç → \"Add record\" de'),
          t(context, 'Type: CNAME seç, Ad ve Hedef değerlerini yukarıdan yapıştır'),
          t(context, 'Proxy durumunu mutlaka gri bulut (DNS only) yap, turuncu bulut bağlantıyı bozar'),
        ],
        'https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/',
      ),
      (
        'Hostinger',
        [
          t(context, '\"Domainler\" → domainin yanındaki \"Yönet\" → \"DNS / Nameservers\" sekmesine geç'),
          t(context, '\"DNS kayıtları\" bölümünde Type: CNAME seç'),
          t(context, 'Ad ve Hedef değerlerini yukarıdan yapıştır, \"Kayıt ekle\" de'),
        ],
        null,
      ),
      (
        'Squarespace / Google Domains',
        [
          t(context, '\"Domains\" → domainine tıkla → \"DNS\" → \"DNS Settings\"'),
          t(context, '\"Add record\" → Type: CNAME seç'),
          t(context, 'Host ve Data alanlarına yukarıdaki Ad ve Hedef değerlerini yapıştır, kaydet'),
        ],
        null,
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
              if (helpUrl == null)
                const SizedBox(height: 10)
              else
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

    final daysRemaining = connected ? liveProject.domainDaysRemaining : null;
    final isExpired = connected && liveProject.isDomainExpired;
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
        if (!connected) ...[
          const SizedBox(height: 12),
          PillButton(
            label: _checking ? 'Kontrol ediliyor…' : 'Domaini kontrol et',
            borderColor: AppColors.accentBlue,
            textColor: AppColors.accentBlue,
            height: 40,
            onTap: _checking ? null : _runCheck,
          ),
          if (_checkResult != null) ...[
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final (message, msgColor) = _checkMessage(_checkResult!);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: msgColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: msgColor.withOpacity(0.4)),
                ),
                child: Text(
                  message,
                  style: TextStyle(color: msgColor, fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              );
            }),
          ],
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
