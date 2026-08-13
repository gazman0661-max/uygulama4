import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Ortak galeri seçici — tüm sektör formlarında kullanılabilir.
///
/// TASARIM KARARI: Backend/upload servisi olmadığı için (yerel, AI'sız
/// üretim akışı) seçilen görseller diske/uzak sunucuya YÜKLENMİYOR;
/// bunun yerine bayt içeriği base64 data URI'ye çevrilip doğrudan
/// `<img src="data:image/jpeg;base64,...">` olarak HTML'e gömülüyor.
/// Bu sayede üretilen site tek bir .html dosyası olarak kalmaya devam
/// ediyor ve dışarıda barındırma gerektirmiyor. Dezavantajı: çok sayıda
/// veya çok büyük görsel dosya boyutunu ciddi artırır — bu yüzden
/// [maxImages] ve basit bir sıkıştırma (maxWidth/imageQuality) uygulanıyor.
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
  });

  final String label;
  final int maxImages;
  final List<Map<String, String?>> initialImages;
  final ValueChanged<List<Map<String, String?>>> onChanged;

  @override
  State<GalleryPickerField> createState() => _GalleryPickerFieldState();
}

class _GalleryPickerFieldState extends State<GalleryPickerField> {
  late final List<Map<String, String?>> _images = List.of(widget.initialImages);
  bool _picking = false;

  Future<void> _pick() async {
    if (_images.length >= widget.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('En fazla ${widget.maxImages} görsel eklenebilir.')),
      );
      return;
    }
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 78,
      );
      if (files.isEmpty) return;

      final remaining = widget.maxImages - _images.length;
      for (final file in files.take(remaining)) {
        final bytes = await file.readAsBytes();
        final ext = file.name.toLowerCase();
        final mime = ext.endsWith('.png')
            ? 'image/png'
            : ext.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
        _images.add({'url': dataUri, 'caption': null});
      }
      widget.onChanged(List.of(_images));
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Görsel eklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _editCaption(int index) async {
    final ctrl = TextEditingController(text: _images[index]['caption'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görsel açıklaması (opsiyonel)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Örn: Öncesi / Sonrası'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Kaydet')),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_images.length}/${widget.maxImages}', style: const TextStyle(color: Colors.grey)),
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
        const Text(
          'Görseller cihazdan seçilir, dosya olarak gömülür (yükleme gerekmez).',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
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
