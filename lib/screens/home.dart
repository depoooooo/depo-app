import 'dart:async';
import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/categories.dart';
import '../data/models.dart';
import 'categories_screen.dart';
import '../widgets/depo_refresh.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/offer_cards.dart';
import 'account.dart';
import 'auth.dart';
import 'following.dart';
import 'join.dart';
import 'search.dart';
import 'store_page.dart';

export '../widgets/offer_cards.dart';

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
        body: TabBarView(controller: _tabs, children: [_RawajiTab(), _MarketTab()]), // ignore: prefer_const_constructors
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TabController tabs;
  const _Header({required this.tabs});

  @override
  Widget build(BuildContext context) {
    final address = app.me?.addresses.isNotEmpty == true ? app.me!.addresses.first : 'الموصل';
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5AD6E3), DepoColors.brand]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('التوصيل إلى', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DepoColors.ink)),
              Row(children: [
                Flexible(
                  child: Text(address, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ]),
            ]),
          ),
          Image.asset('assets/logo/depo-ar-white.png', height: 30, semanticLabel: 'ديبو'),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () async {
              if (await ensureLoggedIn(context, reason: 'سجّل حتى توصلك إشعارات مطاعمك وطلباتك') && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              }
            },
            icon: Badge(
              isLabelVisible: app.unreadCount > 0,
              label: Text('${app.unreadCount}'),
              child: const Icon(Icons.notifications_none_rounded, size: 28, color: DepoColors.ink),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          shadowColor: const Color(0x3306363C),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(Icons.search_rounded, color: DepoColors.dark),
                SizedBox(width: 8),
                Text('دوّر على أكلة أو محل...', style: TextStyle(color: DepoColors.muted)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 46,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: tabs,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x2206363C), blurRadius: 6, offset: Offset(0, 2))],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: DepoColors.ink,
            unselectedLabelColor: DepoColors.ink,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w900, fontSize: 15),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [Tab(text: '🍽️  رواجع المطاعم'), Tab(text: '🛒  الماركت')],
          ),
        ),
      ]),
    );
  }
}

// ======================= رواجع المطاعم =======================
enum _Filter { none, discount, near, boxes, rated, fresh }

const _filterNames = {
  _Filter.discount: 'أعلى خصم',
  _Filter.near: 'قريب عليّ',
  _Filter.boxes: 'صناديق مفاجأة',
  _Filter.rated: 'الأعلى تقييم',
  _Filter.fresh: 'نزل هسه',
};

const _filterIcons = {
  _Filter.discount: Icons.percent_rounded,
  _Filter.near: Icons.near_me_rounded,
  _Filter.boxes: Icons.card_giftcard_rounded,
  _Filter.rated: Icons.star_rounded,
  _Filter.fresh: Icons.bolt_rounded,
};

class _RawajiTab extends StatefulWidget {
  const _RawajiTab();

  @override
  State<_RawajiTab> createState() => _RawajiTabState();
}

class _RawajiTabState extends State<_RawajiTab> {
  _Filter filter = _Filter.none;

  List<Offer> _filtered(List<Offer> offers) {
    var l = offers;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (filter) {
      case _Filter.discount:
        l = [...l]..sort((a, b) => b.discountPercent - a.discountPercent);
      case _Filter.near:
        l = l.where((o) => (app.storeById(o.storeId)?.distanceKm ?? 99) <= app.settings.stage1Km).toList()
          ..sort((a, b) => app.storeById(a.storeId)!.distanceKm.compareTo(app.storeById(b.storeId)!.distanceKm));
      case _Filter.boxes:
        l = l.where((o) => o.surpriseBox).toList();
      case _Filter.rated:
        l = [...l]..sort((a, b) => app.storeById(b.storeId)!.rating.compareTo(app.storeById(a.storeId)!.rating));
      case _Filter.fresh:
        l = l.where((o) => now - o.createdAt < 60 * 60 * 1000).toList();
      case _Filter.none:
        break;
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = app.storesOfType(StoreType.restaurant)
      ..sort((a, b) {
        final sp = (b.sponsored ? 1 : 0) - (a.sponsored ? 1 : 0);
        if (sp != 0) return sp;
        return app.offersOf(b.id).length - app.offersOf(a.id).length;
      });
    final ids = restaurants.map((s) => s.id).toSet();
    final offers = app.offers.where((o) => o.visible && ids.contains(o.storeId) && o.quantityLeft > 0).toList()
      ..sort((a, b) => a.quantityLeft - b.quantityLeft);
    final boxes = offers.where((o) => o.surpriseBox).toList();
    final st = app.settings;
    final campaign = restaurants.where((s) => app.offersOf(s.id).any((o) => o.discountPercent >= st.campaignMinDiscount)).toList();
    final filtering = filter != _Filter.none;

    return DepoRefresh(
      onRefresh: app.refreshFromServer,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        CatStrip(cats: restaurantCats, market: false),
        // أزرار الفلترة
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              for (final f in _filterNames.keys)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: FilterChip(
                    showCheckmark: false,
                    avatar: Icon(_filterIcons[f], size: 18, color: filter == f ? Colors.white : DepoColors.dark),
                    label: Text(_filterNames[f]!),
                    labelStyle: TextStyle(fontWeight: FontWeight.w800, color: filter == f ? Colors.white : DepoColors.ink),
                    selected: filter == f,
                    selectedColor: DepoColors.dark,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: filter == f ? DepoColors.dark : const Color(0xFFDCEFF2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (v) => setState(() => filter = v ? f : _Filter.none),
                  ),
                ),
            ],
          ),
        ),
        if (filtering) ..._results(offers) else ...[
          const SizedBox(height: 6),
          _Banners(slides: [
            _Slide(
              color: DepoColors.ink,
              title: '${st.campaignName} 🔥',
              titleColor: DepoColors.accent,
              text: 'رواجع المطاعم تبدي من 1,000 دينار',
            ),
            _Slide(
              color: DepoColors.dark,
              title: 'استلم بنفسك',
              text: 'ووفّر ${iqd(st.deliveryFee)} رسم التوصيل',
              icon: Icons.storefront_rounded,
            ),
            if (!app.loggedIn)
              _Slide(
                color: DepoColors.accent,
                title: 'سجّل واكسب نقاط',
                titleColor: DepoColors.ink,
                textColor: DepoColors.ink,
                text: 'كل 1,000 دينار = نقطة، بدّلها بصناديق مجانية',
                icon: Icons.stars_rounded,
                onTap: () => ensureLoggedIn(context, reason: 'سجّل حتى تجمع نقاط وتتابع مطاعمك'),
              ),
            _Slide(
              color: const Color(0xFF2B5F66),
              title: 'عندك مطعم أو محل؟',
              text: 'انضم لديبو — أول شهر مجاني للمطاعم',
              icon: Icons.handshake_rounded,
              onTap: () => app.loggedIn
                  ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen()))
                  : ensureLoggedIn(context, reason: 'سجّل أول حتى تقدّم طلب انضمام'),
            ),
          ]),
          const _MyStores(),
          _Section(title: 'رواجع قريبة عليك هسه', subtitle: 'توصل خلال 20–40 دقيقة'),
          if (offers.isEmpty)
            const EmptyState(icon: Icons.restaurant_outlined, text: 'ماكو رواجع هسه. تابع مطاعمك المفضلة حتى يوصلك إشعار أول ما ينشرون.')
          else
            OfferStrip(offers: offers),
          if (campaign.isNotEmpty) _Campaign(name: st.campaignName, minDiscount: st.campaignMinDiscount, stores: campaign),
          if (boxes.isNotEmpty) ...[
            _Section(title: 'صناديق المفاجأة 🎁', subtitle: 'قيمتها 3 أضعاف سعرها'),
            OfferStrip(offers: boxes),
          ],
          _Section(title: 'المطاعم'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [for (final s in restaurants) StoreTile(store: s)]),
          ),
        ],
      ],
      ),
    );
  }

  List<Widget> _results(List<Offer> offers) {
    final res = _filtered(offers);
    final title = _filterNames[filter] ?? '';
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(children: [
          Expanded(child: Text('$title (${res.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          TextButton.icon(
            onPressed: () => setState(() => filter = _Filter.none),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('مسح', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      if (res.isEmpty)
        const EmptyState(icon: Icons.search_off_rounded, text: 'ماكو شي بهذا الاختيار هسه. جرّب نوع ثاني أو ارجع بعد شوية.')
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProductGrid(products: res)),
    ];
  }
}

/// قسم الحملة (مثل «خصم فوق الخصم»)
class _Campaign extends StatelessWidget {
  final String name;
  final int minDiscount;
  final List<Store> stores;
  const _Campaign({required this.name, required this.minDiscount, required this.stores});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE2F7F9), DepoColors.bg]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DepoColors.dark)),
          const Spacer(),
          Badge2('خصم $minDiscount% وأكثر'),
        ]),
        const SizedBox(height: 10),
        for (final s in stores) StoreTile(store: s),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAll;
  const _Section({required this.title, this.subtitle = '', this.onAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
        if (onAll != null) TextButton(onPressed: onAll, child: const Text('الكل', style: TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

/// المحلات اللي أتابعها: دوائر صغيرة فوق
class _MyStores extends StatelessWidget {
  const _MyStores();

  @override
  Widget build(BuildContext context) {
    final me = app.me;
    final list = me == null ? <Store>[] : me.follows.map(app.storeById).whereType<Store>().toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(
        title: 'محلاتي',
        onAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FollowingScreen())),
      ),
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final s = list[i];
            final hasOffers = app.offersOf(s.id).isNotEmpty;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(storeId: s.id))),
              child: SizedBox(
                width: 66,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: hasOffers ? DepoColors.accent : DepoColors.line, width: 2.5),
                      ),
                      child: ClipOval(child: StoreAvatar(store: s, size: 54)),
                    ),
                    if (hasOffers)
                      const Positioned(bottom: -2, left: -2, child: Badge2('جديد', bg: DepoColors.accent)),
                  ]),
                  const SizedBox(height: 4),
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ======================= البنرات المتحركة =======================
class _Slide {
  final Color color;
  final String title;
  final String text;
  final Color titleColor;
  final Color textColor;
  final IconData icon;
  final VoidCallback? onTap;
  const _Slide({
    required this.color,
    required this.title,
    required this.text,
    this.titleColor = Colors.white,
    this.textColor = Colors.white,
    this.icon = Icons.local_fire_department_rounded,
    this.onTap,
  });
}

class _Banners extends StatefulWidget {
  final List<_Slide> slides;
  const _Banners({required this.slides});

  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final _page = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_page.hasClients || widget.slides.isEmpty) return;
      _page.animateToPage((_i + 1) % widget.slides.length,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    return Column(children: [
      SizedBox(
        height: 112,
        child: PageView.builder(
          controller: _page,
          itemCount: n,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (context, i) {
            final s = widget.slides[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: s.color,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: s.onTap,
                  child: Stack(children: [
                    Positioned(
                      left: -18,
                      bottom: -22,
                      child: Icon(s.icon, size: 120, color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(s.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: s.titleColor)),
                        const SizedBox(height: 4),
                        Text(s.text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: s.textColor)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var k = 0; k < n; k++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: k == _i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: k == _i ? DepoColors.dark : DepoColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    ]);
  }
}

// ======================= الماركت =======================
class _MarketTab extends StatelessWidget {
  const _MarketTab();

  @override
  Widget build(BuildContext context) {
    final merchants = app.storesOfType(StoreType.merchant);
    final ids = merchants.map((s) => s.id).toSet();
    final products = app.offers.where((o) => o.visible && ids.contains(o.storeId)).toList();
    final cheap = products.where((o) => o.price <= 1000).toList();
    return DepoRefresh(
      onRefresh: app.refreshFromServer,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        CatStrip(cats: marketCats, market: true),
        const SizedBox(height: 6),
        _Banners(slides: [
          const _Slide(
            color: DepoColors.ink,
            title: 'عروض الأسبوع',
            titleColor: DepoColors.accent,
            text: 'خصومات قوية على مواد قريبة الانتهاء — باقي 3 أيام',
            icon: Icons.local_offer_rounded,
          ),
          _Slide(
            color: DepoColors.dark,
            title: 'كلشي بـ 1,000 دينار',
            text: 'منتجات مختارة بسعر واحد',
            icon: Icons.sell_rounded,
          ),
        ]),
        if (cheap.isNotEmpty) ...[
          _Section(title: 'كلشي بـ 1,000 دينار'),
          OfferStrip(offers: cheap),
        ],
        _Section(title: 'عروض قوية اليوم', subtitle: 'من محلات الموصل مباشرة'),
        if (products.isEmpty)
          const EmptyState(icon: Icons.shopping_basket_outlined, text: 'ماكو عروض بالماركت هسه')
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProductGrid(products: products)),
        _Section(title: 'المحلات'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [for (final s in merchants) StoreTile(store: s)]),
        ),
      ],
      ),
    );
  }
}
