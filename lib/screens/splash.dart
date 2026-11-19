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
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
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
      Future.delayed(const Duration(milliseconds: 150), _maybeGo);
    });
  }

  void _maybeGo() {
    if (!mounted || _left || !app.loaded || !_animDone) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
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
    // نفس توزيع كيو: المعالم على الحافتين تأطّر الشعار بالنص
    final minaretH = h * 0.70;
    final minaretW = minaretH * 0.24;
    final mosqueW = w * 0.74;
    return Scaffold(
      backgroundColor: DepoColors.brand,
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Stack(clipBehavior: Clip.hardEdge, children: [
          // ظل بيوت الموصل (واطي وخفيف)
          Positioned(
            left: -w * 0.09,
            width: w * 1.18,
            bottom: -w * 1.18 * 0.495 * 0.38,
            child: Opacity(opacity: 0.75 * skyline.value, child: Image.asset('assets/splash/skyline.png', fit: BoxFit.fitWidth)),
          ),
          // منارة الحدباء تدخل من حافة الشاشة اليسار
          Positioned(
            left: -w * 0.10 - (minaretW + w * 0.1) * (1 - minaret.value),
            bottom: -4,
            height: minaretH,
            child: Image.asset('assets/splash/minaret.png', fit: BoxFit.fitHeight),
          ),
          // الجامع يدخل من حافة الشاشة اليمين
          Positioned(
            right: -w * 0.06 - mosqueW * (1 - mosque.value),
            bottom: -4,
            width: mosqueW,
            child: Image.asset('assets/splash/mosque.png', fit: BoxFit.fitWidth),
          ),
          // الشعار والجملة
          Positioned(
            top: h * 0.34,
            left: 0,
            right: 0,
            child: Column(children: [
              Opacity(
                opacity: logo.value.clamp(0.0, 1.0),
                child: Image.asset('assets/logo/depo-ar-white.png', width: w * 0.44, semanticLabel: 'ديبو'),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: line1.value,
                child: Text(app.content.splash1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
              Opacity(
                opacity: line2.value,
                child: Text(app.content.splash2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.ink)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
