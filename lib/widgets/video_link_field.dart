import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../templates/html/shared_html_blocks.dart' show videoEmbedUrl;

class VideoLinkField extends StatelessWidget {
  const VideoLinkField({
    super.key,
    required this.urlController,
    required this.orientation,
    required this.onOrientationChanged,
  });

  final TextEditingController urlController;

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

bool isRecognizedVideoUrl(String url) {
  if (url.trim().isEmpty) return true;
  return videoEmbedUrl(url) != null;
}
