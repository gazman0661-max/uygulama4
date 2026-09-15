import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// LOGIN GATE — E-POSTA/ŞİFRE
/// ============================================================================
/// Giriş OPSİYONEL, ama HOSTING (yayınlama) ve SATIN ALMA akışları giriş
/// ister. Bu dosya, o akışların başında çağrılacak tek bir yardımcı
/// fonksiyon sağlar: [requireLogin].
///
/// KULLANIM:
///   final ok = await requireLogin(context, feature: 'Yayınlama');
///   if (!ok) return; // kullanıcı giriş yapmadı/iptal etti, akışı durdur
///   // ... hosting/satın alma akışına devam et
///
/// 14.09.2026 DEĞİŞTİRİLDİ (kanka kararı) — e-posta doğrulama şartı
/// tamamen kaldırıldı. [requireLogin] artık sadece [AuthService.isSignedIn]
/// kontrol eder; kayıt olur olmaz kullanıcı hiçbir bekleme ekranı görmeden
/// devam eder. E-posta/şifre hesabının tek amacı artık cihaz değişince
/// (hak/proje) verisini kaybetmemek.
///
/// NOT: Daha önce burada Google ile Giriş vardı; Google kaynaklı sorunlar
/// nedeniyle tamamen kaldırıldı, e-posta/şifre girişiyle değiştirildi.
/// ============================================================================
Future<bool> requireLogin(
  BuildContext context, {
  required String feature,
}) async {
  if (AuthService.instance.isSignedIn) {
    return true;
  }

  // 12.09.2026 eklendi (kanka isteği) — yayınlama/satın alma huninde login
  // sheet'inin gerçekten AÇILDIĞI anı işaretler (bkz. analytics_service.dart
  // dosya başı huni notu).
  unawaited(AnalyticsService.logLoginGateShown(feature: feature));

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
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

enum _Mode { signIn, signUp }

class _LoginGateSheetState extends State<_LoginGateSheet> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final user = _mode == _Mode.signUp
          ? await AuthService.instance.signUpWithEmail(email, password)
          : await AuthService.instance.signInWithEmail(email, password);
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t(context, e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = isEnglish(context)
            ? 'Something went wrong. Please try again.'
            : 'Bir şeyler ters gitti. Lütfen tekrar deneyin.';
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = t(context, 'Önce e-posta adresini yaz.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = t(context, 'Şifre sıfırlama bağlantısı e-postana gönderildi.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t(context, e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildFormView(context),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context) {
    final isSignIn = _mode == _Mode.signIn;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.feature} ${t(context, 'için giriş gerekiyor')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            t(context,
                'Bu özellik hesabına bağlı çalışır. Devam etmek için e-posta ile giriş yapman gerekiyor.'),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: t(context, 'E-posta'),
              labelStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return t(context, 'E-posta gerekli.');
              if (!value.contains('@') || !value.contains('.')) {
                return t(context, 'Geçerli bir e-posta gir.');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: t(context, 'Şifre'),
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
          if (isSignIn) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _forgotPassword,
                child: Text(
                  t(context, 'Şifremi Unuttum'),
                  style: const TextStyle(color: AppColors.accentBlue, fontSize: 12),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 4),
            Text(
              _info!,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isSignIn ? t(context, 'Giriş Yap') : t(context, 'Kayıt Ol')),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _mode = isSignIn ? _Mode.signUp : _Mode.signIn;
                      _error = null;
                      _info = null;
                    }),
            child: Text(
              isSignIn
                  ? t(context, 'Hesabın yok mu? Kayıt Ol')
                  : t(context, 'Zaten hesabın var mı? Giriş Yap'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(false),
            child: Text(t(context, 'Vazgeç'), style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}
