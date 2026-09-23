import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../models/site_project.dart';
import '../services/gbp_helpers.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_popup.dart';
import 'premium_locked_popup.dart';

/// 20.09.2026 eklendi (kanka isteği) — "Google İşletme Profili Kurulum
/// Sihirbazı".
///
/// ÜRÜN MANTIĞI (kanka kararı): MySitora Google işletme profilini AÇMAZ ve
/// YÖNETMEZ — profil, Google'ın kendi ücretsiz aracında (business.google.com)
/// kullanıcının KENDİ Google hesabıyla açılır. Biz sadece entegrasyonu
/// kolaylaştırıyoruz:
///   1) Formdaki bilgilerden (ad, telefon, adres, saatler, kategori, site
///      adresi) kopyalamaya hazır bir bilgi kartı üretir,
///   2) Google'ın kendi kayıt ekranına adım adım yönlendirir
///      (url_launcher ile business.google.com),
///   3) Profil açılınca alınan yorum linkini sitedeki mevcut "Bizi Google'da
///      Değerlendirin" butonuna bağlar (bkz. google_review_field.dart).
/// Google API'si KULLANILMAZ, Google hesabına erişilmez, sunucuya hiçbir
/// veri gönderilmez (her şey cihazda).
///
/// KİLİT (kanka kararı): SADECE ücretsiz katmanda kilitli. Abonelik kotası,
/// özel domain paketi (ve eski mini paket) = SiteProject.isPremium == true =
/// AÇIK. Merkezi kontrol [showGbpSetupWizard] içinde; GoogleReviewLinkField
/// ayrıca girişte de kilitliyor (LocationPickerField / LeadFormToggleField ile
/// AYNI kalıp).

/// Formdan sihirbaza taşınan (kopyalanacak) işletme bilgileri. Her form
/// elindekini doldurur, olmayan alan boş kalır — sihirbaz içinde düzenlenebilir.
class GbpPrefill {
  const GbpPrefill({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.hours,
    this.categoryTr = '',
    this.categoryEn = '',
  });

  final String name;
  final String phone;
  final String address;

  /// WorkingHoursPickerField'ın ürettiği şekil:
  /// [{'day': 'Pazartesi', 'range': '09:00 - 19:00'}, {'day': 'Pazar', 'range': null}]
  final List<Map<String, String?>>? hours;

  /// Google kategori listesinde ARANACAK öneri (kullanıcı kendi dilinde
  /// arar; birebir eşleşme garantisi yok, sadece başlangıç noktası).
  final String categoryTr;
  final String categoryEn;
}

/// Projenin Google'a yazılacak web adresi: aktif özel domain varsa o,
/// yoksa yayın adresi, hiçbiri yoksa boş (henüz yayınlanmamış).
String gbpSiteUrlFor(SiteProject? p) {
  if (p == null) return '';
  final d = p.customDomain;
  if (d != null && d.trim().isNotEmpty && p.isDomainConnected && !p.isDomainExpired) {
    return 'https://${d.trim()}';
  }
  return (p.publishedUrl ?? '').trim();
}

/// Sihirbazı açar. Free planda ASLA açılmaz — kilitli popup gösterilir
/// (merkezi kilit noktası; alan zaten girişte de kilitli).
Future<void> showGbpSetupWizard(
  BuildContext context, {
  required GbpPrefill prefill,
  required TextEditingController reviewController,
}) async {
  final isPremium = context.read<AppState>().qtCurrentIsPremium;
  if (!isPremium) {
    final en = isEnglish(context);
    await showPremiumLockedPopup(
      context,
      message: en
          ? 'The Google Business Profile Setup Wizard is available with a subscription or a custom-domain package. It is locked on the free plan.'
          : 'Google İşletme Profili Kurulum Sihirbazı abonelik veya özel domain paketinde açılır. Ücretsiz planda kilitlidir.',
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => GbpSetupWizardScreen(
        prefill: prefill,
        reviewController: reviewController,
      ),
    ),
  );
}

class GbpSetupWizardScreen extends StatefulWidget {
  const GbpSetupWizardScreen({
    super.key,
    required this.prefill,
    required this.reviewController,
  });

  final GbpPrefill prefill;

  /// Formdaki "Google Yorum Linki" alanının controller'ı — sihirbaz kaydedince
  /// buraya yazar (site, formun kendi kaydetme akışıyla güncellenir).
  final TextEditingController reviewController;

  @override
  State<GbpSetupWizardScreen> createState() => _GbpSetupWizardScreenState();
}

class _GbpSetupWizardScreenState extends State<GbpSetupWizardScreen> {
  static const int _lastStep = 2;

  int _step = 0;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _reviewCtrl;

  String? _copiedId;
  String? _reviewError;

  bool get _en => isEnglish(context);
  String _s(String tr, String en) => _en ? en : tr;

  @override
  void initState() {
    super.initState();
    final en = Provider.of<LocaleController>(context, listen: false).isEnglish;
    final p = widget.prefill;
    _nameCtrl = TextEditingController(text: p.name.trim());
    _categoryCtrl = TextEditingController(text: (en ? p.categoryEn : p.categoryTr).trim());
    _addressCtrl = TextEditingController(text: p.address.trim());
    _phoneCtrl = TextEditingController(text: p.phone.trim());
    _hoursCtrl = TextEditingController(text: gbpFormatHours(p.hours, en: en));
    final project = Provider.of<AppState>(context, listen: false).qtCurrentProject;
    _siteCtrl = TextEditingController(text: gbpSiteUrlFor(project));
    _reviewCtrl = TextEditingController(text: widget.reviewController.text.trim());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _hoursCtrl.dispose();
    _siteCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Eylemler
  // ------------------------------------------------------------------

  Future<void> _copy(String id, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedId = id);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    if (_copiedId == id) setState(() => _copiedId = null);
  }

  String _allAsText() {
    final lines = <String>[];
    void add(String label, String value) {
      final v = value.trim();
      if (v.isNotEmpty) lines.add('$label: $v');
    }

    add(_s('İşletme adı', 'Business name'), _nameCtrl.text);
    add(_s('Kategori', 'Category'), _categoryCtrl.text);
    add(_s('Adres', 'Address'), _addressCtrl.text);
    add(_s('Telefon', 'Phone'), _phoneCtrl.text);
    add(_s('Web sitesi', 'Website'), _siteCtrl.text);
    final hours = _hoursCtrl.text.trim();
    if (hours.isNotEmpty) {
      lines.add('${_s('Çalışma saatleri', 'Opening hours')}:\n$hours');
    }
    return lines.join('\n');
  }

  Future<void> _openGoogle(String url) async {
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
          'Bağlantı açılamadı. Tarayıcından business.google.com adresini aç.',
          'Could not open the link. Open business.google.com in your browser.',
        ),
        icon: '⚠️',
      );
    }
  }

  Future<void> _pasteReviewLink() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      _reviewCtrl.text = gbpNormalizeReviewLink(text);
      _reviewError = null;
    });
  }

  Future<void> _saveReviewLink() async {
    final normalized = gbpNormalizeReviewLink(_reviewCtrl.text);
    if (normalized.isEmpty) {
      setState(() => _reviewError = _s(
            'Önce Google\'dan aldığın yorum linkini yapıştır.',
            'Paste the review link you got from Google first.',
          ));
      return;
    }
    final problem = gbpReviewLinkProblem(normalized);
    if (problem != null) {
      setState(() => _reviewError = problem == 'host'
          ? _s(
              'Bu bir Google linki gibi görünmüyor. Yorum linki genelde g.page/r/…/review şeklindedir.',
              'This doesn\'t look like a Google link. A review link usually looks like g.page/r/…/review.',
            )
          : _s(
              'Geçerli bir bağlantı değil. Linki olduğu gibi kopyalayıp yapıştır.',
              'Not a valid link. Copy it as-is and paste it here.',
            ));
      return;
    }
    widget.reviewController.text = normalized;
    setState(() {
      _reviewCtrl.text = normalized;
      _reviewError = null;
    });
    final looksRight = gbpLooksLikeReviewLink(normalized);
    await showAppPopup(
      context,
      message: looksRight
          ? _s(
              'Link forma eklendi. Sitene yansıması için formun altındaki ana butona (Düzenlemeyi Bitir / Siteyi Oluştur) bas.',
              'Link added to the form. To publish it on your site, tap the main button at the bottom of the form (Finish Editing / Create Site).',
            )
          : _s(
              'Link forma eklendi ama yorum formu linkine benzemiyor (harita linki olabilir). Google\'da "yorum linkini paylaş/kopyala" seçeneğinden aldığından emin ol. Sitene yansıması için formun altındaki ana butona bas.',
              'Link added, but it doesn\'t look like a review-form link (it may be a map link). Make sure you used Google\'s "share/copy review link" option. To publish it, tap the main button at the bottom of the form.',
            ),
      icon: looksRight ? '✅' : '⚠️',
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final isDark = context.watch<ThemeController>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.lightTitleText;
    final subtle = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.68 : 0.72);
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final cardBorder = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: titleColor,
        title: Text(
          _s('Google İşletme Profili Kurulumu', 'Google Business Profile Setup'),
          style: TextStyle(
            color: titleColor,
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepChips(titleColor, subtle, cardBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDisclaimer(cardBg, cardBorder, subtle),
                    const SizedBox(height: 14),
                    if (_step == 0) ..._buildInfoStep(titleColor, subtle, cardBg, cardBorder),
                    if (_step == 1) ..._buildGoogleStep(titleColor, subtle, cardBg, cardBorder),
                    if (_step == 2) ..._buildLinkStep(titleColor, subtle, cardBg, cardBorder),
                  ],
                ),
              ),
            ),
            _buildBottomBar(bg, cardBorder),
          ],
        ),
      ),
    );
  }

  Widget _buildStepChips(Color titleColor, Color subtle, Color border) {
    final labels = [
      _s('Bilgi kartı', 'Info card'),
      _s('Google\'da kayıt', 'Google sign-up'),
      _s('Yorum linki', 'Review link'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _step = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == _step ? AppColors.accentBlue : border,
                      width: i == _step ? 1.6 : 1,
                    ),
                    color: i == _step ? AppColors.accentBlue.withOpacity(0.12) : Colors.transparent,
                  ),
                  child: Text(
                    '${i + 1} · ${labels[i]}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: i == _step ? titleColor : subtle,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: i == _step ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer(Color cardBg, Color cardBorder, Color subtle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ℹ️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _s(
                'MySitora Google işletme profilini senin yerine AÇMAZ ve yönetmez. Profil, Google\'ın kendi ücretsiz aracında senin Google hesabınla açılır. Biz bilgilerini hazırlar, adım adım yönlendirir ve yorum linkini sitene bağlarız.',
                'MySitora does NOT create or manage your Google Business Profile. It is opened in Google\'s own free tool with your Google account. We prepare your details, guide you step by step, and connect your review link to your site.',
              ),
              style: TextStyle(color: subtle, fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- Adım 1: bilgi kartı -------------------------------------------

  List<Widget> _buildInfoStep(Color titleColor, Color subtle, Color cardBg, Color cardBorder) {
    final siteEmpty = _siteCtrl.text.trim().isEmpty;
    return [
      _stepTitle(_s('1 · Bilgi kartın', '1 · Your info card'), titleColor),
      const SizedBox(height: 6),
      _stepText(
        _s(
          'Formdaki bilgilerin hazır. Eksik ya da yanlış olanı burada düzeltebilirsin (bu, sitendeki formu değiştirmez). Google\'da her satırı kopyalayıp yapıştıracaksın.',
          'Your form details are ready. Fix anything here if needed (this does not change the form on your site). You\'ll copy each line into Google.',
        ),
        subtle,
      ),
      const SizedBox(height: 12),
      _copyField('name', _s('İşletme adı', 'Business name'), _nameCtrl),
      _copyField(
        'category',
        _s('Kategori (Google\'da ara)', 'Category (search it on Google)'),
        _categoryCtrl,
        helper: _s(
          'Google\'ın kategori listesinden en yakın seçeneği seç.',
          'Pick the closest option from Google\'s category list.',
        ),
      ),
      _copyField('address', _s('Adres', 'Address'), _addressCtrl, maxLines: 2),
      _copyField('phone', _s('Telefon', 'Phone'), _phoneCtrl, keyboard: TextInputType.phone),
      _copyField(
        'site',
        _s('Web sitesi adresi', 'Website address'),
        _siteCtrl,
        keyboard: TextInputType.url,
        helper: siteEmpty
            ? _s(
                'Sitenin adresi yayınlandıktan sonra oluşur. Önce siteyi yayınlayıp buraya dönebilir ya da Google\'da bu alanı şimdilik boş bırakabilirsin.',
                'Your site address exists once it is published. Publish first and come back, or leave this empty on Google for now.',
              )
            : null,
      ),
      _copyField(
        'hours',
        _s('Çalışma saatleri', 'Opening hours'),
        _hoursCtrl,
        maxLines: 7,
        helper: _s(
          'Google\'da saatleri gün gün girersin; bu liste referans içindir.',
          'You enter hours day by day on Google; this list is just for reference.',
        ),
      ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => _copy('all', _allAsText()),
        icon: Icon(_copiedId == 'all' ? Icons.check_rounded : Icons.copy_all_rounded, size: 18),
        label: Text(
          _copiedId == 'all'
              ? _s('Kopyalandı ✅', 'Copied ✅')
              : _s('Tüm kartı kopyala', 'Copy whole card'),
        ),
      ),
    ];
  }

  Widget _copyField(
    String id,
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? helper,
  }) {
    final copied = _copiedId == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _s('Kopyala', 'Copy'),
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              color: copied ? AppColors.accentGreenLink : null,
            ),
            onPressed: () => _copy(id, ctrl.text),
          ),
        ),
      ),
    );
  }

  // --- Adım 2: Google'da kayıt ---------------------------------------

  List<Widget> _buildGoogleStep(Color titleColor, Color subtle, Color cardBg, Color cardBorder) {
    final steps = [
      _s(
        'Profili sahiplenecek Google hesabınla giriş yap.',
        'Sign in with the Google account that will own the profile.',
      ),
      _s(
        'İşletme adını yaz ve kategoriyi seç (1. adımdaki kart).',
        'Enter the business name and pick the category (card from step 1).',
      ),
      _s(
        'Müşteriler sana geliyorsa adresi ekle; sen müşterinin yanına gidiyorsan "hizmet alanı" seç.',
        'If customers visit you, add the address; if you go to them, choose a "service area".',
      ),
      _s(
        'Telefonu ve web sitesi adresini yapıştır (1. adımdaki kart).',
        'Paste your phone and website address (card from step 1).',
      ),
      _s(
        'Google\'ın doğrulama adımını tamamla. Yöntemi (SMS, arama, e-posta, video ya da kartpostal) Google belirler; birkaç gün sürebilir.',
        'Complete Google\'s verification. Google decides the method (SMS, call, email, video or postcard); it can take a few days.',
      ),
    ];
    return [
      _stepTitle(_s('2 · Google\'da kayıt', '2 · Sign up on Google'), titleColor),
      const SizedBox(height: 6),
      _stepText(
        _s(
          'Profil senin Google hesabında açılır; MySitora bu hesaba erişemez. Aşağıdaki butonlar Google\'ın kendi ekranını açar.',
          'The profile lives in your own Google account; MySitora cannot access it. The buttons below open Google\'s own screens.',
        ),
        subtle,
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0.0 : 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: titleColor,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          color: titleColor,
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _openGoogle('https://business.google.com/create'),
        icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
        label: Text(
          _s('Google\'da yeni profil oluştur', 'Create a new profile on Google'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _openGoogle('https://business.google.com/'),
        icon: const Icon(Icons.storefront_rounded, size: 18),
        label: Text(_s('Zaten profilim var — profilimi aç', 'I already have a profile — open it')),
      ),
      const SizedBox(height: 10),
      _stepText(
        _s(
          'Zaten bir profilin varsa kayıt adımlarını atlayıp doğrudan 3. adıma geçebilirsin.',
          'If you already have a profile, skip the sign-up and go straight to step 3.',
        ),
        subtle,
      ),
    ];
  }

  // --- Adım 3: yorum linkini bağla -----------------------------------

  List<Widget> _buildLinkStep(Color titleColor, Color subtle, Color cardBg, Color cardBorder) {
    return [
      _stepTitle(_s('3 · Yorum linkini bağla', '3 · Connect your review link'), titleColor),
      const SizedBox(height: 6),
      _stepText(
        _s(
          'Profilin açılınca Google\'da yorumlarla ilgili bölümü aç (genelde "yorum al / get more reviews" gibi bir seçenek; Google arayüzü zaman zaman değişir) ve yorum linkini kopyala. Buraya yapıştırınca sitendeki "⭐ Bizi Google\'da Değerlendirin" butonuna bağlanır.',
          'Once your profile is live, open the reviews section on Google (usually an option like "get more reviews"; Google\'s interface changes from time to time) and copy the review link. Paste it here and it is connected to the "⭐ Rate us on Google" button on your site.',
        ),
        subtle,
      ),
      const SizedBox(height: 8),
      _stepText(
        _s(
          'Google, doğrulama bitmeden bu linki vermeyebilir. Öyleyse sonra bu sihirbaza dönüp linki ekleyebilirsin.',
          'Google may not give you this link until verification is complete. If so, come back to this wizard later and add it.',
        ),
        subtle,
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _reviewCtrl,
        keyboardType: TextInputType.url,
        onChanged: (_) {
          if (_reviewError != null) setState(() => _reviewError = null);
        },
        decoration: InputDecoration(
          labelText: _s('Google yorum linki', 'Google review link'),
          hintText: 'https://g.page/r/.../review',
          errorText: _reviewError,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pasteReviewLink,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: Text(_s('Yapıştır', 'Paste')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGreenLink),
              onPressed: _saveReviewLink,
              icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              label: Text(
                _s('Forma ekle', 'Add to form'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _stepText(
        _s(
          'Bu buton yalnızca formdaki "Google Yorum Linki" alanını doldurur. Sitende görünmesi için formu kaydetmen (Düzenlemeyi Bitir / Siteyi Oluştur) ve siteyi yeniden yayınlaman gerekir.',
          'This only fills the "Google Review Link" field in the form. To show it on your site, save the form (Finish Editing / Create Site) and republish the site.',
        ),
        subtle,
      ),
    ];
  }

  // --- Ortak parçalar ------------------------------------------------

  Widget _stepTitle(String text, Color color) => Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _stepText(String text, Color color) => Text(
        text,
        style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 12, height: 1.45),
      );

  Widget _buildBottomBar(Color bg, Color border) {
    final isLast = _step == _lastStep;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                child: Text(_s('Geri', 'Back')),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (isLast) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step++);
                }
              },
              child: Text(
                isLast ? _s('Kapat', 'Close') : _s('Devam', 'Next'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
