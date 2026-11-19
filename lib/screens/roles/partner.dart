import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/images.dart';
import '../../widgets/offer_cards.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../orders.dart';
import '../categories_screen.dart';
import '../../data/categories.dart';
import '../../widgets/debt_ui.dart';
import 'finance_tab.dart';
import '../../widgets/geo_ui.dart';
import '../../widgets/depo_glyph.dart';

/// واجهة المطعم والتاجر
class PartnerHome extends StatelessWidget {
  const PartnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = app.myStore;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.store_outlined, text: 'ماكو محل مربوط بهذا الحساب'));
    }
    final isRest = s.type == StoreType.restaurant;
    final newOrders = app.ordersOfStore(s.id).where((o) => o.status == OrderStatus.placed).length;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: DepoColors.ink,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          title: Text(s.fullName),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: DepoColors.brand,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
            tabs: [
              const Tab(text: 'اللوحة'),
              Tab(text: isRest ? 'رواجعي' : 'منتجاتي'),
              Tab(text: newOrders > 0 ? 'الطلبات ($newOrders)' : 'الطلبات'),
            ],
          ),
        ),
        body: TabBarView(children: [_Dashboard(store: s), _MyOffers(store: s), StoreOrdersTab(store: s)]),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: DepoColors.dark,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublishOfferScreen(store: s))),
          icon: const Icon(Icons.add),
          label: Text(isRest ? 'انشر رواجع' : 'أضف منتج'),
        ),
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  final Store store;
  const _Dashboard({required this.store});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final all = app.ordersOfStore(s.id);
    final today = all.where((o) => DateTime.fromMillisecondsSinceEpoch(o.createdAt).day == DateTime.now().day).toList();
    final free = app.freeDaysLeft(s);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (s.suspended)
          const AppCard(color: Color(0xFFFDECED), child: Text('المحل موقوف مؤقتاً. تواصل ويه المشرف.', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800))),
        if (free > 0)
          AppCard(color: const Color(0xFFFFF6E5), child: Text('الشهر المجاني: باقي $free يوم بدون عمولة', style: const TextStyle(fontWeight: FontWeight.w800))),
        _PublishHero(store: s),
        const SizedBox(height: 12),
        if (s.type == StoreType.restaurant)
          AppCard(
            borderColor: s.cuisine.isEmpty ? DepoColors.accent : null,
            onTap: () => _pickCuisine(context, s),
            child: Row(children: [
              Icon(catByName(restaurantCats, cuisineOf(s))?.icon ?? Icons.restaurant_menu, color: DepoColors.dark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.cuisine.isEmpty ? 'حدد نوع مطعمك حتى يطلع بقسمه' : 'القسم: ${s.cuisine}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.edit_outlined, size: 18),
            ]),
          ),
        if (s.type != StoreType.shop)
          AppCard(
            borderColor: s.hasLocation ? null : DepoColors.accent,
            onTap: () async {
              final r = await locateWithProgress(context, text: 'جاري تحديد موقع المحل…');
              if (!context.mounted) return;
              if (r.fix == null) return toast(context, r.error);
              final err = app.setStoreLocation(s, r.fix!);
              toast(context, err ?? 'انحفظ موقع المحل ✓');
            },
            child: Row(children: [
              Icon(s.hasLocation ? Icons.location_on : Icons.location_off_outlined, color: s.hasLocation ? DepoColors.success : DepoColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.hasLocation ? 'موقع المحل محدد ✓' : 'ثبّت موقع محلك', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    s.hasLocation ? 'إذا انتقلت أو جان غلط، اضغط وانت بالمحل حتى تحدّثه' : 'اضغط وانت داخل المحل. منه تنحسب مسافة التوصيل بدقة',
                    style: const TextStyle(fontSize: 12, color: DepoColors.muted),
                  ),
                ]),
              ),
              const Icon(Icons.my_location, size: 18),
            ]),
          ),
        StatGrid([
          StatTile('طلبات اليوم', '${today.length}'),
          StatTile('المتابعين', '${app.followersOf(s.id)}'),
          StatTile('التقييم', '${s.rating.toStringAsFixed(1)} (${s.ratingCount})'),
          StatTile('عروض فعّالة', '${app.offersOf(s.id).length}'),
        ]),
        const SizedBox(height: 12),
        _ImpactReport(store: s),
        const SectionTitle('الأرباح والتسوية الشهرية'),
        for (final st in app.myStoreStatements(s).take(4))
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreStatementScreen(storeId: s.id, month: st.month))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${monthLabel(st.month)} • ${st.orders.length} طلب', style: const TextStyle(fontWeight: FontWeight.w800, color: DepoColors.muted)),
              ),
              StatementSummary(st: st),
            ]),
          ),
      ],
    );
  }

  void _pickCuisine(BuildContext context, Store s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('نوع المطعم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            CatPicker(
              cats: restaurantCats,
              value: s.cuisine,
              onChanged: (v) {
                app.setStoreCuisine(s, v);
                Navigator.pop(c);
              },
            ),
          ]),
        ),
      ),
    );
  }

}

class _MyOffers extends StatelessWidget {
  final Store store;
  const _MyOffers({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.offersOf(store.id, onlyVisible: false);
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.inventory_2_outlined, text: 'بعدك ما نشرت شي. اضغط الزر تحت حتى تنشر.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final o in list)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final id = await pickAndUpload(context, owner: store.id);
                    if (id != null) app.setOfferImage(o, id);
                  },
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(children: [
                      OfferImage(offer: o, height: 56, radius: 12),
                      const Positioned(bottom: 2, left: 2, child: Icon(Icons.photo_camera, size: 16, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (o.hidden) const Badge2('مخفي من المشرف', bg: Color(0xFFFDECED), fg: DepoColors.danger)
                else Badge2(o.visible ? 'فعّال' : (o.quantityLeft == 0 ? 'خلص' : (o.expired ? 'انتهى وقته' : 'موقوف')), bg: o.visible ? DepoColors.brand : DepoColors.soft),
              ]),
              PriceTag(price: o.price, original: o.originalPrice, size: 15),
              Text('${o.expiryText} • انطلب ${o.orderedThisWeek} مرة', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              Row(children: [
                const Text('الكمية:'),
                IconButton(tooltip: 'أقل', onPressed: () => app.setOfferQty(o, o.quantityLeft - 1), icon: const Icon(Icons.remove_circle_outline)),
                Text('${o.quantityLeft}', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(tooltip: 'أكثر', onPressed: () => app.setOfferQty(o, o.quantityLeft + 1), icon: const Icon(Icons.add_circle_outline)),
                const Spacer(),
                TextButton(onPressed: () => app.setOfferActive(o, !o.active), child: Text(o.active ? 'إيقاف' : 'تفعيل')),
              ]),
            ]),
          ),
      ],
    );
  }
}

class StoreOrdersTab extends StatelessWidget {
  final Store store;
  const StoreOrdersTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.ordersOfStore(store.id);
    if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, text: 'ماكو طلبات بعد');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (list.any((o) => o.status == OrderStatus.placed))
          AppCard(
            color: const Color(0xFFFDECED),
            child: Text(store.type == StoreType.restaurant ? 'اقبل الطلبات الجديدة خلال 5 دقايق' : 'اقبل الطلبات الجديدة خلال 10 دقايق',
                style: const TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800)),
          ),
        for (final o in list) OrderTile(order: o, trailing: _actions(context, o)),
      ],
    );
  }

  Widget? _actions(BuildContext context, Order o) {
    final who = '${o.customerName.isEmpty ? 'زبون' : o.customerName} • ${o.pickup ? 'استلام ذاتي' : 'توصيل بمندوب'}';
    Widget row(List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(who, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
          const SizedBox(height: 6),
          Row(children: [for (final w in c) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: w))]),
        ]);
    switch (o.status) {
      case OrderStatus.placed:
        return row([
          FilledButton(
            onPressed: () async {
              final err = await app.setStatusSafe(o, OrderStatus.accepted);
              if (err != null && context.mounted) toast(context, err);
            },
            child: const Text('قبول'),
          ),
          OutlinedButton(onPressed: () => _reject(context, o), child: const Text('رفض')),
        ]);
      case OrderStatus.accepted:
        return row([
          FilledButton(onPressed: () => app.setStatus(o, OrderStatus.preparing), child: const Text('بدينا نجهّز')),
          OutlinedButton(onPressed: () => _reject(context, o), child: const Text('إلغاء')),
        ]);
      case OrderStatus.preparing:
        return row([FilledButton(onPressed: () => app.setStatus(o, OrderStatus.ready), child: const Text('جاهز'))]);
      case OrderStatus.ready:
        if (o.pickup) {
          return row([FilledButton.icon(onPressed: () => _handover(context, o), icon: const Icon(Icons.qr_code_scanner), label: const Text('تسليم للزبون (الرمز)'))]);
        }
        if (o.courierPhone == null) {
          return row([
            OutlinedButton.icon(
              onPressed: () {
                app.deliverBySelf(o);
                toast(context, 'خلّي مندوبك ياخذ رمز الزبون وقت التسليم');
              },
              icon: const Icon(Icons.two_wheeler),
              label: const Text('أوصله بمندوبي'),
            ),
          ]);
        }
        return row([const Text('مندوب Depo جاي يستلم', style: TextStyle(fontWeight: FontWeight.w700))]);
      case OrderStatus.onTheWay:
        if (o.courierPhone == app.currentPhone) {
          return row([FilledButton.icon(onPressed: () => _handover(context, o), icon: const Icon(Icons.password), label: const Text('تم التسليم (رمز الزبون)'))]);
        }
        return null;
      default:
        return null;
    }
  }

  void _reject(BuildContext context, Order o) {
    const reasons = ['خلصت الكمية', 'المطبخ مسدود', 'مشكلة بالطلب'];
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('سبب الرفض', style: TextStyle(fontWeight: FontWeight.w900))),
          for (final r in reasons)
            ListTile(
              title: Text(r),
              onTap: () async {
                Navigator.pop(c);
                final err = await app.setStatusSafe(o, OrderStatus.rejected, reason: r);
                if (err != null && context.mounted) toast(context, err);
              },
            ),
        ]),
      ),
    );
  }

  void _handover(BuildContext context, Order o) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رمز الاستلام من الزبون'),
        content: TextField(controller: ctl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, maxLength: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (ctl.text.trim() == o.pickupCode) {
                app.setStatus(o, OrderStatus.delivered);
                Navigator.pop(c);
                toast(context, 'تم التسليم');
              } else {
                toast(context, 'الرمز غلط');
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

/// نشر رواجع (مطعم) أو إضافة منتج (تاجر)
class PublishOfferScreen extends StatefulWidget {
  final Store store;
  const PublishOfferScreen({super.key, required this.store});

  @override
  State<PublishOfferScreen> createState() => _PublishOfferScreenState();
}

class _PublishOfferScreenState extends State<PublishOfferScreen> {
  final title = TextEditingController();
  final original = TextEditingController();
  final price = TextEditingController();
  final qty = TextEditingController(text: '3');
  final expires = TextEditingController(); // التاجر: كم يوم باقي على انتهاء المنتج
  int hours = 3; // المطعم: العرض يبقى كم ساعة
  String category = ''; // صنف المنتج (التاجر)
  final pickupWindow = TextEditingController(text: '10–11 م');
  final desc = TextEditingController();
  bool surprise = true;
  Storage storage = Storage.normal;
  Uint8List? photo;
  bool busy = false;

  Future<void> _pickPhoto(bool camera) async {
    try {
      final b = await Images.pick(camera: camera);
      if (b != null) setState(() => photo = b);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  bool get isRest => widget.store.type == StoreType.restaurant;

  @override
  void initState() {
    super.initState();
    expires.text = '7';
    if (!isRest) {
      surprise = false;
      qty.text = '20';
    }
  }

  @override
  void dispose() {
    for (final c in [title, original, price, qty, expires, pickupWindow, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  int get discount {
    final o = parseInt(original.text) ?? 0;
    final p = parseInt(price.text) ?? 0;
    if (o <= 0 || p <= 0) return 0;
    return ((1 - p / o) * 100).round();
  }

  Future<void> _publish() async {
    if (busy) return;
    if (widget.store.suspended) {
      toast(context, 'المحل موقوف مؤقتاً، ما تكدر تنشر');
      return;
    }
    final o = parseInt(original.text);
    final p = parseInt(price.text);
    final q = parseInt(qty.text);
    if (title.text.trim().isEmpty || o == null || p == null || q == null || q <= 0) {
      toast(context, 'املي الاسم والأسعار والكمية');
      return;
    }
    if (o <= p || p <= 0) {
      toast(context, 'السعر بعد الخصم لازم يكون أقل من الأصلي');
      return;
    }
    if (q > 500) {
      toast(context, 'الكمية كبيرة، تأكد منها');
      return;
    }
    if (!isRest && category.isEmpty) {
      toast(context, 'اختار صنف المنتج');
      return;
    }
    if (!isRest) {
      final d = parseInt(expires.text) ?? 0;
      if (d < 2) {
        toast(context, 'ما ينقبل منتج باقي على انتهائه أقل من يومين (48 ساعة)');
        return;
      }
    }
    final minDiscount = isRest ? 40 : 20;
    if (discount < minDiscount) {
      toast(context, 'الخصم لازم يكون $minDiscount% أو أكثر');
      return;
    }
    var imageId = '';
    if (photo != null) {
      setState(() => busy = true);
      try {
        imageId = await Images.put(photo!, owner: widget.store.id);
      } catch (e) {
        if (mounted) {
          setState(() => busy = false);
          toast(context, 'ما انرفعت الصورة: $e');
        }
        return;
      }
    }
    if (!mounted) return;
    app.publishOffer(app.newOffer(
      imageId: imageId,
      category: isRest ? '' : category,
      storeId: widget.store.id,
      title: title.text.trim(),
      originalPrice: o,
      price: p,
      qty: q,
      expiresLabel: isRest ? 'لمدة $hours ساعة' : 'ينتهي بعد ${parseInt(expires.text) ?? 0} أيام',
      expiresAt: DateTime.now().add(isRest ? Duration(hours: hours) : Duration(days: parseInt(expires.text) ?? 0)).millisecondsSinceEpoch,
      surpriseBox: surprise,
      pickupWindow: isRest ? pickupWindow.text.trim() : '',
      storage: storage,
      description: desc.text.trim(),
    ));
    toast(context, isRest ? 'انتشرت! وصل إشعار لمتابعينك' : 'انضاف المنتج للماركت');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isRest ? 'نشر رواجع' : 'إضافة منتج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isRest)
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('صندوق مفاجأة')), ButtonSegment(value: false, label: Text('وجبة محددة'))],
              selected: {surprise},
              onSelectionChanged: (v) => setState(() => surprise = v.first),
            ),
          const SizedBox(height: 10),
          _QuickFill(onParsed: (r) => setState(() {
            if (r.title.isNotEmpty) title.text = r.title;
            if (r.qty != null) qty.text = '${r.qty}';
            if (r.price != null) price.text = '${r.price}';
            if (r.original != null) original.text = '${r.original}';
          })),
          const SizedBox(height: 10),
          _PhotoBox(photo: photo, onPick: _pickPhoto, onClear: () => setState(() => photo = null)),
          const SizedBox(height: 12),
          if (isRest) ...[
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in ['صندوق مشاوي', 'صندوق معجنات', 'صندوق حلويات', 'وجبة كاملة', 'صمون حار'])
                ActionChip(label: Text(t), onPressed: () => setState(() => title.text = t)),
            ]),
            const SizedBox(height: 8),
          ],
          TextField(controller: title, decoration: InputDecoration(labelText: isRest ? 'اسم العرض' : 'اسم المنتج')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: original, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الأصلي'), onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بعد الخصم'), onChanged: (_) => setState(() {}))),
          ]),
          if (discount > 0) Text('الخصم $discount%', style: TextStyle(color: discount >= (isRest ? 40 : 20) ? DepoColors.success : DepoColors.danger, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))),
            const SizedBox(width: 10),
            if (!isRest)
              Expanded(
                child: TextField(
                  controller: expires,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'باقي على الانتهاء (أيام)'),
                ),
              ),
          ]),
          if (isRest) ...[
            const SizedBox(height: 10),
            const Text('العرض يبقى معروض لمدة:', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final h in [1, 2, 3, 5])
                ChoiceChip(label: Text(h == 1 ? 'ساعة' : (h == 2 ? 'ساعتين' : '$h ساعات')), selected: hours == h, onSelected: (_) => setState(() => hours = h)),
            ]),
            const Text('بعدها يختفي تلقائياً حتى ما ينطلب أكل بايت', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ],
          const SizedBox(height: 10),
          if (isRest)
            TextField(controller: pickupWindow, decoration: const InputDecoration(labelText: 'وقت الاستلام'))
          else ...[
            const Text('الصنف', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            CatPicker(cats: marketCats, value: category, onChanged: (v) => setState(() => category = v)),
            const SizedBox(height: 12),
            const Text('طريقة الحفظ', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            SegmentedButton<Storage>(
              segments: const [
                ButtonSegment(value: Storage.normal, label: Text('عادي')),
                ButtonSegment(value: Storage.chilled, label: Text('مبرّد')),
                ButtonSegment(value: Storage.frozen, label: Text('مجمّد')),
              ],
              selected: {storage},
              onSelectionChanged: (v) => setState(() => storage = v.first),
            ),
            const SizedBox(height: 6),
            const Text('ما ينقبل منتج باقي على انتهائه أقل من 48 ساعة', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ],
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف (اختياري)')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _publish,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(isRest ? 'انشر هسه' : 'حفظ ونشر'),
          ),
          if (isRest)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('يوصل إشعار لمتابعينك والقريبين أول شي، وبعدين يتوسع', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
            ),
        ],
      ),
    );
  }
}


/// مربع الصورة بشاشة النشر
class _PhotoBox extends StatelessWidget {
  final Uint8List? photo;
  final void Function(bool camera) onPick;
  final VoidCallback onClear;
  const _PhotoBox({required this.photo, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(photo!, height: 200, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            onPressed: onClear,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'شيل الصورة',
          ),
        ),
      ]);
    }
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: DepoColors.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DepoColors.brand, width: 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.add_a_photo_rounded, size: 40, color: DepoColors.dark),
        const SizedBox(height: 6),
        const Text('صورة حلوة = طلبات أكثر', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => onPick(true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('صوّر'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => onPick(false),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('من المعرض'),
          ),
        ]),
      ]),
    );
  }
}

/// البطاقة الكبيرة فوق اللوحة: انشر الحين + انشر بضغطة + صورة المحل
class _PublishHero extends StatelessWidget {
  final Store store;
  const _PublishHero({required this.store});

  Future<void> _quick(BuildContext context, Offer t) async {
    var qty = t.surpriseBox ? 3 : 5;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('انشر «${t.title}»'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${iqd(t.price)} بدل ${iqd(t.originalPrice)}', style: const TextStyle(color: DepoColors.muted)),
            const SizedBox(height: 12),
            const Text('شكد عندك؟', style: TextStyle(fontWeight: FontWeight.w800)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: qty > 1 ? () => set(() => qty--) : null, icon: const Icon(Icons.remove)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('$qty', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ),
              IconButton.filledTonal(onPressed: () => set(() => qty++), icon: const Icon(Icons.add)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('انشر')),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (store.suspended) {
        if (context.mounted) toast(context, 'المحل موقوف مؤقتاً، ما تكدر تنشر');
        return;
      }
      app.repostOffer(t, qty);
      if (context.mounted) toast(context, 'انتشرت! وصل إشعار لمتابعينك');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRest = store.type == StoreType.restaurant;
    final templates = app.recentTemplates(store.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DepoColors.dark, Color(0xFF0A5F68)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final id = await pickAndUpload(context, owner: store.id);
              if (id != null) app.setStoreImage(store, id);
            },
            child: Stack(clipBehavior: Clip.none, children: [
              StoreAvatar(store: store, size: 52),
              const Positioned(
                bottom: -4,
                left: -4,
                child: CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.photo_camera, size: 13, color: DepoColors.dark)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              Text(isRest ? 'عندك أكل زايد اليوم؟ لا ترميه، انشره!' : 'عندك بضاعة قريبة الانتهاء؟ صرّفها',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 60,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: DepoColors.accent,
              foregroundColor: DepoColors.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 19, fontWeight: FontWeight.w900),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublishOfferScreen(store: store))),
            icon: const Icon(Icons.campaign_rounded, size: 28),
            label: Text(isRest ? 'انشر رواجع الحين' : 'أضف منتج الحين'),
          ),
        ),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('أو انشر بضغطة وحدة:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in templates)
              ActionChip(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                avatar: const Icon(Icons.replay_rounded, size: 18, color: DepoColors.dark),
                label: Text('${t.title} • ${iqd(t.price)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                onPressed: () => _quick(context, t),
              ),
          ]),
        ],
      ]),
    );
  }
}


/// تقرير الشهر للمحل: شكد بعت بدل ما ترمي — حتى يحس بالفايدة
class _ImpactReport extends StatefulWidget {
  final Store store;
  const _ImpactReport({required this.store});

  @override
  State<_ImpactReport> createState() => _ImpactReportState();
}

class _ImpactReportState extends State<_ImpactReport> {
  int back = 0; // 0 = هذا الشهر، 1 = الشهر الماضي

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = monthKey(DateTime(now.year, now.month - back));
    final s = widget.store;
    final i = app.storeImpact(s, month);
    final unit = s.type == StoreType.restaurant ? 'وجبة' : 'منتج';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: SectionTitle('تقرير الشهر')),
        ChoiceChip(label: const Text('هذا الشهر'), selected: back == 0, onSelected: (_) => setState(() => back = 0)),
        const SizedBox(width: 6),
        ChoiceChip(label: const Text('الماضي'), selected: back == 1, onSelected: (_) => setState(() => back = 1)),
      ]),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [DepoColors.dark, DepoColors.ink]), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const DepoGlyph('🌱', size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(i.meals == 0 ? 'بعد ما بعت رواجع ${monthLabel(month)}' : 'بدل ما ينرمى، بعت ${i.meals} $unit',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('المبيعات', iqd(i.sales)),
            _chip('صافي لك', iqd(i.earnings)),
            _chip('زبائن', '${i.customers}'),
            _chip('طلبات', '${i.orders}'),
          ]),
          if (i.topItem.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('الأكثر طلباً: ${i.topItem}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          if (i.meals > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => shareText(context, app.storeImpactText(s, month, i)),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('شارك التقرير'),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _chip(String a, String b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(b, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ]),
      );
}


/// نشر سريع: يكتب (أو يحچي بمايك الكيبورد) جملة وحدة والتطبيق يعبّي الحقول
class _QuickFill extends StatefulWidget {
  final void Function(({String title, int? qty, int? price, int? original}) r) onParsed;
  const _QuickFill({required this.onParsed});

  @override
  State<_QuickFill> createState() => _QuickFillState();
}

class _QuickFillState extends State<_QuickFill> {
  final ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _go() {
    final r = parseQuickOffer(ctl.text);
    if (r.price == null && r.qty == null && r.title.isEmpty) return toast(context, 'ما فهمت، جرّب مثلاً: 5 صناديق بـ 3000 بدل 9000');
    widget.onParsed(r);
    toast(context, 'تعبّت الحقول، راجعها وانشر');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: DepoColors.soft,
      borderColor: DepoColors.soft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          DepoGlyph('⚡', size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('نشر سريع', style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 4),
        const Text('اكتب جملة وحدة، أو اضغط مايك الكيبورد واحچي', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: ctl,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _go(),
          decoration: InputDecoration(
            hintText: 'مثلاً: 5 صناديق بـ 3000 بدل 9000',
            suffixIcon: IconButton(onPressed: _go, icon: const Icon(Icons.auto_fix_high_rounded, color: DepoColors.dark)),
          ),
        ),
      ]),
    );
  }
}
