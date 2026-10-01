import 'auth_service.dart';

Future<Map<String, String>> authHeaderIfSignedIn() async {
  try {
    final token = await AuthService.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  } catch (_) {
    return const {};
  }
}
