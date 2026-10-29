import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

/// HAFTA SONU ETKINLIGI: "Gezegen Birlestir" (Suika tarzi) fizigi — forge2d 0.13 ile.
///
/// AstroFelyx'teki planet_merge_physics.dart'in sadelestirilmis uyarlamasi. Fizik
/// motoru Fırlat modundaki ([BoardPhysics]) ile AYNI paket/surum (forge2d ^0.13);
/// 0.14 API'sindeki adlandirilmis kurucular yerine burada cascade (..) yazimi kullanilir.
///
/// Dunya birimleri: genislik [PlanetConfig.worldW] x yukseklik [PlanetConfig.worldH],
/// y asagi dogru artar. Box2D metre olcegini sever; fizige giderken [_k] ile 10'a bolunur.
///
/// Birlesme tespiti BILEREK temas dinleyicisiyle degil, her adimdan sonra konum
/// kontroluyle yapilir (iki es gezegenin sonsuza dek yan yana kalma riski olmaz).
///
/// NOT: forge2d'nin top-level velocityIterations/positionIterations degiskenlerine
/// DOKUNULMAZ (global; Fırlat modunun fizigini etkilerdi).
class PlanetBody {
  final int id;
  int tier;
  double x, y, vx, vy;
  Body? phys;

  /// Olusturulduktan sonra gecen sure (sn) — yeni birakilan gezegen tehlike sayilmasin.
  double age = 0;

  /// 0..1 arasi "pop" animasyonu (birlesme ile olusunca 1'den 0'a iner).
  double pop = 0;

  /// 1'den 0'a yavasca iner (~1.3 sn): yeni birlesen gezegen bu sure boyunca SEVINC yuzu yapar (v215).
  double joy = 0;

  PlanetBody({required this.id, required this.tier, required this.x, required this.y, this.vx = 0, this.vy = 0});

  double get r => PlanetConfig.radiusOf(tier);
}

/// Bir birlesme olayi — arayuzun ses/skor/efekt gostermesi icin.
class PlanetMergeEvent {
  /// OLUSAN yeni gezegenin kademesi (en ust ikisi birlesip yok olduysa -1).
  final int tier;
  final double x, y;

  /// Bu birlesmeden gelen toplam puan (kombo bonusu DAHIL).
  final int points;

  /// Zincirdeki sira (1 = tek birlesme, 2+ = kombo).
  final int combo;
  const PlanetMergeEvent(this.tier, this.x, this.y, this.points, this.combo);
}

class PlanetConfig {
  PlanetConfig._();

  static const double worldW = 100;
  static const double worldH = 150;

  /// Bu cizginin (y) ustune tasan ve oturmus gezegen varsa tehlike sayaci isler.
  static const double dangerY = 24;
  static const double dangerSeconds = 1.6;

  /// Kademe sayisi (0..12): Merkur, Kizil Cuce, Bakir Asteroit, Buz Ay, Mars, Dunya,
  /// Gaia, Neptun, Uranus, Saturn, Pembe Gaz Devi, Gunes, Karanlik Kutle.
  static const int tierCount = 13;

  /// Guclendirici fiyatlari (mucevher); her biri reklam izleyerek de kullanilabilir.
  static const int powerShakeGems = 20;
  static const int powerSwapGems = 15;
  static const int powerDeleteGems = 25;

  /// Gorev hedefi kademeleri (0 tabanli).
  static const int tierNeptune = 7;
  static const int tierUranus = 8;
  static const int tierSaturn = 9;

  /// Gorselin collision dairesine oturmasi icin cizim carpani.
  static const List<double> drawScale = [1.06, 1.12, 1.12, 1.12, 1.06, 1.12, 1.06, 1.06, 1.55, 1.55, 1.06, 1.12, 1.12];

  /// Birakilabilen en buyuk baslangic kademesi: 0..4 (agirliklar asagida).
  static const List<int> dropWeights = [34, 28, 20, 12, 6];

  static double radiusOf(int tier) => 4.2 * math.pow(1.2, tier).toDouble();

  /// Kademe t olusunca eklenen puan (3, 6, 10, 15, ...).
  static int pointsForTier(int tier) => (tier + 1) * (tier + 2) ~/ 2;

  /// Iki Karanlik Kutle birlesince yok olur: buyuk bonus.
  static const int vanishBonus = 150;

  /// Kombo: bu sure (sn) icinde ardisik birlesmeler zincir sayilir.
  static const double comboWindow = 1.6;
  static const double comboBonusPerStep = 0.25; // 2. birlesmeden itibaren puan * (kombo-1) * 0.25
  static const double comboBonusMax = 1.0; // en fazla +%100

  static const double gravity = 15;
  static const double restitution = 0.05;
  static const double friction = 0.3;
  static const double fixedDt = 1 / 120;

  /// Agirlikli rastgele baslangic kademesi.
  static int randomDropTier(math.Random rng) {
    final total = dropWeights.fold<int>(0, (a, b) => a + b);
    var roll = rng.nextInt(total);
    for (var i = 0; i < dropWeights.length; i++) {
      roll -= dropWeights[i];
      if (roll < 0) return i;
    }
    return 0;
  }

  /// Kombo bonusu (saf fonksiyon: test edilebilir). [combo] zincirdeki sira (1 = bonus yok).
  static int comboBonus(int points, int combo) {
    if (combo < 2) return 0;
    final f = math.min(comboBonusMax, (combo - 1) * comboBonusPerStep);
    return (points * f).round();
  }
}

class PlanetWorld {
  static const double _k = 0.1;

  late final World _phys;
  final List<PlanetBody> bodies = [];
  final List<PlanetMergeEvent> pendingEvents = [];
  int _nextId = 1;
  double _acc = 0;
  double _clock = 0;
  double _lastMergeAt = -100;

  int score = 0;
  int bestTier = 0;
  int merges = 0;
  int combo = 0;
  int maxCombo = 0;
  bool gameOver = false;
  double dangerTimer = 0;

  PlanetWorld() {
    _phys = World(Vector2(0, PlanetConfig.gravity));
    _buildWalls();
  }

  void _buildWalls() {
    final w = PlanetConfig.worldW * _k;
    final h = PlanetConfig.worldH * _k;
    const top = -30.0;
    final wallBody = _phys.createBody(BodyDef()..type = BodyType.static);
    void edge(double x1, double y1, double x2, double y2) {
      final shape = EdgeShape()..set(Vector2(x1, y1), Vector2(x2, y2));
      wallBody.createFixture(FixtureDef(shape)..friction = PlanetConfig.friction);
    }

    edge(0, h, w, h); // zemin
    edge(0, top, 0, h); // sol
    edge(w, top, w, h); // sag
  }

  void _attach(PlanetBody b) {
    final def = BodyDef()
      ..type = BodyType.dynamic
      ..position = Vector2(b.x * _k, b.y * _k)
      ..linearVelocity = Vector2(b.vx * _k, b.vy * _k);
    final body = _phys.createBody(def);
    final shape = CircleShape()..radius = b.r * _k;
    body.createFixture(FixtureDef(shape)
      ..density = 1.0
      ..friction = PlanetConfig.friction
      ..restitution = PlanetConfig.restitution);
    b.phys = body;
    bodies.add(b);
  }

  PlanetBody drop(int tier, double x) {
    final r = PlanetConfig.radiusOf(tier);
    final cx = x.clamp(r, PlanetConfig.worldW - r).toDouble();
    final b = PlanetBody(id: _nextId++, tier: tier, x: cx, y: PlanetConfig.dangerY - r - 2, vy: 20);
    _attach(b);
    if (tier > bestTier) bestTier = tier;
    return b;
  }

  /// [dt] saniye ilerletir (arayuz her karede cagirir; sabit adimlara boler).
  void step(double dt) {
    if (gameOver) return;
    if (dt > 0.05) dt = 0.05;
    _acc += dt;
    _clock += dt;
    var n = 0;
    while (_acc >= PlanetConfig.fixedDt && n < 8) {
      _phys.stepDt(PlanetConfig.fixedDt);
      _acc -= PlanetConfig.fixedDt;
      n++;
    }
    if (n >= 8) _acc = 0;

    for (final b in bodies) {
      final p = b.phys!;
      final pos = p.position;
      final v = p.linearVelocity;
      b.x = pos.x / _k;
      b.y = pos.y / _k;
      b.vx = v.x / _k;
      b.vy = v.y / _k;
      b.age += dt;
      if (b.pop > 0) b.pop = math.max(0.0, b.pop - dt * 4);
      if (b.joy > 0) b.joy = math.max(0.0, b.joy - dt * 0.75);
    }
    _processMerges();
    _checkDanger(dt);
  }

  void _processMerges() {
    final used = <int>{};
    final spawns = <PlanetBody>[];
    final n = bodies.length;
    for (var i = 0; i < n; i++) {
      final a = bodies[i];
      if (used.contains(a.id)) continue;
      for (var j = i + 1; j < n; j++) {
        final b = bodies[j];
        if (used.contains(b.id) || a.tier != b.tier) continue;
        final dx = b.x - a.x, dy = b.y - a.y;
        final lim = a.r + b.r + 0.35;
        if (dx * dx + dy * dy > lim * lim) continue;
        used.add(a.id);
        used.add(b.id);
        final ma = a.r * a.r, mb = b.r * b.r;
        final mx = (a.x * ma + b.x * mb) / (ma + mb);
        final my = (a.y * ma + b.y * mb) / (ma + mb);

        // Kombo zinciri.
        combo = (_clock - _lastMergeAt <= PlanetConfig.comboWindow) ? combo + 1 : 1;
        _lastMergeAt = _clock;
        if (combo > maxCombo) maxCombo = combo;
        merges++;

        if (a.tier >= PlanetConfig.tierCount - 1) {
          const pts = PlanetConfig.vanishBonus;
          score += pts;
          pendingEvents.add(PlanetMergeEvent(-1, mx, my, pts, combo));
        } else {
          final tier = a.tier + 1;
          final base = PlanetConfig.pointsForTier(tier);
          final pts = base + PlanetConfig.comboBonus(base, combo);
          score += pts;
          if (tier > bestTier) bestTier = tier;
          spawns.add(PlanetBody(
            id: _nextId++,
            tier: tier,
            x: mx,
            y: my,
            vx: (a.vx + b.vx) / 2,
            vy: (a.vy + b.vy) / 2,
          )
            ..pop = 1
            ..joy = 1
            ..age = 10);
          pendingEvents.add(PlanetMergeEvent(tier, mx, my, pts, combo));
        }
        break;
      }
    }
    if (used.isEmpty) return;
    for (final b in bodies) {
      if (used.contains(b.id)) _phys.destroyBody(b.phys!);
    }
    bodies.removeWhere((b) => used.contains(b.id));
    for (final s in spawns) {
      _attach(s);
    }
  }

  void _checkDanger(double dt) {
    var over = false;
    for (final b in bodies) {
      if (b.age < 1.2) continue; // yeni birakilan gecici asabilir
      if (b.y - b.r < PlanetConfig.dangerY) {
        over = true;
        break;
      }
    }
    if (over) {
      dangerTimer += dt;
      if (dangerTimer >= PlanetConfig.dangerSeconds) gameOver = true;
    } else {
      dangerTimer = math.max(0.0, dangerTimer - dt * 2);
    }
  }

  /// "Devam et" odulu: cizgiye en yakin [count] gezegeni kaldirir, oyunu geri acar.
  void rescue({int count = 6}) {
    final byTop = [...bodies]..sort((a, b) => (a.y - a.r).compareTo(b.y - b.r));
    final remove = <int>{};
    for (final b in byTop) {
      if (remove.length >= count) break;
      remove.add(b.id);
    }
    for (final b in bodies) {
      if (remove.contains(b.id)) _phys.destroyBody(b.phys!);
    }
    bodies.removeWhere((b) => remove.contains(b.id));
    dangerTimer = 0;
    gameOver = false;
  }

  /// "Sil" guclendiricisi icin: (x, y) dunya koordinatindaki gezegeni bulur (silmez).
  /// Ust uste olanlardan merkeze en yakin olani secer; hicbiri yoksa null.
  PlanetBody? bodyAt(double x, double y) {
    PlanetBody? best;
    var bestD = double.infinity;
    for (final b in bodies) {
      final dx = b.x - x, dy = b.y - y;
      final d = math.sqrt(dx * dx + dy * dy);
      // Kucuk gezegenlere parmakla dokunmak zor: dokunma alanini biraz genislet.
      if (d <= b.r + 2.5 && d < bestD) {
        best = b;
        bestD = d;
      }
    }
    return best;
  }

  /// [b]'yi tahtadan kaldirir (Sil guclendiricisi). Tahtada degilse false.
  bool removeBody(PlanetBody b) {
    if (!bodies.contains(b)) return false;
    final ph = b.phys;
    if (ph != null) _phys.destroyBody(ph);
    bodies.remove(b);
    dangerTimer = 0;
    return true;
  }

  /// "Salla" guclendiricisi: tum gezegenlere kucuk, rastgele bir itme verir (sikismis yigini
  /// gevsetir). Tehlike cizgisi icin kisa sure korunurlar (age sifirlanir).
  void shake(math.Random rng) {
    for (final b in bodies) {
      final ph = b.phys;
      if (ph == null) continue;
      final vx = (rng.nextDouble() - 0.5) * 80 * _k;
      final vy = -(25 + rng.nextDouble() * 35) * _k;
      final v = ph.linearVelocity;
      ph.linearVelocity = Vector2(v.x + vx, v.y + vy);
      b.age = 0;
    }
    dangerTimer = 0;
  }

  List<PlanetMergeEvent> takeEvents() {
    final e = List<PlanetMergeEvent>.from(pendingEvents);
    pendingEvents.clear();
    return e;
  }
}
