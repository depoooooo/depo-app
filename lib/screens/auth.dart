import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// يرجّع true إذا الزبون مسجّل (أو سجّل هسه)
Future<bool> ensureLoggedIn(BuildContext context, {String reason = 'دخّل رقم تلفونك حتى نكمل'}) async {
  if (app.loggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => LoginScreen(reason: reason)),
  );
  return ok == true;
}

/// تسجيل الدخول برقم التلفون.
/// تجريبي: رمز التحقق يظهر على الشاشة لحد ما نربط رسائل SMS عن طريق Firebase.
class LoginScreen extends StatefulWidget {
  final String reason;
  const LoginScreen({super.key, this.reason = 'دخّل رقم تلفونك حتى نكمل'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, code, name, pin, newPin }

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController(text: '07');
  final code = TextEditingController();
  final name = TextEditingController();
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  int pinAttempts = 0;
  _Step step = _Step.phone;
  String demoCode = '';
  int attempts = 0;

  String get phoneNorm {
    final digits = StringBuffer();
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (final ch in phone.text.trim().split('')) {
      final i = ar.indexOf(ch);
      if (i >= 0) {
        digits.write(i);
      } else if (RegExp(r'\d').hasMatch(ch)) {
        digits.write(ch);
      }
    }
    var p = digits.toString();
    if (p.startsWith('964')) p = '0${p.substring(3)}';
    return p;
  }

  bool get phoneValid => RegExp(r'^07\d{9}$').hasMatch(phoneNorm);

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    name.dispose();
    pin.dispose();
    pin2.dispose();
    super.dispose();
  }

  void _sendCode() {
    setState(() {
      demoCode = (100000 + DateTime.now().millisecond * 777 % 899999).toString().substring(0, 6);
      step = _Step.code;
      attempts = 0;
    });
  }

  void _verify() {
    if (code.text.trim() != demoCode) {
      attempts++;
      if (attempts >= 5) {
        toast(context, 'محاولات كثيرة، أعد إرسال الرمز');
        setState(() => step = _Step.phone);
      } else {
        toast(context, 'الرمز غلط، جرب مرة ثانية');
      }
      return;
    }
    if (app.isNewUser(phoneNorm)) {
      setState(() => step = _Step.name);
    } else {
      final u = app.userByPhone(phoneNorm);
      if (u != null && u.suspended) {
        toast(context, 'هذا الحساب موقوف. تواصل ويه الدعم.');
        return;
      }
      if (u != null && app.needsPin(u)) {
        pin.clear();
        pin2.clear();
        setState(() => step = u.pinHash.isEmpty ? _Step.newPin : _Step.pin);
        return;
      }
      app.login(phoneNorm);
      Navigator.of(context).pop(true);
    }
  }

  /// الحسابات الخاصة (مطعم/تاجر/مندوب/مشرف/مدير) تحتاج رمز سري فوق رمز التحقق
  void _checkPin() {
    final u = app.userByPhone(phoneNorm);
    if (u == null) return;
    if (pinAttempts >= 5) {
      toast(context, 'محاولات كثيرة. تواصل ويه المدير.');
      return;
    }
    if (!app.checkPin(u, pin.text.trim())) {
      pinAttempts++;
      toast(context, 'الرمز السري غلط (${5 - pinAttempts} محاولات باقية)');
      return;
    }
    app.login(phoneNorm);
    Navigator.of(context).pop(true);
  }

  void _savePin() {
    final u = app.userByPhone(phoneNorm);
    if (u == null) return;
    final a = pin.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(a)) {
      toast(context, 'الرمز السري من 4 إلى 6 أرقام');
      return;
    }
    if (a != pin2.text.trim()) {
      toast(context, 'الرمزين مو نفس الشي');
      return;
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(a) || '0123456789'.contains(a) || '9876543210'.contains(a)) {
      toast(context, 'اختار رمز أصعب (مو 1234 أو 1111)');
      return;
    }
    app.setPin(u, a);
    app.login(phoneNorm);
    toast(context, 'انحفظ رمزك السري. لا تنطيه لأحد.');
    Navigator.of(context).pop(true);
  }

  void _finish() {
    if (name.text.trim().length < 2) {
      toast(context, 'اكتب اسمك');
      return;
    }
    app.login(phoneNorm, name: name.text.trim());
    final u = app.me;
    if (u == null) {
      toast(context, 'ما كدرنا نسجّلك، جرّب مرة ثانية');
      return;
    }
    if (u.role == Role.admin) {
      // المدير لازم يسوي رمز سري من أول يوم
      pin.clear();
      pin2.clear();
      toast(context, 'أهلاً! هذا أول حساب بالسيرفر فصار هو المدير العام. سوّي رمز سري يحميه.');
      setState(() => step = _Step.newPin);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Image.asset('assets/logo/depo-ar-teal.png', width: 110, semanticLabel: 'ديبو'),
          ),
          const SizedBox(height: 16),
          if (step == _Step.phone) ...[
            const Text('هلا بيك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(widget.reason, style: const TextStyle(color: DepoColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 14,
              decoration: const InputDecoration(labelText: 'رقم التلفون', hintText: '07xx xxx xxxx'),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton(onPressed: phoneValid ? _sendCode : null, child: const Text('أرسل الرمز')),
          ],
          if (step == _Step.code) ...[
            const Text('دخّل الرمز', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('دزّينا رمز من 6 أرقام على $phoneNorm', style: const TextStyle(color: DepoColors.muted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(12)),
              child: Text('نسخة تجريبية: الرمز هو $demoCode\n(بعد ربط Firebase يوصلك برسالة SMS)',
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(labelText: 'رمز التحقق'),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton(onPressed: code.text.trim().length == 6 ? _verify : null, child: const Text('تأكيد')),
            TextButton(onPressed: () => setState(() => step = _Step.phone), child: const Text('غيّر الرقم أو أعد الإرسال')),
          ],
          if (step == _Step.pin || step == _Step.newPin) ...[
            Text(step == _Step.pin ? 'الرمز السري' : 'سوّي رمز سري', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              step == _Step.pin
                  ? 'هذا حساب ${roleNames[app.userByPhone(phoneNorm)?.role] ?? ''}، فنحتاج رمزك السري'
                  : 'حسابك ${roleNames[app.userByPhone(phoneNorm)?.role] ?? ''}. سوّي رمز سري (4–6 أرقام) يحميه حتى لو أحد عرف رقمك',
              style: const TextStyle(color: DepoColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(labelText: 'الرمز السري'),
            ),
            if (step == _Step.newPin)
              TextField(
                controller: pin2,
                obscureText: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(labelText: 'أعد الرمز'),
              ),
            FilledButton(onPressed: step == _Step.pin ? _checkPin : _savePin, child: const Text('دخول')),
          ],
          if (step == _Step.name) ...[
            const Text('شنو اسمك؟', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('حتى المحل والمندوب يعرفون منو صاحب الطلب', style: TextStyle(color: DepoColors.muted)),
            const SizedBox(height: 20),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _finish, child: const Text('ابدأ')),
          ],
          const SizedBox(height: 12),
          const Text('بالدخول توافق على شروط الاستخدام وسياسة الخصوصية',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        ],
      ),
    );
  }
}
