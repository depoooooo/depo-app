import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme.dart';
import 'login_screen.dart';

enum Fulfilment { delivery, pickup }

/// رسوم التوصيل وحد التوصيل المجاني — تنضبط من المدير لاحقاً
const deliveryFee = 2000;
const freeDeliveryThreshold = 10000;

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Fulfilment mode = Fulfilment.delivery;

  int get fee {
    if (mode == Fulfilment.pickup) return 0;
    return cart.total >= freeDeliveryThreshold ? 0 : deliveryFee;
  }

  @override
  Widget build(BuildContext context) {
    final remainingForFree = freeDeliveryThreshold - cart.total;
    return Scaffold(
      appBar: AppBar(title: const Text('إكمال الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('طريقة الاستلام', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _Option(
            selected: mode == Fulfilment.delivery,
            icon: Icons.delivery_dining,
            title: 'توصيل',
            subtitle: 'مندوب Depo — 20 إلى 40 دقيقة • ${iqd(deliveryFee)}',
            onTap: () => setState(() => mode = Fulfilment.delivery),
          ),
          _Option(
            selected: mode == Fulfilment.pickup,
            icon: Icons.storefront_outlined,
            title: 'أستلم بنفسي ووفّر ${iqd(deliveryFee)}',
            subtitle: 'تروح للمحل وتاخذ طلبك بدون رسم توصيل',
            onTap: () => setState(() => mode = Fulfilment.pickup),
          ),
          const SizedBox(height: 10),
          const Text('الدفع', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const _Option(
            selected: true,
            icon: Icons.payments_outlined,
            title: 'نقداً عند الاستلام',
            subtitle: 'الدفع الإلكتروني راح يتوفر قريباً',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DepoColors.line),
            ),
            child: Column(children: [
              _Line('الطلب', iqd(cart.total)),
              _Line('التوصيل', fee == 0 ? 'مجاني' : iqd(fee)),
              if (mode == Fulfilment.delivery && remainingForFree > 0)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('أضف ${iqd(remainingForFree)} بعد ويصير التوصيل مجاني تلقائياً',
                      style: const TextStyle(fontSize: 12, color: DepoColors.success, fontWeight: FontWeight.w700)),
                ),
              const Divider(),
              _Line('المجموع', iqd(cart.total + fee), bold: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LoginScreen(totalToPay: cart.total + fee)),
              ),
              child: const Text('تأكيد الطلب'),
            ),
            const SizedBox(height: 6),
            const Text('إذا ما مسجّل، نطلب رقمك بهاي الخطوة بس',
                style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _Option({required this.selected, required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? DepoColors.dark : DepoColors.line, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: DepoColors.dark),
              const SizedBox(width: 8),
              Icon(icon, color: DepoColors.dark),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: st)), Text(value, style: st)]),
    );
  }
}
