import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_theme.dart';
import '../localization/app_strings.dart';

/// Builder Pro > "Çizim" aracı.
///
/// Eskiden burada "Stiller" (hazır renk/köşe presetlerini elemanlara
/// döngüsel uygulayan _cycleStyle) aracı vardı — kaldırıldı. Onun yerine
/// kullanıcı burada serbest elle kendi şeklini/çizimini oluşturur; "Çizimi
/// Ekle" ile bu çizim canvas'a normal bir görsel (image) eleman olarak
/// eklenir ve sonrasında diğer elemanlar gibi taşınıp yeniden
/// boyutlandırılabilir.
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke({required this.points, required this.color, required this.width});
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length < 2) {
        if (s.points.isNotEmpty) {
          canvas.drawCircle(s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
        }
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

Future<void> showDrawingPadDialog(
  BuildContext context, {
  required void Function(Uint8List pngBytes) onAdd,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141821),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => DrawingPadDialog(onAdd: onAdd),
  );
}

class DrawingPadDialog extends StatefulWidget {
  final void Function(Uint8List pngBytes) onAdd;
  const DrawingPadDialog({super.key, required this.onAdd});

  @override
  State<DrawingPadDialog> createState() => _DrawingPadDialogState();
}

class _DrawingPadDialogState extends State<DrawingPadDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  Color _penColor = Colors.black;
  double _penSize = 6;
  bool _isEraser = false;

  static const List<Color> _presetColors = [
    Color(0xFFFF0000),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFF00FF00),
    Color(0xFFFF00FF),
    Color(0xFFFFFF00),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  Offset _localFromGlobal(Offset global) {
    final box = _boundaryKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(global);
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(_Stroke(
        points: [_localFromGlobal(details.globalPosition)],
        color: _isEraser ? Colors.white : _penColor,
        width: _penSize,
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _strokes.last.points.add(_localFromGlobal(details.globalPosition));
    });
  }

  void _clear() => setState(() => _strokes.clear());

  Future<void> _pickColor() async {
    Color temp = _penColor;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1C232E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(context, 'Renk seçin'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _presetColors.map((c) {
                    final active = c.value == temp.value;
                    return GestureDetector(
                      onTap: () => setDialogState(() => temp = c),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active ? AppColors.accentCyan : Colors.white24,
                            width: active ? 2.6 : 1.2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final custom = await _showCustomColorSliders(dialogCtx, temp);
                        if (custom != null) setDialogState(() => temp = custom);
                      },
                      child: Text(t(context, 'Özel'), style: const TextStyle(color: AppColors.accentBlue, fontSize: 16)),
                    ),
                    Row(
                      children: [
                        Text(t(context, 'Seçilen renk'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(width: 10),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: temp,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(t(context, 'İptal'), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(temp),
                      child: Text(t(context, 'Ayarla'),
                          style: const TextStyle(
                              color: AppColors.accentBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _penColor = result;
        _isEraser = false;
      });
    }
  }

  Future<Color?> _showCustomColorSliders(BuildContext ctx, Color initial) {
    double r = initial.red.toDouble();
    double g = initial.green.toDouble();
    double b = initial.blue.toDouble();
    return showDialog<Color>(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setS) {
          final preview = Color.fromARGB(255, r.round(), g.round(), b.round());
          Widget slider(String label, double value, ValueChanged<double> onChanged, Color trackColor) {
            return Row(
              children: [
                SizedBox(width: 18, child: Text(label, style: const TextStyle(color: Colors.white70))),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 255,
                    activeColor: trackColor,
                    onChanged: onChanged,
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1C232E),
            title: Text(t(context, 'Özel Renk'), style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(color: preview, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 12),
                slider('R', r, (v) => setS(() => r = v), Colors.red),
                slider('G', g, (v) => setS(() => g = v), Colors.green),
                slider('B', b, (v) => setS(() => b = v), Colors.blue),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dctx).pop(),
                  child: Text(t(context, 'İptal'), style: const TextStyle(color: Colors.white70))),
              TextButton(
                  onPressed: () => Navigator.of(dctx).pop(preview),
                  child: Text(t(context, 'Ayarla'), style: const TextStyle(color: AppColors.accentBlue))),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addDrawing() async {
    if (_strokes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      widget.onAdd(bytes);
    } catch (_) {
      // sessizce yut — kapatma her koşulda gerçekleşir.
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, 'Kendi Şeklini Çiz'),
                  style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CustomPaint(
                        painter: _DrawingPainter(_strokes),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: _isEraser ? const Color(0xFFEF5350) : AppColors.accentBlue,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _isEraser = !_isEraser),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              t(context, _isEraser ? '🖌️ Silgi' : '✏️ Kalem'),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _pickColor,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _penColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(t(context, 'Kalem Boyutu:'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: _penSize,
                      min: 1,
                      max: 30,
                      activeColor: AppColors.accentCyan,
                      onChanged: (v) => setState(() => _penSize = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _addDrawing,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFECEFF1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide.none,
                      ),
                      child: Text(t(context, 'Çizimi Ekle'),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFECEFF1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide.none,
                      ),
                      child: Text(t(context, 'Temizle'),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFECEFF1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                  ),
                  child: Text(t(context, 'Kapat'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
