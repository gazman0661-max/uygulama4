import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import 'ui_kit.dart';

/// Odullu reklamdan ONCE cikan ozel pencere (v118). Oyuncu "Izle"ye basinca
/// reklam acilir; "Vazgec" derse hicbir sey olmaz. Tum odullu reklam
/// noktalari (watchRewardedAd / AdService.showRewarded) bunu kullanir.
class RewardedPrompt {
  /// Buyuk ikon (emoji), ornek: '💎', '⚡', '🏗️'.
  final String icon;

  /// Baslik. null ise genel "Kisa bir reklam izle".
  final String? title;

  /// Odul satiri, ornek: '+1 ⚡' ya da '-30 dk insaat'. 🪙 karakteri coin gorseline cevrilir.
  final String reward;

  /// Opsiyonel kucuk aciklama (ornek: "Bugun 3/4 hakkin kaldi").
  final String? note;

  /// Analytics icin yer adi (ornek: 'x2_coin', 'town_skip').
  final String placement;

  const RewardedPrompt({
    required this.reward,
    this.icon = '🎬',
    this.title,
    this.note,
    this.placement = 'generic',
  });
}

/// Pencereyi gosterir; true = oyuncu "Izle"ye basti.
Future<bool> showRewardedPrompt(BuildContext context, RewardedPrompt p) async {
  if (!context.mounted) return false;
  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) => _RewardedPromptDialog(prompt: p),
  );
  return res ?? false;
}

class _RewardedPromptDialog extends StatelessWidget {
  final RewardedPrompt prompt;
  const _RewardedPromptDialog({required this.prompt});

  static const Color _ink = Color(0xFF5D2E00);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.instance;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF6E0), Color(0xFFFFE6B8)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFB8741A), width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFB300), width: 4),
              ),
              child: CoinText(prompt.icon, style: const TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 12),
            Text(
              prompt.title ?? s.t('ad_confirm_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0A030), width: 2),
              ),
              child: CoinText(
                prompt.reward,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32)),
              ),
            ),
            if (prompt.note != null) ...[
              const SizedBox(height: 8),
              Text(
                prompt.note!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink.withOpacity(0.7)),
              ),
            ],
            const SizedBox(height: 16),
            CandyButton(
              label: '▶  ${s.t('ad_confirm_watch')}',
              height: 54,
              fontSize: 20,
              style: CandyStyle.green,
              pulse: true,
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppStrings.instance.lt('No thanks'),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
