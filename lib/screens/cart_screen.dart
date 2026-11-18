import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  /// embedded = داخل الشريط السفلي (بدون زر رجوع)
  final bool embedded;
  const CartScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final appBar = AppBar(title: const Text('السلة'), automaticallyImplyLeading: !embedded);
        if (cart.isEmpty) {
          return Scaffold(
            appBar: appBar,
            body: const EmptyState(icon: Icons.shopping_bag_outlined, text: 'السلة فارغة. تصفّح الرواجع والماركت وضيف اللي يعجبك.'),
          );
        }
        final store = app.storeById(cart.storeId!);
        final remaining = app.settings.freeDeliveryThreshold - cart.total;
        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(child: Text('${store?.fullName ?? ''} — السلة من محل واحد', style: const TextStyle(fontWeight: FontWeight.w800))),
              for (final line in cart.lines)
                AppCard(
                  child: Row(children: [
                    SizedBox(width: 60, child: ImagePlaceholder(height: 60, box: line.offer.surpriseBox, radius: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(line.offer.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        PriceTag(price: line.offer.price, original: line.offer.originalPrice, size: 15),
                      ]),
                    ),
                    IconButton(tooltip: 'أقل', onPressed: () => cart.setQty(line, line.qty - 1), icon: const Icon(Icons.remove_circle_outline)),
                    Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(
                      tooltip: 'أكثر',
                      onPressed: line.qty < line.offer.quantityLeft ? () => cart.setQty(line, line.qty + 1) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                ),
              AppCard(
                color: DepoColors.successBg,
                borderColor: DepoColors.successBg,
                child: Text('وفّرت ${iqd(cart.saved)} بهذا الطلب', style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
              ),
              if (remaining > 0)
                Text('أضف ${iqd(remaining)} بعد ويصير التوصيل مجاني تلقائياً',
                    style: const TextStyle(fontSize: 12, color: DepoColors.success, fontWeight: FontWeight.w700)),
              TextButton.icon(onPressed: cart.clear, icon: const Icon(Icons.delete_outline), label: const Text('فرّغ السلة')),
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
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
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
