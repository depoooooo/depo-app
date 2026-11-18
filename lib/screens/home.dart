import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'offer_detail.dart';
import 'search.dart';
import 'store_page.dart';

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
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: _Header(tabs: _tabs))],
        body: TabBarView(controller: _tabs, children: const [_RawajiTab(), _MarketTab()]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TabController tabs;
  const _Header({required this.tabs});

  @override
  Widget build(BuildContext context) {
    final address = app.me?.addresses.isNotEmpty == true ? app.me!.addresses.first : 'حي الزهور — الموصل';
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 14),
      decoration: const BoxDecoration(
        color: DepoColors.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 18, color: DepoColors.ink),
                const SizedBox(width: 4),
                Flexible(child: Text(address, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              const Text('رواجع حارّة خلال 20–40 دقيقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          Image.asset('assets/logo/depo-ar-white.png', height: 34, semanticLabel: 'ديبو'),
        ]),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(children: [
                Icon(Icons.search, color: DepoColors.muted),
                SizedBox(width: 8),
                Text('شتشتهي اليوم؟ خبز حار؟', style: TextStyle(color: DepoColors.muted)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
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
      ]),
    );
  }
}

class _RawajiTab extends StatelessWidget {
  const _RawajiTab();

  @override
  Widget build(BuildContext context) {
    final restaurants = app.storesOfType(StoreType.restaurant).where((s) => app.offersOf(s.id).isNotEmpty).toList()
      ..sort((a, b) => (b.sponsored ? 1 : 0) - (a.sponsored ? 1 : 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!app.loggedIn) const _GuestBanner(),
        const _CampaignBanner(),
        const SizedBox(height: 4),
        const SectionTitle('رواجع قريبة عليك هسه'),
        if (restaurants.isEmpty)
          const EmptyState(icon: Icons.restaurant_outlined, text: 'ماكو رواجع هسه. تابع مطاعمك المفضلة حتى يوصلك إشعار أول ما ينشرون.'),
        for (final s in restaurants) StoreRow(store: s),
        const _PickupBanner(),
      ],
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: const Color(0xFF9BD9E1),
      child: Row(children: [
        const Icon(Icons.star_rounded, color: DepoColors.accent),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('سجّل واكسب نقاط تبدّلها بصناديق مجانية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        TextButton(onPressed: () => ensureLoggedIn(context, reason: 'سجّل حتى تجمع نقاط وتتابع مطاعمك'), child: const Text('تسجيل')),
      ]),
    );
  }
}

class _CampaignBanner extends StatelessWidget {
  const _CampaignBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: DepoColors.ink, borderRadius: BorderRadius.circular(18)),
      child: const Row(children: [
        Icon(Icons.local_fire_department, color: DepoColors.accent, size: 30),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('رخيييييص', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.accent)),
            Text('حملة الشهر: رواجع تبدي من 1,000 دينار', style: TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

class _PickupBanner extends StatelessWidget {
  const _PickupBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: DepoColors.dark,
      child: Row(children: [
        const Icon(Icons.storefront_outlined, color: DepoColors.dark, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('استلم بنفسك ووفّر ${iqd(app.settings.deliveryFee)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const Text('تروح للمطعم وتاخذ طلبك بدون رسم توصيل', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// كرت المطعم ويه عروضه بشريط أفقي
class StoreRow extends StatelessWidget {
  final Store store;
  const StoreRow({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.offersOf(store.id);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(storeId: store.id))),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: DepoColors.soft, borderRadius: BorderRadius.circular(14)),
              child: Icon(store.type == StoreType.restaurant ? Icons.restaurant : Icons.storefront, color: DepoColors.dark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(store.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                Text('★ ${store.rating.toStringAsFixed(1)} (${store.ratingCount}) • ${store.distanceKm} كم • ${store.eta}',
                    style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
              ]),
            ),
            if (store.sponsored) const Badge2('مُموّل', bg: DepoColors.soft, fg: DepoColors.muted),
            const Icon(Icons.chevron_left, color: DepoColors.muted),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => MiniOffer(offer: list[i]),
          ),
        ),
      ]),
    );
  }
}

class MiniOffer extends StatelessWidget {
  final Offer offer;
  const MiniOffer({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer))),
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
          Text(offer.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          PriceTag(price: offer.price, original: offer.originalPrice, size: 14),
          Text(offer.quantityLeft <= 2 ? 'باقي ${offer.quantityLeft} بس' : 'باقي ${offer.quantityLeft}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DepoColors.danger)),
        ]),
      ),
    );
  }
}

class _MarketTab extends StatelessWidget {
  const _MarketTab();

  @override
  Widget build(BuildContext context) {
    final merchantIds = app.storesOfType(StoreType.merchant).map((s) => s.id).toSet();
    final products = app.offers.where((o) => o.visible && merchantIds.contains(o.storeId)).toList();
    final cheap = products.where((o) => o.price <= 1000).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: DepoColors.ink, borderRadius: BorderRadius.circular(14)),
          child: const Text('عروض الأسبوع — باقي 3 أيام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        if (cheap.isNotEmpty) ...[
          const SectionTitle('كلشي بـ 1,000 دينار'),
          ProductGrid(products: cheap),
          const SizedBox(height: 6),
        ],
        const SectionTitle('عروض قوية اليوم'),
        if (products.isEmpty) const EmptyState(icon: Icons.shopping_basket_outlined, text: 'ماكو عروض بالماركت هسه'),
        ProductGrid(products: products),
      ],
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
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, i) => ProductCard(offer: products[i]),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Offer offer;
  const ProductCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final store = app.storeById(offer.storeId);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: offer))),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: DepoColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ImagePlaceholder(height: 100, box: true, radius: 12),
          const SizedBox(height: 6),
          Text('${store?.name ?? ''} • ${store?.distanceKm ?? ''} كم', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          StorageChip(offer.storage),
          const Spacer(),
          Text(offer.expiresLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A5A00))),
          PriceTag(price: offer.price, original: offer.originalPrice, size: 15),
          Text('انطلب +${offer.orderedThisWeek} هالأسبوع',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DepoColors.success)),
        ]),
      ),
    );
  }
}
