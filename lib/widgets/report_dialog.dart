import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import 'app_popup.dart';
import '../localization/app_strings.dart';

/// index.html'deki #app-report-overlay modal'ının BİREBİR Flutter karşılığı:
/// 🚩 ikonu + başlık, sebep seçici (dropdown), zorunlu açıklama alanı,
/// İptal / Gönder butonları. Gönderim [ReportService] üzerinden AYNI Apps
/// Script uç noktasına gidiyor.
///
/// [source] hangi ekrandan açıldığını belirler (sohbet mi ön izleme mi).
/// [chatContext] varsa (sohbetten açıldıysa) son kullanıcı isteği + son
/// cevabı; [siteCode] varsa (ön izlemeden açıldıysa) üretilen sitenin TAM
/// HTML kodu — index.html'deki collectChatReportContext() ve `sonKod`
/// eklemesiyle aynı mantık.
Future<void> showReportDialog({
  required BuildContext context,
  required ReportSource source,
  String? chatContext,
  String? siteCode,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _ReportDialogContent(
      source: source,
      chatContext: chatContext,
      siteCode: siteCode,
    ),
  );
}

class _ReportDialogContent extends StatefulWidget {
  final ReportSource source;
  final String? chatContext;
  final String? siteCode;

  const _ReportDialogContent({
    required this.source,
    this.chatContext,
    this.siteCode,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  ReportReason _reason = ReportReason.offensive;
  final _detailsController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final userDetails = _detailsController.text.trim();
    if (userDetails.isEmpty) {
      showAppPopup(context, message: t(context, 'Lütfen kısa bir açıklama yazınız.'), icon: '⚠️');
      return;
    }

    setState(() => _sending = true);

    // index.html > submitReport(): kaynak etiketi + bağlam + (varsa) tam
    // site kodu, "details" alanının içine okunabilir şekilde gömülüyor;
    // Apps Script tarafına hiç dokunmadan mevcut mail akışıyla uyumlu kalır.
    var fullDetails =
        '[${widget.source == ReportSource.preview ? "ÖN İZLEME / ÜRETİLEN SİTE" : "GENEL"}] $userDetails';
    if (widget.chatContext != null && widget.chatContext!.trim().isNotEmpty) {
      fullDetails += '\n\n--- Sohbet Bağlamı ---\n${widget.chatContext!.trim()}';
    }
    if (widget.source == ReportSource.preview &&
        widget.siteCode != null &&
        widget.siteCode!.trim().isNotEmpty) {
      fullDetails += '\n\n--- Bildirilen Sitenin HTML Kodu (Tam) ---\n${widget.siteCode!.trim()}';
    }

    try {
      await ReportService.submit(
        reason: _reason,
        details: fullDetails,
        source: widget.source,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppPopup(context,
          message: t(context, 'Bildirimin bize ulaştı, teşekkürler! En kısa sürede inceleyeceğiz. 🙏'),
          icon: '✅');
    } on ReportException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppPopup(context, message: e.message, icon: '⚠️');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppPopup(context, message: '${isEnglish(context) ? 'Report could not be sent' : 'Bildirim gönderilemedi'}: $e', icon: '⚠️');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accentRed, width: 1.4),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🚩', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(context, 'İçeriği Bildir'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                InkWell(
                  onTap: _sending ? null : () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white54, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            // Sebep seçici (index.html > #app-report-reason)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ReportReason>(
                  value: _reason,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF141821),
                  iconEnabledColor: Colors.white54,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                  items: ReportReason.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(t(context, r.label))))
                      .toList(),
                  onChanged: _sending
                      ? null
                      : (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Açıklama (index.html > #app-report-details, zorunlu)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _detailsController,
                enabled: !_sending,
                autofocus: true,
                minLines: 3,
                maxLines: 4,
                maxLength: 600,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: t(context, 'Kısaca açıkla (zorunlu)...'),
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  counterStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(t(context, 'İptal'), style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _sending ? null : _send,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    t(context, 'Gönder 🚩'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
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
