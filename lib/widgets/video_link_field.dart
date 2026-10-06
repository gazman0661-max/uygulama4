import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/shared_html_blocks.dart' show videoEmbedUrl;

/// 05.09.2026 eklendi — Video bloğu (kanka isteği: "sitede güzel görünsün,
/// dikey/yatay ikisi de sorunsuz oynasın").
///
/// [GoogleReviewLinkField]/[LocationPickerField] ile AYNI basit kalıp:
/// kullanıcı bir YouTube/Vimeo LİNKİ yapıştırır (dosya yüklemez — bkz.
/// templates/html/shared_html_blocks.dart > videoBlockHtml dokümanı: bu
/// yüzden worker/R2 maliyeti YOKTUR). Ayrıca videonun "Yatay" (normal video)
/// mı yoksa "Dikey" (Shorts/Reels tarzı) mi olduğunu seçtirir — bu seçim,
/// üretilen sitede videonun doğru en-boy oranıyla ve doğru genişlikte
/// (dikey video için daralmış, telefon ekranı gibi zarif bir kutu)
/// gösterilmesini sağlar (bkz. videoBlockHtml > orientation parametresi).
///
/// Kullanım: her form ekranında [urlController] ve [orientation]/
/// [onOrientationChanged] ile `_videoUrlCtrl` / `_videoOrientation` state'ine
/// bağlanır, `_captureFormData`/`_restoreFromInitialData`'ya eklenir ve
/// generator çağrısına şu şekilde geçirilir:
///   if (_videoUrlCtrl.text.trim().isNotEmpty)
///     videoBlockHtml(title: labels['videoTitle']!, videoUrl: _videoUrlCtrl.text.trim(), orientation: _videoOrientation, lang: _siteLang)
class VideoLinkField extends StatelessWidget {
  const VideoLinkField({
    super.key,
    required this.urlController,
    required this.orientation,
    required this.onOrientationChanged,
  });

  final TextEditingController urlController;

  /// 'landscape' (yatay) | 'portrait' (dikey)
  final String orientation;
  final ValueChanged<String> onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    final tr = isEnglish(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: t(context, 'Video Linki (opsiyonel)'),
            hintText: 'https://youtube.com/... veya https://vimeo.com/...',
            helperText: tr
                ? 'YouTube or Vimeo link. The video plays directly from YouTube/Vimeo — nothing is uploaded.'
                : 'YouTube veya Vimeo linki. Video doğrudan YouTube/Vimeo üzerinden oynar — hiçbir şey yüklenmez.',
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Text(t(context, 'Video Yönü'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'landscape',
              label: Text(t(context, 'Yatay')),
              icon: const Icon(Icons.crop_landscape_rounded, size: 18),
            ),
            ButtonSegment(
              value: 'portrait',
              label: Text(t(context, 'Dikey')),
              icon: const Icon(Icons.crop_portrait_rounded, size: 18),
            ),
          ],
          selected: {orientation},
          onSelectionChanged: (s) => onOrientationChanged(s.first),
        ),
      ],
    );
  }
}

/// Form gönderilirken linkin tanınıp tanınmadığını kontrol etmek için
/// yardımcı — tanınmıyorsa (boş embed) kullanıcıya uyarı gösterilebilir.
/// bkz. videoBlockHtml zaten tanımadığı linki sessizce atlıyor; bu fonksiyon
/// isteğe bağlı olarak form tarafında ERKEN uyarı vermek içindir.
bool isRecognizedVideoUrl(String url) {
  if (url.trim().isEmpty) return true; // boşsa "sorun yok", zaten eklenmeyecek
  return videoEmbedUrl(url) != null;
}
