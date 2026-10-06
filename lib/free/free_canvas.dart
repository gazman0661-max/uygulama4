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
/// Masaüstü görünümünde serbest yerleşim. Mobil görünümde iki mod:
///  • [mobileCustom] false: alt alta (ReorderableListView ile sıra değişir; yayındaki ≤820px düzeniyle aynı)
///  • [mobileCustom] true : AYRI mobil düzen — aynı ızgara, ama öğelerin mobil konum/boyutu
///    ([FreeElement.mc/mr/mw/mh]) düzenlenir; masaüstü düzeni etkilenmez.
class FreeCanvas extends StatefulWidget {
  final FreeSection section;
  final FreeTheme theme;
  final bool mobile;
  final bool mobileCustom;
  final String? selId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;

  /// Hazır blok / iletişim öğelerinin editördeki önizlemesi (site ve tema bilgisi gerektirir).
  final Widget Function(FreeElement)? specialBuilder;
  const FreeCanvas({
    super.key,
    required this.section,
    required this.theme,
    required this.mobile,
    this.mobileCustom = false,
    required this.selId,
    required this.onSelect,
    required this.onChanged,
    this.specialBuilder,
  });

  @override
  State<FreeCanvas> createState() => _FreeCanvasState();
}

class _FreeCanvasState extends State<FreeCanvas> {
  Offset _acc = Offset.zero;
  int _c0 = 0, _r0 = 0, _w0 = 0, _h0 = 0;

  FreeTheme get th => widget.theme;
  FreeSection get sec => widget.section;

  /// Ayrı mobil düzende mobil geometri düzenleniyor mu? (öğe erişimcilerine geçirilir)
  bool get _m => widget.mobile && widget.mobileCustom;

  /// Eski mobil görünüm: alt alta sıralı liste.
  bool get _list => widget.mobile && !widget.mobileCustom;

  static const _aligns = [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
  static const _textAligns = [TextAlign.left, TextAlign.center, TextAlign.right];

  Widget _view(FreeElement e) {
    final col = e.color != 0 ? Color(e.color) : th.textOn(sec.bandBgFor(e, mobile: _m));
    switch (e.type) {
      case FType.title:
        return ClipRect(
          child: Align(
            alignment: _aligns[e.align],
            child: Text(
              e.text,
              textAlign: _textAligns[e.align],
              style: th.heading(TextStyle(
                fontSize: e.fontPxOn(_m).toDouble(),
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
                fontSize: e.fontPxOn(_m).toDouble(),
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
              fontSize: e.fontPxOn(_m).toDouble(),
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
      case FType.band:
        return Container(color: e.bg != 0 ? Color(e.bg) : th.chipBg.withOpacity(0.6));
      case FType.block:
      case FType.contact:
        return widget.specialBuilder?.call(e) ??
            Container(
              color: th.chipBg,
              alignment: Alignment.center,
              child: Icon(e.type == FType.contact ? Icons.contact_phone_outlined : Icons.view_quilt_outlined, color: th.subtext),
            );
    }
  }

  /// Bir boyutlandırma tutamacı. [dx]/[dy] hangi eksenin değiştiğini söyler:
/// sağ kenar -> sadece genişlik, alt kenar -> sadece yükseklik, köşe -> ikisi.
  /// Dokunma alanı görünen şekilden BÜYÜKTÜR (parmakla tutması kolay); küçük öğelerde
  /// öğenin %40'ından büyük olmaz ki öğeyi sürüklemek de mümkün kalsın.
  Widget _handle(
    FreeElement e, {
    required double cw,
    required double boxW,
    required double boxH,
    required Alignment al,
    required bool dx,
    required bool dy,
    required Size hit,
    required Size look,
    required IconData icon,
  }) {
    final hw = hit.width > boxW * 0.4 ? (boxW * 0.4 < 16 ? 16.0 : boxW * 0.4) : hit.width;
    final hh = hit.height > boxH * 0.4 ? (boxH * 0.4 < 16 ? 16.0 : boxH * 0.4) : hit.height;
    return Align(
      alignment: al,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          _acc = Offset.zero;
          _w0 = e.wOn(_m);
          _h0 = e.hOn(_m);
        },
        onPanUpdate: (d) {
          _acc += d.delta;
          setState(() {
            if (dx && !_list && cw > 0) {
              e.setW(_m, _clampI(_w0 + (_acc.dx / cw).round(), 1, kCols - e.cOn(_m)));
            }
            if (dy) {
              e.setH(_m, _clampI(_h0 + (_acc.dy / kRow).round(), 1, 300));
            }
          });
        },
        onPanEnd: (_) => widget.onChanged(),
        child: SizedBox(
          width: hw,
          height: hh,
          child: Align(
            alignment: al,
            child: Container(
              width: look.width,
              height: look.height,
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(icon, size: 13, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(FreeElement e, {double cw = 0, double? mobileW}) {
    final sel = widget.selId == e.id;
    final boxW = _list ? (mobileW ?? 200) : e.wOn(_m) * cw;
    final boxH = e.hOn(_m) * kRow;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: sel ? Colors.indigo : Colors.transparent, width: 2),
      ),
      child: Stack(fit: StackFit.expand, children: [
        _view(e),
        if (sel) ...[
          // alt kenar (yükseklik) — mobil ve masaüstünde
          _handle(e,
              cw: cw,
              boxW: boxW,
              boxH: boxH,
              al: Alignment.bottomCenter,
              dx: false,
              dy: true,
              hit: const Size(72, 30),
              look: const Size(34, 14),
              icon: Icons.drag_handle),
          // sağ kenar (genişlik) — yalnız masaüstü düzeninde
          if (!_list && e.type != FType.band)
            _handle(e,
                cw: cw,
                boxW: boxW,
                boxH: boxH,
                al: Alignment.centerRight,
                dx: true,
                dy: false,
                hit: const Size(30, 72),
                look: const Size(14, 34),
                icon: Icons.drag_indicator),
          // köşe (ikisi birden) — şeritte yok (hep tam genişlik)
          if (e.type != FType.band)
            _handle(e,
              cw: cw,
              boxW: boxW,
              boxH: boxH,
              al: Alignment.bottomRight,
              dx: true,
              dy: true,
              hit: const Size(46, 46),
              look: const Size(24, 24),
              icon: _list ? Icons.height : Icons.open_in_full),
        ],
      ]),
    );
  }

  bool _isSpecial(FreeElement e) => e.type == FType.block || e.type == FType.contact;

  @override
  Widget build(BuildContext context) {
    final bg = th.sectionBg(0);
    if (_list) {
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
              Container(
                key: ValueKey(e.id),
                // Yayındaki gibi: şerit içindeki öğelerin arkası şerit rengi (tam genişlik).
                color: sec.bandBgFor(e) != 0 ? Color(sec.bandBgFor(e)) : null,
                padding: const EdgeInsets.fromLTRB(12, 5, 28, 5),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelect(e.id),
                  child: _isSpecial(e)
                      // Bloklar mobilde içerik kadar uzar (yayındaki gibi).
                      ? Stack(children: [
                          widget.specialBuilder?.call(e) ?? SizedBox(height: e.h * kRow),
                          if (widget.selId == e.id)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.indigo, width: 2))),
                              ),
                            ),
                        ])
                      : SizedBox(height: e.h * kRow, child: _box(e, mobileW: 300)),
                ),
              ),
          ],
        ),
      );
    }
    // Şeritler en arkada, diğerleri liste sırasıyla (sonraki = üstte).
    final drawn = [
      ...sec.els.where((e) => e.type == FType.band),
      ...sec.els.where((e) => e.type != FType.band),
    ];
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
              height: sec.rowsOn(_m) * kRow,
              child: Stack(children: [
                for (final e in drawn)
                  Positioned(
                    left: e.type == FType.band ? 0 : e.cOn(_m) * cw,
                    top: e.rOn(_m) * kRow,
                    width: e.type == FType.band ? bc.maxWidth : e.wOn(_m) * cw,
                    height: e.hOn(_m) * kRow,
                    child: GestureDetector(
                      onTap: () => widget.onSelect(e.id),
                      onPanStart: (_) {
                        widget.onSelect(e.id);
                        _acc = Offset.zero;
                        _c0 = e.cOn(_m);
                        _r0 = e.rOn(_m);
                      },
                      onPanUpdate: (d) {
                        _acc += d.delta;
                        setState(() {
                          if (e.type != FType.band) {
                            e.setC(_m, _clampI(_c0 + (_acc.dx / cw).round(), 0, kCols - e.wOn(_m)));
                          }
                          e.setR(_m, _clampI(_r0 + (_acc.dy / kRow).round(), 0, 1000));
                        });
                      },
                      onPanEnd: (_) => widget.onChanged(),
                      child: _box(e, cw: e.type == FType.band ? bc.maxWidth / kCols : cw),
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
