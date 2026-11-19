import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/notifier.dart';
import '../theme.dart';
import 'shell.dart';

/// شاشة البداية المتحركة: ظل الموصل ← منارة الحدباء والجامع يطلعون من تحت ← شعار ديبو ← الجملة
/// وبعدها تدخل للتطبيق تلقائياً (التصفح بدون تسجيل — قرار معتمد)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  bool _animDone = false;
  bool _left = false;

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: c, curve: Interval(a, b, curve: curve));

  late final skyline = _iv(0.0, 0.35);
  late final minaret = _iv(0.08, 0.55, Curves.easeOutBack);
  late final mosque = _iv(0.18, 0.62, Curves.easeOutBack);
  late final logo = _iv(0.50, 0.78, Curves.easeOutBack);
  late final tagline = _iv(0.70, 0.95);

  @override
  void initState() {
    super.initState();
    app.load().then((_) {
      Notifier.start();
      _maybeGo();
    });
    c.forward().then((_) {
      if (mounted) setState(() => _animDone = true);
      Future.delayed(const Duration(milliseconds: 500), _maybeGo);
    });
  }

  void _maybeGo() {
    if (!mounted || _left || !app.loaded || !_animDone) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => const Shell(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height, w = size.width;
    final minaretH = h * 0.66;
    final mosqueW = w * 0.5;
    return Scaffold(
      backgroundColor: DepoColors.brand,
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Stack(clipBehavior: Clip.hardEdge, children: [
          // ظل بيوت الموصل
          Positioned(
            left: -w * 0.06,
            right: -w * 0.06,
            bottom: -10 - 60 * (1 - skyline.value),
            child: Opacity(opacity: skyline.value, child: Image.asset('assets/splash/skyline.png', fit: BoxFit.fitWidth)),
          ),
          // منارة الحدباء (يسار) تطلع من تحت
          Positioned(
            left: -w * 0.03,
            bottom: -minaretH * (1 - minaret.value) - 6,
            height: minaretH,
            child: Image.asset('assets/splash/minaret.png', fit: BoxFit.fitHeight),
          ),
          // الجامع (يمين)
          Positioned(
            right: -w * 0.04,
            bottom: -(mosqueW * 1.9) * (1 - mosque.value) - 6,
            width: mosqueW,
            child: Image.asset('assets/splash/mosque.png', fit: BoxFit.fitWidth),
          ),
          // الشعار والجملة
          Positioned(
            top: h * 0.2,
            left: 0,
            right: 0,
            child: Column(children: [
              Opacity(
                opacity: logo.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * logo.value,
                  child: Image.asset('assets/logo/depo-ar-white.png', width: w * 0.5, semanticLabel: 'ديبو'),
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: tagline.value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - tagline.value)),
                  child: const Text('أكل طيب.. بسعر أطيب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.ink)),
                ),
              ),
            ]),
          ),
          // إذا التحميل تأخر (نت ضعيف)
          if (_animDone && !app.loaded)
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))),
            ),
        ]),
      ),
    );
  }
}
