import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        if (cart.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('السلة')),
            body: const Center(child: Text('السلة فارغة')),
          );
        }
        final store = storeById(cart.storeId!);
        return Scaffold(
          appBar: AppBar(title: const Text('السلة')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DepoColors.line),
                ),
                child: Text('${store.fullName} — السلة من محل واحد',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              for (final line in cart.lines)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DepoColors.line),
                  ),
                  child: Row(children: [
                    SizedBox(width: 60, child: ImagePlaceholder(height: 60, box: line.offer.surpriseBox, radius: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(line.offer.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        PriceTag(price: line.offer.price, original: line.offer.originalPrice, size: 15),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'أقل',
                      onPressed: () => cart.setQty(line, line.qty - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(
                      tooltip: 'أكثر',
                      onPressed: line.qty < line.offer.quantityLeft ? () => cart.setQty(line, line.qty + 1) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: DepoColors.successBg, borderRadius: BorderRadius.circular(14)),
                child: Text('وفّرت ${iqd(cart.saved)} بهذا الطلب',
                    style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Expanded(child: Text('المجموع', style: TextStyle(fontSize: 16))),
                  Text(iqd(cart.total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  child: const Text('إكمال الطلب'),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
