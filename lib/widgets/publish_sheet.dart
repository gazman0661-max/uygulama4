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
Future<void> showPublishSheet(
  BuildContext context, {
  required SiteProject project,
  required Map<String, String> files,
  String? ownerEmail,
  required Future<void> Function(String subdomain, String url, String? ownerToken) onPublished,
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
  final Future<void> Function(String subdomain, String url, String? ownerToken) onPublished;

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
    super.dispose();
  }

  Future<void> _publish() async {
    final desired = _subdomainController.text.trim();
    if (desired.isEmpty) return;
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
      );
      if (!mounted) return;
      await widget.onPublished(result.subdomain, result.url, result.ownerToken);
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
