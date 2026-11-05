import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hikaye ve gorev olaylari id bazinda da sayilir, ozet raporda gorunur', () {
    final a = AnalyticsService.instance;
    final before = a.count('story_scene@w0_a');
    a.log('story_scene', {'id': 'w0_a', 'chapter': 1});
    a.log('story_skip', {'id': 'w0_a', 'line': 2});
    a.log('mb_mission_done', {'id': 'd_orders', 'period': 'daily'});
    a.log('mb_mission_claim', {'id': 'd_orders', 'period': 'daily'});
    expect(a.count('story_scene@w0_a'), before + 1);
    expect(a.count('story_skip@w0_a'), greaterThanOrEqualTo(1));
    expect(a.count('mb_mission_claim@d_orders'), greaterThanOrEqualTo(1));
    final s = a.summary();
    expect(s.contains('HIKAYE + MOD 2 GOREVLERI'), isTrue);
    expect(s.contains('sahne w0_a'), isTrue);
    expect(s.contains('gorev d_orders'), isTrue);
  });
}
