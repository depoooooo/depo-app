import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../orders.dart';

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
        body: TabBarView(children: [_Dashboard(store: s), _MyOffers(store: s), _StoreOrders(store: s)]),
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
  bool autoDaily = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final all = app.ordersOfStore(s.id);
    final today = all.where((o) => DateTime.fromMillisecondsSinceEpoch(o.createdAt).day == DateTime.now().day).toList();
    final delivered = all.where((o) => o.status == OrderStatus.delivered).toList();
    final sales = delivered.fold(0, (a, o) => a + o.itemsTotal);
    final comm = delivered.fold(0, (a, o) => a + o.commission);
    // المحل يحصّل النقد بالاستلام الذاتي، فالعمولة تصير دين عليه
    final owed = delivered.where((o) => o.pickup).fold(0, (a, o) => a + o.commission);
    final free = app.freeDaysLeft(s);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (s.suspended)
          const AppCard(color: Color(0xFFFDECED), child: Text('المحل موقوف مؤقتاً. تواصل ويه المشرف.', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800))),
        if (free > 0)
          AppCard(color: const Color(0xFFFFF6E5), child: Text('الشهر المجاني: باقي $free يوم بدون عمولة', style: const TextStyle(fontWeight: FontWeight.w800))),
        StatGrid([
          StatTile('طلبات اليوم', '${today.length}'),
          StatTile('المتابعين', '${app.followersOf(s.id)}'),
          StatTile('التقييم', '${s.rating.toStringAsFixed(1)} (${s.ratingCount})'),
          StatTile('عروض فعّالة', '${app.offersOf(s.id).length}'),
        ]),
        const SizedBox(height: 12),
        if (s.type == StoreType.restaurant)
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: autoDaily,
              onChanged: (v) => setState(() => autoDaily = v),
              title: const Text('رواجع يومية تلقائية', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('تنشر وحدها كل يوم الساعة 10 بالليل وأنت تأكد الكمية بس'),
            ),
          ),
        const SectionTitle('الأرباح والتسويات'),
        AppCard(
          child: Column(children: [
            _row('المبيعات (طلبات مُسلّمة)', iqd(sales)),
            _row('عمولة Depo', iqd(comm)),
            const Divider(),
            _row('الصافي إلك', iqd(sales - comm), bold: true),
            _row('عليك لـ Depo (عمولة الاستلام الذاتي النقدي)', iqd(owed)),
            const SizedBox(height: 6),
            const Text('التسوية أسبوعية', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
          ]),
        ),
      ],
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500))),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );
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
                Expanded(child: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (o.hidden) const Badge2('مخفي من المشرف', bg: Color(0xFFFDECED), fg: DepoColors.danger)
                else Badge2(o.visible ? 'فعّال' : (o.quantityLeft == 0 ? 'خلص' : 'موقوف'), bg: o.visible ? DepoColors.brand : DepoColors.soft),
              ]),
              PriceTag(price: o.price, original: o.originalPrice, size: 15),
              Text('${o.expiresLabel} • انطلب ${o.orderedThisWeek} مرة', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
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

class _StoreOrders extends StatelessWidget {
  final Store store;
  const _StoreOrders({required this.store});

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
          FilledButton(onPressed: () => app.setStatus(o, OrderStatus.accepted), child: const Text('قبول')),
          OutlinedButton(onPressed: () => _reject(context, o), child: const Text('رفض')),
        ]);
      case OrderStatus.accepted:
        return row([FilledButton(onPressed: () => app.setStatus(o, OrderStatus.preparing), child: const Text('بدينا نجهّز'))]);
      case OrderStatus.preparing:
        return row([FilledButton(onPressed: () => app.setStatus(o, OrderStatus.ready), child: const Text('جاهز'))]);
      case OrderStatus.ready:
        if (o.pickup) {
          return row([FilledButton.icon(onPressed: () => _handover(context, o), icon: const Icon(Icons.qr_code_scanner), label: const Text('تسليم للزبون (الرمز)'))]);
        }
        return row([Text(o.courierPhone == null ? 'ننتظر مندوب يستلم' : 'المندوب جاي يستلم', style: const TextStyle(fontWeight: FontWeight.w700))]);
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
              onTap: () {
                app.setStatus(o, OrderStatus.rejected, reason: r);
                Navigator.pop(c);
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
  final expires = TextEditingController();
  final pickupWindow = TextEditingController(text: '10–11 م');
  final desc = TextEditingController();
  bool surprise = true;
  Storage storage = Storage.normal;

  bool get isRest => widget.store.type == StoreType.restaurant;

  @override
  void initState() {
    super.initState();
    expires.text = isRest ? 'ينتهي 11:30 م' : 'ينتهي بعد 7 أيام';
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

  void _publish() {
    final o = parseInt(original.text);
    final p = parseInt(price.text);
    final q = parseInt(qty.text);
    if (title.text.trim().isEmpty || o == null || p == null || q == null || q <= 0) {
      toast(context, 'املي الاسم والأسعار والكمية');
      return;
    }
    final minDiscount = isRest ? 40 : 20;
    if (discount < minDiscount) {
      toast(context, 'الخصم لازم يكون $minDiscount% أو أكثر');
      return;
    }
    app.publishOffer(app.newOffer(
      storeId: widget.store.id,
      title: title.text.trim(),
      originalPrice: o,
      price: p,
      qty: q,
      expiresLabel: expires.text.trim(),
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
            )
          else
            OutlinedButton.icon(onPressed: () => toast(context, 'مسح الباركود يتفعل بالتطبيق على التلفون'), icon: const Icon(Icons.qr_code_scanner), label: const Text('امسح الباركود')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => toast(context, 'رفع الصور يتفعل ويه Firebase'), icon: const Icon(Icons.add_a_photo_outlined), label: const Text('أضف صور')),
          const SizedBox(height: 10),
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
            Expanded(child: TextField(controller: expires, decoration: InputDecoration(labelText: isRest ? 'ينتهي العرض' : 'تاريخ الانتهاء'))),
          ]),
          const SizedBox(height: 10),
          if (isRest)
            TextField(controller: pickupWindow, decoration: const InputDecoration(labelText: 'وقت الاستلام'))
          else ...[
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
          FilledButton(onPressed: _publish, child: Text(isRest ? 'انشر هسه' : 'حفظ ونشر')),
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
