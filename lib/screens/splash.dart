import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/notifier.dart';
import '../theme.dart';
import 'shell.dart';

/// شاشة البداية المتحركة (مثل كيو): ظل الموصل ← منارة الحدباء تدخل من اليسار والجامع من اليمين ← شعار ديبو ← الجملة
/// وبعدها تدخل للتطبيق تلقائياً (التصفح بدون تسجيل — قرار معتمد)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _animDone = false;
  bool _left = false;

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: c, curve: Interval(a, b, curve: curve));

  late final skyline = _iv(0.0, 0.18);
  late final minaret = _iv(0.10, 0.42);
  late final mosque = _iv(0.16, 0.48);
  late final logo = _iv(0.50, 0.68, Curves.easeOut);
  late final line1 = _iv(0.66, 0.80, Curves.easeOut);
  late final line2 = _iv(0.78, 0.92, Curves.easeOut);

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
            bottom: -10,
            child: Opacity(opacity: skyline.value, child: Image.asset('assets/splash/skyline.png', fit: BoxFit.fitWidth)),
          ),
          // منارة الحدباء تدخل من حافة الشاشة اليسار
          Positioned(
            left: -w * 0.03 - (minaretH * 0.26) * (1 - minaret.value),
            bottom: -6,
            height: minaretH,
            child: Image.asset('assets/splash/minaret.png', fit: BoxFit.fitHeight),
          ),
          // الجامع يدخل من حافة الشاشة اليمين
          Positioned(
            right: -w * 0.04 - mosqueW * (1 - mosque.value),
            bottom: -6,
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
                child: Image.asset('assets/logo/depo-ar-white.png', width: w * 0.5, semanticLabel: 'ديبو'),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: line1.value,
                child: const Text('أكل طيب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Opacity(
                opacity: line2.value,
                child: const Text('بسعر أطيب', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: DepoColors.ink)),
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
