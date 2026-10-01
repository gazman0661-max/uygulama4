import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'hosting_service.dart';
import 'server_time_service.dart';

class SubscriptionStatus {
  final bool active;
  final String? productId;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.active,
    this.productId,
    this.expiresAt,
  });

  static const SubscriptionStatus inactive = SubscriptionStatus(active: false);
}

class SubscriptionService {
  static Future<SubscriptionStatus?> fetchStatus(String uid) async {
    if (!HostingConfig.isConfigured) return null;
    final user = AuthService.instance.currentUser;
    if (user == null || user.uid != uid) return null;
    http.Response res;
    try {
      final idToken = await user.getIdToken();
      if (idToken == null) return null;
      res = await http.get(
        Uri.parse('${HostingConfig.baseUrl}/api/subscription-status'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } catch (_) {
      return null;
    }
    ServerTimeService.updateFromResponse(res);
    if (res.statusCode != 200) {
      return null;
    }
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['active'] != true) {
        return SubscriptionStatus.inactive;
      }
      return SubscriptionStatus(
        active: true,
        productId: data['productId'] as String?,
        expiresAt: data['expiryAt'] != null
            ? DateTime.tryParse(data['expiryAt'] as String)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
