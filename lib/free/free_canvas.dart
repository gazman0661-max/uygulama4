import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Sayfayı kaydıran ListView'in controller'ı. Verilirse sürüklerken ekranın üst/alt kenarına
  /// yaklaşınca sayfa OTOMATİK kayar (uzun sayfada öğeyi uzağa taşımak için).
  final ScrollController? scrollController;

  /// Parmak bir öğenin/tutamacın üstüne inince true, kalkınca false. Üstteki ListView bu sırada
  /// kaydırmayı kilitler; yoksa dikey sürükleme öğeyi taşımak yerine SAYFAYI kaydırırdı.
  final ValueChanged<bool>? onDragLock;

  /// Altta açık duran özellik panelinin kapladığı yükseklik (px): otomatik kaydırma bölgesi bunun üstünde biter.
  final double bottomInset;
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
    this.scrollController,
    this.onDragLock,
    this.bottomInset = 0,
  });

  @override
  State<FreeCanvas> createState() => _FreeCanvasState();
}

class _FreeCanvasState extends State<FreeCanvas> {
  int _c0 = 0, _r0 = 0, _w0 = 0, _h0 = 0;

  // ---- sürükleme motoru -------------------------------------------------------------------
  // Konum, parmağın EKRANDAKİ konumundan + sayfanın kayma miktarından hesaplanır; böylece sayfa
  // otomatik kayarken öğe parmağın altında kalır. Hesap her seferinde başlangıca göre yapılır
  // (birikimli delta yok): yuvarlama hatası birikmez, öğe parmaktan kopmaz.
  Offset _startGlobal = Offset.zero;
  Offset _lastGlobal = Offset.zero;
  double _startScroll = 0;
  void Function(Offset total)? _applyDrag;
  Timer? _autoTimer;
  double _autoVel = 0;

  double get _scrollNow {
    final sc = widget.scrollController;
    return sc != null && sc.hasClients ? sc.offset : 0;
  }

  void _beginDrag(Offset global) {
    _startGlobal = global;
    _lastGlobal = global;
    _startScroll = _scrollNow;
    _applyDrag = null;
  }

  void _moveDrag(Offset global, void Function(Offset total) apply) {
    _lastGlobal = global;
    _applyDrag = apply;
    _applyNow();
    _updateAutoScroll(global);
  }

  void _applyNow() {
    final a = _applyDrag;
    if (a == null || !mounted) return;
    final total = Offset(
      _lastGlobal.dx - _startGlobal.dx,
      _lastGlobal.dy - _startGlobal.dy + (_scrollNow - _startScroll),
    );
    setState(() => a(total));
  }

  void _endDrag() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _autoVel = 0;
    _applyDrag = null;
  }

  /// Parmak görünür alanın üst/alt kenarına yaklaştıysa kaydırma hızını ayarlar.
  void _updateAutoScroll(Offset g) {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;
    final ro = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final top = ro.localToGlobal(Offset.zero).dy;
    final bottom = top + ro.size.height - widget.bottomInset;
    const zone = 80.0;
    double v = 0;
    if (g.dy < top + zone) {
      v = -((top + zone - g.dy) / zone).clamp(0.0, 1.0) * 14;
    } else if (g.dy > bottom - zone) {
      v = ((g.dy - (bottom - zone)) / zone).clamp(0.0, 1.0) * 14;
    }
    _autoVel = v;
    if (v == 0) {
      _autoTimer?.cancel();
      _autoTimer = null;
      return;
    }
    _autoTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final c = widget.scrollController;
      if (!mounted || c == null || !c.hasClients || _autoVel == 0) return;
      final pos = c.position;
      final next = (pos.pixels + _autoVel).clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
      if (next == pos.pixels) return;
      c.jumpTo(next);
      _applyNow(); // sayfa kaydı, parmak yerinde: öğe de kaymış kadar ilerler
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

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
      child: Listener(
        // Tutamaç küçük: üstündeyken sayfa kaydırması kilitlenir (boyutlandırma sırasında sayfa kaymasın).
        onPointerDown: (_) => widget.onDragLock?.call(true),
        onPointerUp: (_) => widget.onDragLock?.call(false),
        onPointerCancel: (_) => widget.onDragLock?.call(false),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          _beginDrag(d.globalPosition);
          _w0 = e.wOn(_m);
          _h0 = e.hOn(_m);
        },
        onPanUpdate: (d) => _moveDrag(d.globalPosition, (t) {
          if (dx && !_list && cw > 0) {
            e.setW(_m, _clampI(_w0 + (t.dx / cw).round(), 1, kCols - e.cOn(_m)));
          }
          if (dy) {
            e.setH(_m, _clampI(_h0 + (t.dy / kRow).round(), 1, 300));
          }
        }),
        onPanEnd: (_) {
          _endDrag();
          widget.onChanged();
        },
        onPanCancel: () {
          _endDrag();
          widget.onChanged();
        },
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

  /// Öğeyi taşımak için UZUN BAS (350 ms) ve sürükle. Kısa dokunuş seçer, hızlı sürükleme sayfayı kaydırır.
  Widget _movable(FreeElement e, double cw, Widget child) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 350)),
          (r) {
            r.onLongPressStart = (d) {
              HapticFeedback.selectionClick();
              widget.onSelect(e.id);
              _beginDrag(d.globalPosition);
              _c0 = e.cOn(_m);
              _r0 = e.rOn(_m);
            };
            r.onLongPressMoveUpdate = (d) => _moveDrag(d.globalPosition, (t) {
                  if (e.type != FType.band) {
                    e.setC(_m, _clampI(_c0 + (t.dx / cw).round(), 0, kCols - e.wOn(_m)));
                  }
                  e.setR(_m, _clampI(_r0 + (t.dy / kRow).round(), 0, 1000));
                });
            r.onLongPressEnd = (_) {
              _endDrag();
              widget.onChanged();
            };
            r.onLongPressCancel = () => _endDrag();
          },
        ),
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (r) => r.onTap = () => widget.onSelect(e.id),
        ),
      },
      child: child,
    );
  }

  /// Liste (otomatik sıra) modunda tek öğe satırı.
  Widget _listRow(FreeElement e) {
    return Container(
      // Yayındaki gibi: şerit içindeki öğelerin arkası şerit rengi (tam genişlik).
      color: sec.bandBgFor(e) != 0 ? Color(sec.bandBgFor(e)) : null,
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(e.id),
        // ÖNEMLİ: her öğe SINIRLI yükseklikte çizilir (hazır bloklar sınırsız yükseklikte çizilince liste boş kalıyordu).
        child: SizedBox(height: e.h * kRow, child: _listItem(e)),
      ),
    );
  }

  Widget _listItem(FreeElement e) {
    if (_isSpecial(e)) {
      return Stack(fit: StackFit.expand, children: [
        widget.specialBuilder?.call(e) ?? const SizedBox.shrink(),
        if (widget.selId == e.id)
          IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.indigo, width: 2)))),
      ]);
    }
    return _box(e, mobileW: 300);
  }

  /// Liste modunda kart: [şekil, içindeki öğeler...] tek kutu içinde. Kartın boş yerine dokunmak şekli seçer.
  Widget _listCard(List<FreeElement> g) {
    final shape = g.first;
    final sel = widget.selId == shape.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(shape.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: shape.bg != 0 ? Color(shape.bg) : th.chipBg,
            border: Border.all(color: sel ? Colors.indigo : (shape.bg != 0 ? Colors.transparent : th.border), width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (final k in g.skip(1))
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelect(k.id),
                child: SizedBox(height: k.h * kRow, child: _listItem(k)),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = th.sectionBg(0);
    if (_list) {
      final o = sec.ordered;
      // 08.10.2026: Bir kutunun (şeklin) İÇİNE düşen başlık/yazı/buton/resim/sosyal öğeler telefonda o kutunun
      // içinde TEK KART olarak gösterilir (yayındaki/önizlemedeki .fb-grp ile aynı mantık). Sıralama grup
      // düzeyinde yapılır; kart içindeki her öğe yine ayrı seçilip düzenlenir.
      final kidsOf = <FreeElement, List<FreeElement>>{};
      final grouped = <FreeElement>{};
      for (final k in o) {
        if (k.type == FType.band || k.type == FType.shape || _isSpecial(k)) continue;
        final kc = k.c + k.w / 2, kr = k.r + k.h / 2;
        FreeElement? best;
        for (final sh in o) {
          if (sh.type != FType.shape) continue;
          if (kc >= sh.c && kc <= sh.c + sh.w && kr >= sh.r && kr <= sh.r + sh.h) {
            if (best == null || sh.w * sh.h < best.w * best.h) best = sh;
          }
        }
        if (best != null) {
          (kidsOf[best] ??= []).add(k);
          grouped.add(k);
        }
      }
      final rows = <List<FreeElement>>[]; // her satır: [öğe] ya da [şekil, çocuk...]
      for (final e in o) {
        if (grouped.contains(e)) continue;
        final kids = kidsOf[e];
        rows.add(kids == null || kids.isEmpty
            ? [e]
            : [e, ...(kids..sort((x, y) => o.indexOf(x).compareTo(o.indexOf(y))))]);
      }
      return Container(
        color: bg,
        constraints: const BoxConstraints(minHeight: kMinCanvasRows * kRow),
        child: ReorderableListView(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          // Tüm platformlarda aynı: öğeye UZUN BASIP sürükle (sağda tutamaç çıkmaz).
          buildDefaultDragHandles: false,
          onReorder: (a, b) {
            if (b > a) b--;
            final it = rows.removeAt(a);
            rows.insert(b, it);
            var n = 0;
            for (final r in rows) {
              for (final x in r) {
                x.mo = n++;
              }
            }
            widget.onChanged();
          },
          children: [
            for (var i = 0; i < rows.length; i++)
              ReorderableDelayedDragStartListener(
                key: ValueKey(rows[i].first.id),
                index: i,
                child: rows[i].length == 1 ? _listRow(rows[i].first) : _listCard(rows[i]),
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
      // Kilit yok: öğe uzun basınca taşınır, normal sürükleme sayfayı kaydırır -> yan şeride gerek yok.
      const gutter = 0.0;
      final canvasW = (bc.maxWidth - gutter).clamp(48.0, double.infinity).toDouble();
      final cw = canvasW / kCols;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: canvasW,
          child: GestureDetector(
            onTap: () => widget.onSelect(null),
            child: Container(
              color: bg,
              child: CustomPaint(
                // Izgara çizgileri ARKADA: eskiden öğelerin ÜSTÜNE çiziliyor, yazıları çiziklemiş gibi gösteriyordu.
                painter: _GridPainter(cw, th.border),
                child: SizedBox(
                  width: canvasW,
                  height: sec.rowsOn(_m) * kRow,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (final e in drawn)
                      Positioned(
                        key: ValueKey(e.id),
                        left: e.type == FType.band ? 0 : e.cOn(_m) * cw,
                        top: e.rOn(_m) * kRow,
                        width: e.type == FType.band ? canvasW : e.wOn(_m) * cw,
                        height: e.hOn(_m) * kRow,
                        child: _movable(e, cw, _box(e, cw: cw)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: gutter),
      ]);
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
