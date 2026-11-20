import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/notifier.dart';
import 'screens/splash.dart';
import 'theme.dart';

void main() {
  // أي خطأ غير متوقع: بدل الشاشة الحمرا/الرمادية، رسالة مرتبة، والتطبيق يكمل
  ErrorWidget.builder = (details) {
    final msg = details.exceptionAsString();
    errorLog.add('${DateTime.now()} [واجهة] $msg');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('صار خلل بهذا الجزء — ارجع وافتحه مرة ثانية', textAlign: TextAlign.center, style: TextStyle(color: DepoColors.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          // تفاصيل قصيرة حتى نعرف السبب من صورة الشاشة
          Text(msg.length > 160 ? msg.substring(0, 160) : msg, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(color: DepoColors.muted, fontSize: 10)),
        ]),
      ),
    );
  };
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    errorLog.add('${DateTime.now()} ${d.exceptionAsString()}');
    if (errorLog.length > 100) errorLog.removeAt(0);
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
