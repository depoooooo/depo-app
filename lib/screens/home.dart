import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import 'offer_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _Header(tabs: _tabs)),
        ],
        body: TabBarView(
          controller: _tabs,
          children: const [_RawajiTab(), _MerchantsTab()],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: cart,
        builder: (context, _) => cart.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                backgroundColor: DepoColors.ink,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CartScreen())),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text('السلة (${cart.count}) — ${iqd(cart.total)}'),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TabController tabs;
  const _Header({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 14),
      decoration: const BoxDecoration(
        color: DepoColors.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 18, color: DepoColors.ink),
                  SizedBox(width: 4),
                  Text('حي الزهور — الموصل', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 4),
                Text('رواجع حارّة خلال 20–40 دقيقة',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
            Image.asset('assets/logo/depo-ar-white.png', height: 34, semanticLabel: 'ديبو'),
          ]),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              hintText: 'شتشتهي اليوم؟ خبز حار؟',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: tabs,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: DepoColors.ink,
              unselectedLabelColor: DepoColors.ink,
              labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15),
              tabs: const [
                Tab(icon: Icon(Icons.restaurant_outlined, size: 18), text: 'رواجع المطاعم', iconMargin: EdgeInsets.zero),
                Tab(icon: Icon(Icons.shopping_basket_outlined, size: 18), text: 'الماركت', iconMargin: EdgeInsets.zero),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawajiTab extends StatelessWidget {
  const _RawajiTab();

  @override
  Widget build(BuildContext context) {
    final restaurants = stores.where((s) => s.type == StoreType.restaurant).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _GuestBanner(),
        const SizedBox(height: 12),
        _CampaignBanner(),
        const SizedBox(height: 14),
        const SectionTitle('رواجع قريبة عليك هسه'),
        for (final s in restaurants) ...[
          _StoreRow(store: s),
          const SizedBox(height: 12),
        ],
        _PickupBanner(),
      ],
    );
  }
}

class _GuestBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9BD9E1)),
      ),
      child: Row(children: [
        const Icon(Icons.star_rounded, color: DepoColors.accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('سجّل واكسب نقاط تبدّلها بصناديق مجانية',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        TextButton(onPressed: () {}, child: const Text('تسجيل')),
      ]),
    );
  }
}

class _CampaignBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DepoColors.ink, borderRadius: BorderRadius.circular(18)),
      child: const Row(children: [
        Icon(Icons.local_fire_department, color: DepoColors.accent, size: 30),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('رخيييييص',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.accent)),
            Text('حملة الشهر: رواجع تبدي من 1,000 دينار',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

class _PickupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DepoColors.dark, width: 1.5),
      ),
      child: const Row(children: [
        Icon(Icons.storefront_outlined, color: DepoColors.dark, size: 28),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('استلم بنفسك ووفّر 2,000 دينار', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('تروح للمطعم وتاخذ طلبك بدون رسم توصيل',
                style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// كرت المطعم ويه عروضه بشريط أفقي
class _StoreRow extends StatelessWidget {
  final Store store;
  const _StoreRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = offersOf(store.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DepoColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: DepoColors.soft, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.restaurant, color: DepoColors.dark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              Text(
                '★ ${store.rating} (${store.ratingCount}) • ${store.distanceKm} كم • ${store.eta}',
                style: const TextStyle(fontSize: 11, color: DepoColors.muted),
              ),
            ]),
          ),
          if (store.sponsored)
            const Badge2('مُموّل', bg: DepoColors.soft, fg: DepoColors.muted),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _MiniOffer(offer: list[i]),
          ),
        ),
      ]),
    );
  }
}

class _MiniOffer extends StatelessWidget {
  final Offer offer;
  const _MiniOffer({required this.offer});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer))),
      child: SizedBox(
        width: 132,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ImagePlaceholder(height: 92, box: offer.surpriseBox, radius: 12),
            Positioned(
              top: 6,
              right: 6,
              child: Badge2(offer.surpriseBox ? 'صندوق مفاجأة' : 'خصم ${offer.discountPercent}%',
                  bg: offer.surpriseBox ? DepoColors.brand : DepoColors.accent),
            ),
          ]),
          const SizedBox(height: 4),
          Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          PriceTag(price: offer.price, original: offer.originalPrice, size: 14),
          Text(
            offer.quantityLeft <= 2 ? 'باقي ${offer.quantityLeft} بس' : 'باقي ${offer.quantityLeft}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DepoColors.danger),
          ),
        ]),
      ),
    );
  }
}

class _MerchantsTab extends StatelessWidget {
  const _MerchantsTab();

  @override
  Widget build(BuildContext context) {
    final products = offers.where((o) => storeById(o.storeId).type == StoreType.merchant).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: DepoColors.ink, borderRadius: BorderRadius.circular(14)),
          child: const Text('عروض الأسبوع — باقي 3 أيام',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 14),
        const SectionTitle('عروض قوية اليوم'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.58,
          ),
          itemBuilder: (context, i) => _ProductCard(offer: products[i]),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Offer offer;
  const _ProductCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final store = storeById(offer.storeId);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer))),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DepoColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ImagePlaceholder(height: 100, box: true, radius: 12),
          const SizedBox(height: 6),
          Text('${store.name} • ${store.distanceKm} كم',
              style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          StorageChip(offer.storage),
          const Spacer(),
          Text(offer.expiresLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00))),
          PriceTag(price: offer.price, original: offer.originalPrice, size: 15),
          Text('انطلب +${offer.orderedThisWeek} هالأسبوع',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DepoColors.success)),
        ]),
      ),
    );
  }
}
