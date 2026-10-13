import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';

/// ============================================================================
/// ŞİFRE SIFIRLAMAYI UYGULAMA İÇİNDE TAMAMLAMA
/// ============================================================================
/// 31.08.2026 eklendi. AndroidManifest.xml'deki autoVerify intent-filter
/// yüzünden "şifremi unuttum" e-postasındaki link artık TARAYICIYA değil
/// doğrudan bu uygulamaya düşüyor (bkz. auth_link_service.dart) — bu yüzden
/// Firebase'in normalde tarayıcıda gösterdiği "yeni şifre belirle" sayfasının
/// eşdeğerini burada, uygulama içinde sağlıyoruz.
///
/// [oobCode] AuthLinkService tarafından gelen linkten çıkarılıp buraya
/// aktarılır; [FirebaseAuth.confirmPasswordReset] ile tek seferde hem kodun
/// geçerliliği doğrulanır hem de yeni şifre uygulanır.
/// ============================================================================
class ResetPasswordConfirmScreen extends StatefulWidget {
  final String oobCode;
  const ResetPasswordConfirmScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends State<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _done = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _messageForCode(e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'İşlem başarısız: $e';
      });
    }
  }

  String _messageForCode(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Bu bağlantının süresi dolmuş. Şifremi unuttum akışını tekrar başlat.';
      case 'invalid-action-code':
        return 'Bu bağlantı geçersiz veya daha önce kullanılmış.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullan.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Bu bağlantıya ait bir hesap bulunamadı.';
      default:
        return 'İşlem başarısız: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _done ? _buildDoneView(context) : _buildFormView(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 56),
        const SizedBox(height: 16),
        Text(
          t(context, 'Şifren güncellendi'),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          t(context, 'Yeni şifrenle giriş yapabilirsin.'),
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(t(context, 'Tamam')),
        ),
      ],
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            t(context, 'Yeni şifre belirle'),
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: t(context, 'Yeni şifre'),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return t(context, 'Şifre gerekli.');
              if (value.length < 6) {
                return t(context, 'Şifre en az 6 karakter olmalı.');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: t(context, 'Yeni şifre (tekrar)'),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) {
                return t(context, 'Şifreler eşleşmiyor.');
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t(context, 'Şifreyi Güncelle')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            child: Text(t(context, 'Vazgeç'),
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}
