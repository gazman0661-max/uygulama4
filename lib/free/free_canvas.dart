import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'free_model.dart';
import 'free_social.dart';
import 'free_theme.dart';

int _clampI(int v, int lo, int hi) {
  if (hi < lo) hi = lo;
  return v < lo ? lo : (v > hi ? hi : v);
}

/// Izgaraya yapışan sürükle-bırak tuval — TEK bir canvas bölümü için.
/// Masaüstü görünümünde serbest yerleşim, mobil görünümde alt alta
/// (ReorderableListView ile sıra değişir; yayınlanan sitenin ≤820px düzeniyle aynı).
class FreeCanvas extends StatefulWidget {
  final FreeSection section;
  final FreeTheme theme;
  final bool mobile;
  final String? selId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;
  const FreeCanvas({
    super.key,
    required this.section,
    required this.theme,
    required this.mobile,
    required this.selId,
    required this.onSelect,
    required this.onChanged,
  });

  @override
  State<FreeCanvas> createState() => _FreeCanvasState();
}

class _FreeCanvasState extends State<FreeCanvas> {
  Offset _acc = Offset.zero;
  int _c0 = 0, _r0 = 0, _w0 = 0, _h0 = 0;

  FreeTheme get th => widget.theme;
  FreeSection get sec => widget.section;

  static const _aligns = [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
  static const _textAligns = [TextAlign.left, TextAlign.center, TextAlign.right];

  Widget _view(FreeElement e) {
    final col = e.color != 0 ? Color(e.color) : th.textOn(sec.bg);
    switch (e.type) {
      case FType.title:
        return ClipRect(
          child: Align(
            alignment: _aligns[e.align],
            child: Text(
              e.text,
              textAlign: _textAligns[e.align],
              style: th.heading(TextStyle(
                fontSize: e.fontPx.toDouble(),
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: col,
              )),
            ),
          ),
        );
      case FType.text:
        return ClipRect(
          child: Align(
            alignment: _aligns[e.align],
            child: Text(
              e.text,
              textAlign: _textAligns[e.align],
              style: th.body(TextStyle(
                fontSize: e.fontPx.toDouble(),
                height: 1.5,
                color: col,
              )),
            ),
          ),
        );
      case FType.button:
        return Container(
          decoration: BoxDecoration(
            color: e.bg != 0 ? Color(e.bg) : th.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            e.text,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: th.body(TextStyle(
              fontSize: e.fontPx.toDouble(),
              fontWeight: FontWeight.w600,
              color: e.color != 0 ? Color(e.color) : th.accentText,
            )),
          ),
        );
      case FType.image:
        final bytes = freeImageBytes(e.img);
        if (bytes == null) {
          return Container(
            color: th.chipBg,
            child: Center(child: Icon(Icons.image_outlined, size: 36, color: th.subtext)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          ),
        );
      case FType.social:
        final pf = SocialPlatform.values.firstWhere(
          (x) => x.name == e.platform,
          orElse: () => SocialPlatform.whatsapp,
        );
        return Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.string(FreeSocial.forPlatform(pf)),
        );
      case FType.shape:
        return Container(
          decoration: BoxDecoration(
            color: e.bg != 0 ? Color(e.bg) : th.chipBg,
            border: e.bg != 0 ? null : Border.all(color: th.border),
            borderRadius: BorderRadius.circular(10),
          ),
        );
    }
  }

  Widget _box(FreeElement e, {double cw = 0}) {
    final sel = widget.selId == e.id;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: sel ? Colors.indigo : Colors.transparent, width: 2),
      ),
      child: Stack(fit: StackFit.expand, children: [
        _view(e),
        if (sel)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanStart: (_) {
                _acc = Offset.zero;
                _w0 = e.w;
                _h0 = e.h;
              },
              onPanUpdate: (d) {
                _acc += d.delta;
                setState(() {
                  if (!widget.mobile && cw > 0) {
                    e.w = _clampI(_w0 + (_acc.dx / cw).round(), 1, kCols - e.c);
                  }
                  e.h = _clampI(_h0 + (_acc.dy / kRow).round(), 1, 300);
                });
              },
              onPanEnd: (_) => widget.onChanged(),
              child: Container(
                width: 28,
                height: 28,
                color: Colors.indigo,
                child: Icon(
                  widget.mobile ? Icons.height : Icons.open_in_full,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = th.sectionBg(sec.bg);
    if (widget.mobile) {
      final o = sec.ordered;
      return Container(
        color: bg,
        constraints: const BoxConstraints(minHeight: kMinCanvasRows * kRow),
        child: ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          onReorder: (a, b) {
            if (b > a) b--;
            final it = o.removeAt(a);
            o.insert(b, it);
            for (var i = 0; i < o.length; i++) {
              o[i].mo = i;
            }
            widget.onChanged();
          },
          children: [
            for (final e in o)
              Padding(
                key: ValueKey(e.id),
                padding: const EdgeInsets.fromLTRB(12, 5, 28, 5),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelect(e.id),
                  child: SizedBox(height: e.h * kRow, child: _box(e)),
                ),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(builder: (ctx, bc) {
      final cw = bc.maxWidth / kCols;
      return GestureDetector(
        onTap: () => widget.onSelect(null),
        child: Container(
          color: bg,
          child: CustomPaint(
            foregroundPainter: _GridPainter(cw, th.border),
            child: SizedBox(
              width: bc.maxWidth,
              height: sec.rows * kRow,
              child: Stack(children: [
              for (final e in sec.els)
                Positioned(
                  left: e.c * cw,
                  top: e.r * kRow,
                  width: e.w * cw,
                  height: e.h * kRow,
                  child: GestureDetector(
                    onTap: () => widget.onSelect(e.id),
                    onPanStart: (_) {
                      widget.onSelect(e.id);
                      _acc = Offset.zero;
                      _c0 = e.c;
                      _r0 = e.r;
                    },
                    onPanUpdate: (d) {
                      _acc += d.delta;
                      setState(() {
                        e.c = _clampI(_c0 + (_acc.dx / cw).round(), 0, kCols - e.w);
                        e.r = _clampI(_r0 + (_acc.dy / kRow).round(), 0, 1000);
                      });
                    },
                    onPanEnd: (_) => widget.onChanged(),
                    child: _box(e, cw: cw),
                  ),
                ),
            ]),
            ),
          ),
        ),
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  final double cw;
  final Color color;
  _GridPainter(this.cw, this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color.withOpacity(0.35);
    for (var i = 4; i < kCols; i += 4) {
      c.drawLine(Offset(i * cw, 0), Offset(i * cw, s.height), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => o.cw != cw || o.color != color;
}
