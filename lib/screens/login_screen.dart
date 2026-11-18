import 'package:flutter/material.dart';
import '../theme.dart';
import 'tracking_screen.dart';

/// تسجيل الدخول برقم التلفون — يظهر وقت تأكيد الطلب.
/// هسه تجريبي: أي رمز من 6 أرقام يمشي. نربطه بـ Firebase بالمرحلة الجاية.
class LoginScreen extends StatefulWidget {
  final int totalToPay;
  const LoginScreen({super.key, required this.totalToPay});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController(text: '07');
  final code = TextEditingController();
  bool codeSent = false;

  bool get phoneValid => RegExp(r'^07\d{9}$').hasMatch(phone.text.trim());

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
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
            child: Image.asset('assets/logo/depo-ar-teal.png', width: 120, semanticLabel: 'ديبو'),
          ),
          const SizedBox(height: 16),
          Text(codeSent ? 'دخّل الرمز' : 'باقي خطوة وحدة',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            codeSent
                ? 'دزّينا رمز من 6 أرقام على ${phone.text}'
                : 'دخّل رقم تلفونك حتى نأكد طلبك ونرسلك رمز التحقق',
            style: const TextStyle(color: DepoColors.muted),
          ),
          const SizedBox(height: 20),
          if (!codeSent)
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 11,
              decoration: const InputDecoration(labelText: 'رقم التلفون', prefixText: '+964  '),
              onChanged: (_) => setState(() {}),
            )
          else
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
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !codeSent
                ? (phoneValid ? () => setState(() => codeSent = true) : null)
                : (code.text.length == 6
                    ? () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => TrackingScreen(totalToPay: widget.totalToPay)),
                          (r) => r.isFirst,
                        )
                    : null),
            child: Text(codeSent ? 'تأكيد' : 'أرسل الرمز'),
          ),
          const SizedBox(height: 12),
          const Text('بالدخول توافق على شروط الاستخدام وسياسة الخصوصية',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        ],
      ),
    );
  }
}
