import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/chapter_mods.dart';
import 'package:fastfood_merge/models/game_theme.dart';
import 'package:fastfood_merge/localization/app_strings.dart';
import 'package:fastfood_merge/localization/translations.dart';

void main() {
  test('normal bolumlerde dalga: blok basina 2 kolay 2 zor (rahat/boss haric)', () {
    // Blok 17-24: 20 boss. Diger 7 bolumun tier dagilimi.
    final tiers = [for (var c = 17; c <= 24; c++) ChapterConfig.modsFor(c).tier];
    expect(tiers.where((t) => t == ChapterTier.hard).length, greaterThanOrEqualTo(2));
    expect(tiers.where((t) => t == ChapterTier.easy).length, greaterThanOrEqualTo(1));
  });

  test('mutator bolumleri 6-10 bolumde bir gelir', () {
    final ms = [for (var c = 1; c <= 400; c++) if (ChapterMods.isMutatorChapter(c)) c];
    expect(ms.first, 12);
    for (var i = 1; i < ms.length; i++) {
      final gap = ms[i] - ms[i - 1];
      expect(gap, inInclusiveRange(6, 10), reason: '${ms[i - 1]} -> ${ms[i]}');
    }
  });

  test('boss kisilikleri birbirini tekrarlamaz (ilk 4 boss) ve kapilar korunur', () {
    final rules = [for (final c in [10, 20, 30, 40]) ChapterConfig.modsFor(c).ruleEn];
    expect(rules.toSet().length, 4);
    expect(ChapterConfig.modsFor(10).bombMul, 1.0); // bomba kapisi 11
    expect(ChapterConfig.modsFor(20).bombMul, greaterThan(1));
    expect(ChapterConfig.modsFor(30).frozenAdd, greaterThan(0));
    expect(ChapterConfig.modsFor(40).obstacleAdd, greaterThan(0));
  });

  test('ozel mekanik kapilari: kural gelse bile erken bolumde obje cikmaz', () {
    for (var c = 1; c < ChapterConfig.frozenStartChapter; c++) {
      expect(ChapterConfig.frozenCount(c), 0, reason: 'bolum $c');
    }
    for (var c = 1; c < ChapterConfig.obstacleStartChapter; c++) {
      expect(ChapterConfig.obstacleCount(c), 0, reason: 'bolum $c');
    }
    for (var c = 1; c < ChapterConfig.wildStartChapter; c++) {
      expect(ChapterConfig.wildChance(c), 0, reason: 'bolum $c');
    }
  });

  test('tur (lap) ilerledikce kurallar sertlesir: 100+ bolum farkli hisseder', () {
    // Ayni temada (Buz, 33-40 / 81-88) donma kurali ikinci turda daha guclu.
    final lap0 = ChapterConfig.modsFor(38); // Buz blogu, kural aktif
    final lap1 = ChapterConfig.modsFor(86); // ayni tema, 2. tur
    expect(lap1.frozenAdd, greaterThan(lap0.frozenAdd));
  });

  test('coin carpani ortalamada ~1.0 (ekonomi sapmaz)', () {
    var sum = 0.0, n = 0;
    for (var c = 100; c < 200; c++) {
      if (ChapterConfig.kindFor(c) != ChapterKind.normal) continue;
      sum += ChapterConfig.modsFor(c).coinMul;
      n++;
    }
    expect(sum / n, inInclusiveRange(0.97, 1.08));
  });

  test('9. bolumden once hicbir sey degismez', () {
    for (var c = 1; c < 9; c++) {
      expect(ChapterConfig.modsFor(c).isNeutral, true);
    }
  });

  test('zamanli/sinirli atisli bolumde mutator, zor etiketi ve sureyi kisaltan kural yok', () {
    for (var c = 9; c <= 400; c++) {
      if (ChapterConfig.variantFor(c) == ChapterVariant.none) continue;
      final m = ChapterConfig.modsFor(c);
      expect(ChapterMods.isMutatorChapter(c), false, reason: 'bolum $c');
      expect(m.tier, ChapterTier.medium, reason: 'bolum $c');
      if (ChapterConfig.variantFor(c) == ChapterVariant.timed) {
        expect(m.timeMul, greaterThanOrEqualTo(0.8), reason: 'bolum $c'); // sadece tur carpani
      }
    }
  });

  test('her blokta mutator var (kaymis olsa da)', () {
    for (var b = 1; b < 60; b++) {
      expect(ChapterMods.mutatorChapterOfBlock(b), isNot(0), reason: 'blok $b');
    }
  });

  test('yeni metinlerin tum dillerde cevirisi var', () {
    final keys = <String>{};
    for (var c = 9; c <= 400; c++) {
      final m = ChapterConfig.modsFor(c);
      keys.add(m.tierEn);
      if (m.ruleEn.isNotEmpty) keys.add(m.ruleEn);
    }
    expect(keys.length, greaterThan(10));
    for (final k in keys) {
      expect(kDynTr[k] ?? kDynTrExtra[k], isNotNull, reason: 'tr: $k');
      for (final lang in [AppLanguage.es, AppLanguage.pt, AppLanguage.de, AppLanguage.fr, AppLanguage.ru]) {
        expect(kTranslations[lang]?[k] ?? kTranslationsExtra[lang]?[k], isNotNull, reason: '$lang: $k');
      }
    }
  });
}
