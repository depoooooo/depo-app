import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'admin.dart';
import 'courier.dart';
import 'partner.dart';
import 'supervisor.dart';

/// يفتح الواجهة حسب دور الحساب
class RoleHome extends StatelessWidget {
  const RoleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final me = app.me;
        if (me != null && app.needsPin(me) && me.pinHash.isEmpty) return const _PinGate();
        switch (app.me?.role) {
          case Role.restaurant:
          case Role.merchant:
            return PartnerHome(); // ignore: prefer_const_constructors
          case Role.courier:
            return CourierHome(); // ignore: prefer_const_constructors
          case Role.supervisor:
            return SupervisorHome(); // ignore: prefer_const_constructors
          case Role.admin:
            return AdminHome(); // ignore: prefer_const_constructors
          default:
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('هذا الحساب زبون')));
        }
      },
    );
  }
}


/// الحسابات الخاصة لازم يكون عدها رمز سري قبل ما تفتح واجهتها
class _PinGate extends StatefulWidget {
  const _PinGate();

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  final a = TextEditingController();
  final b = TextEditingController();

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  void _save() {
    final p = a.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(p)) return toast(context, 'الرمز السري من 4 إلى 6 أرقام');
    if (p != b.text.trim()) return toast(context, 'الرمزين مو نفس الشي');
    if (RegExp(r'^(\d)\1+$').hasMatch(p) || '0123456789'.contains(p) || '9876543210'.contains(p)) {
      return toast(context, 'اختار رمز أصعب (مو 1234 أو 1111)');
    }
    app.setPin(app.me!, p);
    toast(context, 'انحفظ رمزك السري. راح ينطلب منك كل ما تسجّل دخول.');
  }

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label) => TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: InputDecoration(labelText: label),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('حماية الحساب')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.lock_outline_rounded, size: 56, color: DepoColors.dark),
        const SizedBox(height: 12),
        Text('حسابك ${roleNames[app.me?.role] ?? ''}، فلازم تسوي رمز سري (4–6 أرقام) يحميه حتى لو أحد عرف رقم تلفونك.',
            textAlign: TextAlign.center, style: const TextStyle(height: 1.6, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        field(a, 'الرمز السري'),
        field(b, 'أعد الرمز'),
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ]),
    );
  }
}
