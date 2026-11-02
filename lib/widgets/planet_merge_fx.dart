import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/planet_physics.dart';

/// HAFTA SONU ETKINLIGI (Gezegen Birlestir): BIRLESME EFEKTI (v223).
///
/// Iki gezegen birlesince eskiden biri aniden yok olup yenisi beliriyordu; oyuncu ne oldugunu
/// anlamiyordu. Simdi sirayla sunlar olur (hepsi DUNYA BIRIMLERINDE, 100 x 150 tahta):
///  1. HAYALET: eski iki gezegen ~0.16 sn birlesme noktasina dogru kayip kuculur,
///  2. PARLAMA: birlesme noktasinda gezegen renginde isik patlamasi,
///  3. HALKA: genisleyen sok dalgasi (kombo varsa ikinci, altin halka),
///  4. KIVILCIM: yildiz/nokta parcaciklari sacilir (kademe yukseldikce daha cok),
///  5. TITRESIM: buyuk kademelerde (>=6) tahta hafifce sarsilir.
/// Fizige/skora DOKUNMAZ; yalnizca cizim. Parcacik sayisi sinirlidir ([_maxSparks]).
class PlanetMergeFx {
  static const int _maxSparks = 240;
  static const double _ghostLife = 0.16;

  /// Kademe renkleri (0..12): Merkur, Kizil Cuce, Bakir Asteroit, Buz Ay, Mars, Dunya, Gaia,
  /// Neptun, Uranus, Saturn, Pembe Gaz Devi, Gunes, Karanlik Kutle.
  static const List<Color> tierColors = [
    Color(0xFFBDBDBD), Color(0xFFFF5252), Color(0xFFE0955A), Color(0xFF80DEEA), Color(0xFFFF7043),
    Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFF5C6BC0), Color(0xFF4DD0E1), Color(0xFFFFD54F),
    Color(0xFFF06292), Color(0xFFFFB300), Color(0xFFAB47BC),
  ];

  final math.Random _rng = math.Random();
  final List<_Ghost> _ghosts = [];
  final List<_Flash> _flashes = [];
  final List<_Ring> _rings = [];
  final List<_Spark> _sparks = [];

  double _shakeT = 0;
  double _shakeDur = 0.01;
  double _shakeAmp = 0;

  /// Tahta sarsintisi (dunya birimi); painter canvas'i bu kadar kaydirir.
  double shakeX = 0;
  double shakeY = 0;

  bool get isEmpty => _ghosts.isEmpty && _flashes.isEmpty && _rings.isEmpty && _sparks.isEmpty && _shakeT <= 0;
  int get sparkCount => _sparks.length;

  void clear() {
    _ghosts.clear();
    _flashes.clear();
    _rings.clear();
    _sparks.clear();
    _shakeT = 0;
    shakeX = 0;
    shakeY = 0;
  }

  static double _easeOut(double p) {
    final q = 1.0 - p.clamp(0.0, 1.0);
    return 1.0 - q * q * q;
  }

  /// Bir birlesme olayi icin efektleri baslatir.
  void spawn(PlanetMergeEvent e) {
    final vanish = e.tier < 0;
    final tier = vanish ? PlanetConfig.tierCount - 1 : e.tier.clamp(0, PlanetConfig.tierCount - 1).toInt();
    final r = PlanetConfig.radiusOf(tier);
    final base = tierColors[tier];

    // 1) Hayaletler: eski iki gezegen birlesme noktasina kayar.
    if (e.parentTier >= 0 && e.parentTier < PlanetConfig.tierCount) {
      _ghosts.add(_Ghost(e.parentTier, e.ax, e.ay, e.x, e.y));
      _ghosts.add(_Ghost(e.parentTier, e.bx, e.by, e.x, e.y));
    }

    // 2) Parlama.
    _flashes.add(_Flash(e.x, e.y, r * (vanish ? 4.5 : 2.4), vanish ? 0.6 : 0.34, vanish ? Colors.white : base));

    // 3) Sok dalgasi halkalari.
    _rings.add(_Ring(e.x, e.y, r * 0.8, r * (vanish ? 3.6 : 2.3), vanish ? 0.7 : 0.45, 1.6 + tier * 0.12, Colors.white));
    if (e.combo >= 2 || vanish) {
      _rings.add(_Ring(e.x, e.y, r * 0.5, r * (vanish ? 5.0 : 3.1), 0.6, 1.2 + math.min(e.combo, 6) * 0.15, Colors.amberAccent));
    }

    // 4) Kivilcimlar.
    final n = vanish ? 70 : (12 + tier * 2 + (e.combo >= 2 ? 6 : 0)).clamp(12, 44).toInt();
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = 25 + _rng.nextDouble() * (50 + tier * 3);
      final roll = _rng.nextDouble();
      final Color col;
      if (vanish) {
        col = HSVColor.fromAHSV(1, _rng.nextDouble() * 360, 0.55, 1).toColor();
      } else if (roll < 0.45) {
        col = base;
      } else if (roll < 0.75) {
        col = Colors.white;
      } else {
        col = Colors.amberAccent;
      }
      _sparks.add(_Spark(
        x: e.x + math.cos(a) * r * 0.6,
        y: e.y + math.sin(a) * r * 0.6,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp - 10,
        life: 0.45 + _rng.nextDouble() * 0.45,
        size: 0.7 + _rng.nextDouble() * (1.0 + tier * 0.08),
        color: col,
        star: _rng.nextDouble() < 0.35,
        rot: _rng.nextDouble() * math.pi,
        spin: (_rng.nextDouble() - 0.5) * 8,
      ));
    }
    final over = _sparks.length - _maxSparks;
    if (over > 0) _sparks.removeRange(0, over);

    // 5) Tahta titremesi: yalnizca buyuk kademelerde.
    if (vanish || tier >= 6) {
      final amp = vanish ? 1.6 : 0.35 + (tier - 6) * 0.12;
      if (amp >= _shakeAmp * (_shakeT / _shakeDur)) {
        _shakeAmp = amp;
        _shakeDur = vanish ? 0.5 : 0.28;
        _shakeT = _shakeDur;
      }
    }
  }

  void update(double dt) {
    for (final g in _ghosts) {
      g.age += dt;
    }
    _ghosts.removeWhere((g) => g.age >= _ghostLife);
    for (final f in _flashes) {
      f.age += dt;
    }
    _flashes.removeWhere((f) => f.age >= f.life);
    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= r.life);
    for (final s in _sparks) {
      s.age += dt;
      s.vy += 70 * dt; // hafif yercekimi
      final drag = (1.0 - 1.6 * dt).clamp(0.0, 1.0).toDouble();
      s.vx *= drag;
      s.vy *= drag;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.rot += s.spin * dt;
    }
    _sparks.removeWhere((s) => s.age >= s.life);

    if (_shakeT > 0) {
      _shakeT = math.max(0.0, _shakeT - dt);
      final k = _shakeT / _shakeDur;
      shakeX = (_rng.nextDouble() - 0.5) * 2 * _shakeAmp * k;
      shakeY = (_rng.nextDouble() - 0.5) * 2 * _shakeAmp * k;
    } else {
      shakeX = 0;
      shakeY = 0;
      _shakeAmp = 0;
    }
  }

  /// Gezegenlerin ALTINA cizilir: birlesen eski iki gezegen (hayalet).
  void paintBelow(Canvas c, List<ui.Image?> imgs) {
    for (final g in _ghosts) {
      final p = (g.age / _ghostLife).clamp(0.0, 1.0).toDouble();
      final e = p * p; // hizlanarak birbirine carpar
      final x = g.x0 + (g.x1 - g.x0) * e;
      final y = g.y0 + (g.y1 - g.y0) * e;
      final r = PlanetConfig.radiusOf(g.tier) * (1.0 - 0.3 * e);
      final opacity = 1.0 - 0.35 * e;
      final img = imgs[g.tier];
      if (img == null) {
        c.drawCircle(Offset(x, y), r, Paint()..color = tierColors[g.tier].withOpacity(opacity));
        continue;
      }
      final d = r * 2 * PlanetConfig.drawScale[g.tier];
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(x, y), width: d, height: d),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, opacity),
      );
    }
  }

  /// Gezegenlerin USTUNE cizilir: parlama, halka, kivilcim (parlak, toplamali karisim).
  void paintAbove(Canvas c) {
    for (final f in _flashes) {
      final p = (f.age / f.life).clamp(0.0, 1.0).toDouble();
      final a = 1.0 - p;
      final rad = f.radius * (0.5 + 0.5 * _easeOut(p));
      c.drawCircle(
        Offset(f.x, f.y),
        rad,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            Offset(f.x, f.y),
            rad,
            [
              Colors.white.withOpacity(0.85 * a),
              f.color.withOpacity(0.45 * a),
              f.color.withOpacity(0.0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }
    for (final r in _rings) {
      final p = (r.age / r.life).clamp(0.0, 1.0).toDouble();
      final rad = r.r0 + (r.r1 - r.r0) * _easeOut(p);
      c.drawCircle(
        Offset(r.x, r.y),
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.2, r.width * (1.0 - p))
          ..color = r.color.withOpacity(0.9 * (1.0 - p)),
      );
    }
    for (final s in _sparks) {
      final p = (s.age / s.life).clamp(0.0, 1.0).toDouble();
      final a = math.pow(1.0 - p, 0.8).toDouble();
      final size = s.size * (1.0 - 0.5 * p);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..color = s.color.withOpacity(a);
      if (s.star) {
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final rr = (i.isEven ? size * 1.7 : size * 0.55);
          final ang = s.rot + i * math.pi / 4;
          final pt = Offset(s.x + math.cos(ang) * rr, s.y + math.sin(ang) * rr);
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        c.drawPath(path, paint);
      } else {
        c.drawCircle(Offset(s.x, s.y), size, paint);
      }
    }
  }
}

class _Ghost {
  final int tier;
  final double x0, y0, x1, y1;
  double age = 0;
  _Ghost(this.tier, this.x0, this.y0, this.x1, this.y1);
}

class _Flash {
  final double x, y, radius, life;
  final Color color;
  double age = 0;
  _Flash(this.x, this.y, this.radius, this.life, this.color);
}

class _Ring {
  final double x, y, r0, r1, life, width;
  final Color color;
  double age = 0;
  _Ring(this.x, this.y, this.r0, this.r1, this.life, this.width, this.color);
}

class _Spark {
  double x, y, vx, vy, rot;
  final double life, size, spin;
  final Color color;
  final bool star;
  double age = 0;
  _Spark({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.color,
    required this.star,
    required this.rot,
    required this.spin,
  });
}
