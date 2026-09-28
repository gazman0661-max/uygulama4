import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../localization/app_strings.dart';
import '../services/image_compress_service.dart';
import '../theme/app_theme.dart';
import 'app_popup.dart';

/// Ortak galeri seçici — tüm sektör formlarında kullanılabilir.
///
/// TASARIM KARARI: Backend/upload servisi olmadığı için (tamamen yerel
/// üretim akışı) seçilen görseller diske/uzak sunucuya YÜKLENMİYOR;
/// bunun yerine bayt içeriği base64 data URI'ye çevrilip doğrudan
/// `<img src="data:image/jpeg;base64,...">` olarak HTML'e gömülüyor.
/// Bu sayede üretilen site tek bir .html dosyası olarak kalmaya devam
/// ediyor ve dışarıda barındırma gerektirmiyor. Dezavantajı: çok sayıda
/// veya çok büyük görsel dosya boyutunu ciddi artırır — bu yüzden
/// [maxImages] ve bir sıkıştırma uygulanıyor. 06.09.2026 — sıkıştırma
/// JPEG yerine WebP'ye çevrildi (bkz. ImageCompressService); PNG
/// kaynaklar (şeffaf logo/ikon olabilir) olduğu gibi bırakılıyor.
///
/// 28.09.2026 (kanka kararı): galeri en fazla 12 fotoğraf alır (TÜM planlarda
/// aynı); eski free tavanı (3) kaldırıldı. Ayrıca boyut limitleri geçerli:
/// sayfa dosyası 8 MB, site toplamı 40 MB — aşılırsa yayınlarken "boyutu küçült"
/// uyarısı çıkar (publish_sheet). Galeri altında toplam boyut sayacı gösterilir.
///
/// Döndürdüğü veri şekli, generator'ların beklediği ile birebir aynı:
/// `List<Map<String, String?>>` — {'url': ..., 'caption': ...}
class GalleryPickerField extends StatefulWidget {
  const GalleryPickerField({
    super.key,
    required this.onChanged,
    this.label = 'Galeri',
    this.maxImages = kMaxGalleryImages,
    this.initialImages = const [],
    this.showStyleOption = false,
    this.initialStyle = 'grid',
    this.onStyleChanged,
  });

  /// Galeri başına en fazla fotoğraf sayısı (free dahil TÜM planlarda aynı).
  /// 28.09.2026: eski free tavanı (3) kaldırıldı, tavan 12 olarak kaldı.
  /// Ayrıca yayın boyut limitleri geçerli: sayfa dosyası 8 MB, site toplamı 40 MB
  /// (worker'da PUBLISH_MAX_FILE_BYTES / PUBLISH_MAX_TOTAL_BYTES); aşılırsa
  /// publish_sheet.dart'taki "boyutu küçült" uyarısı çıkar.
  /// Kapak/logo gibi alanlar maxImages:1 ile açıldığı için 1 görselle sınırlı.
  static const int kMaxGalleryImages = 12;

  final String label;
  final int maxImages;
  final List<Map<String, String?>> initialImages;
  final ValueChanged<List<Map<String, String?>>> onChanged;

  /// true ise altta "Izgara / Slayt Gösterisi" görünüm seçici gösterilir.
  /// SADECE gerçek çoklu-görsel galerilerinde açılmalı (kapak/profil
  /// fotoğrafı gibi tek görsel alanlarında anlamsız — orada varsayılan
  /// false kalmalı).
  final bool showStyleOption;
  final String initialStyle;
  final ValueChanged<String>? onStyleChanged;

  @override
  State<GalleryPickerField> createState() => _GalleryPickerFieldState();
}

class _GalleryPickerFieldState extends State<GalleryPickerField>
    with AutomaticKeepAliveClientMixin {
  /// 28.09.2026 eklendi (kanka isteği — "kapak/galeri fotoğrafı aşağı
  /// kaydırınca beyaz oluyor" hatası): formlar `ListView(children: [...])`
  /// kullanıyor; ListView ekrandan çıkan çocukları DISPOSE eder, geri
  /// gelince state sıfırdan kurulup her fotoğraf yeniden base64'ten çözülüyordu
  /// (birkaç MB'lık görsel = beyaz kutu / çözülemeyince boş kalıyor).
  /// Keep-alive ile state ve çözülmüş görseller kaydırmada yaşamaya devam eder.
  @override
  bool get wantKeepAlive => true;

  late final List<Map<String, String?>> _images = List.of(widget.initialImages);
  late String _style = widget.initialStyle;
  bool _picking = false;

  /// 28.09.2026: free plan tavanı (eski 3) KALDIRILDI — sınır sadece formun
  /// kendi [GalleryPickerField.maxImages] değeri (galeride sınırsız, kapak/logo 1).
  int _effectiveMax(BuildContext context, {bool listen = true}) => widget.maxImages;

  /// 28.09.2026 eklendi (kanka isteği): galerideki görsellerin HTML'e gömülen
  /// toplam boyutu. Görseller base64 data URI olarak sayfaya gömüldüğü için
  /// URI string uzunluğu = sayfaya eklenen gerçek bayt (ASCII). Yayın limitleri
  /// (worker): tek dosya 8 MB, site toplamı 40 MB — bkz. hosting_service /
  /// publish_sheet'teki "boyutu küçült" uyarıları.
  static const int _kFileLimitBytes = 8 * 1024 * 1024;
  static const int _kSiteLimitBytes = 40 * 1024 * 1024;

  int get _totalBytes =>
      _images.fold<int>(0, (sum, m) => sum + (m['url'] ?? '').length);

  String _fmtMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  Future<void> _pick() async {
    final maxImages = _effectiveMax(context, listen: false);
    if (_images.length >= maxImages) {
      showAppPopup(
        context,
        message: isEnglish(context)
            ? 'You can add up to $maxImages images.'
            : 'En fazla $maxImages görsel eklenebilir.',
      );
      return;
    }
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      // NOT: imageQuality artık burada verilmiyor — asıl sıkıştırma
      // (WebP + kalite) aşağıda ImageCompressService ile yapılıyor.
      // maxWidth ise native decode aşamasında kaba bir ön-limit olarak
      // kalıyor (çok büyük orijinal fotoğrafları baştan küçültür).
      final files = await picker.pickMultiImage(maxWidth: 1600);
      if (files.isEmpty) return;

      final remaining = maxImages - _images.length;
      for (final file in files.take(remaining)) {
        final rawBytes = await file.readAsBytes();
        final isPng = file.name.toLowerCase().endsWith('.png');
        final compressed = await ImageCompressService.compress(
          rawBytes,
          isPng: isPng,
        );
        final dataUri =
            'data:${compressed.mime};base64,${base64Encode(compressed.bytes)}';
        _images.add({'url': dataUri, 'caption': null});
      }
      widget.onChanged(List.of(_images));
      setState(() {});
    } catch (e) {
      if (mounted) {
        showAppPopup(context, message: 
                '${isEnglish(context) ? 'Could not add image' : 'Görsel eklenemedi'}: $e', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _editCaption(int index) async {
    final ctrl = TextEditingController(text: _images[index]['caption'] ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141821),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🖼️', style: TextStyle(fontSize: 30)),
              const SizedBox(height: 10),
              Text(
                t(ctx, 'Görsel açıklaması (opsiyonel)'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13.5),
                cursorColor: AppColors.accentCyan,
                decoration: InputDecoration(
                  hintText: t(ctx, 'Örn: Öncesi / Sonrası'),
                  hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0D1117),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentCyan),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t(ctx, 'Vazgeç'),
                          style: const TextStyle(
                              color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: Text(t(ctx, 'Kaydet'),
                          style: const TextStyle(
                              color: Colors.black, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _images[index]['caption'] = result.isEmpty ? null : result);
      widget.onChanged(List.of(_images));
    }
  }

  void _remove(int index) {
    setState(() => _images.removeAt(index));
    widget.onChanged(List.of(_images));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin gereği
    final maxImages = _effectiveMax(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t(context, widget.label), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_images.length}/$maxImages', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _images.length; i++)
              _GalleryThumb(
                dataUri: _images[i]['url'] ?? '',
                hasCaption: (_images[i]['caption'] ?? '').toString().isNotEmpty,
                onTap: () => _editCaption(i),
                onRemove: () => _remove(i),
              ),
            InkWell(
              onTap: _picking ? null : _pick,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _picking
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t(context, 'Görseller cihazdan seçilir, dosya olarak gömülür (yükleme gerekmez).'),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        // 28.09.2026 eklendi — galeri toplam boyut sayacı (sadece çoklu galeri).
        if (widget.maxImages > 1 && _images.isNotEmpty) ...[
          const SizedBox(height: 4),
          Builder(builder: (context) {
            final total = _totalBytes;
            final over = total > _kFileLimitBytes;
            final near = !over && total > _kFileLimitBytes * 0.75;
            final en = isEnglish(context);
            final base = en
                ? 'Gallery size: ${_fmtMb(total)} MB · limit 8 MB per page file, 40 MB per site'
                : 'Galeri boyutu: ${_fmtMb(total)} MB · sayfa dosyası sınırı 8 MB, site sınırı 40 MB';
            final warn = over
                ? (en
                    ? ' — over the limit; reduce the number of photos or use smaller ones, otherwise publishing will fail.'
                    : ' — sınır aşıldı; fotoğraf sayısını azalt veya daha küçük görseller kullan, yoksa yayınlama hata verir.')
                : near
                    ? (en ? ' — close to the limit.' : ' — sınıra yaklaştı.')
                    : '';
            return Text(
              base + warn,
              style: TextStyle(
                fontSize: 11,
                color: over
                    ? Colors.redAccent
                    : near
                        ? Colors.orange
                        : Colors.grey,
              ),
            );
          }),
        ],
        if (widget.showStyleOption) ...[
          const SizedBox(height: 14),
          Text(t(context, 'Galeri Görünümü'), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(t(context, 'Izgara')),
                selected: _style == 'grid',
                onSelected: (_) {
                  setState(() => _style = 'grid');
                  widget.onStyleChanged?.call('grid');
                },
              ),
              ChoiceChip(
                label: Text(t(context, 'Slayt Gösterisi')),
                selected: _style == 'slideshow',
                onSelected: (_) {
                  setState(() => _style = 'slideshow');
                  widget.onStyleChanged?.call('slideshow');
                },
              ),
              // 27.09.2026 eklendi (kanka isteği) — üçüncü galeri stili:
              // yumuşak crossfade + altyazı overlay (bkz.
              // shared_html_blocks.dart > _galleryCrossfadeBlockHtml).
              // Seçilmezse (varsayılan 'grid') hiçbir şey değişmez.
              ChoiceChip(
                label: Text(t(context, 'Geçişli (Crossfade)')),
                selected: _style == 'crossfade',
                onSelected: (_) {
                  setState(() => _style = 'crossfade');
                  widget.onStyleChanged?.call('crossfade');
                },
              ),
              // 27.09.2026 eklendi (kanka isteği) — dördüncü galeri stili:
              // sürekli kayan/infinite-scroll şerit, saf CSS (bkz.
              // shared_html_blocks.dart > _galleryMarqueeBlockHtml).
              // Seçilmezse (varsayılan 'grid') hiçbir şey değişmez.
              ChoiceChip(
                label: Text(t(context, 'Kayan Şerit (Marquee)')),
                selected: _style == 'marquee',
                onSelected: (_) {
                  setState(() => _style = 'marquee');
                  widget.onStyleChanged?.call('marquee');
                },
              ),
              // 28.09.2026 eklendi (kanka isteği) — beşinci galeri stili:
              // editoryal "bento" / mozaik ızgara (bkz.
              // shared_html_blocks.dart > _galleryBentoBlockHtml). 3'ten az
              // görselde otomatik olarak 'grid'e düşer, kullanıcı yine de
              // seçebilir — sonuç sessizce ızgara olur.
              ChoiceChip(
                label: Text(t(context, 'Mozaik (Bento)')),
                selected: _style == 'bento',
                onSelected: (_) {
                  setState(() => _style = 'bento');
                  widget.onStyleChanged?.call('bento');
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GalleryThumb extends StatefulWidget {
  const _GalleryThumb({
    required this.dataUri,
    required this.hasCaption,
    required this.onTap,
    required this.onRemove,
  });

  final String dataUri;
  final bool hasCaption;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode(widget.dataUri);
  }

  @override
  void didUpdateWidget(covariant _GalleryThumb old) {
    super.didUpdateWidget(old);
    // Sadece görsel gerçekten değiştiyse yeniden çöz (ESKİDEN her build'de
    // base64Decode + yeni MemoryImage vardı → sürekli yeniden decode/flicker).
    if (old.dataUri != widget.dataUri) _bytes = _decode(widget.dataUri);
  }

  static Uint8List? _decode(String dataUri) {
    try {
      return base64Decode(dataUri.split(',').last);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 88,
              height: 88,
              color: Colors.grey.shade800,
              // cacheWidth: 88px'lik küçük resim için tam çözünürlüklü
              // (ör. 1080x2340 PNG ≈ 10 MB bitmap) çözmek yerine küçültülmüş
              // çözülür → bellek/CPU çok düşük, beyaz kutu riski azalır.
              child: bytes == null
                  ? const Icon(Icons.broken_image_outlined, color: Colors.white54)
                  : Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 264,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, color: Colors.white54),
                    ),
            ),
          ),
          if (widget.hasCaption)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.label, size: 14, color: Colors.white),
            ),
          Positioned(
            right: -4,
            top: -4,
            child: InkWell(
              onTap: widget.onRemove,
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black87,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
