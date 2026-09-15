import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/site_project.dart';
import '../services/hosting_service.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../widgets/login_gate.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import 'app_popup.dart';

/// "Yayınla" akışının bottom sheet'i.
///
/// Çağıran taraf (preview_screen.dart > _publishSite) burayı açmadan önce
/// zaten [requireLogin] ile giriş kontrolünü yapmış olmalı. SAVUNMA
/// KATMANI olarak kontrol burada da TEKRAR yapılır — girişe bağlı olması
/// gereken bu akışın ileride başka bir çağıran tarafından yanlışlıkla
/// atlanmasını önler. Zaten giriş yapılmışsa requireLogin hiçbir şey
/// göstermeden anında true döner, davranış mevcut çağıran için değişmez.
///
/// [onPublished] başarılı bir yayınlamadan sonra çağrılır; çağıran taraf
/// bunu AppState.markProjectPublished(...) için kullanır — böylece bu
/// dosya AppState'e doğrudan bağımlı olmaz, sadece bir callback alır.
/// 15.09.2026 eklendi (kanka isteği) — [onPublished]'a artık kullanıcının
/// bu sheet içinde seçtiği `leadDelivery`/`leadEmail` de geçiliyor, çağıran
/// taraf bunları SiteProject'e kalıcı yazsın diye (bkz. AppState.
/// markProjectPublished ve HostingService.publish > leadDelivery dokümanı).
Future<void> showPublishSheet(
  BuildContext context, {
  required SiteProject project,
  required Map<String, String> files,
  String? ownerEmail,
  required Future<void> Function(
    String subdomain,
    String url,
    String? ownerToken,
    String leadDelivery,
    String? leadEmail,
  ) onPublished,
}) async {
  final ok = await requireLogin(context, feature: t(context, 'Yayınlama'));
  if (!ok || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PublishSheet(
      project: project,
      files: files,
      ownerEmail: ownerEmail,
      onPublished: onPublished,
    ),
  );
}

/// Basit bir slugify: proje adını (Türkçe karakterler dahil) URL-uyumlu bir
/// alt alan adı önerisine çevirir. Worker zaten müsaitlik kontrolü yapıp
/// gerekirse benzersizleştiriyor (bkz. handlePublish) — bu sadece kullanıcıya
/// iyi bir başlangıç noktası sunmak için.
String _slugify(String input) {
  const trMap = {
    'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
  };
  var s = input;
  trMap.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'site' : s;
}

class _PublishSheet extends StatefulWidget {
  final SiteProject project;
  final Map<String, String> files;
  final String? ownerEmail;
  final Future<void> Function(
    String subdomain,
    String url,
    String? ownerToken,
    String leadDelivery,
    String? leadEmail,
  ) onPublished;

  const _PublishSheet({
    required this.project,
    required this.files,
    required this.ownerEmail,
    required this.onPublished,
  });

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  late final TextEditingController _subdomainController;
  bool _publishing = false;
  String? _error;
  PublishResult? _result;

  // 15.09.2026 eklendi (kanka isteği) — "Talepler nereye gelsin?" seçimi.
  // 'box': sadece uygulama içi Talep Kutusu (mevcut/varsayılan davranış).
  // 'email': sadece mailto (Resend YOK, ücretsiz/sınırsız — bkz.
  // HostingService.publish dokümanı). 'both': ikisi de.
  late String _leadDelivery;
  late final TextEditingController _leadEmailController;

  // Ziyaretçi sayısı (bkz. HostingService.fetchStats) — worker tarafı zaten
  // her sayfa görüntülemesinde visit_count'u artırıyordu (bkz.
  // cloudflare/worker/src/index.mjs > serveHostedSite), ama bunu GÖSTEREN
  // bir arayüz yoktu. Site zaten yayındaysa açılışta, yeni yayınlandığında
  // da hemen ardından burada sorgulanır.
  SiteStats? _stats;
  bool _loadingStats = false;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    final existing = widget.project.publishedSubdomain;
    _subdomainController = TextEditingController(
      text: existing ?? _slugify(widget.project.name),
    );
    _leadDelivery = widget.project.leadDelivery;
    _leadEmailController = TextEditingController(
      text: widget.project.leadEmail ?? widget.ownerEmail ?? '',
    );
    if (widget.project.isPublished) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });
    try {
      final stats = await HostingService.fetchStats(siteId: widget.project.id);
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      // Sessizce yutulmaz ama kritik de değil: stats kartı "—" gösterir,
      // publish/republish akışını asla engellemez.
      if (mounted) setState(() => _statsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Widget _statsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text('👁 ', style: TextStyle(fontSize: 15)),
          Expanded(
            child: Text(
              _loadingStats
                  ? t(context, 'yükleniyor…')
                  : (_stats != null
                      ? '${_stats!.visitCount} ${t(context, 'ziyaretçi')}'
                      : (_statsError != null ? t(context, 'İstatistik alınamadı') : '—')),
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _loadingStats ? null : _loadStats,
            child: Text(
              t(context, '↻ Yenile'),
              style: TextStyle(color: Colors.grey.shade400, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subdomainController.dispose();
    _leadEmailController.dispose();
    super.dispose();
  }

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _publish() async {
    final desired = _subdomainController.text.trim();
    if (desired.isEmpty) return;
    final wantsEmail = _leadDelivery == 'email' || _leadDelivery == 'both';
    final leadEmail = _leadEmailController.text.trim();
    if (wantsEmail && !_emailRe.hasMatch(leadEmail)) {
      setState(() => _error = t(context, 'Talepler için geçerli bir e-posta adresi gir.'));
      return;
    }
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final result = await HostingService.publish(
        files: widget.files,
        desiredSubdomain: desired,
        siteId: widget.project.id,
        ownerEmail: widget.ownerEmail,
        ownerUid: AuthService.instance.currentUser?.uid,
        siteName: widget.project.name,
        ownerToken: widget.project.ownerToken,
        // 06.09.2026 eklendi — bkz. HostingService.publish > lang dokümanı.
        lang: context.read<LocaleController>().isEnglish ? 'en' : 'tr',
        // 15.09.2026 eklendi — bkz. yukarıdaki _leadDelivery dokümanı.
        leadDelivery: _leadDelivery,
        leadEmail: wantsEmail ? leadEmail : null,
      );
      if (!mounted) return;
      await widget.onPublished(
        result.subdomain,
        result.url,
        result.ownerToken,
        _leadDelivery,
        // 'box' modunda daha önce girilmiş bir e-postayı SİLMEYİZ — sadece
        // kullanılmaz hale gelir, kullanıcı ileride 'email'/'both'a
        // dönerse alan yine dolu gelsin diye korunur (bkz. initState).
        wantsEmail ? leadEmail : widget.project.leadEmail,
      );
      if (!mounted) return;
      setState(() => _result = result);
      _loadStats();
      // "Mutluluk anı": site az önce başarıyla yayına alındı — Play'in
      // in-app review popup'ını burada tetikliyoruz (kendi throttle
      // kurallarımız ReviewService içinde, bkz. o dosya). Sonucu
      // beklemeye/dallanmaya gerek yok, akışı bloklamasın diye
      // unawaited bırakılıyor.
      unawaited(ReviewService.maybeRequestReview());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = t(context, e.toString()));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    showAppPopup(context, message: t(context, 'Kopyalandı ✅'), icon: '✅');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _result != null ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  /// "Talepler nereye gelsin?" seçici — bkz. [_leadDelivery] dokümanı.
  /// 15.09.2026 eklendi (kanka isteği).
  List<Widget> _buildLeadDeliveryPicker() {
    Widget option(String value, String emoji, String label) {
      final selected = _leadDelivery == value;
      return Expanded(
        child: GestureDetector(
          onTap: _publishing ? null : () => setState(() => _leadDelivery = value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentBlue.withOpacity(0.18) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.accentBlue : Colors.transparent,
                width: 1.3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade400,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final wantsEmail = _leadDelivery == 'email' || _leadDelivery == 'both';
    return [
      Text(
        t(context, 'Talepler nereye gelsin?'),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5, fontFamily: 'monospace'),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          option('box', '📥', t(context, 'Talep Kutusu')),
          option('email', '✉️', t(context, 'E-posta')),
          option('both', '🔁', t(context, 'İkisi de')),
        ],
      ),
      if (wantsEmail) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _leadEmailController,
          enabled: !_publishing,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ornek@eposta.com',
            hintStyle: TextStyle(color: Colors.grey.shade600, fontFamily: 'monospace'),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t(context, 'Ziyaretçi formu gönderdiğinde kendi mail uygulamasından bu adrese e-posta açılır — ücretsiz ve sınırsızdır.'),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'monospace'),
        ),
      ],
    ];
  }

  List<Widget> _buildForm() {
    return [
      Text(
        t(context, 'Siteyi Yayınla'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        t(context, 'Sitenin ücretsiz bir alt alan adında yayına alınacak. İstediğin adı yazabilirsin, dolu ise Sitora otomatik benzersizleştirir.'),
        style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5, fontFamily: 'monospace'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      if (widget.project.isPublished && widget.project.publishedUrl != null)
        _statsCard(),
      TextField(
        controller: _subdomainController,
        enabled: !_publishing,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
        decoration: InputDecoration(
          hintText: 'kuaforum',
          hintStyle: TextStyle(color: Colors.grey.shade600, fontFamily: 'monospace'),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      const SizedBox(height: 18),
      ..._buildLeadDeliveryPicker(),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(color: AppColors.danger, fontFamily: 'monospace', fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 18),
      PillButton(
        label: _publishing ? 'Yayınlanıyor…' : 'Yayınla',
        emoji: '🚀',
        borderColor: AppColors.accentBlue,
        textColor: AppColors.accentBlue,
        filled: true,
        height: 46,
        onTap: _publishing ? null : _publish,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _publishing ? null : () => Navigator.of(context).pop(),
        child: Text(t(context, 'Vazgeç'), style: TextStyle(color: Colors.grey.shade500)),
      ),
    ];
  }

  List<Widget> _buildSuccess() {
    final result = _result!;
    return [
      const Icon(Icons.check_circle, color: AppColors.accentGreenLink, size: 40),
      const SizedBox(height: 10),
      Text(
        t(context, 'Siten yayında! ✅'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                result.url,
                style: const TextStyle(
                  color: AppColors.accentGreenLink,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade400),
              onPressed: () => _copy(result.url),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _statsCard(),
      PillButton(
        label: t(context, 'Siteyi Aç'),
        emoji: '🌐',
        borderColor: AppColors.accentGreenLink,
        textColor: AppColors.accentGreenLink,
        filled: true,
        height: 44,
        onTap: () => launchUrl(Uri.parse(result.url), mode: LaunchMode.externalApplication),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(t(context, 'Kapat'), style: TextStyle(color: Colors.grey.shade500)),
      ),
    ];
  }
}
