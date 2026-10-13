import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// 18.09.2026 eklendi (kanka isteği — "Serbest Font Seçimi") — ThemePickerField
/// "Özel Tema" arama kutusuyla AYNI mantık: kullanıcı ham metin yazmaz,
/// bu KÜRATÖRLÜ liste üzerinde arar/seçer. Böylece serbest seçimde bile
/// her zaman GEÇERLİ bir Google Fonts ailesi seçilmiş olur (yazım hatası,
/// var olmayan bir aile, XSS/CSS-injection riski YOK). Liste, Google
/// Fonts'un en popüler ~50 ailesinden, geniş bir stil yelpazesi
/// (sans/serif/monospace/display/el yazısı) kapsayacak şekilde seçildi.
const List<String> kCuratedGoogleFontNames = [
  'Inter', 'Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Poppins', 'Nunito',
  'Source Sans 3', 'Work Sans', 'Rubik', 'Manrope', 'Karla', 'DM Sans',
  'Mulish', 'Raleway', 'Quicksand', 'Sora', 'Outfit', 'Figtree', 'Urbanist',
  'Space Grotesk', 'IBM Plex Sans', 'Barlow', 'Josefin Sans', 'Cabin',
  'Playfair Display', 'Merriweather', 'Fraunces', 'Lora', 'Libre Baskerville',
  'PT Serif', 'Crimson Text', 'Cormorant Garamond', 'Bitter', 'Spectral',
  'EB Garamond', 'Source Serif 4', 'Noto Serif',
  'Oswald', 'Bebas Neue', 'Archivo', 'Anton', 'Big Shoulders Display',
  'League Spartan', 'Unbounded',
  'Dancing Script', 'Pacifico', 'Caveat', 'Satisfy', 'Great Vibes',
  'Sacramento', 'Playfair Display SC',
  'JetBrains Mono', 'Space Mono', 'IBM Plex Mono', 'Roboto Mono',
];

/// Sektörel site formlarında ortak kullanılan TİPOGRAFİ seçicisi.
///
/// ThemePickerField (renk teması) ile BİREBİR AYNI mantık: kullanıcı ham
/// font ailesi/boyut/renk seçmez — küratörlü "font çifti" paketlerinden
/// birini seçer (bkz. templates/html/shared_html_blocks.dart ->
/// fontPackageOf), böylece sonuç her zaman uyumlu çıkar. Hedef kitle
/// tasarımcı değil esnaf; sınırsız seçenek çoğu zaman ya hiç kullanılmaz
/// ya da kötü kombinasyonlarla siteyi çirkinleştirir.
///
/// İkinci, bağımsız bir seçim de "Yoğunluk" (başlık kalınlığı/boyutu) —
/// sadece 3 kademe: İnce / Normal / Kalın. Serbest slider YOK; body metni
/// hep normal ağırlıkta kalır (bkz. typeDensityOf).
class TypographyPickerField extends StatefulWidget {
  const TypographyPickerField({
    super.key,
    required this.onFontPackageChanged,
    required this.onDensityChanged,
    this.onCustomFontPackageChanged,
    this.label = 'Tipografi',
    this.initialFontPackageId = 'modern_sade',
    this.initialDensity = 'normal',
    this.initialCustomFontPackage,
  });

  final String label;
  final String initialFontPackageId;
  final String initialDensity;
  final ValueChanged<String> onFontPackageChanged;
  final ValueChanged<String> onDensityChanged;

  /// 18.09.2026 eklendi (kanka isteği — "Serbest Font Seçimi", PREMİUM).
  /// ThemePickerField.onCustomThemeChanged ile BİREBİR AYNI desen: "Serbest
  /// Font Seçimi" çipi seçiliyken {'heading':..., 'body':...} döner. Bu
  /// çip SADECE bu callback sağlanan ekranlarda görünür — sağlamayan eski
  /// ekranlar hiçbir şekilde etkilenmez, geriye dönük tam uyumlu.
  final ValueChanged<Map<String, String>>? onCustomFontPackageChanged;

  /// Düzenle akışında formu eski haline getirirken kullanılır.
  final Map<String, String>? initialCustomFontPackage;

  static const String customFontPackageId = 'custom_font';

  /// shared_html_blocks.dart -> _fontPackageData id'leriyle birebir eşleşmeli.
  static const List<Map<String, String>> fontPackageOptions = [
    {'id': 'editorial', 'label': 'Editoryal'},
    {'id': 'modern_sade', 'label': 'Modern Sade'},
    {'id': 'sicak_elyazisi', 'label': 'Sıcak'},
    {'id': 'klasik', 'label': 'Klasik'},
    {'id': 'kalin_vurgulu', 'label': 'Kalın / Vurgulu'},
  ];

  /// shared_html_blocks.dart -> _typeDensityData id'leriyle birebir eşleşmeli.
  static const List<Map<String, String>> densityOptions = [
    {'id': 'ince', 'label': 'İnce'},
    {'id': 'normal', 'label': 'Normal'},
    {'id': 'kalin', 'label': 'Kalın'},
  ];

  @override
  State<TypographyPickerField> createState() => _TypographyPickerFieldState();
}

class _TypographyPickerFieldState extends State<TypographyPickerField> {
  late String _selectedPackage = widget.initialFontPackageId;
  late String _selectedDensity = widget.initialDensity;
  late final _headingCtrl =
      TextEditingController(text: widget.initialCustomFontPackage?['heading'] ?? '');
  late final _bodyCtrl = TextEditingController(text: widget.initialCustomFontPackage?['body'] ?? '');

  bool get _showCustomPanel =>
      widget.onCustomFontPackageChanged != null &&
      _selectedPackage == TypographyPickerField.customFontPackageId;

  @override
  void dispose() {
    _headingCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _emitCustomFontPackage() {
    widget.onCustomFontPackageChanged?.call({
      'heading': _headingCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
    });
  }

  /// [ctrl]'e seçilen font adını yazar ve üst callback'i tetikler —
  /// arama kutusundan bir öneri seçildiğinde ya da metin elle
  /// düzenlendiğinde (elle yazım [kCuratedGoogleFontNames] dışında bir
  /// değere düşerse, buildHtml tarafında [resolveFontPackage] zaten
  /// güvenli şekilde süzüyor, yani en kötü ihtimalle 'Inter'e düşer).
  Widget _fontSearchField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 220,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue value) {
          if (value.text.trim().isEmpty) return kCuratedGoogleFontNames;
          final q = value.text.toLowerCase();
          return kCuratedGoogleFontNames.where((name) => name.toLowerCase().contains(q));
        },
        initialValue: TextEditingValue(text: ctrl.text),
        onSelected: (selection) {
          ctrl.text = selection;
          _emitCustomFontPackage();
        },
        fieldViewBuilder: (context, fieldCtrl, focusNode, onSubmitted) {
          // Autocomplete kendi iç controller'ını yönetir; dışarıdaki
          // [ctrl] sadece initial değer/senkron okuma için tutuluyor —
          // her karakter değişiminde de dış controller'ı senkron tutup
          // callback'i tetikliyoruz ki elle yazılan (öneriden seçilmeyen)
          // bir değer de kaybolmasın.
          fieldCtrl.text = ctrl.text;
          return TextField(
            controller: fieldCtrl,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: t(context, label),
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search, size: 18),
            ),
            onChanged: (v) {
              ctrl.text = v;
              _emitCustomFontPackage();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 220,
                height: options.length > 6 ? 260 : options.length * 42.0 + 8,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final opt = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(opt),
                      onTap: () => onSelected(opt),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, widget.label), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...TypographyPickerField.fontPackageOptions.map((f) {
              final selected = _selectedPackage == f['id'];
              return ChoiceChip(
                label: Text(t(context, f['label']!)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selectedPackage = f['id']!);
                  widget.onFontPackageChanged(f['id']!);
                },
              );
            }),
            // 18.09.2026 eklendi (kanka isteği — "Serbest Font Seçimi",
            // PREMİUM) — sadece bu callback'i sağlayan ekranlarda görünür
            // (bkz. sınıf dokümanı). ThemePickerField'daki premium
            // temalarla AYNI desen: burada KİLİTLİ/blur GÖSTERİLMEZ,
            // herkes serbestçe seçip önizleyebilir — kısıtlama SADECE
            // "Oluştur"a basılınca devreye girer (bkz.
            // LocalGenerationHelper._isPremiumChoiceLocked). '🔒' etiketi
            // sadece bilgilendirme amaçlı.
            if (widget.onCustomFontPackageChanged != null)
              ChoiceChip(
                label: Text(t(context, '🔒 Serbest Font Seçimi')),
                selected: _selectedPackage == TypographyPickerField.customFontPackageId,
                onSelected: (_) {
                  setState(() => _selectedPackage = TypographyPickerField.customFontPackageId);
                  widget.onFontPackageChanged(TypographyPickerField.customFontPackageId);
                  _emitCustomFontPackage();
                },
              ),
          ],
        ),
        if (_showCustomPanel) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'Google Fonts\'tan ara ve seç (Premium)'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _fontSearchField('Başlık Fontu', _headingCtrl),
                    _fontSearchField('Gövde Fontu', _bodyCtrl),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(t(context, 'Yoğunluk'), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TypographyPickerField.densityOptions.map((d) {
            final selected = _selectedDensity == d['id'];
            return ChoiceChip(
              label: Text(t(context, d['label']!)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedDensity = d['id']!);
                widget.onDensityChanged(d['id']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
