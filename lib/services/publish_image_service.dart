import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PublishImageService {
  PublishImageService._();

  static const int minExternalizeChars = 20 * 1024;

  static const int _parallel = 4;

  static final RegExp _dataUriRe =
      RegExp(r'data:image/(?:png|jpe?g|webp|gif);base64,([A-Za-z0-9+/=]+)');
  static final RegExp _serverPathRe =
      RegExp(r'^img/[a-f0-9]{32}\.(?:webp|png|jpg|gif)$');

  static Future<Map<String, String>> externalize({
    required Map<String, String> files,
    required Uri endpoint,
    required String siteId,
    String? ownerToken,
    Map<String, String> authHeaders = const {},
  }) async {
    final unique = <String>{};
    for (final e in files.entries) {
      if (!e.key.toLowerCase().endsWith('.html')) continue;
      for (final m in _dataUriRe.allMatches(e.value)) {
        if (m.group(1)!.length >= minExternalizeChars) unique.add(m.group(0)!);
      }
    }
    if (unique.isEmpty) return files;

    final uploaded = <String, String>{};
    final queue = unique.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final uri = queue.removeLast();
        final path = await _uploadWithRetry(
          uri: uri,
          endpoint: endpoint,
          siteId: siteId,
          ownerToken: ownerToken,
          authHeaders: authHeaders,
        );
        if (path != null) uploaded[uri] = path;
      }
    }

    await Future.wait(List.generate(
        _parallel < queue.length ? _parallel : queue.length, (_) => worker()));
    if (uploaded.isEmpty) return files;

    final out = Map<String, String>.from(files);
    for (final e in files.entries) {
      if (!e.key.toLowerCase().endsWith('.html')) continue;
      final depth = '/'.allMatches(e.key).length;
      final up = '../' * depth;
      out[e.key] = e.value.replaceAllMapped(_dataUriRe, (m) {
        final p = uploaded[m.group(0)!];
        return p == null ? m.group(0)! : '$up$p';
      });
    }
    return out;
  }

  static Future<String?> uploadOne({
    required String dataUri,
    required Uri endpoint,
    required String siteId,
    String? ownerToken,
    Map<String, String> authHeaders = const {},
  }) {
    return _uploadWithRetry(
      uri: dataUri,
      endpoint: endpoint,
      siteId: siteId,
      ownerToken: ownerToken,
      authHeaders: authHeaders,
    );
  }

  static Future<String?> _uploadWithRetry({
    required String uri,
    required Uri endpoint,
    required String siteId,
    required String? ownerToken,
    required Map<String, String> authHeaders,
  }) async {
    Uint8List bytes;
    try {
      bytes = base64Decode(uri.substring(uri.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .post(
              endpoint,
              headers: {
                'Content-Type': 'application/octet-stream',
                'x-site-id': siteId,
                if (ownerToken != null && ownerToken.trim().isNotEmpty)
                  'x-owner-token': ownerToken.trim(),
                ...authHeaders,
              },
              body: bytes,
            )
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) {
          final path = (jsonDecode(res.body) as Map)['path'];
          if (path is String && _serverPathRe.hasMatch(path)) return path;
          return null;
        }
        if (res.statusCode >= 400 && res.statusCode < 500) return null;
      } catch (_) {
      }
    }
    return null;
  }
}
