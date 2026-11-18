import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/images.dart';
import '../../widgets/offer_cards.dart';
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
        _PublishHero(store: s),
        const SizedBox(height: 12),
        StatGrid([
          StatTile('طلبات اليوم', '${today.length}'),
          StatTile('المتابعين', '${app.followersOf(s.id)}'),
          StatTile('التقييم', '${s.rating.toStringAsFixed(1)} (${s.ratingCount})'),
          StatTile('عروض فعّالة', '${app.offersOf(s.id).length}'),
        ]),
        const SizedBox(height: 12),
        if (s.type == StoreType.restaurant)
          AppCard(
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.schedule_rounded, color: DepoColors.muted),
              title: Text('رواجع يومية تلقائية (قريباً)', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('تنشر وحدها كل يوم بوقت تختاره وأنت تأكد الكمية بس. هسه استخدم «انشر بضغطة وحدة» فوق.'),
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
  final expires = TextEditingController(); // التاجر: كم يوم باقي على انتهاء المنتج
  int hours = 3; // المطعم: العرض يبقى كم ساعة
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
            )
          else
            OutlinedButton.icon(onPressed: () => toast(context, 'مسح الباركود يتفعل بالتطبيق على التلفون'), icon: const Icon(Icons.qr_code_scanner), label: const Text('امسح الباركود')),
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
