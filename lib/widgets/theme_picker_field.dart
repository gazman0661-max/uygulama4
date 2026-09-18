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

  /// 18.09.2026 eklendi (kanka isteği — "renk seçim paleti de olsun") —
  /// hex yazma alanı olduğu gibi KALIYOR, sadece yanına dokunulunca bir
  /// renk seçici (hue/saturation/value) açan bir "swatch buton" ekliyoruz.
  /// Geçersiz/boş bir hex varsa seçiciyi mavi bir varsayılanla açıyoruz ki
  /// buton her zaman tıklanabilir olsun.
  Color _colorFromField(TextEditingController ctrl) {
    if (_isValidHex(ctrl.text)) {
      final hex = ctrl.text.trim().replaceFirst('#', '');
      final full = hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex;
      return Color(int.parse('FF$full', radix: 16));
    }
    return const Color(0xFF3D5AFE);
  }

  Future<void> _openColorPicker(TextEditingController ctrl) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(initialColor: _colorFromField(ctrl)),
    );
    if (picked == null) return;
    final hex = '#${picked.value.toRadixString(16).substring(2).toUpperCase()}';
    ctrl.text = hex;
    setState(() {});
    _emitCustomTheme();
  }

  Widget _hexField(String label, TextEditingController ctrl) {
    final valid = _isValidHex(ctrl.text);
    final swatch = valid ? _colorFromField(ctrl) : null;
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: ctrl.text.isNotEmpty && !valid ? t(context, 'Geçersiz renk (örn. #3D5AFE)') : null,
          suffixIcon: GestureDetector(
            onTap: () => _openColorPicker(ctrl),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: swatch ?? Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black38),
                ),
                child: swatch == null
                    ? const Icon(Icons.palette_outlined, size: 12, color: Colors.black45)
                    : null,
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
                  // 18.09.2026 fix (kanka bug raporu) — "Özel Tema" seçilip
                  // sonra hazır bir temaya geri dönüldüğünde, parent'ta
                  // saklanan _customTheme haritası TEMİZLENMİYORDU. Bu
                  // yüzden resolveTheme() hâlâ eski customTheme'i (varsayılan
                  // #FFFFFF beyaz arkaplan dahil) kullanmaya devam ediyor,
                  // kullanıcı başka hangi temayı seçerse seçsin site hep
                  // beyaz/eski özel renklerle üretiliyordu. Boş bir harita
                  // gönderip resolveTheme'in "customTheme boşsa/yoksa
                  // themeId'yi kullan" davranışını (bkz. resolveTheme
                  // dokümanı) devreye sokuyoruz — bu callback'i sağlamayan
                  // eski ekranlarda hiçbir şey değişmez (null-safe call).
                  widget.onCustomThemeChanged?.call(const {});
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

/// 18.09.2026 eklendi (kanka isteği — "renk seçim paleti de olsun") —
/// dışarıdan paket eklemeden (offline/sürüm bağımsız), sadece Flutter'ın
/// kendi widget'larıyla basit bir HSV renk seçici. Hex yazarak girmenin
/// YERİNE değil, YANINA eklenmiş ikinci bir seçim yolu — kullanıcı ister
/// hex yazar, ister burada dokunarak/kaydırarak rengi görsel seçer, ikisi
/// de aynı hex alanını doldurur.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initialColor);

  Color get _color => _hsv.toColor();

  String get _hex => '#${_color.value.toRadixString(16).substring(2).toUpperCase()}';

  // Not: num.clamp() her zaman num döner (double değil), bu yüzden
  // HSVColor.withSaturation/withValue/withHue gibi double bekleyen
  // yerlere geçmeden önce .toDouble() ile açıkça double'a çeviriyoruz —
  // yoksa derleme zamanı tip hatası olur.
  void _updateFromSvBox(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0).toDouble();
    final v = 1 - (local.dy / size.height).clamp(0.0, 1.0).toDouble();
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
  }

  void _updateHue(double dx, double width) {
    final hue = (dx / width).clamp(0.0, 1.0).toDouble() * 360;
    setState(() {
      _hsv = _hsv.withHue(hue);
      // 18.09.2026 fix (kanka bug raporu — "renk paletinden seçince
      // çalışmıyor, beyaz arkaplan oluyor") — "Arka Plan" gibi varsayılanı
      // #FFFFFF (S=0) olan alanlarda dialog S=0/V=1 ile açılıyordu. SV
      // kutusundaki seçim noktası bu durumda (-7,-7) civarında, neredeyse
      // görünmez bir köşede kalıyordu; kullanıcı SV kutusuna hiç dokunmadan
      // sadece alttaki hue çubuğunu sürüklüyordu. S=0 iken hue'nun rengi
      // HİÇBİR etkisi olmuyor (HSV'de S=0 => gri/beyaz), yani kullanıcı
      // "renk seçtim" dediği hâlde sonuç hep beyaz kalıyordu. Çözüm: hue
      // çubuğu sürüklendiğinde S ve/veya V dejenere (0) ise görünür bir
      // değere (1.0) çekiyoruz ki hue seçimi anında gözle görülür bir renk
      // üretsin. Kullanıcı SV kutusunda BİLİNÇLİ olarak düşük S/V seçtiyse
      // (yani hue çubuğuna dokunmadan önce zaten oradaydı) bu kod hiç
      // çalışmaz, çünkü sadece hue çubuğu sürüklenirken tetikleniyor.
      if (_hsv.saturation == 0) _hsv = _hsv.withSaturation(1.0);
      if (_hsv.value == 0) _hsv = _hsv.withValue(1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final en = isEnglish(context);
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();

    return AlertDialog(
      title: Text(en ? 'Pick a color' : 'Renk Seç'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Doygunluk (yatay) / Parlaklık (dikey) kutusu.
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, 180);
                return GestureDetector(
                  onPanDown: (d) => _updateFromSvBox(d.localPosition, size),
                  onPanUpdate: (d) => _updateFromSvBox(d.localPosition, size),
                  child: Container(
                    width: size.width,
                    height: size.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [Colors.white, hueColor],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: (_hsv.saturation * size.width - 7).clamp(-7.0, size.width - 7).toDouble(),
                            top: ((1 - _hsv.value) * size.height - 7).clamp(-7.0, size.height - 7).toDouble(),
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            // Ton (hue) çubuğu.
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  onPanDown: (d) => _updateHue(d.localPosition.dx, width),
                  onPanUpdate: (d) => _updateHue(d.localPosition.dx, width),
                  child: Container(
                    width: width,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: (_hsv.hue / 360 * width - 3).clamp(-3, width - 3),
                          child: Container(
                            width: 6,
                            height: 24,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 10),
                Text(_hex, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(en ? 'Cancel' : 'Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(en ? 'Select' : 'Seç'),
        ),
      ],
    );
  }
}
