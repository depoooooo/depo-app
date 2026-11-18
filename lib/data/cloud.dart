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

  static Future<bool> init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 12));
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously().timeout(const Duration(seconds: 12));
      }
      db = FirebaseFirestore.instance;
      // تجربة قراءة حتى نتأكد إن Firestore موجود والقواعد تسمح
      await db!.collection('meta').doc('settings').get().timeout(const Duration(seconds: 12));
      enabled = true;
      status = 'متصل بالسيرفر ✓';
    } catch (e) {
      enabled = false;
      final msg = e.toString();
      if (msg.contains('admin-restricted') || msg.contains('operation-not-allowed')) {
        status = 'محلي — فعّل Anonymous بـ Authentication';
      } else if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
        status = 'محلي — قواعد Firestore تمنع (الصق firestore.rules)';
      } else if (msg.contains('not-found') || msg.contains('NOT_FOUND') || msg.contains('does not exist')) {
        status = 'محلي — قاعدة Firestore بعدها ما انخلقت';
      } else if (e is TimeoutException) {
        status = 'محلي — ماكو اتصال بالسيرفر';
      } else {
        status = 'محلي — ${msg.length > 120 ? msg.substring(0, 120) : msg}';
      }
    }
    return enabled;
  }
}
