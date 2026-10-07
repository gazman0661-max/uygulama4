import 'package:flutter_test/flutter_test.dart';
import 'package:sitora_ai/services/gsc_helpers.dart';

void main() {
  const code = 'aB3dE_fGh-1234567890XyZ';

  group('gscExtractCode', () {
    test('çıplak kodu olduğu gibi döndürür', () {
      expect(gscExtractCode(code), code);
    });

    test('boşluk ve tırnakları kırpar', () {
      expect(gscExtractCode('  "$code"  '), code);
    });

    test('tam meta etiketinden content değerini çıkarır', () {
      expect(
        gscExtractCode(
            '<meta name="google-site-verification" content="$code" />'),
        code,
      );
    });

    test('tek tırnaklı etiketi de çözer', () {
      expect(
        gscExtractCode(
            "<meta name='google-site-verification' content='$code'>"),
        code,
      );
    });

    test('sadece content= parçasını çözer', () {
      expect(gscExtractCode('content="$code"'), code);
    });

    test('boş metin null', () {
      expect(gscExtractCode('   '), isNull);
    });

    test('çok kısa / geçersiz karakterli kod null', () {
      expect(gscExtractCode('abc'), isNull);
      expect(gscExtractCode('geçersiz kod boşluklu değer burada'), isNull);
      expect(gscExtractCode('<script>alert(1)</script>'), isNull);
    });
  });
}
