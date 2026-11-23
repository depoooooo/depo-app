import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../screens/offer_detail.dart';
import '../screens/store_page.dart';
import '../theme.dart';
import 'common.dart';

/// يضيف للسلة مباشرة (ويسأل إذا السلة من محل ثاني)
Future<void> quickAdd(BuildContext context, Offer o) async {
  final live = app.offerById(o.id) ?? o;
  if (!live.visible) {
    toast(context, live.expired ? 'انتهى وقت هذا العرض' : 'خلص هذا العرض');
    return;
  }
  if (app.storeById(live.storeId)?.suspended ?? true) {
    toast(context, 'المحل مو متوفر هسه');
    return;
  }
  if (!live.unlimited && qtyInCart(live) >= live.quantityLeft) {
    toast(context, 'وصلت لآخر كمية متوفرة');
    return;
  }
  o = live;
  if (!cart.canAdd(o)) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('السلة من محل ثاني'),
        content: const Text('السلة لازم تكون من محل واحد. تفرّغها وتضيف هذا؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('فرّغها وضيف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    cart.clear();
  }
  cart.add(o);
}

int qtyInCart(Offer o) {
  for (final l in cart.lines) {
    if (l.offer.id == o.id) return l.qty;
  }
  return 0;
}

/// زر + الدائري، ويصير «− 2 +» إذا العرض بالسلة
class AddButton extends StatelessWidget {
  final Offer offer;
  const AddButton({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final q = qtyInCart(offer);
        final soldOut = !offer.visible;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: q == 0
              ? Material(
                  key: const ValueKey('add'),
                  color: soldOut ? DepoColors.line : DepoColors.dark,
                  shape: const CircleBorder(),
                  elevation: soldOut ? 0 : 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: soldOut ? null : () => quickAdd(context, offer),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(soldOut ? Icons.block : Icons.add_rounded, color: Colors.white, size: 22,
                          semanticLabel: 'أضف للسلة'),
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('qty'),
                  decoration: BoxDecoration(color: DepoColors.dark, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _mini(Icons.add_rounded, () => quickAdd(context, offer)),
                    Text('$q', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    _mini(q == 1 ? Icons.delete_outline : Icons.remove_rounded, () {
                      final line = cart.lines.firstWhere((l) => l.offer.id == offer.id);
                      cart.setQty(line, line.qty - 1);
                    }),
                  ]),
                ),
        );
      },
    );
  }

  Widget _mini(IconData i, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(i, color: Colors.white, size: 18)),
      );
}

void openOffer(BuildContext context, Offer o) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: o)));

/// كارت العرض الكبير (للشرائط الأفقية)
class OfferCard extends StatelessWidget {
  final Offer offer;
  final double width;
  final bool showStore;
  const OfferCard({super.key, required this.offer, this.width = 168, this.showStore = true});

  @override
  Widget build(BuildContext context) {
    final s = app.storeById(offer.storeId);
    final low = offer.quantityLeft <= 2;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0.8,
        shadowColor: const Color(0x2206363C),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openOffer(context, offer),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              OfferImage(offer: offer, height: 112),
              if (offer.surpriseBox || offer.discountPercent > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Badge2(offer.surpriseBox ? 'صندوق مفاجأة' : '-${offer.discountPercent}%',
                      bg: offer.surpriseBox ? DepoColors.brand : DepoColors.accent),
                ),
              if (offer.quantityLeft > 0 && !offer.unlimited)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Badge2(low ? 'باقي ${offer.quantityLeft} بس!' : 'باقي ${offer.quantityLeft}',
                      bg: low ? DepoColors.danger : Colors.white, fg: low ? Colors.white : DepoColors.ink),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                if (showStore && s != null)
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (offer.shownOriginal > offer.shownPrice)
                        Text(iqd(offer.shownOriginal),
                            style: const TextStyle(fontSize: 11, color: DepoColors.muted, decoration: TextDecoration.lineThrough)),
                      Text(iqd(offer.shownPrice), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DepoColors.dark)),
                    ]),
                  ),
                  AddButton(offer: offer),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// نفس الكارت بالحجم الصغير (صفحة المحل)
class MiniOffer extends StatelessWidget {
  final Offer offer;
  const MiniOffer({super.key, required this.offer});
  @override
  Widget build(BuildContext context) => OfferCard(offer: offer, width: 160, showStore: false);
}

/// شريط أفقي من الكروت
class OfferStrip extends StatelessWidget {
  final List<Offer> offers;
  const OfferStrip({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => OfferCard(offer: offers[i]),
      ),
    );
  }
}

class ProductGrid extends StatelessWidget {
  final List<Offer> products;
  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 262,
      ),
      itemBuilder: (context, i) => ProductCard(offer: products[i]),
    );
  }
}

/// كارت منتج الماركت
class ProductCard extends StatelessWidget {
  final Offer offer;
  const ProductCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final store = app.storeById(offer.storeId);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0.8,
      shadowColor: const Color(0x2206363C),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openOffer(context, offer),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(children: [
            OfferImage(offer: offer, height: 110),
            if (offer.discountPercent > 0) Positioned(top: 8, right: 8, child: Badge2('-${offer.discountPercent}%')),
            if (offer.storage != Storage.normal) Positioned(top: 8, left: 8, child: StorageChip(offer.storage)),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, height: 1.3)),
                const SizedBox(height: 2),
                Text(store?.name ?? '', maxLines: 1, style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
                if (offer.expiryText.isNotEmpty)
                  Text(offer.expiryText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: offer.expiresAt > 0 || !offer.unlimited ? const Color(0xFF8A5A00) : DepoColors.muted)),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (offer.shownOriginal > offer.shownPrice)
                        Text(iqd(offer.shownOriginal),
                            style: const TextStyle(fontSize: 11, color: DepoColors.muted, decoration: TextDecoration.lineThrough)),
                      Text(iqd(offer.shownPrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: DepoColors.dark)),
                    ]),
                  ),
                  AddButton(offer: offer),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// كارت المحل: صورة كبيرة على اليمين وفوقها الخصم، والمعلومات يسار
class StoreTile extends StatelessWidget {
  final Store store;
  const StoreTile({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.offersOf(store.id);
    final maxDisc = list.isEmpty ? 0 : list.map((o) => o.discountPercent).reduce((a, b) => a > b ? a : b);
    final isShop = store.type == StoreType.shop;
    final withImg = list.where((o) => o.imageId.isNotEmpty).toList();
    final cover = store.imageId.isNotEmpty
        ? AppImage(imageId: store.imageId, height: 112, width: 120, fallback: _ph())
        : withImg.isNotEmpty
            ? SizedBox(width: 120, child: OfferImage(offer: withImg.first, height: 112))
            : list.isNotEmpty
                ? SizedBox(width: 120, child: OfferImage(offer: list.first, height: 112))
                : _ph();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0.8,
        shadowColor: const Color(0x2206363C),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(storeId: store.id))),
          child: SizedBox(
            height: 112,
            child: Row(children: [
              Stack(children: [
                cover,
                if (maxDisc > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(10)),
                      child: Text('خصم $maxDisc%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ]),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                      Flexible(
                        child: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      if (store.sponsored) ...[
                        const SizedBox(width: 6),
                        const Badge2('مُموّل', bg: DepoColors.soft, fg: DepoColors.muted),
                      ],
                    ]),
                    Text('${store.area} • ${app.distanceText(store)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 17, color: DepoColors.brand),
                      Text(' ${store.rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      const Icon(Icons.schedule_rounded, size: 15, color: DepoColors.muted),
                      Text(' ${store.eta}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                    ]),
                    const SizedBox(height: 4),
                    Text(list.isEmpty ? (isShop ? 'ماكو منتجات بعد' : 'ماكو عروض هسه') : (isShop ? '${list.length} منتج بأسعارها' : '${list.length} عروض متوفرة هسه'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: list.isEmpty ? DepoColors.muted : DepoColors.success)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ph() => ImagePlaceholder(height: 112, radius: 0, seed: store.name).let((w) => SizedBox(width: 120, child: w));
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class StoreAvatar extends StatelessWidget {
  final Store store;
  final double size;
  const StoreAvatar({super.key, required this.store, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final letter = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DepoColors.brand, DepoColors.dark]),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(store.name.replaceFirst('مطعم ', '').replaceFirst('محل ', '').characters.first,
          style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900)),
    );
    return AppImage(imageId: store.imageId, height: size, width: size, radius: size * 0.3, fallback: letter);
  }
}
