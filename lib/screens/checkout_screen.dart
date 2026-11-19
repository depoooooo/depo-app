import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'orders.dart';
import '../data/geo.dart';
import '../widgets/geo_ui.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool pickup = false;
  String? address;
  bool placing = false;
  GeoFix? here;

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
    final Order order;
    try {
      order = await app.placeOrder(pickup: pickup, address: addr, location: here);
    } on OrderError catch (e) {
      if (mounted) {
        setState(() => placing = false);
        toast(context, e.message);
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
      (r) => r.isFirst,
    );
  }

  Future<void> _addAddress() async {
    if (!await ensureLoggedIn(context, reason: 'سجّل حتى نحفظ عنوانك') || !mounted) return;
    final a = await askAddress(context);
    if (a != null) {
      app.addAddress(a);
      setState(() => address = a);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([app, cart]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final deliveryFee = app.settings.deliveryFee;
    final remaining = app.settings.freeDeliveryThreshold - cart.total;
    final addresses = app.me?.addresses ?? const <String>[];
    final firstFree = !pickup && app.eligibleFirstOrder && cart.total < app.settings.freeDeliveryThreshold;
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _addAddress,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(addresses.isEmpty ? 'أضف عنوان التوصيل' : 'عنوان جديد'),
            ),
            const SizedBox(height: 8),
            AppCard(
              borderColor: here != null ? DepoColors.success : null,
              onTap: () async {
                final r = await locateWithProgress(context);
                if (!context.mounted) return;
                if (r.fix == null) return toast(context, r.error);
                setState(() => here = r.fix);
              },
              child: Row(children: [
                Icon(here != null ? Icons.check_circle : Icons.my_location, color: here != null ? DepoColors.success : DepoColors.dark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(here != null ? 'انرسل موقعك ✓' : 'أرسل موقعي الحالي (اختياري)', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Text('إذا انت هسه بمكان التوصيل، المندوب يوصلك أسرع', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          const Text('الدفع', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const _Option(selected: true, icon: Icons.payments_outlined, title: 'نقداً عند الاستلام', subtitle: 'الدفع الإلكتروني راح يتوفر قريباً'),
          AppCard(
            child: Column(children: [
              _Line('الطلب', iqd(cart.total)),
              _Line('التوصيل', fee == 0 ? 'مجاني' : iqd(fee)),
              if (firstFree)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('🎉 أول طلب: التوصيل علينا', style: TextStyle(fontSize: 12, color: DepoColors.success, fontWeight: FontWeight.w800)),
                ),
              if (!pickup && fee > 0 && remaining > 0)
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
            FilledButton(
              onPressed: placing || cart.isEmpty ? null : _confirm,
              child: placing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('تأكيد الطلب • ${iqd(cart.total + fee)}'),
            ),
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
