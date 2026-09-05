import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_project.dart';
import '../services/local_generation_helper.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../templates/html/real_estate_html_generator.dart';
import '../widgets/pill_button.dart';
import '../widgets/lead_form_toggle_field.dart';
import '../widgets/theme_picker_field.dart';
import '../widgets/typography_picker_field.dart';
import '../widgets/gallery_picker_field.dart';
import '../widgets/location_picker_field.dart';
import 'preview_screen.dart';
import '../services/qt_form_data_codec.dart';
import '../localization/app_strings.dart';
import '../localization/locale_controller.dart';
import '../widgets/app_popup.dart';
import '../widgets/google_review_field.dart';
import '../widgets/video_link_field.dart'; // 05.09.2026 eklendi (kanka isteği: her ilana video)
import '../widgets/section_order_field.dart'; // 05.09.2026 eklendi (kanka isteği: sürükle-bırak bölüm sırası)

/// kuafor_form_screen.dart kalıbından FARKLI bir yapıda — real_estate_
/// html_generator.dart Çok Sayfa (B) modu üretiyor (index.html + her ilan
/// için ayrı listing_<id>.html), bu yüzden tekil form yerine "ilan listesi
/// + ilan ekle" akışı kuruldu. Üretim LocalGenerationHelper.generateMultiPage
/// üzerinden (bkz. services/local_generation_helper.dart).
class RealEstateFormScreen extends StatefulWidget {
  const RealEstateFormScreen({super.key, this.initialData, this.isEditing = false});

  /// 25.08.2026 eklendi — Düzenle akışı: önceden kaydedilmiş ham form
  /// alanları (bkz. services/qt_form_data_codec.dart).
  final Map<String, dynamic>? initialData;

  /// true ise bu ekran "Düzenle" akışıyla açılmıştır — buton metni ve
  /// puan maliyeti buna göre değişir (bkz. _generate).
  final bool isEditing;

  @override
  State<RealEstateFormScreen> createState() => _RealEstateFormScreenState();
}

class _RealEstateFormScreenState extends State<RealEstateFormScreen> {
  final _agentNameCtrl = TextEditingController();
  final _agentLogoCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _faqCtrl = TextEditingController(); // "Soru | Cevap" satır satır
  final _testimonialsCtrl = TextEditingController(); // "İsim | Yorum | Puan(1-5, opsiyonel)" satır satır
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _googleReviewCtrl = TextEditingController(); // 01.09.2026 eklendi
  String _selectedTheme = 'clean_light';
  String _fontPackageId = 'modern_sade';
  String _typeDensity = 'normal';
  String _galleryStyle = 'grid';
  bool _generating = false;
  bool _includeLeadForm = true; // 05.09.2026 eklendi (kanka isteği)
  // Site İÇERİĞİNİN dili — uygulama arayüz dilinden BAĞIMSIZ, kullanıcı
  // seçiyor (bkz. generic_business_form_screen.dart'taki aynı desen).
  // Varsayılan olarak açılışta app diline eşitlenir (initState), kullanıcı
  // isterse TR uygulamada EN içerikli site üretebilir.
  String _siteLang = 'tr';

  // 05.09.2026 eklendi (kanka isteği) — kullanıcı sürükle-bırakla
  // sıralayabilsin diye. 05.09.2026 değişti (kanka isteği, "tam
  // özgürlük olsun") — Hero ve İletişim ARTIK bu listelere DAHİL,
  // istenirse aşağı/yukarı taşınabilirler (önceki kararın tersine).
  // Varsayılan sıra yine eski sabit sırayla BİREBİR AYNI (hero en üstte,
  // contact en altta) — mevcut siteler etkilenmez, sadece artık
  // kullanıcı isterse taşıyabiliyor.
  List<String> _indexSectionOrder = ['hero', 'reviewButton', 'listings', 'testimonials', 'faq'];
  List<String> _detailSectionOrder = ['gallery', 'video', 'propertyDetails', 'map', 'contact'];

  // 05.09.2026 eklendi (kanka isteği) — anasayfa Hero alanı için GERÇEK
  // kapak fotoğrafı (opsiyonel). Generator tarafı (real_estate_html_
  // generator.dart > agentCoverImage) zaten hazırdı, sadece bu UI eksikti
  // (generic_business_form_screen.dart'taki "Kapak Görseli" ile AYNI
  // desen: GalleryPickerField(maxImages: 1)). Boş bırakılırsa eski sade
  // metin başlığa (emlakçı adı + slogan) düşülür — davranış değişmez.
  List<Map<String, String?>> _agentCover = [];

  final List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    if (initial != null) {
      _restoreFromInitialData(initial);
    }
    // Açılışta uygulamanın o anki diliyle eşitle — kullanıcı isterse
    // aşağıdaki seçiciden değiştirebilir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isEditing) return;
      setState(() {
        _siteLang = context.read<LocaleController>().isEnglish ? 'en' : 'tr';
      });
    });
  }

  @override
  void dispose() {
    _agentNameCtrl.dispose();
    _agentLogoCtrl.dispose();
    _taglineCtrl.dispose();
    _faqCtrl.dispose();
    _testimonialsCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _googleReviewCtrl.dispose();
    super.dispose();
  }

  /// "Soru | Cevap" satırlarını parse eder — bkz. faqBlockHtml
  /// (templates/html/shared_html_blocks.dart). Boş/eksik satırlar atlanır.
  List<Map<String, String>> _parseFaqs(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('|'))
        .map((line) {
      final parts = line.split('|');
      return {
        'question': parts[0].trim(),
        'answer': parts.sublist(1).join('|').trim(),
      };
    }).where((f) => f['question']!.isNotEmpty && f['answer']!.isNotEmpty).toList();
  }

  /// "İsim | Yorum | Puan(1-5, opsiyonel)" satırlarını parse eder — bkz.
  /// testimonialBlockHtml. Puan verilmezse/yanlış girilirse yıldız satırı
  /// hiç basılmaz (testimonialBlockHtml içinde ele alınıyor).
  List<Map<String, dynamic>> _parseTestimonials(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.contains('|'))
        .map((line) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      return {
        'name': parts.isNotEmpty ? parts[0] : '',
        'text': parts.length > 1 ? parts[1] : '',
        'rating': parts.length > 2 ? parts[2] : '',
      };
    }).where((t) => (t['name'] as String).isNotEmpty && (t['text'] as String).isNotEmpty).toList();
  }

  Future<void> _openListingEditor({Map<String, dynamic>? existing, int? index}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ListingEditorSheet(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _listings[index] = result;
      } else {
        _listings.add(result);
      }
    });
  }

  /// 25.08.2026 eklendi — Düzenle akışı: bu formun HAM alan
  /// değerlerinin JSON-uyumlu bir anlık görüntüsü (bkz.
  /// services/qt_form_data_codec.dart). Üretim/düzenleme başarıyla
  /// bittiğinde AppState.qtFormData'ya yazılır ki sonraki "Düzenle"
  /// bu formu dolu açabilsin.
  Map<String, dynamic> _captureFormData() {
    return {
      'includeLeadForm': _includeLeadForm,
      'agentNameCtrl': _agentNameCtrl.text,
      'agentLogoCtrl': _agentLogoCtrl.text,
      'taglineCtrl': _taglineCtrl.text,
      'faqCtrl': _faqCtrl.text,
      'testimonialsCtrl': _testimonialsCtrl.text,
      'phoneCtrl': _phoneCtrl.text,
      'whatsappCtrl': _whatsappCtrl.text,
      'googleReviewCtrl': _googleReviewCtrl.text,
      'selectedTheme': _selectedTheme,
      'fontPackageId': _fontPackageId,
      'typeDensity': _typeDensity,
      'galleryStyle': _galleryStyle,
      'siteLang': _siteLang,
      'listings': _listings,
      'indexSectionOrder': _indexSectionOrder,
      'detailSectionOrder': _detailSectionOrder,
      'agentCover': _agentCover, // 05.09.2026 eklendi (kanka isteği)
    };
  }

  /// _captureFormData()'nın tersi — initState'te widget.initialData
  /// doluysa çağrılır ve formu, önceki üretimdeki değerlerle DOLU açar.
  void _restoreFromInitialData(Map<String, dynamic> d) {
    _includeLeadForm = (d['includeLeadForm'] as bool?) ?? _includeLeadForm;
    _agentNameCtrl.text = (d['agentNameCtrl'] as String?) ?? _agentNameCtrl.text;
    _agentLogoCtrl.text = (d['agentLogoCtrl'] as String?) ?? _agentLogoCtrl.text;
    _taglineCtrl.text = (d['taglineCtrl'] as String?) ?? _taglineCtrl.text;
    _faqCtrl.text = (d['faqCtrl'] as String?) ?? _faqCtrl.text;
    _testimonialsCtrl.text = (d['testimonialsCtrl'] as String?) ?? _testimonialsCtrl.text;
    _phoneCtrl.text = (d['phoneCtrl'] as String?) ?? _phoneCtrl.text;
    _whatsappCtrl.text = (d['whatsappCtrl'] as String?) ?? _whatsappCtrl.text;
    _googleReviewCtrl.text = (d['googleReviewCtrl'] as String?) ?? _googleReviewCtrl.text;
    _selectedTheme = (d['selectedTheme'] as String?) ?? _selectedTheme;
    _fontPackageId = (d['fontPackageId'] as String?) ?? _fontPackageId;
    _typeDensity = (d['typeDensity'] as String?) ?? _typeDensity;
    _galleryStyle = (d['galleryStyle'] as String?) ?? _galleryStyle;
    _siteLang = (d['siteLang'] as String?) ?? _siteLang;
    final restored_listings = qtDecodeMapList(d['listings']);
    if (restored_listings != null) {
      _listings
        ..clear()
        ..addAll(restored_listings);
    }
    // 05.09.2026 eklendi (kanka isteği) — eski kayıtlarda bu alanlar
    // yoktur (null döner), o zaman initState'teki varsayılan sıra
    // (eski sabit sırayla aynı) korunur.
    final restoredIndexOrder = (d['indexSectionOrder'] as List?)?.map((e) => e.toString()).toList();
    if (restoredIndexOrder != null && restoredIndexOrder.isNotEmpty) {
      _indexSectionOrder = restoredIndexOrder;
    }
    final restoredDetailOrder = (d['detailSectionOrder'] as List?)?.map((e) => e.toString()).toList();
    if (restoredDetailOrder != null && restoredDetailOrder.isNotEmpty) {
      _detailSectionOrder = restoredDetailOrder;
    }
    // 05.09.2026 eklendi (kanka isteği)
    _agentCover = qtDecodeNullableStringMapList(d['agentCover']);
  }

  Future<void> _generate() async {
    if (_agentNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'Emlakçı/ofis adı ve telefon gerekli.'), icon: '⚠️');
      return;
    }
    if (_listings.isEmpty) {
      showAppPopup(context, message: t(context, 'En az 1 ilan eklemelisin.'), icon: '⚠️');
      return;
    }
    setState(() => _generating = true);
    final formData = _captureFormData();

    // 05.09.2026 eklendi (kanka isteği) — bkz. _agentCover yorumu.
    final agentCoverUrl = _agentCover.isNotEmpty && (_agentCover.first['url'] ?? '').isNotEmpty
        ? _agentCover.first['url']
        : null;

    final siteLang = _siteLang;
    final ok = await LocalGenerationHelper.generateMultiPage(
      context: context,
      projectNameHint: _agentNameCtrl.text.trim(),
      kind: ProjectKind.realEstate,
      formData: formData,
      isEditing: widget.isEditing,
      activeFileName: 'index.html',
      buildFiles: () => generateRealEstateSite(
        agentName: _agentNameCtrl.text.trim(),
        agentLogo: _agentLogoCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        agentCoverImage: agentCoverUrl,
        agentPhone: _phoneCtrl.text.trim(),
        agentWhatsapp: _whatsappCtrl.text.trim(),
        agentGoogleReviewLink: _googleReviewCtrl.text.trim().isEmpty ? null : _googleReviewCtrl.text.trim(),
        listings: _listings,
        themeId: _selectedTheme,
        fontPackageId: _fontPackageId,
        density: _typeDensity,
        galleryStyle: _galleryStyle,
        lang: siteLang,
        includeLeadForm: _includeLeadForm,
        faqs: _parseFaqs(_faqCtrl.text),
        testimonials: _parseTestimonials(_testimonialsCtrl.text),
        indexSectionOrder: _indexSectionOrder,
        detailSectionOrder: _detailSectionOrder,
      ),
    );

    if (mounted) setState(() => _generating = false);
    if (ok && mounted) {
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QuickToolsPreviewScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleController>();
    final generating = _generating || context.watch<AppState>().isGenerating;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? '${t(context, 'Emlak Sitesi')} • ${t(context, 'Düzenle')}'
              : t(context, 'Emlak Sitesi'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Site içeriği dili — uygulama diline bağımlı DEĞİL ---
            Text(t(context, 'Site İçeriği Dili'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              t(context, 'Sitenin ziyaretçiye görüneceği dil. Bu uygulamanın kendi arayüz dilinden bağımsızdır.'),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tr', label: Text('Türkçe')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_siteLang},
              onSelectionChanged: (s) => setState(() => _siteLang = s.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _agentNameCtrl,
              decoration: InputDecoration(labelText: t(context, 'Emlakçı / ofis adı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taglineCtrl,
              decoration: InputDecoration(labelText: t(context, 'Slogan (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agentLogoCtrl,
              decoration: InputDecoration(labelText: t(context, 'Logo/foto URL (opsiyonel)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            // 05.09.2026 eklendi (kanka isteği) — anasayfa Hero alanına
            // gerçek kapak fotoğrafı. Boş bırakılırsa eski sade metin
            // başlığa (emlakçı adı + slogan) düşülür.
            GalleryPickerField(
              label: t(context, 'Kapak Fotoğrafı Ekle (opsiyonel)'),
              maxImages: 1,
              initialImages: _agentCover,
              onChanged: (v) => _agentCover = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'Telefon'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t(context, 'WhatsApp (90XXXXXXXXXX)'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            // 05.09.2026 değişti (kanka isteği, madde 4) — free plan'da kilitli
            GoogleReviewLinkField(controller: _googleReviewCtrl),
            const SizedBox(height: 20),
            ThemePickerField(
              initialThemeId: _selectedTheme,
              onChanged: (v) => _selectedTheme = v,
            ),
            const SizedBox(height: 20),
            TypographyPickerField(
              initialFontPackageId: _fontPackageId,
              initialDensity: _typeDensity,
              onFontPackageChanged: (v) => _fontPackageId = v,
              onDensityChanged: (v) => _typeDensity = v,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _testimonialsCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Müşteri Yorumları (opsiyonel — her satıra bir tane: İsim | Yorum | Puan)'),
                hintText: t(context, 'Ayşe K. | Süreç boyunca çok ilgiliydi, teşekkürler! | 5'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _faqCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t(context, 'Sıkça Sorulan Sorular (opsiyonel — her satıra bir tane: Soru | Cevap)'),
                hintText: t(context, 'Kredi kullanabilir miyim? | Evet, anlaşmalı bankalarımız üzerinden destek sağlıyoruz.'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            // 05.09.2026 eklendi (kanka isteği) — ANA SAYFA bölümlerinin
            // sırası (Google Yorum Butonu / İlan Listesi / Müşteri
            // Yorumları / SSS). 05.09.2026 değişti: Hero artık sabit
            // DEĞİL, listeye dahil — kullanıcı isterse taşıyabilir.
            SectionOrderField(
              title: 'Ana Sayfa Bölüm Sırası',
              helperText: 'Anasayfadaki bölümleri sürükleyerek istediğin sıraya getirebilirsin.',
              sectionLabels: const {
                'hero': 'Üst Tanıtım Alanı',
                'reviewButton': 'Google Yorum Butonu',
                'listings': 'İlan Listesi',
                'testimonials': 'Müşteri Yorumları',
                'faq': 'Sık Sorulan Sorular',
              },
              order: _indexSectionOrder,
              onChanged: (v) => _indexSectionOrder = v,
            ),
            const SizedBox(height: 20),
            // 05.09.2026 eklendi (kanka isteği) — İLAN DETAY sayfasının
            // bölüm sırası (Galeri / Video / İlan Bilgileri / Harita /
            // İletişim). Bu sıra TÜM ilanlar için ortak (site genelinde
            // tutarlı görünüm için).
            SectionOrderField(
              title: 'İlan Detay Sayfası Bölüm Sırası',
              helperText: 'Her ilanın kendi sayfasındaki bölüm sırası — tüm ilanlar için ortaktır.',
              sectionLabels: const {
                'gallery': 'İlan Galerisi',
                'video': 'Video',
                'propertyDetails': 'İlan Bilgileri (Fiyat/m²/Oda)',
                'map': 'Harita/Konum',
                'contact': 'İletişim / Talep Kutusu',
              },
              order: _detailSectionOrder,
              onChanged: (v) => _detailSectionOrder = v,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${isEnglish(context) ? 'Listings' : 'İlanlar'} (${_listings.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openListingEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(t(context, 'İlan Ekle')),
                ),
              ],
            ),
            for (var i = 0; i < _listings.length; i++)
              Card(
                child: ListTile(
                  title: Text(_listings[i]['title']?.toString() ?? ''),
                  subtitle: Text(
                    '${_listings[i]['price']} TL · ${_listings[i]['m2']} m² · ${_listings[i]['roomLabel']}',
                  ),
                  onTap: () => _openListingEditor(existing: _listings[i], index: i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _listings.removeAt(i)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            LeadFormToggleField(
              value: _includeLeadForm,
              onChanged: (v) => setState(() => _includeLeadForm = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(
                      context,
                      generating
                          ? 'Oluşturuluyor...'
                          : (widget.isEditing ? 'Düzenlemeyi Bitir' : 'Siteyi Oluştur'),
                    ),
                    borderColor: AppTheme.accentBlue,
                    textColor: AppTheme.accentBlue,
                    onTap: generating ? null : _generate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir ilanın eklenmesi/düzenlenmesi için alt sayfa (bottom sheet).
class _ListingEditorSheet extends StatefulWidget {
  const _ListingEditorSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ListingEditorSheet> createState() => _ListingEditorSheetState();
}

class _ListingEditorSheetState extends State<_ListingEditorSheet> {
  late final _titleCtrl = TextEditingController(text: widget.existing?['title']?.toString() ?? '');
  late final _priceCtrl = TextEditingController(text: widget.existing?['price']?.toString() ?? '');
  late final _m2Ctrl = TextEditingController(text: widget.existing?['m2']?.toString() ?? '');
  late final _roomCtrl = TextEditingController(text: widget.existing?['roomLabel']?.toString() ?? '');
  late final _floorCtrl = TextEditingController(text: widget.existing?['floor']?.toString() ?? '');
  late final _aidatCtrl = TextEditingController(text: widget.existing?['aidat']?.toString() ?? '');
  late final _locationTagCtrl = TextEditingController(text: widget.existing?['locationTag']?.toString() ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.existing?['description']?.toString() ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?['address']?.toString() ?? '');

  late List<Map<String, String?>> _gallery =
      (widget.existing?['gallery'] as List?)?.cast<Map<String, String?>>() ?? [];
  // 28.08.2026 düzeltildi (build hatası) — bu alan hiç tanımlanmamıştı,
  // 466-467. satırlarda yanlışlıkla _RealEstateFormScreenState'e (FARKLI
  // bir class) ait _galleryStyle'a referans veriliyordu, bu da derleme
  // hatasıydı. Her ilanın kendi galeri stili olması daha mantıklı (ortak
  // form seviyesinde değil), bu yüzden düzenlenen ilana ('existing') özel
  // bir alan olarak eklendi ve _save() içinde geri döndürülüyor.
  late String _galleryStyle = widget.existing?['galleryStyle']?.toString() ?? 'grid';
  late double _lat = (widget.existing?['lat'] as num?)?.toDouble() ?? 41.0082;
  late double _lng = (widget.existing?['lng'] as num?)?.toDouble() ?? 28.9784;

  // 05.09.2026 eklendi (kanka isteği) — ilan başına video, dış link embed
  // (generator tarafı zaten hazırdı, bkz. real_estate_html_generator.dart
  // > videoUrl/videoOrientation; sadece bu UI eksikti).
  late final _videoUrlCtrl = TextEditingController(text: widget.existing?['videoUrl']?.toString() ?? '');
  late String _videoOrientation = widget.existing?['videoOrientation']?.toString() ?? 'landscape';

  // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim") — kullanıcı tek
  // tek fotoğrafları galeriden bağımsız, sayfanın herhangi bir yerine
  // (ör. bir fotoğrafı en üste, bir başkasını Harita'nın altına)
  // sürükle-bırakla yerleştirebilsin diye. Sadece "Izgara" stilinde
  // anlamlı — Slayt Gösterisi kendi otomatik sırasını kullanır, bu
  // yüzden slayt seçiliyken bu alan gizlenir/kapanır (kanka isteği:
  // "slayt gösterisi hariç" — aynı kural burada da geçerli).
  late bool _freeformLayout = (widget.existing?['freeformLayout'] as bool?) ?? false;
  late List<String> _photoLayoutOrder =
      (widget.existing?['photoLayoutOrder'] as List?)?.map((e) => e.toString()).toList() ?? [];

  /// [_photoLayoutOrder]'ı mevcut galeriyle senkron tutar: silinen
  /// fotoğrafların anahtarını çıkarır, yeni eklenen fotoğrafları
  /// (galerideki sırayla) ve sabit blokları sona ekler. Hem UI'da
  /// gösterirken hem kaydederken çağrılır, bu yüzden liste her zaman
  /// geçerli/güncel kalır.
  List<String> _syncedPhotoLayoutOrder() {
    final photoKeys = [
      for (final g in _gallery)
        if ((g['url'] ?? '').isNotEmpty) 'photo::${g['url']}',
    ];
    const fixedKeys = ['video', 'propertyDetails', 'map', 'contact'];
    final valid = {...photoKeys, ...fixedKeys};
    final synced = _photoLayoutOrder.where(valid.contains).toList();
    for (final k in [...photoKeys, ...fixedKeys]) {
      if (!synced.contains(k)) synced.add(k);
    }
    return synced;
  }

  /// [_syncedPhotoLayoutOrder]'daki 'photo::<url>' anahtarları için
  /// "Fotoğraf 1", "Fotoğraf 2"... etiketlerini üretir (galerideki mevcut
  /// sırayla numaralandırılır — bkz. GalleryPickerField.enableReorder).
  Map<String, String> _freeformSectionLabels() {
    final labels = <String, String>{};
    for (var i = 0; i < _gallery.length; i++) {
      final url = _gallery[i]['url'] ?? '';
      if (url.isEmpty) continue;
      labels['photo::$url'] = '${isEnglish(context) ? 'Photo' : 'Fotoğraf'} ${i + 1}';
    }
    labels['video'] = t(context, 'Video');
    labels['propertyDetails'] = t(context, 'İlan Bilgileri (Fiyat/m²/Oda)');
    labels['map'] = t(context, 'Harita/Konum');
    labels['contact'] = t(context, 'İletişim / Talep Kutusu');
    return labels;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _m2Ctrl.dispose();
    _roomCtrl.dispose();
    _floorCtrl.dispose();
    _aidatCtrl.dispose();
    _locationTagCtrl.dispose();
    _descriptionCtrl.dispose();
    _addressCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      showAppPopup(context, message: t(context, 'İlan başlığı ve fiyat gerekli.'), icon: '⚠️');
      return;
    }
    final id = widget.existing?['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    // 05.09.2026 değişti (kanka isteği) — galeri boşsa artık zorla bir
    // "https://placehold.co/..." gri kutu URL'i ATANMIYOR. Boş bırakılırsa
    // ilan kartında hiç görsel basılmaz, temiz bir metin kartına düşer
    // (bkz. shared_html_blocks.dart > propertyCardGridHtml > no-image).
    final coverImage = _gallery.isNotEmpty ? (_gallery.first['url'] ?? '') : '';
    Navigator.pop(context, {
      'id': id,
      'title': _titleCtrl.text.trim(),
      'coverImage': coverImage,
      'price': double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
      'm2': double.tryParse(_m2Ctrl.text.replaceAll(',', '.')) ?? 0,
      'roomLabel': _roomCtrl.text.trim(),
      'floor': int.tryParse(_floorCtrl.text.trim()),
      'aidat': double.tryParse(_aidatCtrl.text.replaceAll(',', '.')),
      'locationTag': _locationTagCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'gallery': _gallery,
      'galleryStyle': _galleryStyle,
      'videoUrl': _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
      'videoOrientation': _videoOrientation,
      // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim")
      'freeformLayout': _freeformLayout && _galleryStyle != 'slideshow',
      'photoLayoutOrder': _syncedPhotoLayoutOrder(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, widget.existing == null ? 'Yeni İlan' : 'İlanı Düzenle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: t(context, 'İlan başlığı'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Fiyat (TL)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _m2Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'm²'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _roomCtrl,
                  decoration: InputDecoration(labelText: t(context, 'Oda (örn. 3+1)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _floorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Kat (opsiyonel)'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _aidatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t(context, 'Aidat (opsiyonel)'), border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _locationTagCtrl,
                  decoration: InputDecoration(labelText: t(context, 'Semt/ilçe etiketi'), border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: t(context, 'Açıklama'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            GalleryPickerField(
              label: t(context, 'İlan Galerisi'),
              initialImages: _gallery,
              onChanged: (v) => setState(() => _gallery = v),
              showStyleOption: true,
              initialStyle: _galleryStyle,
              onStyleChanged: (v) => setState(() {
                _galleryStyle = v;
                // "slayt gösterisi hariç" (kanka isteği) — slaytta serbest
                // yerleşimin bir karşılığı yok, otomatik kapatılır.
                if (v == 'slideshow') _freeformLayout = false;
              }),
              // 05.09.2026 eklendi (kanka isteği) — şimdilik sadece emlak
              // sektörü: kullanıcı görselleri sürükle-bırakla tek tek
              // istediği sıraya koyabilir (slayt gösterisinde kapanır,
              // bkz. GalleryPickerField.enableReorder yorumu).
              enableReorder: true,
            ),
            // 05.09.2026 eklendi (kanka isteği, "serbest yerleşim") —
            // fotoğrafları galeriden çıkarıp sayfanın istenen noktalarına
            // (Video/İlan Bilgileri/Harita/İletişim arasına) tek tek
            // dağıtabilme. Sadece Izgara stilinde ve galeri doluyken
            // anlamlı olduğu için diğer durumlarda gizli.
            if (_gallery.isNotEmpty && _galleryStyle != 'slideshow') ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context, 'Fotoğrafları sayfada serbestçe yerleştir (opsiyonel)')),
                subtitle: Text(
                  t(context, 'Kapalıyken tüm fotoğraflar tek bir galeri bloğunda gösterilir. Açarsan her fotoğrafı, aşağıdaki listede sürükleyerek, sayfanın istediğin noktasına (ör. Harita\'nın altına) tek tek yerleştirebilirsin.'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                value: _freeformLayout,
                onChanged: (v) => setState(() => _freeformLayout = v),
              ),
              if (_freeformLayout) ...[
                const SizedBox(height: 8),
                SectionOrderField(
                  title: 'Sayfa Yerleşimi',
                  helperText: 'Fotoğrafları ve diğer bölümleri sürükleyerek istediğin sıraya getirebilirsin.',
                  sectionLabels: _freeformSectionLabels(),
                  order: _syncedPhotoLayoutOrder(),
                  onChanged: (v) => setState(() => _photoLayoutOrder = v),
                ),
              ],
            ],
            const SizedBox(height: 16),
            LocationPickerField(
              initialAddress: _addressCtrl.text,
              initialLat: _lat,
              initialLng: _lng,
              onChanged: (address, lat, lng) {
                _addressCtrl.text = address;
                _lat = lat;
                _lng = lng;
              },
            ),
            const SizedBox(height: 16),
            // 05.09.2026 eklendi (kanka isteği) — her ilana video linki
            VideoLinkField(
              urlController: _videoUrlCtrl,
              orientation: _videoOrientation,
              onOrientationChanged: (v) => setState(() => _videoOrientation = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: t(context, 'Kaydet'),
                    borderColor: AppTheme.accentBlue,
                    textColor: AppTheme.accentBlue,
                    onTap: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
