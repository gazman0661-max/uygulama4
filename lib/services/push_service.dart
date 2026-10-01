import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'analytics_service.dart';
import 'auth_service.dart';
import 'hosting_service.dart';
import 'notification_service.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<dynamic>? _authSub;
  bool _initialized = false;

  String? _lastRegisteredUid;
  String? _lastRegisteredToken;
  String? _lastRegisteredIdToken;

  Future<void> init() async {
    if (_initialized || !AuthService.isAvailable) return;
    _initialized = true;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      unawaited(AnalyticsService.logNotificationPermission(
          _permissionLabel(settings.authorizationStatus)));

      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        AnalyticsService.logPushOpened(type: _pushType(message));
      });
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        AnalyticsService.logPushOpened(type: _pushType(initialMessage), coldStart: true);
      }

      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final uid = AuthService.instance.currentUser?.uid;
        if (uid != null) _registerToken(uid, token);
      });

      _authSub = AuthService.instance.authStateChanges.listen((user) {
        if (user != null) {
          _registerCurrentToken(user.uid);
        } else {
          _unregisterLastToken();
        }
      });

      final currentUid = AuthService.instance.currentUser?.uid;
      if (currentUid != null) {
        await _registerCurrentToken(currentUid);
      }
    } catch (e) {
    }
  }

  Future<void> _registerCurrentToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(uid, token);
    } catch (_) {
    }
  }

  Future<void> _registerToken(String uid, String token) async {
    if (!HostingConfig.isConfigured) return;
    try {
      final idToken = await AuthService.instance.currentUser?.getIdToken();
      if (idToken == null) return;
      await http
          .post(
            Uri.parse('${HostingConfig.baseUrl}/api/fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'uid': uid, 'token': token, 'platform': 'android'}),
          )
          .timeout(const Duration(seconds: 10));
      _lastRegisteredUid = uid;
      _lastRegisteredToken = token;
      _lastRegisteredIdToken = idToken;
    } catch (_) {
    }
  }

  Future<void> _unregisterLastToken() async {
    final uid = _lastRegisteredUid;
    final token = _lastRegisteredToken;
    final idToken = _lastRegisteredIdToken;
    _lastRegisteredUid = null;
    _lastRegisteredToken = null;
    _lastRegisteredIdToken = null;
    if (uid == null || token == null || !HostingConfig.isConfigured) return;
    if (idToken == null) return;
    try {
      await http
          .delete(
            Uri.parse('${HostingConfig.baseUrl}/api/fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'uid': uid, 'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
    }
  }

  static String _permissionLabel(AuthorizationStatus status) {
    if (status == AuthorizationStatus.authorized) return 'granted';
    if (status == AuthorizationStatus.denied) return 'denied';
    if (status == AuthorizationStatus.provisional) return 'provisional';
    return 'not_determined';
  }

  static String _pushType(RemoteMessage message) {
    final type = message.data['type'];
    return type == null ? 'unknown' : type.toString();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    NotificationService.instance.showPushNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: message.data['type'] as String?,
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _authSub?.cancel();
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
}
