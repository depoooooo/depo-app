import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';

class OfferDetailScreen extends StatefulWidget {
  final Offer offer;
  const OfferDetailScreen({super.key, required this.offer});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  int qty = 1;

  Future<void> _add() async {
    final o = widget.offer;
    if (!cart.canAdd(o)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('السلة من محل ثاني'),
          content: const Text('السلة لازم تكون من محل واحد. تريد تفرّغها وتضيف هذا العرض؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('فرّغها وضيف')),
          ],
        ),
      );
      if (ok != true) return;
      cart.clear();
    }
    cart.add(o, qty: qty);
    if (!mounted) return;
    toast(context, 'انضاف للسلة');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    final s = app.storeById(o.storeId)!;
    final isRawaji = s.type == StoreType.restaurant;
    return Scaffold(
      appBar: AppBar(title: Text(s.fullName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ImagePlaceholder(height: 210, box: o.surpriseBox || !isRawaji),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Badge2(o.surpriseBox ? 'صندوق مفاجأة' : 'خصم ${o.discountPercent}%',
                bg: o.surpriseBox ? DepoColors.brand : DepoColors.accent),
            const Badge2('موثوق من Depo', bg: DepoColors.soft, fg: DepoColors.dark),
            StorageChip(o.storage),
          ]),
          const SizedBox(height: 8),
          Text(o.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('${s.fullName} • ${s.eta}', style: const TextStyle(color: DepoColors.dark, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PriceTag(price: o.price, original: o.originalPrice, size: 22),
          const SizedBox(height: 12),
          Row(children: [
            _Info(label: 'باقي', value: o.quantityLeft <= 2 ? '${o.quantityLeft} بس' : '${o.quantityLeft}', danger: o.quantityLeft <= 2),
            const SizedBox(width: 8),
            _Info(label: isRawaji ? 'ينتهي العرض' : 'الصلاحية', value: o.expiresLabel),
            if (o.pickupWindow.isNotEmpty) ...[
              const SizedBox(width: 8),
              _Info(label: 'الاستلام', value: o.pickupWindow),
            ],
          ]),
          const SizedBox(height: 12),
          Text('انطلب ${o.orderedThisWeek} مرة هالأسبوع',
              style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
          if (o.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(o.description, style: const TextStyle(color: DepoColors.muted, height: 1.7)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: DepoColors.line)),
          ),
          child: Row(children: [
            IconButton.filledTonal(
              tooltip: 'أقل',
              onPressed: qty > 1 ? () => setState(() => qty--) : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            IconButton.filledTonal(
              tooltip: 'أكثر',
              onPressed: qty < o.quantityLeft ? () => setState(() => qty++) : null,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: o.quantityLeft > 0 && o.visible ? _add : null,
                child: Text(o.quantityLeft > 0 ? 'أضف للسلة — ${iqd(o.price * qty)}' : 'خلصت'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  const _Info({required this.label, required this.value, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DepoColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w900, color: danger ? DepoColors.danger : DepoColors.ink)),
        ]),
      ),
    );
  }
}
