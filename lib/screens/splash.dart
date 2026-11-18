import 'package:flutter/material.dart';
import '../theme.dart';
import 'home.dart';

/// شاشة البداية — التصفح بدون تسجيل (قرار معتمد)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
              const Text(
                'أكل طيب.. بسعر أطيب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DepoColors.ink),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
                child: const Text('ابدأ التصفح'),
              ),
              const SizedBox(height: 10),
              const Text(
                'الموصل — رواجع المطاعم وعروض التجار',
                style: TextStyle(fontSize: 12, color: DepoColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
