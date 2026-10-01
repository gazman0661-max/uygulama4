import 'dart:convert';
import 'dart:typed_data';

class TransferImagePrep {
  final Map<String, dynamic> snapshot;

  final int uploaded;

  final int failed;

  final bool droppedInline;

  const TransferImagePrep({
    required this.snapshot,
    required this.uploaded,
    required this.failed,
    required this.droppedInline,
  });
}

class TransferImageRestore {
  final Map<String, dynamic> snapshot;

  final int restored;

  final int missing;

  const TransferImageRestore({
    required this.snapshot,
    required this.restored,
    required this.missing,
  });
}

class TransferImages {
  TransferImages._();

  static const int minExternalizeChars = 20 * 1024;

  static const int maxSnapshotChars = 700000;

  static const int maxDownloadBytes = 3 * 1024 * 1024;

  static const String markerPrefix = 'sitora-img:';

  static const String placeholderDataUri =
      'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';

  static const int _parallel = 4;

  static final RegExp _dataUriRe =
      RegExp(r'data:image/(?:png|jpe?g|webp|gif);base64,([A-Za-z0-9+/=]+)');
  static final RegExp _pathRe =
      RegExp(r'^img/[a-f0-9]{32}\.(?:webp|png|jpg|gif)$');
  static final RegExp _markerRe =
      RegExp(r'sitora-img:(img/[a-f0-9]{32}\.(?:webp|png|jpg|gif))');
  static final RegExp _looseMarkerRe = RegExp(r'''sitora-img:[^\s"')]*''');
  static final RegExp _slugRe = RegExp(r'^[a-z0-9][a-z0-9-]{0,62}$');

  static void _walkStrings(dynamic v, void Function(String) f) {
    if (v is String) {
      f(v);
    } else if (v is Map) {
      for (final e in v.values) {
        _walkStrings(e, f);
      }
    } else if (v is List) {
      for (final e in v) {
        _walkStrings(e, f);
      }
    }
  }

  static dynamic _mapStrings(dynamic v, String Function(String) f) {
    if (v is String) return f(v);
    if (v is Map) {
      return v.map<String, dynamic>(
        (k, val) => MapEntry(k.toString(), _mapStrings(val, f)),
      );
    }
    if (v is List) return v.map((e) => _mapStrings(e, f)).toList();
    return v;
  }

  static Future<TransferImagePrep> prepareSnapshot(
    Map<String, dynamic> json, {
    required Future<String?> Function(String dataUri) upload,
    required Map<String, dynamic> Function(Map<String, dynamic>) stripAll,
    Future<String> Function(String dataUri)? optimize,
  }) async {
    final large = <String>{};
    _walkStrings(json, (s) {
      if (!s.contains('base64,')) return;
      for (final m in _dataUriRe.allMatches(s)) {
        if (m.group(1)!.length >= minExternalizeChars) large.add(m.group(0)!);
      }
    });

    final table = <String, String>{};
    var failed = 0;
    final queue = large.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final original = queue.removeLast();
        var toUpload = original;
        if (optimize != null) {
          try {
            toUpload = await optimize(original);
          } catch (_) {
            toUpload = original;
          }
        }
        String? path;
        try {
          path = await upload(toUpload);
        } catch (_) {
          path = null;
        }
        if (path != null && _pathRe.hasMatch(path)) {
          table[original] = '$markerPrefix$path';
        } else {
          failed++;
        }
      }
    }

    final n = _parallel < queue.length ? _parallel : queue.length;
    await Future.wait(List.generate(n, (_) => worker()));

    var tree = json;
    if (table.isNotEmpty) {
      tree = _mapStrings(json, (s) {
        if (!s.contains('data:image/')) return s;
        return s.replaceAllMapped(_dataUriRe, (m) => table[m.group(0)!] ?? m.group(0)!);
      }) as Map<String, dynamic>;
    }

    var droppedInline = false;
    if (jsonEncode(tree).length > maxSnapshotChars) {
      tree = stripAll(tree);
      droppedInline = true;
    }
    return TransferImagePrep(
      snapshot: tree,
      uploaded: table.length,
      failed: failed,
      droppedInline: droppedInline,
    );
  }

  static Uri? trustedSiteBase({required String workerBaseUrl, required String? slug}) {
    if (slug == null || !_slugRe.hasMatch(slug)) return null;
    final base = Uri.tryParse(workerBaseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) return null;
    return Uri(scheme: 'https', host: base.host, port: base.hasPort ? base.port : null, path: '/s/$slug/');
  }

  static String _mime(String path) {
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.jpg')) return 'image/jpeg';
    if (path.endsWith('.gif')) return 'image/gif';
    return 'image/webp';
  }

  static Future<TransferImageRestore> restore(
    Map<String, dynamic> json, {
    required Uri? siteBase,
    required Future<Uint8List?> Function(Uri url) download,
  }) async {
    final paths = <String>{};
    _walkStrings(json, (s) {
      if (!s.contains(markerPrefix)) return;
      for (final m in _markerRe.allMatches(s)) {
        paths.add(m.group(1)!);
      }
    });

    final table = <String, String>{};
    var missing = 0;
    var restored = 0;
    final queue = paths.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        Uint8List? bytes;
        if (siteBase != null) {
          try {
            bytes = await download(siteBase.resolve(path));
          } catch (_) {
            bytes = null;
          }
        }
        if (bytes == null || bytes.isEmpty || bytes.length > maxDownloadBytes) {
          table['$markerPrefix$path'] = placeholderDataUri;
          missing++;
        } else {
          table['$markerPrefix$path'] = 'data:${_mime(path)};base64,${base64Encode(bytes)}';
          restored++;
        }
      }
    }

    final n = _parallel < queue.length ? _parallel : queue.length;
    await Future.wait(List.generate(n, (_) => worker()));

    final tree = _mapStrings(json, (s) {
      if (!s.contains(markerPrefix)) return s;
      final replaced = s.replaceAllMapped(_markerRe, (m) => table[m.group(0)!] ?? placeholderDataUri);
      return replaced.replaceAll(_looseMarkerRe, placeholderDataUri);
    }) as Map<String, dynamic>;

    return TransferImageRestore(snapshot: tree, restored: restored, missing: missing);
  }
}
