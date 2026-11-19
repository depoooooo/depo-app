import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/notifier.dart';
import 'screens/splash.dart';
import 'theme.dart';

void main() {
  // أي خطأ غير متوقع: بدل الشاشة الحمرا/الرمادية، رسالة مرتبة، والتطبيق يكمل
  ErrorWidget.builder = (details) => const Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('صار خلل بسيط بهذا الجزء — ارجع وافتحه مرة ثانية', textAlign: TextAlign.center, style: TextStyle(color: DepoColors.muted)),
          ),
        ),
      );
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    errorLog.add('${DateTime.now()} ${d.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (e, st) {
    errorLog.add('${DateTime.now()} $e');
    return true; // ما نطيّح التطبيق
  };
  runApp(const DepoApp());
}

/// آخر الأخطاء (للدعم الفني)
final errorLog = <String>[];

class DepoApp extends StatelessWidget {
  const DepoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ديبو',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      theme: buildDepoTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
