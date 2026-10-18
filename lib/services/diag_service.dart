import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TESHIS (gecici): oyundaki tum kayit/giris/hata olaylarini toplar, ekranda gosterir.
/// Sag ustteki kucuk "TESHIS" dugmesine bas -> kayit penceresi -> KOPYALA.
class Diag {
  Diag._();
  static final Diag instance = Diag._();

  final List<String> _lines = [];
  final ValueNotifier<int> changed = ValueNotifier<int>(0);

  void log(String tag, String msg) {
    final n = DateTime.now();
    String two(int v) => v < 10 ? '0$v' : '$v';
    final t = '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
    _lines.add('$t [$tag] $msg');
    if (_lines.length > 400) _lines.removeAt(0);
    scheduleMicrotask(() => changed.value++);
  }

  String get text => _lines.join('\n');

  /// Acilista bir kez: kalicilik kaniti (acilis sayaci) + diskte ne var.
  Future<void> startup() async {
    try {
      final p = await SharedPreferences.getInstance();
      final n = (p.getInt('diag_launch_count') ?? 0) + 1;
      final okW = await p.setInt('diag_launch_count', n);
      final first = p.getString('diag_first_launch') ?? DateTime.now().toIso8601String();
      await p.setString('diag_first_launch', first);
      log('ACILIS', 'acilis sayisi=$n (setInt=$okW) ilk acilis=$first');
      final keys = p.getKeys().toList()..sort();
      log('ACILIS', 'diskte ${keys.length} anahtar: ${keys.join(', ')}');
      log('ACILIS', 'onay=${p.getInt('legal_consent_version_v1')} ilerlemeBoyu=${p.getString('game_progress_v1')?.length}');
    } catch (e) {
      log('ACILIS-HATA', '$e');
    }
  }
}

/// MaterialApp.builder icinde: sag ustte dugme + tam ekran kayit paneli.
class DiagOverlay extends StatefulWidget {
  const DiagOverlay({super.key});

  @override
  State<DiagOverlay> createState() => _DiagOverlayState();
}

class _DiagOverlayState extends State<DiagOverlay> {
  bool _open = false;
  String _copied = '';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        if (!_open)
          Positioned(
            top: top + 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _open = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xCCB00020), borderRadius: BorderRadius.circular(8)),
                child: const Text('TESHIS', style: TextStyle(color: Colors.white, fontSize: 10, decoration: TextDecoration.none)),
              ),
            ),
          ),
        if (_open)
          Positioned.fill(
            child: Material(
              color: const Color(0xF2101010),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: Diag.instance.text));
                            setState(() => _copied = 'Kopyalandi');
                          },
                          child: const Text('KOPYALA'),
                        ),
                        TextButton(onPressed: () => setState(() {}), child: const Text('YENILE')),
                        TextButton(onPressed: () => setState(() => _open = false), child: const Text('KAPAT')),
                        Text(_copied, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      ],
                    ),
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: Diag.instance.changed,
                        builder: (_, __, ___) => SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: SelectableText(
                            Diag.instance.text,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String diagJson(Object? o) {
  try {
    return jsonEncode(o);
  } catch (_) {
    return '$o';
  }
}
