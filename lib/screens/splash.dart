import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/notifier.dart';
import '../theme.dart';
import 'shell.dart';

/// شاشة البداية — التصفح بدون تسجيل (قرار معتمد)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    app.load().then((_) => Notifier.start());
  }

  void _go() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DepoColors.brand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/logo/depo-ar-white.png', width: 210, semanticLabel: 'ديبو'),
              const SizedBox(height: 18),
              Image.asset('assets/logo/depo-en-white.png', width: 120),
              const SizedBox(height: 20),
              const Text('أكل طيب.. بسعر أطيب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DepoColors.ink)),
              const Spacer(),
              ListenableBuilder(
                listenable: app,
                builder: (context, _) => FilledButton(
                  onPressed: app.loaded ? _go : null,
                  child: Text(app.loaded ? 'ابدأ التصفح' : 'لحظة...'),
                ),
              ),
              const SizedBox(height: 10),
              const Text('الموصل — رواجع المطاعم والماركت', style: TextStyle(fontSize: 12, color: DepoColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
