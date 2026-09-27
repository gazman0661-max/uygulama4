import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_button.dart';
import '../localization/app_strings.dart';
import '../widgets/app_popup.dart';

/// QR kod üretici. Tamamen yerel bir üretim olduğu için (form
/// akışıyla aynı kategoride) her "Oluştur" işlemi doğrudan yerel olarak yapılır.
class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _controller = TextEditingController();
  final _repaintKey = GlobalKey();

  // Kullanıcı yazdıkça anında/bedavaya QR üretilmesin diye, ekranda
  // görünen QR ile input metni ayrı tutuluyor: yalnızca "Oluştur"a
  // basınca _generatedData set edilir.
  String? _generatedData;
  bool _generating = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _generating = true);
    if (mounted) {
      setState(() {
        _generatedData = text;
        _generating = false;
      });
    }
  }

  Future<Uint8List?> _captureQrPng() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_generatedData == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureQrPng();
      if (bytes == null) throw Exception('QR görseli oluşturulamadı.');
      final saved = await DownloadService.pickAndSavePng(
          pngBytes: bytes, isEnglish: isEnglish(context));
      if (mounted && saved) {
        showAppPopup(context, message: t(context, 'QR kod PNG olarak kaydedildi! ✅'), icon: '✅');
      }
    } catch (e) {
      if (mounted) {
        showAppPopup(context, message: 
                '${isEnglish(context) ? 'Could not save' : 'Kaydedilemedi'}: $e', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    if (_generatedData == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureQrPng();
      if (bytes == null) throw Exception('QR görseli oluşturulamadı.');
      await DownloadService.sharePng(
          pngBytes: bytes, fileName: 'qr-kod.png', isEnglish: isEnglish(context));
    } catch (e) {
      if (mounted) {
        showAppPopup(context, message: 
                '${isEnglish(context) ? 'Could not share' : 'Paylaşılamadı'}: $e', icon: '⚠️');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _generating || _saving;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'QR Kod Oluştur'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: t(context, 'Link, wifi bilgisi veya metin'),
                  hintText: t(context, 'https://ornek.com'),
                  border: OutlineInputBorder(),
                ),
                // Metin değiştiğinde önceki üretilmiş QR'ı otomatik
                // GEÇERSİZ kılmıyoruz (kullanıcı ürettiği QR'ı
                // kaybetmesin); yeniden "Oluştur"a basması gerekir.
              ),
              const SizedBox(height: 12),
              PillButton(
                label: t(context, _generating ? 'Oluşturuluyor...' : 'QR Oluştur'),
                borderColor: AppTheme.accentPurple,
                textColor: AppTheme.accentPurple,
                onTap: busy ? null : _generate,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: _generatedData == null
                      ? Text(
                          t(context, 'QR kodun burada görünecek'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : RepaintBoundary(
                          key: _repaintKey,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            color: Colors.white,
                            child: QrImageView(
                              data: _generatedData!,
                              version: QrVersions.auto,
                              size: 240,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: t(context, _saving ? 'Kaydediliyor...' : 'PNG Kaydet'),
                      borderColor: AppTheme.accentBlue,
                      textColor: AppTheme.accentBlue,
                      onTap: (busy || _generatedData == null) ? null : _save,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: t(context, 'Paylaş'),
                      borderColor: AppTheme.accentGreenLink,
                      textColor: AppTheme.accentGreenLink,
                      onTap: (busy || _generatedData == null) ? null : _share,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
