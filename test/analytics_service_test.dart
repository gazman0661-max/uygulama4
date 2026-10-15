import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fastfood_merge/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sink baglanmadan gelen olaylar tamponlanir, baglaninca sirayla iletilir, sonra dogrudan gider', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AnalyticsService.instance;
    a.log('t_a');
    a.log('t_b', {'step': 'drag'});

    final got = <String>[];
    a.sink = (n, p) => got.add(p.isEmpty ? n : '$n:${p['step']}');
    expect(got, ['t_a', 't_b:drag']);

    a.log('t_c');
    expect(got, ['t_a', 't_b:drag', 't_c']);
    expect(a.count('t_a'), 1);
    a.sink = null;
  });

  test('sink hata firlatsa bile log() hata firlatmaz ve olay cihazda sayilir', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AnalyticsService.instance;
    a.sink = (n, p) => throw StateError('boom');
    a.log('t_err');
    expect(a.count('t_err'), 1);
    a.sink = null;
  });
}
