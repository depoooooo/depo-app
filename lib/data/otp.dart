import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// طريقة وصول رمز التحقق
enum OtpChannel { whatsapp, sms }

const otpChannelNames = {OtpChannel.whatsapp: 'واتساب', OtpChannel.sms: 'رسالة SMS'};

/// إرسال رمز التحقق والتأكد منه.
///
/// - [live] = true (من إعدادات المدير): السيرفر (Cloud Functions) يرسل الرمز عن طريق OTPIQ
///   (واتساب وإذا ما وصل SMS)، ويتأكد منه، ويرجّع هوية رسمية من Firebase (custom token) للرقم.
/// - [live] = false: نسخة تجريبية، الرمز يطلع على الشاشة.
class Otp {
  static bool live = false;
  static final _rnd = Random.secure();
  static String? _code;
  static DateTime? _sentAt;
  static const resendAfter = Duration(seconds: 60);
  static String? lastError;

  static HttpsCallable _fn(String name) => FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable(name);

  static String _msg(Object e) {
    if (e is FirebaseFunctionsException) return e.message ?? 'صار خطأ، جرّب مرة ثانية';
    return 'ماكو اتصال بالسيرفر — تأكد من الإنترنت';
  }

  /// يرسل الرمز. بالتجريبي يرجّع الرمز حتى ينعرض. بالحقيقي يرجّع '' إذا انرسل، وnull إذا فشل (السبب بـ [lastError]).
  static Future<String?> send(String phone, OtpChannel channel) async {
    lastError = null;
    if (live) {
      try {
        await _fn('sendOtp').call({'phone': phone, 'channel': channel == OtpChannel.sms ? 'sms' : 'whatsapp'}).timeout(const Duration(seconds: 30));
        _sentAt = DateTime.now();
        return '';
      } catch (e) {
        lastError = _msg(e);
        return null;
      }
    }
    _code = List.generate(6, (_) => _rnd.nextInt(10)).join();
    _sentAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return _code;
  }

  static Duration get waitBeforeResend {
    if (_sentAt == null) return Duration.zero;
    final left = resendAfter - DateTime.now().difference(_sentAt!);
    return left.isNegative ? Duration.zero : left;
  }

  static Future<bool> verify(String phone, String code) async {
    lastError = null;
    if (live) {
      try {
        final r = await _fn('verifyOtp').call({'phone': phone, 'code': code.trim()}).timeout(const Duration(seconds: 30));
        final token = (r.data as Map)['token'] as String;
        await FirebaseAuth.instance.signInWithCustomToken(token).timeout(const Duration(seconds: 20));
        return true;
      } catch (e) {
        lastError = _msg(e);
        return false;
      }
    }
    final ok = _code != null && code.trim() == _code;
    if (ok) _code = null; // الرمز يستخدم مرة وحدة
    return ok;
  }
}
