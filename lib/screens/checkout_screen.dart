import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'orders.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool pickup = false;
  String? address;
  bool placing = false;

  int get fee {
    if (pickup) return 0;
    return app.deliveryFeeFor(cart.total);
  }

  Future<void> _confirm() async {
    if (cart.isEmpty) return;
    final ok = await ensureLoggedIn(context, reason: 'دخّل رقم تلفونك حتى نأكد طلبك');
    if (!ok || !mounted) return;
    final addr = address ?? (app.me!.addresses.isNotEmpty ? app.me!.addresses.first : '');
    if (!pickup && addr.isEmpty) {
      toast(context, 'ضيف عنوان التوصيل');
      return;
    }
    setState(() => placing = true);
    final order = app.placeOrder(pickup: pickup, address: addr);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = app.settings.deliveryFee;
    final remaining = app.settings.freeDeliveryThreshold - cart.total;
    final addresses = app.me?.addresses ?? const ['حي الزهور — الجانب الأيسر'];
    return Scaffold(
      appBar: AppBar(title: const Text('إكمال الطلب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('طريقة الاستلام', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          _Option(
            selected: !pickup,
            icon: Icons.delivery_dining,
            title: 'توصيل',
            subtitle: 'مندوب Depo — 20 إلى 40 دقيقة • ${iqd(deliveryFee)}',
            onTap: () => setState(() => pickup = false),
          ),
          _Option(
            selected: pickup,
            icon: Icons.storefront_outlined,
            title: 'أستلم بنفسي ووفّر ${iqd(deliveryFee)}',
            subtitle: 'تروح للمحل وتاخذ طلبك بدون رسم توصيل',
            onTap: () => setState(() => pickup = true),
          ),
          if (!pickup) ...[
            const SizedBox(height: 6),
            const Text('العنوان', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (final a in addresses)
              _Option(
                selected: (address ?? addresses.first) == a,
                icon: Icons.location_on_outlined,
                title: a,
                subtitle: '',
                onTap: () => setState(() => address = a),
              ),
          ],
          const SizedBox(height: 6),
          const Text('الدفع', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const _Option(selected: true, icon: Icons.payments_outlined, title: 'نقداً عند الاستلام', subtitle: 'الدفع الإلكتروني راح يتوفر قريباً'),
          AppCard(
            child: Column(children: [
              _Line('الطلب', iqd(cart.total)),
              _Line('التوصيل', fee == 0 ? 'مجاني' : iqd(fee)),
              if (!pickup && remaining > 0)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('أضف ${iqd(remaining)} بعد ويصير التوصيل مجاني تلقائياً',
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
            FilledButton(onPressed: placing || cart.isEmpty ? null : _confirm, child: const Text('تأكيد الطلب')),
            const SizedBox(height: 6),
            Text(app.loggedIn ? 'الطلب يوصل للمحل فوراً' : 'إذا ما مسجّل، نطلب رقمك بهاي الخطوة بس',
                style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
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
    return AppCard(
      onTap: onTap,
      borderColor: selected ? DepoColors.dark : DepoColors.line,
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: DepoColors.dark),
        const SizedBox(width: 8),
        Icon(icon, color: DepoColors.dark),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
      ]),
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
