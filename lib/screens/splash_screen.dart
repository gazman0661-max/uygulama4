import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import 'quick_tools_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _textFadeAnim;
  late final Animation<double> _sparkleAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // İkon: başlangıçta hafif "pop" ile büyüyerek belirir.
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.26, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.34, curve: Curves.easeOutBack),
      ),
    );

    // Arka plan glow: ikon belirdikten sonra yavaşça nefes alır (nabız).
    _glowAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.55)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 0.55, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 35),
    ]).animate(_controller);

    // Başlık: ikondan biraz sonra yukarı kayarak belirir.
    _textFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.5, curve: Curves.easeOut),
    );

    // Sparkle parıltı dönüşü: sürekli, ince bir parlama-sönme döngüsü.
    _sparkleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.linear),
    );

    _controller.forward();

    // Toplam 3.5 saniye splash gösterimi.
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          // Yeni ana ekran: Hızlı Araçlar (sektörel site formları). AI
          // Sohbet artık buradan açılan, ilerde PRO olarak sunulabilecek
          // ayrı bir akış — bkz. quick_tools_screen.dart üstteki AI kartı.
          pageBuilder: (_, __, ___) => const QuickToolsScreen(),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              // İkonla aynı diyagonal marka gradyanı: koyu lacivert -> camgöbeği mavi.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF071426),
                  Color(0xFF0C4A82),
                  Color(0xFF1E9BD6),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Merkezi nefes alan glow (ikonun arkasında atmosfer).
                Center(
                  child: Container(
                    width: size.width * 0.9,
                    height: size.width * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF38BDF8)
                              .withOpacity(0.30 * _glowAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Sabit dekoratif sparkle'lar (ikondaki kompozisyonla uyumlu).
                Positioned(
                  right: size.width * 0.16,
                  top: size.height * 0.30,
                  child: _Sparkle(
                    animation: _sparkleAnim,
                    size: 22,
                    color: Colors.white,
                    phase: 0.0,
                  ),
                ),
                Positioned(
                  left: size.width * 0.20,
                  bottom: size.height * 0.34,
                  child: _Sparkle(
                    animation: _sparkleAnim,
                    size: 13,
                    color: const Color(0xFF6EDCFF),
                    phase: 0.5,
                  ),
                ),

                // Orta içerik: ikon + başlık.
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8)
                                      .withOpacity(0.45 * _glowAnim.value),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeTransition(
                        opacity: _textFadeAnim,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _textFadeAnim.value) * 10),
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) =>
                                    const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFBFEBFF),
                                  ],
                                ).createShader(rect),
                                child: const Text(
                                  'SITORA AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: 2.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t(context, 'AI DESTEKLİ SİTE OLUŞTURUCU'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Alt kısımda ince, marka renginde nabız çizgisi (nokta yerine).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: size.height * 0.09,
                  child: Center(
                    child: FadeTransition(
                      opacity: _textFadeAnim,
                      child: _PulseBar(animation: _sparkleAnim),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 4 köşeli ışıltı (sparkle) şekli; animasyonla hafifçe parlayıp söner.
class _Sparkle extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final Color color;
  final double phase;

  const _Sparkle({
    required this.animation,
    required this.size,
    required this.color,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = (animation.value + phase) % 1.0;
        final opacity = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: CustomPaint(
            size: Size(size, size),
            painter: _SparklePainter(color: color),
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = outer * 0.22;

    final path = Path()
      ..moveTo(cx, cy - outer)
      ..lineTo(cx + inner * 0.6, cy - inner * 0.6)
      ..lineTo(cx + outer, cy)
      ..lineTo(cx + inner * 0.6, cy + inner * 0.6)
      ..lineTo(cx, cy + outer)
      ..lineTo(cx - inner * 0.6, cy + inner * 0.6)
      ..lineTo(cx - outer, cy)
      ..lineTo(cx - inner * 0.6, cy - inner * 0.6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Yükleniyor göstergesi: dönen mavi nokta yerine, genişliği nabız gibi
/// yumuşakça oynayan ince bir gradyan çubuk.
class _PulseBar extends StatelessWidget {
  final Animation<double> animation;
  const _PulseBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        final width = 46 + 18 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
        return Container(
          width: width,
          height: 3.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF6EDCFF),
                Colors.white,
                Color(0xFF6EDCFF),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}
