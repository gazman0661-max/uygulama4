import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../services/log_service.dart';

/// HATA KAYITLARI: oyun icinde hatalari gor, kopyala (yapistir), paylas, temizle.
/// Sekmeler: Bu oturum | Sadece hatalar | Onceki oturumlar.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  static const MethodChannel _share = MethodChannel('merge_dunyalari/share');

  final AppLog _log = AppLog.instance;
  final ScrollController _sc = ScrollController();
  int _tab = 0; // 0 = bu oturum, 1 = hatalar, 2 = onceki
  bool _stick = true;

  bool get _tr => AppStrings.instance.language == AppLanguage.tr;

  @override
  void initState() {
    super.initState();
    _log.changed.addListener(_onChanged);
  }

  @override
  void dispose() {
    _log.changed.removeListener(_onChanged);
    _sc.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Ekranda sadece SON satirlar gosterilir (binlerce satirlik tek SelectableText donar).
  /// Kopyala / Paylas tum metni verir.
  static const int _showLines = 500;
  String _tail(String full) {
    final lines = full.split('\n');
    if (lines.length <= _showLines) return full;
    final skipped = lines.length - _showLines;
    return '... ($skipped eski satir ekranda gizli; KOPYALA/PAYLAS tamamini verir)\n${lines.sublist(lines.length - _showLines).join('\n')}';
  }

  String get _text {
    switch (_tab) {
      case 1:
        return _log.currentText(errorsOnly: true);
      case 2:
        return _log.previousText();
      default:
        return _log.currentText();
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  Future<void> _copy() async {
    final t = _text;
    await Clipboard.setData(ClipboardData(text: t));
    _toast(_tr ? 'Kopyalandı (${t.length} karakter)' : 'Copied (${t.length} chars)');
  }

  Future<void> _shareText() async {
    var t = _text;
    if (t.length > 60000) t = t.substring(t.length - 60000);
    try {
      await _share.invokeMethod<void>('shareText', <String, dynamic>{'text': t});
    } catch (err) {
      _toast(_tr ? 'Paylaşılamadı: $err' : 'Share failed: $err');
    }
  }

  Future<void> _clear() async {
    await _log.clear();
    if (mounted) setState(() {});
  }

  Widget _tabBtn(int i, String label) {
    final sel = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tab = i;
          _stick = true;
        }),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFFF7A1A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8A5A2B), width: 1.2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: sel ? Colors.white : const Color(0xFF4A2C0A)),
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = _tr;
    final text = _text;
    if (_stick && _tab != 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        title: Text(tr ? 'Hata Kayıtları' : 'Error Log', style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFFFF7A1A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  _tabBtn(0, tr ? 'Bu oturum' : 'This run'),
                  _tabBtn(1, tr ? 'Hatalar (${_log.errorCount + _log.warnCount})' : 'Errors (${_log.errorCount + _log.warnCount})'),
                  _tabBtn(2, tr ? 'Önceki' : 'Previous'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Row(
                children: [
                  _action(Icons.copy_rounded, tr ? 'Kopyala' : 'Copy', _copy),
                  _action(Icons.share_rounded, tr ? 'Paylaş' : 'Share', _shareText),
                  _action(Icons.delete_outline_rounded, tr ? 'Temizle' : 'Clear', _clear),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (n) {
                    if (_sc.hasClients) {
                      _stick = _sc.position.pixels >= _sc.position.maxScrollExtent - 40;
                    }
                    return false;
                  },
                  child: Scrollbar(
                    controller: _sc,
                    child: SingleChildScrollView(
                      controller: _sc,
                      child: SelectableText(
                        _tail(text),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.3,
                          color: Color(0xFFE6E6E6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
