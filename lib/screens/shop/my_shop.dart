import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/categories.dart';
import '../../data/cloud.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../auth.dart';
import '../chat_screen.dart';
import '../roles/partner.dart';
import 'debtor_screen.dart';
import 'jm_ui.dart';

/// أحياء الموصل (للاختيار السريع)
const mosulAreas = [
  'الزهور', 'النور', 'المثنى', 'الضباط', 'الخضراء', 'الحدباء', 'المجموعة الثقافية', 'الكفاءات', 'القاهرة', 'السكر', 'الشرطة',
  'الإصلاح الزراعي', 'الفيصلية', 'باب الطوب', 'الدواسة', 'اليرموك', 'الموصل الجديدة', 'العربي', 'الرفاعي', 'الجامعة', 'أخرى',
];

/// «محلي»: ينشئ حساب المحل، أو يدخل عليه إذا موجود
class MyShopScreen extends StatelessWidget {
  const MyShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.myShop;
        if (s == null) return const _NoShop();
        return _ShopHome(store: s);
      },
    );
  }
}

/// «محلي» قبل الإنشاء: كارت «إنشاء حساب محل»
class _NoShop extends StatelessWidget {
  const _NoShop();

  @override
  Widget build(BuildContext context) {
    return JmScaffold(
      title: 'محلي',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        JmEmpty(
          icon: Icons.add,
          title: 'إنشاء حساب محل',
          text: 'اضغط هنا لإنشاء حساب محلك لتسجيل طلبات زبائنك وديونهم ودفعاتهم، وتعطي كل زبون رمزاً يتابع به حسابه. ومنتجاتك تظهر بالأسواق وبأسعارها.',
          onTap: () async {
            if (!await ensureLoggedIn(context, reason: 'سجّل حتى تفتح محلك') || !context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopFormScreen()));
          },
        ),
      ]),
    );
  }
}

/// إنشاء حساب محل / بيانات المحل (نفس الشاشة)
class ShopFormScreen extends StatefulWidget {
  final Store? store;
  const ShopFormScreen({super.key, this.store});

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  late final name = TextEditingController(text: widget.store?.name ?? '');
  late final phone = TextEditingController(text: widget.store?.phone ?? (app.currentPhone ?? ''));
  late final about = TextEditingController(text: widget.store?.usuallyPublishes ?? '');
  late String area = widget.store?.area ?? '';
  late bool listed = widget.store?.listed ?? true;
  late String mapLink = widget.store?.mapLink ?? '';
  late String imageId = widget.store?.imageId ?? '';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    about.dispose();
    super.dispose();
  }

  Future<void> _pasteLink() async {
    final t = (await clipboardText())?.trim() ?? '';
    if (t.isEmpty) return mounted ? jmToast(context, 'انسخ رابط الموقع أو الإحداثيات أول') : null;
    setState(() => mapLink = t);
  }

  void _save() {
    if (name.text.trim().length < 2) return jmToast(context, 'اكتب اسم المحل');
    if (area.isEmpty) return jmToast(context, 'اختار الحي');
    final s = widget.store;
    if (s == null) {
      final n = app.openShop(name: name.text, area: area, about: about.text, phone: phone.text, mapLink: mapLink, listed: listed, imageId: imageId);
      if (n == null) return jmToast(context, 'ما انفتح المحل، جرّب مرة ثانية');
      Navigator.pop(context);
      jmToast(context, 'انفتح محلك! ابدأ بزبائنك ومنتجاتك');
    } else {
      app.updateShop(s, name: name.text, area: area, about: about.text, phone: phone.text, mapLink: mapLink, listed: listed);
      if (imageId != s.imageId) app.setShopImage(s, imageId);
      Navigator.pop(context);
      jmToast(context, 'تم حفظ بيانات المحل');
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.store != null;
    final areas = [if (area.isNotEmpty && !mosulAreas.contains(area)) area, ...mosulAreas];
    return JmScaffold(
      title: edit ? 'بيانات المحل' : 'إنشاء حساب محل',
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        JmCard(
          dashed: true,
          onTap: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  final id = await pickAndUpload(context, owner: widget.store?.id ?? 'shop');
                  if (mounted) setState(() => busy = false);
                  if (id != null && mounted) setState(() => imageId = id);
                },
          child: Column(children: [
            JmAvatar(
              letter: name.text.trim().isEmpty ? 'م' : name.text.trim().characters.first,
              size: 72,
              image: imageId.isEmpty ? null : AppImage(imageId: imageId, height: 72, width: 72, fallback: const SizedBox()),
            ),
            const SizedBox(height: 8),
            Text(busy ? 'جاري الرفع…' : (imageId.isEmpty ? 'إضافة صورة للمحل' : 'تغيير الصورة'), style: const TextStyle(fontSize: 12, color: Jm.sub)),
          ]),
        ),
        TextField(controller: name, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'اسم المحل'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Jm.text),
          decoration: const InputDecoration(hintText: 'رقم الهاتف (اختياري)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: area.isEmpty ? null : area,
          isExpanded: true,
          dropdownColor: Jm.bgMid,
          iconEnabledColor: Jm.sub,
          style: const TextStyle(color: Jm.text, fontFamily: 'Tajawal', fontSize: 15),
          hint: const Text('الحي', style: TextStyle(color: Jm.faint)),
          items: [for (final a in areas) DropdownMenuItem(value: a, child: Text(a))],
          onChanged: (v) => setState(() => area = v ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: about,
          maxLines: 4,
          style: const TextStyle(color: Jm.text),
          decoration: const InputDecoration(hintText: 'وصف المحل (اختياري): ماذا تبيع، ساعات العمل...'),
        ),
        const SizedBox(height: 18),
        Center(child: Checkbox(value: listed, onChanged: (v) => setState(() => listed = v ?? true))),
        const Center(child: Text('الظهور في الأسواق (للجميع)', style: TextStyle(fontSize: 13, color: Jm.sub))),
        const SizedBox(height: 22),
        const Text('موقع المحل', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        JmCard(
          dashed: mapLink.isEmpty,
          child: Column(children: [
            CircleAvatar(radius: 22, backgroundColor: DepoColors.soft, child: Icon(mapLink.isEmpty ? Icons.location_on_outlined : Icons.check, color: Jm.cyan)),
            const SizedBox(height: 8),
            Text(mapLink.isEmpty ? 'لم تحدد موقع المحل بعد' : 'تم تحديد موقع المحل', style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              mapLink.isEmpty ? 'يساعد الزبائن على الوصول إليك بزر «الاتجاهات»' : mapLink,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: mapLink.isEmpty ? null : TextDirection.ltr,
              style: const TextStyle(fontSize: 12, color: Jm.sub),
            ),
          ]),
        ),
        Row(children: [
          Expanded(
            child: JmButton(
              label: 'تحديد على الخريطة',
              icon: Icons.map_outlined,
              color: Jm.green,
              fg: Colors.white,
              height: 46,
              onTap: () {
                openLink(context, 'https://www.google.com/maps');
                jmToast(context, 'حدّد محلك، انسخ الرابط، وارجع اضغط «لصق رابط»');
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: JmButton(label: mapLink.isEmpty ? 'لصق رابط' : 'تغيير', icon: Icons.content_paste, outlined: true, height: 46, onTap: _pasteLink)),
        ]),
        const SizedBox(height: 6),
        const Text('◂ الصق رابط خرائط جوجل أو الإحداثيات', style: TextStyle(fontSize: 12, color: Jm.faint)),
        const SizedBox(height: 22),
        JmButton(label: edit ? 'حفظ' : 'إنشاء الحساب', onTap: _save),
      ]),
    );
  }
}

// ======================= واجهة المحل =======================
class _ShopHome extends StatefulWidget {
  final Store store;
  const _ShopHome({required this.store});

  @override
  State<_ShopHome> createState() => _ShopHomeState();
}

class _ShopHomeState extends State<_ShopHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final light = Theme.of(context);
    final newOrders = app.ordersOfStore(s.id).where((o) => o.status == OrderStatus.placed).length;
    final unread = app.shopChats(s.id).any((c) => c.unreadFor(staff: true) > 0);
    return JmScaffold(
      title: s.name,
      subtitle: Cloud.enabled ? 'محفوظ سحابياً' : 'محفوظ على الجهاز',
      leading: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final id = await pickAndUpload(context, owner: s.id);
          if (id != null) app.setShopImage(s, id);
        },
        child: JmAvatar(
          letter: s.name.characters.first,
          image: s.imageId.isEmpty ? null : AppImage(imageId: s.imageId, height: 52, width: 52, fallback: const SizedBox()),
        ),
      ),
      actions: [
        Badge(
          isLabelVisible: unread,
          child: JmCircleBtn(
            icon: Icons.forum_outlined,
            tooltip: 'رسائل الزبائن',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Theme(
                data: light,
                child: Scaffold(
                  appBar: AppBar(title: const Text('رسائل الزبائن')),
                  body: ListenableBuilder(listenable: app, builder: (context, _) => ChatListView(source: () => app.shopChats(s.id))),
                ),
              ),
            )),
          ),
        ),
        JmCircleBtn(icon: Icons.settings_outlined, tooltip: 'بيانات المحل', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopFormScreen(store: s)))),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: JmSegment(
            items: ['الزبائن والديون', 'المنتجات', newOrders > 0 ? 'الطلبات ($newOrders)' : 'الطلبات'],
            index: tab,
            onChanged: (i) => setState(() => tab = i),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (tab) {
            0 => _DebtsTab(store: s),
            1 => _ProductsTab(store: s),
            _ => Theme(
                data: light,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(color: DepoColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  clipBehavior: Clip.antiAlias,
                  child: StoreOrdersTab(store: s),
                ),
              ),
          },
        ),
      ]),
    );
  }
}

// ======================= الزبائن والديون =======================
enum _DFilter { all, overdue, settled }

class _DebtsTab extends StatefulWidget {
  final Store store;
  const _DebtsTab({required this.store});

  @override
  State<_DebtsTab> createState() => _DebtsTabState();
}

class _DebtsTabState extends State<_DebtsTab> {
  _DFilter f = _DFilter.all;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final sum = app.shopSummary(s.id);
    final all = app.debtorsOf(s.id);
    var list = all.where((d) => q.isEmpty || d.name.contains(q) || d.phone.contains(q)).toList();
    final sums = {for (final d in all) d.id: app.summaryOf(d.id)};
    if (f == _DFilter.overdue) list = list.where((d) => sums[d.id]!.overdue > 0).toList();
    if (f == _DFilter.settled) list = list.where((d) => sums[d.id]!.remaining == 0 && sums[d.id]!.ordered > 0).toList();
    list.sort((a, b) => sums[b.id]!.remaining.compareTo(sums[a.id]!.remaining));
    final overdueCount = all.where((d) => sums[d.id]!.overdue > 0).length;
    final withDebt = all.where((d) => sums[d.id]!.remaining > 0).length;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      JmAmountCard(
        label: 'إجمالي المتبقي على الزبائن',
        amount: iqd(sum.remaining),
        sub: withDebt == 0 ? 'لا توجد ديون مسجلة بعد' : 'على $withDebt ${withDebt == 1 ? 'زبون' : 'زبائن'}',
      ),
      Row(children: [
        Expanded(child: JmStat(label: 'المحصّل', value: iqd(sum.paid), sub: 'من أصل ${iqd(sum.ordered)}', up: true)),
        const SizedBox(width: 10),
        Expanded(child: JmStat(label: 'متأخر', value: iqd(sum.overdue), sub: overdueCount == 0 ? 'لا يوجد' : '$overdueCount ${overdueCount == 1 ? 'زبون' : 'زبائن'}', up: false)),
      ]),
      Row(children: [
        Expanded(
          child: JmButton(
            label: 'طلب جديد',
            icon: Icons.arrow_downward,
            color: Jm.red,
            fg: Colors.white,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtOrderScreen(store: s))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JmButton(
            label: 'تسجيل دفعة',
            icon: Icons.arrow_upward,
            color: Jm.green,
            fg: Colors.white,
            onTap: () => pickDebtorThen(context, s, (d) => recordPayment(context, d)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      JmCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OverdueReport(store: s))),
        child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: Jm.red.withValues(alpha: 0.2), child: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: DepoColors.danger)),
          const SizedBox(width: 10),
          const Expanded(child: Text('تقرير الديون المتأخرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          if (overdueCount > 0) Badge2('$overdueCount', bg: Jm.red, fg: Colors.white),
          const Icon(Icons.chevron_left, color: Jm.sub),
        ]),
      ),
      JmSegment(items: const ['الكل', 'المتأخرة', 'المسددة'], index: f.index, onChanged: (i) => setState(() => f = _DFilter.values[i])),
      const SizedBox(height: 10),
      TextField(style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'ابحث باسم الزبون أو رقمه'), onChanged: (v) => setState(() => q = v.trim())),
      const SizedBox(height: 12),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            all.isEmpty ? 'ابدأ بتسجيل أول طلب من الزر الأحمر أعلاه' : 'ماكو زبائن بهذا البحث',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Jm.sub),
          ),
        )
      else
        for (final d in list) _DebtorTile(d: d, sum: sums[d.id]!),
    ]);
  }
}

class _DebtorTile extends StatelessWidget {
  final Debtor d;
  final DebtSummary sum;
  const _DebtorTile({required this.d, required this.sum});

  @override
  Widget build(BuildContext context) {
    final late = sum.overdue > 0;
    return JmCard(
      border: late ? Jm.red.withValues(alpha: 0.6) : null,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id))),
      child: Row(children: [
        JmAvatar(letter: d.name.characters.first, size: 44, color: late ? DepoColors.danger : Jm.yellow),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: sum.ordered == 0 ? 0 : sum.paid / sum.ordered, minHeight: 5, backgroundColor: Jm.red.withValues(alpha: 0.5), color: DepoColors.success),
            ),
            const SizedBox(height: 3),
            Text(
              late ? 'متأخر ${iqd(sum.overdue)}' : (sum.nextDue > 0 ? 'يستحق ${dateLabel(sum.nextDue)}' : 'مسدّد ${sum.paidPercent}%'),
              style: TextStyle(fontSize: 11, color: late ? DepoColors.danger : Jm.sub, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(iqd(sum.remaining), style: TextStyle(fontWeight: FontWeight.w900, color: sum.remaining > 0 ? DepoColors.danger : DepoColors.success)),
          const Text('المتبقي', style: TextStyle(fontSize: 11, color: Jm.sub)),
        ]),
      ]),
    );
  }
}

/// تقرير الديون المتأخرة
class OverdueReport extends StatelessWidget {
  final Store store;
  const OverdueReport({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.debtorsOf(store.id).where((d) => app.summaryOf(d.id).overdue > 0).toList()
          ..sort((a, b) => app.summaryOf(b.id).overdue.compareTo(app.summaryOf(a.id).overdue));
        final total = list.fold(0, (s, d) => s + app.summaryOf(d.id).overdue);
        final base = list.fold(0, (s, d) => s + app.summaryOf(d.id).remaining);
        final now = DateTime.now();
        return JmScaffold(
          title: 'الديون المتأخرة',
          actions: [Text('${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Jm.sub))],
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            JmAmountCard(
              label: 'إجمالي المتأخر',
              amount: iqd(total),
              sub: list.isEmpty ? 'لا توجد ديون متأخرة' : '${list.length} ${list.length == 1 ? 'زبون' : 'زبائن'} • من أصل متبقٍ ${iqd(base)}',
            ),
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('كل الزبائن ملتزمون بمواعيدهم', textAlign: TextAlign.center, style: TextStyle(color: Jm.sub))),
            for (final d in list)
              JmCard(
                border: Jm.red.withValues(alpha: 0.5),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('متأخر من ${dateLabel(app.summaryOf(d.id).oldestOverdue)} • الباقي ${iqd(app.summaryOf(d.id).remaining)}', style: const TextStyle(fontSize: 12, color: Jm.sub)),
                    ]),
                  ),
                  Text(iqd(app.summaryOf(d.id).overdue), style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.danger)),
                  IconButton(tooltip: 'إرسال تذكير', onPressed: () => sendDebtReminder(context, d), icon: const Icon(Icons.notifications_active_outlined, color: Jm.cyan)),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

// ======================= المنتجات =======================
class _ProductsTab extends StatelessWidget {
  final Store store;
  const _ProductsTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.offersOf(store.id, onlyVisible: false);
    final groups = <String, List<Offer>>{};
    for (final o in list) {
      groups.putIfAbsent(o.category.isEmpty ? 'أخرى' : o.category, () => []).add(o);
    }
    final hasPromo = store.promoImageId.isNotEmpty || store.promoText.isNotEmpty;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
      Row(children: [
        const Expanded(child: Text('العروض الخاصة', style: TextStyle(fontWeight: FontWeight.w900))),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: DepoColors.success, backgroundColor: DepoColors.successBg, shape: const StadiumBorder()),
          onPressed: () => promoSheet(context, store),
          child: Text(hasPromo ? 'تعديل البنر' : '+ بنر عرض', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]),
      const Text('أضف بنراً لعرض خاص يظهر في أعلى صفحة محلك لكل الزبائن.', style: TextStyle(fontSize: 12, color: Jm.sub)),
      const SizedBox(height: 10),
      if (hasPromo) PromoBanner(store: store, onTap: () => promoSheet(context, store)),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          width: 150,
          child: JmButton(label: 'إضافة منتج', height: 44, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditor(store: store)))),
        ),
      ),
      const SizedBox(height: 6),
      const Text('منتجاتك تظهر للجميع في الأسواق، ويطلبها الزبون بمراسلتك مباشرة.', style: TextStyle(fontSize: 12, color: Jm.sub)),
      const SizedBox(height: 14),
      if (list.isEmpty)
        JmEmpty(icon: Icons.storefront_outlined, title: 'لا توجد منتجات', text: 'أضف منتجاتك واختر صنف كل منتج', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditor(store: store))))
      else ...[
        const Text('الأصناف', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 0,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final g in groups.entries)
              JmCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CategoryProducts(store: store, category: g.key))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircleAvatar(radius: 22, backgroundColor: Jm.green, child: Icon(catByName(marketCats, g.key)?.icon ?? Icons.shopping_basket_outlined, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(g.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${g.value.length} منتج', style: const TextStyle(fontSize: 12, color: Jm.sub)),
                ]),
              ),
          ],
        ),
      ],
    ]);
  }
}

class PromoBanner extends StatelessWidget {
  final Store store;
  final VoidCallback? onTap;
  const PromoBanner({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    return JmCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 120,
        child: Stack(fit: StackFit.expand, children: [
          if (store.promoImageId.isNotEmpty)
            AppImage(imageId: store.promoImageId, height: 120, fallback: const SizedBox())
          else
            Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Jm.green, Color(0xFF0B3F2C)]))),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99000000)]))),
          Positioned(
            right: 12,
            bottom: 10,
            left: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Jm.red, borderRadius: BorderRadius.circular(10)),
                child: const Text('عرض خاص', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              if (store.promoText.isNotEmpty) Text(store.promoText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> promoSheet(BuildContext context, Store store) async {
  final text = TextEditingController(text: store.promoText);
  var img = store.promoImageId;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Jm.bgMid,
    builder: (c) => Theme(
      data: jmTheme(context),
      child: StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('بنر العرض الخاص', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Jm.text)),
            const SizedBox(height: 12),
            JmCard(
              dashed: true,
              padding: EdgeInsets.zero,
              onTap: () async {
                final id = await pickAndUpload(c, owner: store.id);
                if (id != null) set(() => img = id);
              },
              child: SizedBox(
                height: 120,
                child: img.isEmpty
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate_outlined, color: Jm.cyan), Text('صورة البنر', style: TextStyle(color: Jm.sub))]))
                    : AppImage(imageId: img, height: 120, fallback: const SizedBox()),
              ),
            ),
            TextField(controller: text, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'نص العرض (مثلاً: خصم 20% على الزيوت)')),
            const SizedBox(height: 14),
            JmButton(
              label: 'حفظ',
              onTap: () {
                app.setShopPromo(store, imageId: img, text: text.text);
                Navigator.pop(c);
              },
            ),
            if (store.promoImageId.isNotEmpty || store.promoText.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  app.setShopPromo(store, imageId: '', text: '');
                  Navigator.pop(c);
                },
                child: const Text('حذف البنر', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
}

class _CategoryProducts extends StatelessWidget {
  final Store store;
  final String category;
  const _CategoryProducts({required this.store, required this.category});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.offersOf(store.id, onlyVisible: false).where((o) => (o.category.isEmpty ? 'أخرى' : o.category) == category).toList();
        return JmScaffold(
          title: category,
          actions: [JmCircleBtn(icon: Icons.add, tooltip: 'إضافة منتج', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditor(store: store, category: category))))],
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('ماكو منتجات بهذا الصنف', textAlign: TextAlign.center, style: TextStyle(color: Jm.sub))),
            for (final o in list)
              JmCard(
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductEditor(store: store, edit: o))),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 60, height: 60, child: OfferImage(offer: o, height: 60))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.title, style: TextStyle(fontWeight: FontWeight.w900, color: o.active ? Jm.text : Jm.faint)),
                      Text(iqd(o.price), style: const TextStyle(fontWeight: FontWeight.w900, color: Jm.cyan)),
                      Text(o.active ? 'متوفر للطلب' : 'غير متوفر', style: TextStyle(fontSize: 11, color: o.active ? DepoColors.success : DepoColors.danger)),
                    ]),
                  ),
                  const Icon(Icons.chevron_left, color: Jm.sub),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

/// منتج جديد / تعديل منتج
class ProductEditor extends StatefulWidget {
  final Store store;
  final Offer? edit;
  final String category;
  const ProductEditor({super.key, required this.store, this.edit, this.category = ''});

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late final name = TextEditingController(text: widget.edit?.title ?? '');
  late final price = TextEditingController(text: widget.edit == null ? '' : '${widget.edit!.price}');
  late final customCat = TextEditingController();
  late final desc = TextEditingController(text: widget.edit?.description ?? '');
  late String cat = widget.edit?.category ?? widget.category;
  late bool available = widget.edit?.active ?? true;
  late String imageId = widget.edit?.imageId ?? '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (cat.isNotEmpty && !marketCats.any((c) => c.name == cat)) customCat.text = cat;
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    customCat.dispose();
    desc.dispose();
    super.dispose();
  }

  void _save() {
    final p = parseInt(price.text) ?? 0;
    if (name.text.trim().isEmpty) return jmToast(context, 'اكتب اسم المنتج');
    if (p <= 0) return jmToast(context, 'اكتب السعر');
    final c = customCat.text.trim().isNotEmpty ? customCat.text.trim() : cat;
    final e = widget.edit;
    if (e == null) {
      app.addShopProduct(widget.store, name: name.text, price: p, imageId: imageId, description: desc.text, category: c, available: available);
    } else {
      app.updateShopProductFull(e, name: name.text, price: p, category: c, description: desc.text, available: available, imageId: imageId);
    }
    Navigator.pop(context);
    jmToast(context, 'تم الحفظ');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.edit;
    return JmScaffold(
      title: e == null ? 'منتج جديد' : 'تعديل المنتج',
      actions: [
        if (e != null)
          JmCircleBtn(
            icon: Icons.delete_outline,
            tooltip: 'حذف',
            onTap: () {
              app.deleteShopProduct(e);
              Navigator.pop(context);
              jmToast(context, 'انحذف المنتج');
            },
          ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final id = await pickAndUpload(context, owner: widget.store.id);
                    if (mounted) setState(() => busy = false);
                    if (id != null && mounted) setState(() => imageId = id);
                  },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Jm.line), color: Colors.white),
              clipBehavior: Clip.antiAlias,
              child: imageId.isNotEmpty
                  ? AppImage(imageId: imageId, height: 88, width: 88, fallback: const SizedBox())
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(busy ? Icons.hourglass_top : Icons.add, color: Jm.sub),
                      const Text('صورة', style: TextStyle(fontSize: 12, color: Jm.sub)),
                    ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: name, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'اسم المنتج'))),
        ]),
        const SizedBox(height: 18),
        TextField(
          controller: price,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Jm.text),
          decoration: const InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(fontSize: 34, color: Jm.faint),
            helperText: 'د.ع',
            helperStyle: TextStyle(color: Jm.sub),
            filled: false,
            border: UnderlineInputBorder(borderSide: BorderSide(color: Jm.sub)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Jm.sub)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Jm.cyan, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('الصنف', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in marketCats)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                cat = c.name;
                customCat.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cat == c.name && customCat.text.isEmpty ? DepoColors.dark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cat == c.name && customCat.text.isEmpty ? DepoColors.dark : Jm.line),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cat == c.name && customCat.text.isEmpty ? Colors.white : Jm.text)),
                  const SizedBox(width: 4),
                  Icon(c.icon, size: 15, color: cat == c.name && customCat.text.isEmpty ? Colors.white : Jm.text),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(controller: customCat, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'أو اكتب صنفاً جديداً'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        TextField(controller: desc, maxLines: 3, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'وصف قصير (اختياري)')),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(value: available, onChanged: (v) => setState(() => available = v ?? true)),
          const Text('متوفر للطلب', style: TextStyle(color: Jm.sub)),
        ]),
        const SizedBox(height: 16),
        JmButton(label: 'حفظ', onTap: _save),
      ]),
    );
  }
}
