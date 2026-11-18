// إعدادات Firebase لمشروع depo-app-2e93e.
// هذني مو أسرار: Firebase يعتبرها معرّفات عامة، والحماية تكون بقواعد Firestore (firestore.rules).
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  /// حالياً نستخدم إعدادات الويب لكل المنصات. لما نسجّل تطبيق أندرويد بـ Firebase نضيف إعداداته هنا.
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCds_x1L-d8sQPVMWb2VscwFNKy7YQnXzc',
    authDomain: 'depo-app-2e93e.firebaseapp.com',
    projectId: 'depo-app-2e93e',
    storageBucket: 'depo-app-2e93e.firebasestorage.app',
    messagingSenderId: '436054711901',
    appId: '1:436054711901:web:9733b2f6a3fbd49c8b77b4',
  );
}
