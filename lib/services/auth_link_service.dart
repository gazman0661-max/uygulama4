import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'crash_service.dart';
import '../screens/reset_password_confirm_screen.dart';

class AuthLinkService {
  AuthLinkService._();
  static final AuthLinkService instance = AuthLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    if (!AuthService.isAvailable) return;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handle(initialUri));
      }
    } catch (e, st) {
      CrashService.record(e, st, context: 'AuthLinkService.initialLink', fatal: false);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri)),
      onError: (e, st) =>
          CrashService.record(e, st, context: 'AuthLinkService.stream', fatal: false),
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handle(Uri uri) async {
    if (uri.host != AuthService.authDomain) return;

    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    switch (mode) {
      case 'resetPassword':
        await _handleResetPassword(oobCode);
        break;
      default:
        break;
    }
  }

  Future<void> _handleResetPassword(String oobCode) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordConfirmScreen(oobCode: oobCode),
      ),
    );
  }
}
