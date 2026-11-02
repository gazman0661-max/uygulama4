import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/models/game_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('yeni kayit: tutSeen listesi aynen uygulanir', () async {
    SharedPreferences.setMockInitialValues({});
    await GameProgress.instance.applyRemote({'maxUnlockedChapter': 1, 'tutSeen': ['danger']});
    expect(GameProgress.instance.tutSeen('danger'), true);
    expect(GameProgress.instance.tutSeen('combo'), false);
    expect(GameProgress.instance.tutSeen('ch1'), false);
  });

  test('eski kayit (tutSeen yok, bolum > 1): ogretici hepsi gorulmus sayilir', () async {
    SharedPreferences.setMockInitialValues({});
    await GameProgress.instance.applyRemote({'maxUnlockedChapter': 6});
    for (final k in GameProgress.tutKeys) {
      expect(GameProgress.instance.tutSeen(k), true, reason: k);
    }
  });

  test('v126 tur seviyeleri: Dukkan 2, Davet 3, Album 4', () {
    expect(GameProgress.upgradesTourLevel, 2);
    expect(GameProgress.inviteTourLevel, 3);
    expect(GameProgress.albumTourLevel, 4);
    for (final k in ['feat_upgrades', 'feat_invite', 'feat_album', 'tour_upgrades', 'tour_invite', 'tour_album']) {
      expect(GameProgress.tutKeys, contains(k));
    }
  });

  test('v126 gecisi: seviye 8 eski oyuncu Dukkan/Album turunu gormez, Davet turunu gorur', () async {
    SharedPreferences.setMockInitialValues({});
    await GameProgress.instance.applyRemote({
      'maxUnlockedChapter': 20,
      'playerLevel': 8,
      'tutSeen': ['ch1', 'feat_missions', 'tour_missions'],
    });
    final gp = GameProgress.instance;
    expect(gp.tutSeen('feat_upgrades'), true);
    expect(gp.tutSeen('tour_upgrades'), true);
    expect(gp.tutSeen('feat_album'), true);
    expect(gp.tutSeen('tour_album'), true);
    expect(gp.tutSeen('feat_invite'), false);
    expect(gp.tutSeen('tour_invite'), false);
  });

  test('v126 gecisi: seviye 3 oyuncu Dukkan/Davet/Album turlarini hala gorecek', () async {
    SharedPreferences.setMockInitialValues({});
    await GameProgress.instance.applyRemote({
      'maxUnlockedChapter': 4,
      'playerLevel': 3,
      'tutSeen': ['ch1'],
    });
    final gp = GameProgress.instance;
    expect(gp.tutSeen('feat_upgrades'), false);
    expect(gp.tutSeen('feat_invite'), false);
    expect(gp.tutSeen('feat_album'), false);
    expect(gp.upgradesTourReady, true);
    expect(gp.inviteTourReady, true);
    expect(gp.albumTourReady, false); // Sv 4'te acilir
  });
}
