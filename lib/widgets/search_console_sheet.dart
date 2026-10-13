import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_strings.dart';
import '../models/site_project.dart';
import '../services/google_verification_service.dart';
import '../services/gsc_helpers.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'app_popup.dart';
import 'gbp_setup_wizard.dart' show gbpSiteUrlFor;
import 'premium_locked_popup.dart';

/// 20.09.2026 eklendi (kanka isteği) — "Google Search Console'a Bağlan" arayüzü.
///
/// Arka uç zaten hazır: PATCH /api/sites/:id/google-verification (bkz.
/// cloudflare/worker/src/index.mjs > handleSetGoogleVerification) meta etiketini
/// yayınlanan sitenin HER .html sayfasına istek anında enjekte eder — bu yüzden
/// kullanıcı kodu kaydettikten sonra siteyi YENİDEN YAYINLAMAK ZORUNDA DEĞİL
/// (önbellek yüzünden birkaç dakika sürebilir).
///
/// Neden form alanı değil de Projelerim kartından açılan bir sheet: kod sitenin
/// içeriğine (formData/HTML) hiç yazılmıyor, sunucuda ayrı tutuluyor; ayrıca
/// site YAYINDA olmadan (worker'da kaydı yokken) kaydedilemez. Bu yüzden
/// 32 forma dokunmadan, sadece yayındaki projelerin kartında gösteriliyor.
///
/// Kilit: kaydetme SADECE premium sitelerde (SiteProject.isPremium — diğer
/// premium kilitlerle AYNI merkezi kontrol; worker da 402 ile ayrıca doğrular).
/// Bağlantıyı KESMEK her zaman serbest (paketi bitmiş sitede de).
Future<void> showSearchConsoleSheet(BuildContext context, SiteProject project) async {
  final en = isEnglish(context);
  if (!project.isPublished) {
    await showAppPopup(
      context,
      message: en
          ? 'Publish your site first — Google can only verify a live site.'
          : 'Önce siteni yayınla — Google sadece yayında olan siteyi doğrulayabilir.',
      icon: 'ℹ️',
    );
    return;
  }
  // Free planda kilitli (kodu yoksa); kodu olup paketi bitmiş site kesmek için açılabilir.
  if (!project.isPremium && project.googleVerificationCode == null) {
    await showPremiumLockedPopup(
      context,
      message: en
          ? 'Connecting to Google Search Console is available with a subscription or a custom-domain package. It is locked on the free plan.'
          : 'Google Search Console bağlantısı abonelik veya özel domain paketinde açılır. Ücretsiz planda kilitlidir.',
    );
    return;
  }
  final appState = context.read<AppState>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SearchConsoleSheet(appState: appState, projectId: project.id),
    ),
  );
}

class _SearchConsoleSheet extends StatefulWidget {
  const _SearchConsoleSheet({required this.appState, required this.projectId});

  final AppState appState;
  final String projectId;

  @override
  State<_SearchConsoleSheet> createState() => _SearchConsoleSheetState();
}

class _SearchConsoleSheetState extends State<_SearchConsoleSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _busy = false;
  bool _copiedUrl = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  SiteProject? get _project {
    final i = widget.appState.projects.indexWhere((p) => p.id == widget.projectId);
    return i == -1 ? null : widget.appState.projects[i];
  }

  String _s(String tr, String en) => isEnglish(context) ? en : tr;

  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      await showAppPopup(
        context,
        message: _s(
          'Bağlantı açılamadı. Tarayıcından search.google.com/search-console adresini aç.',
          'Could not open the link. Open search.google.com/search-console in your browser.',
        ),
        icon: '⚠️',
      );
    }
  }

  Future<void> _copyUrl(String url) async {
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() => _copiedUrl = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() => _copiedUrl = false);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      final extracted = gscExtractCode(text);
      _codeCtrl.text = extracted ?? text.trim();
      _error = null;
      _success = null;
    });
  }

  Future<void> _save() async {
    final raw = _codeCtrl.text;
    if (raw.trim().isEmpty) {
      setState(() {
        _error = _s(
          'Önce Search Console\'un verdiği doğrulama kodunu yapıştır.',
          'First paste the verification code Search Console gave you.',
        );
        _success = null;
      });
      return;
    }
    final code = gscExtractCode(raw);
    if (code == null) {
      setState(() {
        _error = _s(
          'Bu geçerli bir doğrulama kodu gibi görünmüyor. Search Console\'daki HTML etiketinden sadece content="..." içindeki değeri (veya tüm etiketi) yapıştır.',
          'This doesn\'t look like a valid verification code. Paste only the value inside content="..." from the Search Console HTML tag (or the whole tag).',
        );
        _success = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.appState.setGoogleVerification(widget.projectId, code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeCtrl.text = code;
        _success = _s(
          'Kaydedildi. Birkaç dakika içinde sitende aktif olur — şimdi Search Console\'a dönüp "Doğrula"ya bas. Siteyi yeniden yayınlamana gerek yok.',
          'Saved. It goes live on your site within a few minutes — now go back to Search Console and press "Verify". No need to republish.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is GoogleVerificationException
            ? e.message
            : _s('Kaydedilemedi, bağlantını kontrol edip tekrar dene.',
                'Could not save — check your connection and try again.');
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.appState.setGoogleVerification(widget.projectId, null);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeCtrl.clear();
        _success = _s(
          'Bağlantı kesildi; doğrulama etiketi siteden kalktı.',
          'Disconnected; the verification tag was removed from your site.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is GoogleVerificationException
            ? e.message
            : _s('İşlem yapılamadı, tekrar dene.', 'Could not complete, try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final project = _project;
        if (project == null) {
          return const SizedBox(height: 120);
        }
        final connected = project.googleVerificationCode != null;
        final locked = !project.isPremium;
        final siteUrl = gbpSiteUrlFor(project);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _s('Google Search Console\'a Bağlan', 'Connect to Google Search Console'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _s(
                    'Sitenin gerçek sahibi olduğunu Google\'a kanıtlarsın; hangi aramalarda göründüğünü izler ve yeni sayfaların taranmasını isteyebilirsin. Sitenin Google\'da ÇIKMASI için şart değildir (sitemap zaten otomatik).',
                    'You prove to Google that you own the site; you can track which searches it appears in and request faster crawling of new pages. It is NOT required for your site to appear on Google (the sitemap is already automatic).',
                  ),
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (connected) _statusBox(
                  color: locked ? AppColors.accentOrange : AppColors.accentGreenLink,
                  text: locked
                      ? _s(
                          'Kod kayıtlı ama paketin bittiği için şu an sitede YAYINDA DEĞİL. Paketi yenilersen tekrar devreye girer; istersen bağlantıyı kesebilirsin.',
                          'A code is saved but it is NOT live right now because your plan expired. It resumes when you renew; you can also disconnect it.',
                        )
                      : _s('Bağlı — doğrulama kodu sitende aktif.', 'Connected — the verification code is live on your site.'),
                ),
                if (connected) const SizedBox(height: 12),
                _stepLabel(_s('1. Search Console\'u aç ve mülk ekle', '1. Open Search Console and add a property')),
                Text(
                  _s(
                    '"URL öneki" türünü seç ve aşağıdaki adresi yapıştır. Doğrulama yöntemi olarak "HTML etiketi"ni seç.',
                    'Choose the "URL prefix" type and paste the address below. As the verification method choose "HTML tag".',
                  ),
                  style: _bodyStyle,
                ),
                const SizedBox(height: 8),
                if (siteUrl.isNotEmpty)
                  InkWell(
                    onTap: () => _copyUrl(siteUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              siteUrl,
                              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _copiedUrl ? Icons.check : Icons.copy_rounded,
                            size: 16,
                            color: _copiedUrl ? AppColors.accentGreenLink : Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _open('https://search.google.com/search-console'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(_s('Search Console\'u aç', 'Open Search Console')),
                ),
                const SizedBox(height: 14),
                _stepLabel(_s('2. Doğrulama kodunu buraya yapıştır', '2. Paste the verification code here')),
                Text(
                  _s(
                    'Google sana <meta name="google-site-verification" content="KOD" /> gibi bir etiket verir. Tüm etiketi ya da sadece KOD kısmını yapıştırabilirsin.',
                    'Google gives you a tag like <meta name="google-site-verification" content="CODE" />. You can paste the whole tag or just the CODE part.',
                  ),
                  style: _bodyStyle,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeCtrl,
                  enabled: !_busy && !locked,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: _s('Doğrulama kodu', 'Verification code'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintText: connected ? project.googleVerificationCode : 'aB3dE_fGh-1234567890...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _s('Panodan yapıştır', 'Paste from clipboard'),
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      onPressed: (_busy || locked) ? null : _paste,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontFamily: 'monospace', fontSize: 11.5)),
                ],
                if (_success != null) ...[
                  const SizedBox(height: 8),
                  Text(_success!, style: const TextStyle(color: AppColors.accentGreenLink, fontFamily: 'monospace', fontSize: 11.5, height: 1.35)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: (_busy || locked) ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                connected ? _s('Kodu Güncelle', 'Update code') : _s('Kaydet', 'Save'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                      ),
                    ),
                    if (connected) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        ),
                        onPressed: _busy ? null : _disconnect,
                        child: Text(_s('Bağlantıyı Kes', 'Disconnect')),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _stepLabel(_s('3. Doğrula ve sitemap\'i ekle', '3. Verify and add your sitemap')),
                Text(
                  _s(
                    'Kaydettikten sonra Search Console\'da "Doğrula"ya bas (birkaç dakika sürebilir; olmazsa biraz bekleyip tekrar dene). Sonra "Site Haritaları" bölümüne sitemap.xml yaz — sitemap otomatik hazır.',
                    'After saving, press "Verify" in Search Console (it can take a few minutes; if it fails, wait a bit and retry). Then enter sitemap.xml under "Sitemaps" — the sitemap is generated automatically.',
                  ),
                  style: _bodyStyle,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const TextStyle _bodyStyle =
      TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11.5, height: 1.4);

  Widget _stepLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
      );

  Widget _statusBox({required Color color, required String text}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Text(text, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11.5, height: 1.35)),
      );
}
