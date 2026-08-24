import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../services/auth_service.dart';

/// ============================================================================
/// LOGIN GATE — İSKELET
/// ============================================================================
/// Kararlaştırdığımız gibi: giriş OPSİYONEL, ama HOSTING (yayınlama) ve
/// SATIN ALMA akışları giriş ister. Bu dosya, o akışların başında çağrılacak
/// tek bir yardımcı fonksiyon sağlar: [requireLogin].
///
/// KULLANIM (ileride, ilgili ekranlarda — henüz hiçbir çağrı noktasına
/// bağlanmadı, bu saf bir iskelet):
///
///   final ok = await requireLogin(context, feature: 'Yayınlama');
///   if (!ok) return; // kullanıcı giriş yapmadı/iptal etti, akışı durdur
///   // ... hosting/satın alma akışına devam et
///
/// [requireLogin] zaten giriş yapılmışsa hiçbir şey göstermeden true döner.
/// Giriş yapılmamışsa bir bottom sheet açar: "Google ile Giriş Yap" /
/// "Vazgeç". Giriş başarılıysa true, iptal/hata durumunda false döner.
/// ============================================================================
Future<bool> requireLogin(
  BuildContext context, {
  required String feature,
}) async {
  if (AuthService.instance.isSignedIn) return true;

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF141821),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _LoginGateSheet(feature: feature),
  );
  return result ?? false;
}

class _LoginGateSheet extends StatefulWidget {
  final String feature;
  const _LoginGateSheet({required this.feature});

  @override
  State<_LoginGateSheet> createState() => _LoginGateSheetState();
}

class _LoginGateSheetState extends State<_LoginGateSheet> {
  bool _loading = false;
  String? _error;
  // Son hatanın TAM tanı raporu (varsayımsız — bkz. auth_service.dart).
  // "Detaylar" butonuna basılınca bu diyalogda gösterilir/kopyalanır.
  String? _diagnosticsReport;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
      _diagnosticsReport = null;
    });
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        // kullanıcı iptal etti — sessizce kapat
        setState(() => _loading = false);
        return;
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
        _diagnosticsReport = e.diagnosticsReport;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
        _diagnosticsReport = null;
      });
    }
  }

  Future<void> _showDiagnosticsDialog() async {
    final report = _diagnosticsReport;
    if (report == null) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141821),
        title: const Text(
          'Google Giriş — Tam Hata Raporu',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Rapor panoya kopyalandı')),
                );
              }
            },
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.feature} için giriş gerekiyor',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bu özellik hesabına bağlı çalışır. Devam etmek için Google '
              'ile giriş yapman gerekiyor.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_diagnosticsReport != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _showDiagnosticsDialog,
                  child: const Text(
                    'Tam hata raporunu göster',
                    style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _loading ? null : _handleGoogleSignIn,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loading ? 'Giriş yapılıyor…' : 'Google ile Giriş Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(false),
              child: Text('Vazgeç', style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}
