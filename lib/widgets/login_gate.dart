import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
/// [requireLogin] zaten giriş yapılmış VE e-postası doğrulanmışsa hiçbir şey
/// göstermeden true döner. Aksi halde bir bottom sheet açar — bkz.
/// _LoginGateSheet: ya e-posta/şifre formu, ya da (kayıt sonrası oturum açık
/// ama doğrulanmamışsa) "e-postanı doğrula" bekleme ekranı.
///
/// NOT: Daha önce burada Google ile Giriş vardı; Google kaynaklı sorunlar
/// nedeniyle tamamen kaldırıldı, e-posta/şifre girişiyle değiştirildi.
/// ============================================================================
Future<bool> requireLogin(
  BuildContext context, {
  required String feature,
}) async {
  if (AuthService.instance.isSignedIn && AuthService.instance.isVerified) {
    return true;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // 30.08.2026: kullanıcı sheet'i sürükleyip kapatsa bile (X'e basmadan)
    // arkada oturum açık ama doğrulanmamış kalabilir — bu normal, bir
    // sonraki requireLogin çağrısında bekleme ekranı otomatik tekrar açılır.
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

class _LoginGateSheetState extends State<_LoginGateSheet>
    with WidgetsBindingObserver {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Mode _mode = _Mode.signIn;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;
  // 30.08.2026 eklendi — signInWithEmail EmailNotVerifiedException
  // fırlattığında true olur; formda "Doğrulama e-postasını tekrar gönder"
  // butonu gösterilir (bkz. _resendFromSignIn). Mod/alan değişince
  // sıfırlanır ki eski bir denemeye ait buton yanlışlıkla asılı kalmasın.
  bool _needsVerification = false;

  // 30.08.2026 eklendi — true iken form yerine "e-postanı doğrula" bekleme
  // ekranı gösterilir. Sheet AÇILIRKEN de true olabilir: kullanıcı daha
  // önce kayıt olup doğrulamadan sheet'i kapatmışsa, oturumu hâlâ açık
  // (bkz. AuthService.signUpWithEmail'in artık signOut ETMEMESİ) — bu
  // durumda kullanıcıyı forma değil direkt bekleme ekranına düşürüyoruz.
  bool _awaitingVerification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _awaitingVerification =
        AuthService.instance.isSignedIn && !AuthService.instance.isVerified;
    if (_awaitingVerification) {
      // Sheet açılır açılmaz bir kere kontrol et — belki kullanıcı
      // sheet'i kapattıktan sonra (ama uygulamayı hiç arka plana almadan)
      // e-postayı başka bir cihaz/tarayıcıdan zaten doğrulamıştır.
      _checkVerified();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 30.08.2026 eklendi — kullanıcı e-postadaki doğrulama linkine tıklayıp
  /// (tarayıcıda açılır) uygulamaya GERİ DÖNÜNCE bu tetiklenir. Böylece
  /// hiçbir şey yazmadan otomatik devam edilir — asıl istenen davranış
  /// buydu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingVerification) {
      _checkVerified();
    }
  }

  Future<void> _checkVerified({bool showLoading = false}) async {
    if (showLoading) setState(() => _loading = true);
    final verified = await AuthService.instance.checkEmailVerified();
    if (!mounted) return;
    if (verified) {
      Navigator.of(context).pop(true);
      return;
    }
    if (showLoading) {
      setState(() {
        _loading = false;
        _info = t(context, 'Henüz doğrulanmamış görünüyor. E-postanı kontrol et.');
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _needsVerification = false;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (_mode == _Mode.signUp) {
        // signUpWithEmail BAŞARILI olsa bile her zaman
        // EmailVerificationSentException fırlatır (bkz. auth_service.dart) —
        // yani buraya "başarı" olarak asla düşmez, catch bloğunda ele
        // alınır ve bekleme ekranına geçilir.
        await AuthService.instance.signUpWithEmail(email, password);
        return;
      }
      final user = await AuthService.instance.signInWithEmail(email, password);
      if (!mounted) return;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      Navigator.of(context).pop(true);
    } on EmailVerificationSentException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = e.message;
        _awaitingVerification = true; // bekleme ekranına geç
      });
    } on EmailNotVerifiedException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _needsVerification = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Giriş formundaki "Doğrulama e-postasını tekrar gönder" — sadece
  /// [_needsVerification] true iken (yani şifre doğru ama e-posta
  /// doğrulanmamışken, signInWithEmail'in signOut ettiği durumda)
  /// gösterilir. Oturum kapalı olduğu için şifre gerekiyor.
  Future<void> _resendFromSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.resendVerificationEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _info = t(context, 'Doğrulama bağlantısı tekrar gönderildi.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Bekleme ekranındaki "Tekrar gönder" — oturum zaten açık, şifre GEREKMEZ.
  Future<void> _resendWhileAwaiting() async {
    setState(() {
      _loading = true;
      _info = null;
    });
    await AuthService.instance.resendCurrentUserVerification();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _info = t(context, 'Doğrulama bağlantısı tekrar gönderildi.');
    });
  }

  Future<void> _switchAccount() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    setState(() {
      _awaitingVerification = false;
      _mode = _Mode.signIn;
      _info = null;
      _error = null;
      _passwordCtrl.clear();
    });
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
        _error = e.toString();
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
          child: _awaitingVerification ? _buildAwaitingView(context) : _buildFormView(context),
        ),
      ),
    );
  }

  /// 30.08.2026 eklendi — kayıt sonrası (veya oturumu açık kalmış eski bir
  /// kayıt için) gösterilen bekleme ekranı. Form YOK — sadece bilgi +
  /// "Tekrar gönder" + "Farklı hesapla devam et". Doğrulama, uygulama öne
  /// gelince otomatik algılanır (bkz. didChangeAppLifecycleState).
  Widget _buildAwaitingView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_unread_outlined, color: AppColors.accentBlue, size: 40),
        const SizedBox(height: 12),
        Text(
          t(context, 'E-postanı doğrula'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          t(context,
              'Gelen kutuna bir doğrulama bağlantısı gönderdik. Linke tıklayıp buraya döndüğünde otomatik devam edeceğiz — başka bir şey yapmana gerek yok.'),
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (_info != null) ...[
          const SizedBox(height: 12),
          Text(
            _info!,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : () => _checkVerified(showLoading: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t(context, 'Doğruladım, kontrol et')),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _loading ? null : _resendWhileAwaiting,
          child: Text(t(context, 'Doğrulama e-postasını tekrar gönder'),
              style: const TextStyle(color: AppColors.accentBlue, fontSize: 13)),
        ),
        TextButton(
          onPressed: _loading ? null : _switchAccount,
          child: Text(t(context, 'Farklı hesapla devam et'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ),
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: Text(t(context, 'Vazgeç'), style: TextStyle(color: Colors.grey.shade600)),
        ),
      ],
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
          if (_needsVerification) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _resendFromSignIn,
                child: Text(
                  t(context, 'Doğrulama e-postasını tekrar gönder'),
                  style: const TextStyle(color: AppColors.accentBlue, fontSize: 12),
                ),
              ),
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
                      _needsVerification = false;
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
