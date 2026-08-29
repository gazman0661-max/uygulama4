import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../services/ads_service.dart';

/// widgets/confirm_popup.dart ile AYNI görsel dilde, "İndir"/"Yayınla"
/// butonlarına basıldığında açılan özel rewarded-reklam onay popup'ı.
///
/// Kullanıcı "Tamam"a basarsa AdsService.showRewardedAd çağrılır ve reklam
/// AÇILIR; kullanıcı reklamı sonuna kadar izlerse (veya reklam altyapısı şu
/// an kullanılamıyorsa) asıl işlem (indirme/yayınlama) devam eder. Kullanıcı
/// popup'ı "Vazgeç" ile kapatırsa ya da reklamı yarıda bırakırsa işlem
/// BAŞLAMAZ.
///
/// Döner: işleme devam edilmeli mi (true) yoksa vazgeçildi mi (false).
Future<bool> showRewardedAdGate(
  BuildContext context, {
  required String message,
  String icon = '🎬',
  String placement = 'download_publish',
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: false,
    builder: (ctx) => _RewardedAdGateDialog(
      message: message,
      icon: icon,
      placement: placement,
    ),
  );
  return proceed ?? false;
}

class _RewardedAdGateDialog extends StatefulWidget {
  const _RewardedAdGateDialog({
    required this.message,
    required this.icon,
    required this.placement,
  });

  final String message;
  final String icon;
  final String placement;

  @override
  State<_RewardedAdGateDialog> createState() => _RewardedAdGateDialogState();
}

class _RewardedAdGateDialogState extends State<_RewardedAdGateDialog> {
  bool _loading = false;

  Future<void> _watchAd() async {
    setState(() => _loading = true);
    final rewarded = await AdsService.instance.showRewardedAd(placement: widget.placement);
    if (!mounted) return;
    // rewarded==false SADECE kullanıcı reklamı gerçekten yarıda bıraktığında
    // olur (reklam altyapısı kullanılamıyorsa AdsService zaten true döner) —
    // bu durumda popup kapanır ama işlem BAŞLAMAZ, kullanıcı isterse tekrar
    // dener.
    Navigator.of(context).pop(rewarded);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
            Text(widget.icon, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              t(context, widget.message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                    child: Text(t(context, 'Vazgeç'),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _watchAd,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(t(context, 'Tamam'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace')),
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
