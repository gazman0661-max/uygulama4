import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../screens/settings_sheet.dart' show kPrivacyPolicyUrl, kTermsOfUseUrl, openLegalUrl;

/// Uygulama ilk açıldığında gösterilen, Gizlilik Politikası ve Kullanım
/// Şartları'nı kabul etmeden kapatılamayan (dışarı tıklayınca kapanmayan)
/// custom popup. Kullanıcı "Kabul Ediyorum ve Devam Et"e basana kadar
/// arkasındaki uygulama kullanılamaz.
///
/// Döndürür: kullanıcı kabul ettiyse true.
Future<bool> showLegalConsentPopup(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _LegalConsentDialog(),
    ),
  );
  return result ?? false;
}

class _LegalConsentDialog extends StatefulWidget {
  @override
  State<_LegalConsentDialog> createState() => _LegalConsentDialogState();
}

class _LegalConsentDialogState extends State<_LegalConsentDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📜', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 10),
            Text(
              t(context, 'Devam Etmeden Önce'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context,
                  'Sitora\'yı kullanmaya devam etmeden önce lütfen Gizlilik Politikası ve Kullanım Şartları\'nı okuyup onaylayın.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => setState(() => _accepted = !_accepted),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _accepted,
                      activeColor: const Color(0xFF26C6DA),
                      onChanged: (v) => setState(() => _accepted = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildConsentText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA),
                  disabledBackgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _accepted
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(
                  t(context, 'Kabul Ediyorum ve Devam Et'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _accepted ? Colors.black : Colors.white38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentText(BuildContext context) {
    final baseStyle = const TextStyle(
      color: Colors.white70,
      fontFamily: 'monospace',
      fontSize: 12.5,
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: const Color(0xFF26C6DA),
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: t(context, 'Okudum, kabul ediyorum: ')),
          TextSpan(
            text: t(context, 'Gizlilik Politikası'),
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalUrl(kPrivacyPolicyUrl),
          ),
          TextSpan(text: t(context, ' ve ')),
          TextSpan(
            text: t(context, 'Kullanım Şartları'),
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => openLegalUrl(kTermsOfUseUrl),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
