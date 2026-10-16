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
}
