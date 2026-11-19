import 'dart:math';

/// طريقة وصول رمز التحقق
enum OtpChannel { whatsapp, sms }

const otpChannelNames = {OtpChannel.whatsapp: 'واتساب', OtpChannel.sms: 'رسالة SMS'};

/// إرسال رمز التحقق والتأكد منه.
///
/// هسه (المرحلة التجريبية): الرمز يطلع على الشاشة.
/// بعد تفعيل Blaze:
///  - واتساب: Cloud Function ترسل الرمز بقالب «Authentication» من WhatsApp Cloud API وتتأكد منه
///    وترجّع custom token لـ Firebase Auth.
///  - SMS: Firebase Phone Auth مباشرة (verifyPhoneNumber).
/// الشاشة ما تتغير، بس هذا الملف.
class Otp {
  static const demo = true;
  static final _rnd = Random.secure();
  static String? _code;
  static DateTime? _sentAt;
  static const resendAfter = Duration(seconds: 60);

  /// يرسل الرمز. يرجّع الرمز نفسه بالنسخة التجريبية بس (حتى ينعرض)، وإلا null.
  static Future<String?> send(String phone, OtpChannel channel) async {
    _code = List.generate(6, (_) => _rnd.nextInt(10)).join();
    _sentAt = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return demo ? _code : null;
  }

  static Duration get waitBeforeResend {
    if (_sentAt == null) return Duration.zero;
    final left = resendAfter - DateTime.now().difference(_sentAt!);
    return left.isNegative ? Duration.zero : left;
  }

  static Future<bool> verify(String code) async {
    final ok = _code != null && code.trim() == _code;
    if (ok) _code = null; // الرمز يستخدم مرة وحدة
    return ok;
  }
}
