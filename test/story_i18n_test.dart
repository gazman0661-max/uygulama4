import 'package:flutter_test/flutter_test.dart';
import 'package:fastfood_merge/localization/app_strings.dart';
import 'package:fastfood_merge/localization/story_i18n.dart';
import 'package:fastfood_merge/localization/story_strings.dart';
import 'package:fastfood_merge/models/mb_missions.dart';
import 'package:fastfood_merge/models/mb_story.dart';

void main() {
  const langs = [AppLanguage.es, AppLanguage.pt, AppLanguage.de, AppLanguage.fr, AppLanguage.ru];
  final ph = RegExp(r'\{\d\}');

  test('kStoryTr her anahtari ES/PT/DE/FR/RU icin de ceviri sahibi', () {
    for (final l in langs) {
      final m = kStoryI18n[l];
      expect(m, isNotNull, reason: l.name);
      for (final k in kStoryTr.keys) {
        expect(m!.containsKey(k), isTrue, reason: '${l.name}: $k');
        expect(m[k]!.trim(), isNotEmpty, reason: '${l.name}: $k');
      }
      expect(m!.length, kStoryTr.length, reason: '${l.name}: fazladan anahtar var');
    }
  });

  test('yer tutucular ({0} {1}) her dilde korunmus', () {
    for (final l in langs) {
      kStoryTr.forEach((k, _) {
        final a = ph.allMatches(k).map((e) => e.group(0)).toList()..sort();
        final b = ph.allMatches(kStoryI18n[l]![k]!).map((e) => e.group(0)).toList()..sort();
        expect(b, a, reason: '${l.name}: $k');
      });
    }
  });

  test('sahne metinleri ve gorev etiketleri AppStrings.lt ile her dilde cevrilir', () {
    final s = AppStrings.instance;
    final before = s.language;
    addTearDown(() => s.language = before);
    for (final l in langs) {
      s.language = l;
      for (final sc in kStoryScenes) {
        for (final line in sc.lines) {
          expect(s.lt(line.text), kStoryI18n[l]![line.text], reason: '${l.name}: ${sc.id}');
          expect(s.lt(line.who), kStoryI18n[l]![line.who]);
        }
      }
      for (final m in MbMetric.values) {
        final out = s.lt(MbMissions.labelKey(m), [2, 5]);
        expect(out.contains('2/5'), isTrue, reason: '${l.name}: ${m.name} -> $out');
      }
      expect(s.lt('Play'), kStoryI18n[l]!['Play']);
      expect(s.lt('Throw Mode'), kStoryI18n[l]!['Throw Mode']);
    }
  });
}
