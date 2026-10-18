import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/models/game_progress.dart';
import 'package:fastfood_merge/models/game_theme.dart';

DateTime _daysAgo(int d) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - d, 12);
}

void main() {
  test('zorlu bolum turleri: yalnizca normal bolumlerde, boss/rahat ve ilk bolumlerde yok', () {
    for (var ch = 1; ch <= 300; ch++) {
      final v = ChapterConfig.variantFor(ch);
      if (ChapterConfig.kindFor(ch) != ChapterKind.normal) {
        expect(v, ChapterVariant.none, reason: 'bolum $ch boss/rahat');
      }
      if (ch < ChapterConfig.limitedShotsStartChapter) {
        expect(v, ChapterVariant.none, reason: 'bolum $ch erken');
      }
    }
    expect(ChapterConfig.variantFor(14), ChapterVariant.limitedShots);
    expect(ChapterConfig.variantFor(22), ChapterVariant.timed);
  });

  test('ozel obje tanitim bolumleri (11/21/31/41) zorlu tur ile cakismaz', () {
    for (final ch in [11, 21, 31, 41]) {
      expect(ChapterConfig.variantFor(ch), ChapterVariant.none, reason: 'bolum $ch');
    }
  });

  test('atis ve sure limiti hedef siparisle orantili', () {
    for (final ch in [14, 26, 38, 62]) {
      expect(ChapterConfig.shotLimitFor(ch),
          ChapterConfig.goalFor(ch) * ChapterConfig.shotsPerOrder + ChapterConfig.shotsBase);
    }
    for (final ch in [22, 28, 46, 70]) {
      expect(ChapterConfig.timeLimitFor(ch),
          ChapterConfig.goalFor(ch) * ChapterConfig.secondsPerOrder + ChapterConfig.secondsBase);
    }
  });

  test('seri koruma: 1 gun kacirinca elmasla kurtarilir ve seri devam eder', () {
    final gp = GameProgress.instance;
    gp.dailyStreak = 3;
    gp.lastDailyRewardClaim = _daysAgo(2);
    gp.gems = 100;
    expect(gp.dailyMissedDays, 1);
    expect(gp.canSaveDailyStreak, true);
    expect(gp.canSaveDailyStreakWithAd, true);
    expect(gp.dailyStreakSaveCost, GameProgress.streakSaveGemBase);
    expect(gp.pendingDailyIndex, 0); // kurtarmadan seri sifirlanirdi
    expect(gp.saveDailyStreakWithGems(), true);
    expect(gp.gems, 100 - GameProgress.streakSaveGemBase);
    expect(gp.pendingDailyIndex, 4); // seri devam ediyor
    expect(gp.canSaveDailyStreak, false); // ayni gun ikinci kez kurtarilamaz
    gp.gems = 0;
    gp.lastDailyRewardClaim = null;
    gp.dailyStreak = 0;
  });

  test('seri koruma: yetersiz elmas, cok gun kacirma ve kisa seri kurtarilmaz', () {
    final gp = GameProgress.instance;
    gp.dailyStreak = 3;
    gp.lastDailyRewardClaim = _daysAgo(2);
    gp.gems = 5;
    expect(gp.saveDailyStreakWithGems(), false);
    expect(gp.gems, 5);
    expect(gp.pendingDailyIndex, 0);

    gp.lastDailyRewardClaim = _daysAgo(3); // 2 gun kacirildi: elmas evet, reklam hayir
    expect(gp.canSaveDailyStreak, true);
    expect(gp.canSaveDailyStreakWithAd, false);
    expect(gp.dailyStreakSaveCost, GameProgress.streakSaveGemBase + GameProgress.streakSaveGemPerExtraDay);

    gp.lastDailyRewardClaim = _daysAgo(GameProgress.streakSaveMaxMissedDays + 2); // cok gec
    expect(gp.canSaveDailyStreak, false);

    gp.lastDailyRewardClaim = _daysAgo(2);
    gp.dailyStreak = 0; // 1 gunluk seri kurtarmaya degmez
    expect(gp.canSaveDailyStreak, false);

    gp.gems = 0;
    gp.lastDailyRewardClaim = null;
    gp.dailyStreak = 0;
  });

  test('gunluk odul onizlemesi claim ile ayni gunu gosterir', () {
    final gp = GameProgress.instance;
    gp.dailyStreak = 1;
    gp.lastDailyRewardClaim = _daysAgo(1); // dun almis -> bugun 3. gun (index 2)
    expect(gp.pendingDailyIndex, 2);
    gp.lastDailyRewardClaim = null; // hic almamis -> ilk gun
    gp.dailyStreak = 0;
    expect(gp.pendingDailyIndex, 0);
  });
}
