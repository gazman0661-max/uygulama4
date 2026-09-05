import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../localization/app_strings.dart';
import '../services/debug_log_service.dart';
import '../theme/theme_controller.dart';

/// 05.09.2026 eklendi — Ayarlar > "Hata Kayıtları" ekranı. Kanka'nın
/// telefonunun USB'si sorunlu olduğu için `adb logcat` kullanamıyor; bu
/// ekran DebugLogService'teki bellek-içi kayıtları gösterip tek dokunuşla
/// panoya kopyalamayı sağlıyor (bkz. debug_log_service.dart üstündeki not —
/// KALICI değil, uygulama kapanınca sıfırlanır).
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  void _copyAll(List<String> logs) {
    Clipboard.setData(ClipboardData(text: logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(context, 'Kayıtlar kopyalandı'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
    final bg = isDark ? const Color(0xFF0D1117) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    // Eskiden yeniye tutuluyor (bkz. DebugLogService) — ekranda en yeni
    // kayıt en üstte görünsün diye ters çeviriyoruz.
    final logs = DebugLogService.instance.entries.toList().reversed.toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: textColor,
        title: Text(
          t(context, 'Hata Kayıtları'),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: t(context, 'Tümünü kopyala'),
            onPressed: logs.isEmpty ? null : () => _copyAll(logs),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: t(context, 'Temizle'),
            onPressed: logs.isEmpty
                ? null
                : () => setState(() => DebugLogService.instance.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: t(context, 'Yenile'),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SafeArea(
        child: logs.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t(
                      context,
                      'Henüz kayıt yok. Bir proje oluştur/yayınla, sonra uygulamayı kapatmadan buraya dön.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, __) =>
                    Divider(color: textColor.withOpacity(0.08)),
                itemBuilder: (context, i) => SelectableText(
                  logs[i],
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
      ),
    );
  }
}
