import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// طريقة وصول رمز التحقق
enum OtpChannel { whatsapp, sms }

const otpChannelNames = {OtpChannel.whatsapp: 'واتساب', OtpChannel.sms: 'رسالة SMS'};

/// إرسال رمز التحقق والتأكد منه.
///
/// - [live] = true (من إعدادات المدير): السيرفر (Cloudflare Worker بـ [server]) يرسل الرمز عن طريق OTPIQ
///   (واتساب وإذا ما وصل SMS)، ويتأكد منه، ويرجّع هوية رسمية من Firebase (custom token) للرقم.
/// - [live] = false: نسخة تجريبية، الرمز يطلع على الشاشة.
class Otp {
  static bool live = false;
  static String server = ''; // رابط سيرفر Cloudflare، مثلاً https://depo-otp.xxx.workers.dev
  static final _rnd = Random.secure();
  static String? _code;
  static DateTime? _sentAt;
  static const resendAfter = Duration(seconds: 60);
  static String? lastError;

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final base = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final r = await http
        .post(Uri.parse('$base/$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final j = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
    if (r.statusCode != 200) throw _OtpError((j['error'] ?? 'صار خطأ، جرّب مرة ثانية').toString());
    return j;
  }

  static String _msg(Object e) => e is _OtpError ? e.message : 'ماكو اتصال بالسيرفر — تأكد من الإنترنت';

  /// يرسل الرمز. بالتجريبي يرجّع الرمز حتى ينعرض. بالحقيقي يرجّع '' إذا انرسل، وnull إذا فشل (السبب بـ [lastError]).
  static Future<String?> send(String phone, OtpChannel channel) async {
    lastError = null;
    if (live) {
      try {
        await _post('send', {'phone': phone, 'channel': channel == OtpChannel.sms ? 'sms' : 'whatsapp'});
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
        final r = await _post('verify', {'phone': phone, 'code': code.trim()});
        final token = r['token'] as String;
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

class _OtpError {
  final String message;
  _OtpError(this.message);
}
