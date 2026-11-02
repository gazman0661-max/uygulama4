import 'package:flutter/material.dart';
import '../models/food_order.dart';
import '../models/game_theme.dart';

/// Siparis fisi: istenen objenin gorseli, seviye ve coin odulu. Sureli siparişte
/// kalan SANIYE sayisi kartin altinda net gorunur (son 10 sn kirmizi + nabiz).
/// [size]: kart kenari (kart sayisi azaldikca buyur); ic olculer buna gore olceklenir.
class OrderCardView extends StatelessWidget {
  final FoodOrder order;
  final GameTheme theme;
  final bool deliverable;
  final double size;

  /// Kalan sure orani (1.0 dolu -> 0.0 bitti). null = suresiz siparis.
  final double? timeFraction;

  /// Kalan saniye (sureli siparis). null = suresiz.
  final int? secondsLeft;

  const OrderCardView({
    super.key,
    required this.order,
    required this.theme,
    this.deliverable = false,
    this.size = 92,
    this.timeFraction,
    this.secondsLeft,
  });

  static String fmt(int secs) {
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    final r = secs % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final k = size / 92.0;
    final tier = theme.byLevel(order.level);
    final frac = timeFraction;
    final low = secondsLeft != null && secondsLeft! <= 10;
    final barColor = frac == null
        ? Colors.green.shade500
        : (frac > 0.5 ? Colors.green.shade500 : (frac > 0.25 ? Colors.amber.shade600 : Colors.red.shade600));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * k),
        boxShadow: deliverable
            ? [BoxShadow(color: Colors.green.withOpacity(0.55), blurRadius: 10, spreadRadius: 1)]
            : const [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/order_card_frame.webp', fit: BoxFit.contain),
          ),
          // Icerik (klips alanini atlayip kagit yuzeyinde).
          Padding(
            padding: EdgeInsets.only(top: 14 * k, bottom: frac != null ? 12 * k : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(tier.imagePath, width: 42 * k, height: 42 * k),
                SizedBox(height: 1 * k),
                Text(
                  order.anyAbove ? 'Lv${tier.level}+' : 'Lv${tier.level}',
                  style: TextStyle(
                    fontSize: 10 * k,
                    fontWeight: FontWeight.bold,
                    color: order.anyAbove ? Colors.deepPurple : Colors.black87,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${order.reward} ', style: TextStyle(fontSize: 11 * k, fontWeight: FontWeight.w700)),
                    Image.asset('assets/images/coin_icon.webp', width: 12 * k, height: 12 * k),
                  ],
                ),
              ],
            ),
          ),
          // Sure seridi: cubuk + ortada kalan saniye.
          if (frac != null)
            Positioned(
              left: 10 * k,
              right: 10 * k,
              bottom: 4 * k,
              height: 15 * k,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * k),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black38),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: frac.clamp(0.0, 1.0).toDouble(),
                      child: Container(color: low ? Colors.red.shade600 : barColor),
                    ),
                    if (secondsLeft != null)
                      Center(
                        child: Text(
                          '\u23F1 ${fmt(secondsLeft!)}',
                          style: TextStyle(
                            fontSize: 10.5 * k,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 2)],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
