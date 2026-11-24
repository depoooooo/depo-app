import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/loyalty_ui.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  /// embedded = داخل الشريط السفلي (بدون زر رجوع)
  final bool embedded;
  const CartScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cart, app]),
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
        final problem = _problem();
        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(child: Text('${store?.fullName ?? ''} — السلة من محل واحد', style: const TextStyle(fontWeight: FontWeight.w800))),
              if (store != null && store.type != StoreType.shop && app.loggedIn) StampCard(store: store, compact: true),
              for (final line in cart.lines)
                AppCard(
                  child: Row(children: [
                    SizedBox(width: 60, child: OfferImage(offer: line.offer, height: 60, radius: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(line.offer.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        PriceTag(price: line.offer.shownPrice, original: line.offer.shownOriginal, size: 15),
                        if (_lineIssue(line) != null)
                          Text(_lineIssue(line)!, style: const TextStyle(fontSize: 12, color: DepoColors.danger, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    IconButton(tooltip: 'أقل', onPressed: () => cart.setQty(line, line.qty - 1), icon: const Icon(Icons.remove_circle_outline)),
                    Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(
                      tooltip: 'أكثر',
                      onPressed: line.qty < (app.offerById(line.offer.id)?.quantityLeft ?? 0) ? () => cart.setQty(line, line.qty + 1) : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ]),
                ),
              AppCard(
                color: DepoColors.successBg,
                borderColor: DepoColors.successBg,
                child: Text('وفّرت ${iqd(cart.saved)} بهذا الطلب', style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
              ),
              if (problem != null)
                AppCard(color: const Color(0xFFFDECED), borderColor: const Color(0xFFFDECED), child: Text(problem, style: const TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800))),
              if (remaining > 0 && !app.eligibleFirstOrder)
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
                  onPressed: problem != null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                  child: const Text('إكمال الطلب'),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  /// مشكلة بسطر من السلة (العرض خلص أو الكمية ما تكفي)
  static String? _lineIssue(CartLine l) {
    final of = app.offerById(l.offer.id);
    if (of == null || !of.visible) return 'خلص هذا العرض — شيله';
    if (of.quantityLeft < l.qty) return 'باقي ${of.quantityLeft} بس';
    return null;
  }

  static String? _problem() {
    final s = app.storeById(cart.storeId ?? '');
    if (s == null || s.suspended) return 'المحل مو متوفر هسه';
    for (final l in cart.lines) {
      if (_lineIssue(l) != null) return 'بالسلة شي خلص أو كميته ما تكفي. عدّله حتى تكمل.';
    }
    return null;
  }
}
