import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// Sektörel site formlarında (kafe, kuaför, klinik, portfolyo, emlak vb.)
/// ortak kullanılan hazır TEMA seçicisi.
///
/// Biyo Link formundaki tema seçiciyle BİREBİR AYNI 5 hazır temayı
/// kullanır (bkz. templates/html/shared_html_blocks.dart -> siteThemes),
/// böylece tüm sektörlerde tutarlı, tek bir seçim deneyimi olur. Önceki
/// "Vurgu Rengi" seçicisinin (AccentColorPickerField) yerini alır: artık
/// kullanıcı tek bir rengi değil, tam bir görsel kimliği (arkaplan + kart
/// yüzeyi + metin tonları + vurgu rengi) seçmiş oluyor.
///
/// 17.09.2026 eklendi (kanka isteği — "Özel Renk" B seçeneği) — hazır
/// paletlerin sonuna bir "Özel Tema" çipi eklendi. Seçilirse bg/text/
/// cardBg/accent için 4 hex alanı açılır ve [onCustomThemeChanged] ile
/// bir Map<String,String> döner. Bu çip seçili DEĞİLKEN [onCustomThemeChanged]
/// hiç çağrılmaz — yani bu alanı dinlemeyen eski çağıran kodlar (varsa)
/// hiçbir şekilde etkilenmez, geriye dönük tam uyumlu.
class ThemePickerField extends StatefulWidget {
  const ThemePickerField({
    super.key,
    required this.onChanged,
    this.onCustomThemeChanged,
    this.label = 'Tema',
    this.initialThemeId = 'clean_light',
    this.initialCustomTheme,
  });

  final String label;
  final String initialThemeId;
  final ValueChanged<String> onChanged;

  /// "Özel Tema" çipi seçiliyken {'bg':..., 'text':..., 'cardBg':...,
  /// 'accent':...} döner. Formun bu callback'i sağlamadığı ekranlarda
  /// "Özel Tema" çipi hiçbir şey kırmadan basitçe görünmez (bkz. build()
  /// içindeki kontrol) — yani eski ekranlara dokunmadan tek tek
  /// yaygınlaştırılabilir.
  final ValueChanged<Map<String, String>>? onCustomThemeChanged;

  /// Düzenle akışında formu eski haline getirirken kullanılır.
  final Map<String, String>? initialCustomTheme;

  static const String customThemeId = 'custom';

  /// siteThemes'teki id'lerle birebir eşleşmeli.
  static const List<Map<String, String>> options = [
    {'id': 'clean_light', 'label': 'Clean Light'},
    {'id': 'midnight_dark', 'label': 'Midnight Dark'},
    {'id': 'sunset_gradient', 'label': 'Sunset Gradient'},
    {'id': 'neon_cyber', 'label': 'Neon Cyber'},
    {'id': 'soft_pastel', 'label': 'Soft Pastel'},
    // 06.09.2026 eklendi (kanka isteği) — PREMİUM temalar (bkz.
    // shared_html_blocks.dart > premiumThemeIds). Kanka kararı: burada
    // KİLİTLİ/blur GÖSTERİLMEZ — herkes serbestçe seçip önizleyebilir,
    // kısıtlama SADECE "Oluştur"a basılınca (LocalGenerationHelper'daki
    // gate) devreye girer. '👑' etiketi sadece bilgilendirme amaçlı.
    {'id': 'obsidian_gold', 'label': '👑 Obsidian Gold'},
    {'id': 'glass_frost', 'label': '👑 Glass Frost'},
    {'id': 'royal_emerald', 'label': '👑 Royal Emerald'},
  ];

  @override
  State<ThemePickerField> createState() => _ThemePickerFieldState();
}

class _ThemePickerFieldState extends State<ThemePickerField> {
  late String _selected = widget.initialThemeId;
  late final _bgCtrl = TextEditingController(text: widget.initialCustomTheme?['bg'] ?? '#FFFFFF');
  late final _textCtrl = TextEditingController(text: widget.initialCustomTheme?['text'] ?? '#1A1A1A');
  late final _cardCtrl = TextEditingController(text: widget.initialCustomTheme?['cardBg'] ?? '#F5F5F5');
  late final _accentCtrl = TextEditingController(text: widget.initialCustomTheme?['accent'] ?? '#3D5AFE');

  bool get _showCustomPanel =>
      widget.onCustomThemeChanged != null && _selected == ThemePickerField.customThemeId;

  @override
  void dispose() {
    _bgCtrl.dispose();
    _textCtrl.dispose();
    _cardCtrl.dispose();
    _accentCtrl.dispose();
    super.dispose();
  }

  void _emitCustomTheme() {
    widget.onCustomThemeChanged?.call({
      'bg': _bgCtrl.text.trim(),
      'text': _textCtrl.text.trim(),
      'cardBg': _cardCtrl.text.trim(),
      'accent': _accentCtrl.text.trim(),
    });
  }

  /// '#RGB' veya '#RRGGBB' — kullanıcı hatalı bir değer yazarsa (ör. eksik
  /// #) kırmızı çerçeveyle uyarır ama formu bloklamaz; boş/geçersiz alan
  /// varsa resolveTheme() zaten clean_light'tan tamamlıyor (bkz.
  /// shared_html_blocks.dart), yani en kötü ihtimalle o tek renk göz ardı
  /// edilir, sayfa asla bozuk render olmaz.
  bool _isValidHex(String v) => RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(v.trim());

  Widget _hexField(String label, TextEditingController ctrl) {
    final valid = _isValidHex(ctrl.text);
    Color? swatch;
    if (valid) {
      final hex = ctrl.text.trim().replaceFirst('#', '');
      final full = hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex;
      swatch = Color(int.parse('FF$full', radix: 16));
    }
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: ctrl.text.isNotEmpty && !valid ? t(context, 'Geçersiz renk (örn. #3D5AFE)') : null,
          suffixIcon: swatch == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
        ),
        onChanged: (_) {
          setState(() {}); // swatch/hata anlık güncellensin
          _emitCustomTheme();
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
            ...ThemePickerField.options.map((opt) {
              final selected = _selected == opt['id'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: selected,
                onSelected: (_) {
                  setState(() => _selected = opt['id']!);
                  widget.onChanged(opt['id']!);
                },
              );
            }),
            // 17.09.2026 eklendi — sadece bu callback'i sağlayan ekranlarda
            // görünür (bkz. sınıf dokümanı); sağlamayan eski ekranlar bu
            // çipi hiç görmez.
            if (widget.onCustomThemeChanged != null)
              ChoiceChip(
                label: Text(t(context, '🎨 Özel Tema')),
                selected: _selected == ThemePickerField.customThemeId,
                onSelected: (_) {
                  setState(() => _selected = ThemePickerField.customThemeId);
                  widget.onChanged(ThemePickerField.customThemeId);
                  _emitCustomTheme();
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
                  t(context, 'Marka renklerinizi girin (hex kod)'),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _hexField(t(context, 'Arka Plan'), _bgCtrl),
                    _hexField(t(context, 'Metin'), _textCtrl),
                    _hexField(t(context, 'Kart Yüzeyi'), _cardCtrl),
                    _hexField(t(context, 'Vurgu (Buton/Link)'), _accentCtrl),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'Not: Buton yazı rengi, okunabilirlik için vurgu rengine göre otomatik ayarlanır.'),
                  style: const TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
