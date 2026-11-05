import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gezegenlere SEVIMLI YUZ (v215): gorsel dosya yok, hepsi kodla cizilir ve CANLIDIR.
/// Hafta sonu etkinligi (Gezegen Birlestir) icin.
///
/// Her gezegenin (id'sine gore) kendi zamanlamasi var -> hepsi ayni anda goz kirpmaz:
///  * Goz kirpma: ~2-4 sn'de bir (yumusak kapanip acilir).
///  * Ara sira: dil cikarma, goz kirpma (wink), saskinlik, mutlu kapali gozler (^ ^).
///  * Disaridan gelen durumlar: yeni birlesti -> sevinc, hizla dusuyor -> saskin,
///    tehlike cizgisine yakin -> endiseli (ter damlasi).
///  * Gozbebekleri yavasca etrafa bakar, yuz hafifce yalpalar.
/// Tum sureler/oranlar asagidaki sabitlerden ayarlanabilir.
enum PlanetMood { smile, tongue, wink, shock, joy, worry }

class PlanetFace {
  PlanetFace._();

  /// Gorselin (256x256) icinde GEZEGEN GOVDESININ cap orani (halka/parlama haric), kademe basina.
  /// Yuz bu govdenin uzerine oturur (halkali Uranus/Saturn'de govde kucuktur).
  static const List<double> bodyFrac = [
    0.926, 0.816, 0.816, 0.777, 0.926, 0.66, 0.926, 0.926, 0.527, 0.523, 0.926, 0.68, 0.72,
  ];

  // --- ayarlar ---
  static const double blinkBase = 2.2; // sn: goz kirpma periyodu = base + (id%4)*0.5 (=> 2.2..3.7 sn)
  static const double blinkLen = 0.16; // sn: tek goz kirpma suresi
  static const double moodBase = 7.0; // sn: ozel ifade periyodu = base + (id%5)*0.9
  static const double fallSpeed = 30.0; // bu dikey hizdan hizli dusen gezegen saskin olur

  static const Color _ink = Color(0xFF2B1620);
  static const Color _inkLight = Color(0xFFFFE0E8); // koyu gezegende (Karanlik Kutle) acik cizgi
  static const Color _blush = Color(0xFFFF6F91);
  static const Color _tongue = Color(0xFFFF5C8A);
  static const Color _mouthIn = Color(0xFF7A1F3D);

  /// Kademenin govde yaricapi, [d] = cizilen gorselin kenar uzunlugu.
  static double bodyRadius(int tier, double d) => bodyFrac[tier.clamp(0, bodyFrac.length - 1).toInt()] * 0.5 * d;

  /// O anki ifade. [pop] > 0: yeni birlesti, [vy]: dikey hiz, [worried]: tehlikede.
  static PlanetMood moodAt(int id, double t, {double pop = 0, double vy = 0, bool worried = false}) {
    if (pop > 0.05) return PlanetMood.joy;
    if (vy > fallSpeed) return PlanetMood.shock;
    if (worried) return PlanetMood.worry;
    final per = moodBase + (id % 5) * 0.9;
    final shifted = t + id * 1.37;
    final slot = (shifted / per).floor();
    final ph = shifted - slot * per;
    final k = (slot + id).abs() % 4;
    const lens = [1.5, 0.9, 1.1, 1.3]; // tongue, wink, shock, joy
    final start = per * 0.5;
    if (ph >= start && ph < start + lens[k]) {
      switch (k) {
        case 0:
          return PlanetMood.tongue;
        case 1:
          return PlanetMood.wink;
        case 2:
          return PlanetMood.shock;
        default:
          return PlanetMood.joy;
      }
    }
    return PlanetMood.smile;
  }

  /// 0 = tamamen kapali, 1 = acik (goz kirpma egrisi).
  static double eyeOpen(int id, double t) {
    final bp = blinkBase + (id % 4) * 0.5;
    final ph = (t + id * 0.73) % bp;
    if (ph >= blinkLen) return 1.0;
    return (1.0 - math.sin(ph / blinkLen * math.pi)).clamp(0.0, 1.0).toDouble();
  }

  /// [bodyR] gezegen govdesinin yaricapi (cizim birimi); (x, y) govde merkezi.
  static void paint(
    Canvas c, {
    required int tier,
    required int id,
    required double x,
    required double y,
    required double bodyR,
    required double t,
    double pop = 0,
    double vy = 0,
    bool worried = false,
    double opacity = 1.0,
  }) {
    if (bodyR <= 0.5 || opacity <= 0.02) return;
    final mood = moodAt(id, t, pop: pop, vy: vy, worried: worried);
    var open = eyeOpen(id, t);
    final ink = tier == 12 ? _inkLight : _ink;
    final R = bodyR;

    // Yuz hafifce yalpalar + gozbebekleri etrafa bakar.
    final cx = x + math.sin(t * 0.9 + id) * 0.04 * R;
    final cy = y + math.cos(t * 0.7 + id * 2) * 0.03 * R;
    final lookX = math.sin(t * 0.6 + id * 1.7) * 0.35;
    final lookY = math.cos(t * 0.45 + id * 0.9) * 0.2;

    Color a(Color col, [double k = 1.0]) => col.withOpacity((col.opacity * k * opacity).clamp(0.0, 1.0).toDouble());
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = R * 0.07
      ..color = a(ink);
    final fill = Paint()..style = PaintingStyle.fill;

    // Yanaklar (allik).
    fill.color = a(_blush, 0.42);
    for (final s in const [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(cx + s * R * 0.55, cy + R * 0.2), width: R * 0.3, height: R * 0.18), fill);
    }

    // ---- GOZLER ----
    final ex = R * 0.3;
    final ey = cy - R * 0.1;
    var er = R * 0.19; // goz (beyaz) yaricapi
    var pupilK = 0.58; // gozbebegi / goz orani
    // Ifadeye gore goz tipi: 0 acik, 1 kapali cizgi, 2 mutlu ^
    var leftType = 0, rightType = 0;
    switch (mood) {
      case PlanetMood.smile:
        break;
      case PlanetMood.tongue:
        leftType = 2;
        rightType = 2;
        break;
      case PlanetMood.wink:
        if (id.isEven) {
          leftType = 1;
        } else {
          rightType = 1;
        }
        break;
      case PlanetMood.shock:
        er = R * 0.24;
        pupilK = 0.38;
        open = 1.0;
        break;
      case PlanetMood.joy:
        leftType = 2;
        rightType = 2;
        break;
      case PlanetMood.worry:
        pupilK = 0.5;
        break;
    }
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final type = i == 0 ? leftType : rightType;
      final px = cx + side * ex;
      if (type == 2) {
        // ^ seklinde mutlu goz
        final p = Path()
          ..moveTo(px - er * 0.95, ey + er * 0.35)
          ..quadraticBezierTo(px, ey - er * 1.15, px + er * 0.95, ey + er * 0.35);
        c.drawPath(p, line..strokeWidth = R * 0.075);
        continue;
      }
      if (type == 1 || open < 0.22) {
        // kapali goz: hafif asagi kavisli cizgi
        final p = Path()
          ..moveTo(px - er * 0.9, ey)
          ..quadraticBezierTo(px, ey + er * 0.55, px + er * 0.9, ey);
        c.drawPath(p, line..strokeWidth = R * 0.075);
        continue;
      }
      // acik goz: beyaz + gozbebegi + parilti
      final h = er * 2 * (type == 0 ? open : 1.0);
      final rect = Rect.fromCenter(center: Offset(px, ey), width: er * 2, height: h);
      fill.color = a(Colors.white);
      c.drawOval(rect, fill);
      c.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = R * 0.03
          ..color = a(ink, 0.55),
      );
      final pr = er * pupilK;
      final pc = Offset(px + lookX * er * 0.35, ey + lookY * er * 0.3);
      c.save();
      c.clipPath(Path()..addOval(rect));
      fill.color = a(_ink); // gozbebegi her zaman koyu (beyaz gozun icinde)
      c.drawOval(Rect.fromCenter(center: pc, width: pr * 2, height: pr * 2 * math.min(1.0, open + 0.15)), fill);
      fill.color = a(Colors.white);
      c.drawCircle(Offset(pc.dx - pr * 0.35, pc.dy - pr * 0.35), pr * 0.32, fill);
      c.restore();
    }

    // Endiseli: kaslar + ter damlasi.
    if (mood == PlanetMood.worry) {
      for (final s in const [-1.0, 1.0]) {
        final px = cx + s * ex;
        c.drawLine(
          Offset(px - s * er * 0.9, ey - er * 1.55),
          Offset(px + s * er * 0.9, ey - er * 1.1),
          line..strokeWidth = R * 0.055,
        );
      }
      fill.color = a(const Color(0xFF7FD6FF));
      final dx = cx + R * 0.72, dy = cy - R * 0.25;
      final drop = Path()
        ..moveTo(dx, dy - R * 0.14)
        ..quadraticBezierTo(dx + R * 0.1, dy + R * 0.02, dx, dy + R * 0.08)
        ..quadraticBezierTo(dx - R * 0.1, dy + R * 0.02, dx, dy - R * 0.14);
      c.drawPath(drop, fill);
    }

    // ---- AGIZ ----
    final mx = cx;
    final my = cy + R * 0.3;
    line.strokeWidth = R * 0.07;
    switch (mood) {
      case PlanetMood.smile:
      case PlanetMood.wink:
        final p = Path()
          ..moveTo(mx - R * 0.2, my - R * 0.02)
          ..quadraticBezierTo(mx, my + R * 0.24, mx + R * 0.2, my - R * 0.02);
        c.drawPath(p, line);
        break;
      case PlanetMood.tongue:
        // Gulumseme + saga dogru disari cikan dil.
        final p = Path()
          ..moveTo(mx - R * 0.22, my - R * 0.03)
          ..quadraticBezierTo(mx, my + R * 0.22, mx + R * 0.22, my - R * 0.03);
        fill.color = a(_tongue);
        final tongueRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(mx + R * 0.0, my + R * 0.05, R * 0.2, R * 0.27),
          Radius.circular(R * 0.1),
        );
        c.drawRRect(tongueRect, fill);
        c.drawLine(
          Offset(mx + R * 0.1, my + R * 0.1),
          Offset(mx + R * 0.1, my + R * 0.22),
          Paint()
            ..color = a(const Color(0xFFC2185B))
            ..strokeWidth = R * 0.025
            ..strokeCap = StrokeCap.round,
        );
        c.drawPath(p, line);
        break;
      case PlanetMood.shock:
        // Saskin "O" agiz.
        final rect = Rect.fromCenter(center: Offset(mx, my + R * 0.06), width: R * 0.2, height: R * 0.27);
        fill.color = a(_mouthIn);
        c.drawOval(rect, fill);
        c.drawOval(rect, line..strokeWidth = R * 0.05);
        break;
      case PlanetMood.joy:
        // Acik, kocaman gulumseme (D sekli) + ic dil.
        final w = R * 0.27;
        final p = Path()
          ..moveTo(mx - w, my - R * 0.04)
          ..quadraticBezierTo(mx, my + R * 0.08, mx + w, my - R * 0.04)
          ..quadraticBezierTo(mx + w * 0.8, my + R * 0.3, mx, my + R * 0.32)
          ..quadraticBezierTo(mx - w * 0.8, my + R * 0.3, mx - w, my - R * 0.04)
          ..close();
        fill.color = a(_mouthIn);
        c.drawPath(p, fill);
        c.save();
        c.clipPath(p);
        fill.color = a(_tongue);
        c.drawOval(Rect.fromCenter(center: Offset(mx, my + R * 0.3), width: R * 0.3, height: R * 0.2), fill);
        c.restore();
        c.drawPath(p, line..strokeWidth = R * 0.05);
        break;
      case PlanetMood.worry:
        // Titrek, hafif asagi kavisli agiz.
        final p = Path()
          ..moveTo(mx - R * 0.17, my + R * 0.08)
          ..quadraticBezierTo(mx - R * 0.08, my - R * 0.02, mx, my + R * 0.06)
          ..quadraticBezierTo(mx + R * 0.08, my + R * 0.14, mx + R * 0.17, my + R * 0.04);
        c.drawPath(p, line);
        break;
    }
  }
}

/// Kucuk onizlemelerde (ornegin "Sonraki" gezegen) gorselin ustune yuz cizer.
/// Zamani [time] disaridan verilir (ekran zaten her karede yeniden cizilir).
class PlanetFaceOverlay extends StatelessWidget {
  final int tier;
  final int id;
  final double time;
  const PlanetFaceOverlay({super.key, required this.tier, required this.time, this.id = 7000});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _FaceOnlyPainter(tier, id, time)),
    );
  }
}

class _FaceOnlyPainter extends CustomPainter {
  final int tier;
  final int id;
  final double time;
  _FaceOnlyPainter(this.tier, this.id, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height); // BoxFit.contain: gorsel bu kareye oturur
    PlanetFace.paint(
      canvas,
      tier: tier,
      id: id + tier,
      x: size.width / 2,
      y: size.height / 2,
      bodyR: PlanetFace.bodyRadius(tier, d),
      t: time,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceOnlyPainter old) => old.time != time || old.tier != tier;
}
