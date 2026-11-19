import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// الاتصال بـ Firebase. إذا فشل لأي سبب، التطبيق يشتغل «محلي» على الجهاز.
class Cloud {
  static bool enabled = false;
  static String status = 'جاري الاتصال...';
  static FirebaseFirestore? db;

  /// تهيئة Firebase + دخول مجهول. ما ننتظر السيرفر هنا (الدخول المحفوظ ما يحتاج نت)
  static Future<bool> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 12));
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously().timeout(const Duration(seconds: 15));
      }
      final d = FirebaseFirestore.instance;
      try {
        // نسخة محلية من البيانات: التطبيق يفتح فوراً من آخر بيانات، والجديد يجي بالخلفية
        d.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
      } catch (_) {}
      db = d;
      enabled = true;
      status = 'جاري الاتصال...';
    } catch (e) {
      enabled = false;
      status = describe(e);
    }
    return enabled;
  }

  /// سبب الخطأ بالعربي
  static String describe(Object e) {
    final msg = e.toString();
    if (msg.contains('admin-restricted') || msg.contains('operation-not-allowed')) return 'محلي — فعّل Anonymous بـ Authentication';
    if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) return 'محلي — قواعد Firestore تمنع (الصق firestore.rules)';
    if (msg.contains('not-found') || msg.contains('NOT_FOUND') || msg.contains('does not exist')) return 'محلي — قاعدة Firestore بعدها ما انخلقت';
    if (e is TimeoutException) return 'محلي — ماكو اتصال بالسيرفر';
    return 'محلي — ${msg.length > 120 ? msg.substring(0, 120) : msg}';
  }
}
