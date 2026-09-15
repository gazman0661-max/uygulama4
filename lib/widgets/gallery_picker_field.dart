import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../localization/app_strings.dart';
import '../services/image_compress_service.dart';
import '../state/app_state.dart';
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
/// 04.09.2026 eklendi — "Ücretsiz plan kısıtlamaları" işi (kanka isteği):
/// free plan'da (bkz. AppState.qtCurrentIsPremium) galeri en fazla
/// [kFreePlanGalleryMax] (3) görsel olabiliyor — kapak fotoğrafı zaten HER
/// formda maxImages:1 ile açılıyor, yani "1 kapak" kısıtlaması zaten
/// yapısal olarak var, ayrıca bir şey yapmaya gerek yok. Bu widget PROJE
/// BAZLI kontrol ediyor (hesap geneli değil): domain bağlanıp premium olan
/// SİTE galeri limitsiz (formun kendi maxImages'ı, örn. 12) kalırken, aynı
/// hesabın başka/yeni bir sitesi hâlâ free limitte kalır — bkz.
/// SiteProject.isPremium yorumu.
///
/// Döndürdüğü veri şekli, generator'ların beklediği ile birebir aynı:
/// `List<Map<String, String?>>` — {'url': ..., 'caption': ...}
class GalleryPickerField extends StatefulWidget {
  const GalleryPickerField({
    super.key,
    required this.onChanged,
    this.label = 'Galeri',
    this.maxImages = 12,
    this.initialImages = const [],
    this.showStyleOption = false,
    this.initialStyle = 'grid',
    this.onStyleChanged,
  });

  /// Free plan'da galeri için uygulanan tavan. Kapak alanları zaten
  /// maxImages:1 ile açıldığından bu değerden düşük kaldıkları için
  /// etkilenmezler.
  static const int kFreePlanGalleryMax = 3;

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

class _GalleryPickerFieldState extends State<GalleryPickerField> {
  late final List<Map<String, String?>> _images = List.of(widget.initialImages);
  late String _style = widget.initialStyle;
  bool _picking = false;

  /// Bu formun bağlı olduğu proje premium mi (bkz. AppState.qtCurrentIsPremium)
  /// — değilse [widget.maxImages] [GalleryPickerField.kFreePlanGalleryMax]
  /// ile sınırlanır. [listen] false verildiğinde (ör. _pick içindeki tek
  /// seferlik kontrol) gereksiz rebuild tetiklenmez.
  int _effectiveMax(BuildContext context, {bool listen = true}) {
    final isPremium = listen
        ? context.watch<AppState>().qtCurrentIsPremium
        : context.read<AppState>().qtCurrentIsPremium;
    if (isPremium) return widget.maxImages;
    return widget.maxImages < GalleryPickerField.kFreePlanGalleryMax
        ? widget.maxImages
        : GalleryPickerField.kFreePlanGalleryMax;
  }

  Future<void> _pick() async {
    final maxImages = _effectiveMax(context, listen: false);
    if (_images.length >= maxImages) {
      final isPremium = context.read<AppState>().qtCurrentIsPremium;
      final capped = !isPremium && widget.maxImages > maxImages;
      showAppPopup(
        context,
        message: isEnglish(context)
            ? (capped
                ? 'The free plan allows up to $maxImages images here. Upgrade to Premium for more.'
                : 'You can add up to $maxImages images.')
            : (capped
                ? 'Ücretsiz planda burada en fazla $maxImages görsel eklenebilir. Daha fazlası için Premium\'a geç.'
                : 'En fazla $maxImages görsel eklenebilir.'),
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
    final maxImages = _effectiveMax(context);
    final isCapped = maxImages < widget.maxImages;
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
        // 04.09.2026 eklendi — free plan'da tavan formun kendi maxImages
        // değerinden düşükse (yani gerçekten kısıldıysa) küçük bir bilgi
        // notu gösterilir; kapak gibi zaten maxImages:1 olan alanlarda
        // isCapped hep false kalır, gereksiz not çıkmaz.
        if (isCapped) ...[
          const SizedBox(height: 4),
          Text(
            isEnglish(context)
                ? 'Free plan limit: $maxImages. Premium allows up to ${widget.maxImages}.'
                : 'Ücretsiz plan sınırı: $maxImages. Premium\'da ${widget.maxImages}\'e kadar.',
            style: const TextStyle(fontSize: 11, color: Colors.orange),
          ),
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
            ],
          ),
        ],
      ],
    );
  }
}

class _GalleryThumb extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      final base64Part = dataUri.split(',').last;
      bytes = base64Decode(base64Part);
    } catch (_) {
      bytes = null;
    }
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade200,
              image: bytes != null
                  ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                  : null,
            ),
          ),
          if (hasCaption)
            const Positioned(
              left: 4,
              bottom: 4,
              child: Icon(Icons.label, size: 14, color: Colors.white),
            ),
          Positioned(
            right: -4,
            top: -4,
            child: InkWell(
              onTap: onRemove,
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
