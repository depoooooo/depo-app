import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../../widgets/offer_cards.dart';
import '../roles/partner.dart';
import 'debtor_screen.dart';

/// «محلي»: يفتح المتجر المجاني، أو يدخل عليه إذا موجود
class MyShopScreen extends StatelessWidget {
  const MyShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.myShop;
        if (s == null) return const _OpenShop();
        return _ShopHome(store: s);
      },
    );
  }
}

class _OpenShop extends StatefulWidget {
  const _OpenShop();

  @override
  State<_OpenShop> createState() => _OpenShopState();
}

class _OpenShopState extends State<_OpenShop> {
  final name = TextEditingController();
  final area = TextEditingController();
  final about = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    area.dispose();
    about.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('افتح محلك مجاناً')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [DepoColors.dark, Color(0xFF0A5F68)]), borderRadius: BorderRadius.circular(20)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('متجرك داخل ديبو — مجاناً', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('• اعرض منتجاتك وأسعارك حتى الزبون يعرفها قبل ما يجي\n• الزبون يطلب ويستلم من محلك أو توصّله بمندوبك\n• دفتر ديون: كل زبون بحسابه، وكل شهر بلون، ويشوف ديونه برمز خاص بيه',
                style: TextStyle(color: Colors.white, height: 1.8)),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المحل')),
        const SizedBox(height: 10),
        TextField(controller: area, decoration: const InputDecoration(labelText: 'الحي', hintText: 'مثلاً: النور، الزهور')),
        const SizedBox(height: 10),
        TextField(controller: about, maxLines: 2, decoration: const InputDecoration(labelText: 'شنو تبيع؟ وأوقات الدوام (اختياري)')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (name.text.trim().length < 2 || area.text.trim().length < 2) return toast(context, 'اكتب اسم المحل والحي');
            final s = app.openShop(name: name.text, area: area.text, about: about.text);
            toast(context, s == null ? 'ما انفتح المحل، جرّب مرة ثانية' : 'انفتح محلك! ابدي بإضافة زبائنك ومنتجاتك');
          },
          child: const Text('افتح المحل'),
        ),
      ]),
    );
  }
}

class _ShopHome extends StatelessWidget {
  final Store store;
  const _ShopHome({required this.store});

  @override
  Widget build(BuildContext context) {
    final newOrders = app.ordersOfStore(store.id).where((o) => o.status == OrderStatus.placed).length;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            InkWell(
              onTap: () async {
                final id = await pickAndUpload(context, owner: store.id);
                if (id != null) app.setStoreImage(store, id);
              },
              child: StoreAvatar(store: store, size: 36),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(store.name, overflow: TextOverflow.ellipsis)),
          ]),
          bottom: TabBar(
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w900),
            tabs: [const Tab(text: 'الزبائن والديون'), const Tab(text: 'المنتجات'), Tab(text: newOrders > 0 ? 'الطلبات ($newOrders)' : 'الطلبات')],
          ),
        ),
        body: TabBarView(children: [_DebtsTab(store: store), _ProductsTab(store: store), StoreOrdersTab(store: store)]),
      ),
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
    var list = app.debtorsOf(s.id).where((d) => q.isEmpty || d.name.contains(q) || d.phone.contains(q)).toList();
    final sums = {for (final d in list) d.id: app.summaryOf(d.id)};
    if (f == _DFilter.overdue) list = list.where((d) => sums[d.id]!.overdue > 0).toList();
    if (f == _DFilter.settled) list = list.where((d) => sums[d.id]!.remaining == 0 && sums[d.id]!.ordered > 0).toList();
    list.sort((a, b) => sums[b.id]!.remaining.compareTo(sums[a.id]!.remaining));
    final overdueCount = app.debtorsOf(s.id).where((d) => app.summaryOf(d.id).overdue > 0).length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      DebtSummaryCard(title: 'إجمالي المتبقي على الزبائن', remaining: sum.remaining, paid: sum.paid, ordered: sum.ordered, overdue: sum.overdue),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: DepoColors.danger),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtOrderScreen(store: s))),
            icon: const Icon(Icons.south_rounded),
            label: const Text('طلب جديد'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: DepoColors.success),
            onPressed: () => pickDebtorThen(context, s, (d) => recordPayment(context, d)),
            icon: const Icon(Icons.north_rounded),
            label: const Text('تسجيل دفعة'),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _OverdueReport(store: s))),
        child: Row(children: [
          const Icon(Icons.picture_as_pdf_outlined, color: DepoColors.danger),
          const SizedBox(width: 10),
          const Expanded(child: Text('تقرير الديون المتأخرة', style: TextStyle(fontWeight: FontWeight.w900))),
          if (overdueCount > 0) Badge2('$overdueCount', bg: DepoColors.danger, fg: Colors.white),
          const Icon(Icons.chevron_left),
        ]),
      ),
      Row(children: [
        for (final x in _DFilter.values) ...[
          Expanded(
            child: ChoiceChip(
              showCheckmark: false,
              label: SizedBox(width: double.infinity, child: Text(['الكل', 'المتأخرة', 'المسددة'][x.index], textAlign: TextAlign.center)),
              selected: f == x,
              onSelected: (_) => setState(() => f = x),
            ),
          ),
          if (x != _DFilter.settled) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث باسم الزبون أو رقمه', isDense: true), onChanged: (v) => setState(() => q = v.trim())),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        onPressed: () async {
          final d = await addDebtorDialog(context, s);
          if (d != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id)));
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('زبون جديد'),
      ),
      const SizedBox(height: 10),
      if (list.isEmpty)
        const EmptyState(icon: Icons.groups_outlined, text: 'ماكو زبائن هنا. أضف زبون أو سجّل أول طلب.')
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
    return AppCard(
      borderColor: late ? DepoColors.danger : null,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id))),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: late ? const Color(0xFFFDECED) : DepoColors.soft,
          child: Text(d.name.characters.first, style: TextStyle(fontWeight: FontWeight.w900, color: late ? DepoColors.danger : DepoColors.dark)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: sum.ordered == 0 ? 0 : sum.paid / sum.ordered, minHeight: 5, backgroundColor: DepoColors.line, color: DepoColors.success),
            ),
            const SizedBox(height: 2),
            Text(
              late ? 'متأخر ${iqd(sum.overdue)}' : (sum.nextDue > 0 ? 'يستحق ${dateLabel(sum.nextDue)}' : 'مسدّد ${sum.paidPercent}%'),
              style: TextStyle(fontSize: 11, color: late ? DepoColors.danger : DepoColors.muted, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(iqd(sum.remaining), style: TextStyle(fontWeight: FontWeight.w900, color: sum.remaining > 0 ? DepoColors.danger : DepoColors.success)),
          const Text('المتبقي', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
        ]),
      ]),
    );
  }
}

/// تقرير الديون المتأخرة
class _OverdueReport extends StatelessWidget {
  final Store store;
  const _OverdueReport({required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.debtorsOf(store.id).where((d) => app.summaryOf(d.id).overdue > 0).toList()
          ..sort((a, b) => app.summaryOf(b.id).overdue.compareTo(app.summaryOf(a.id).overdue));
        final total = list.fold(0, (s, d) => s + app.summaryOf(d.id).overdue);
        return Scaffold(
          appBar: AppBar(title: const Text('الديون المتأخرة')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            DebtSummaryCard(title: 'مجموع المتأخر', remaining: total, paid: 0, ordered: 0),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyState(icon: Icons.verified_outlined, text: 'كل الزبائن ملتزمين بمواعيدهم 👌'),
            for (final d in list)
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('متأخر من ${dateLabel(app.summaryOf(d.id).oldestOverdue)} • الباقي الكلي ${iqd(app.summaryOf(d.id).remaining)}',
                          style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                    ]),
                  ),
                  Text(iqd(app.summaryOf(d.id).overdue), style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.danger)),
                  IconButton(
                    tooltip: 'تذكير بالواتساب',
                    onPressed: () => sendDebtReminder(context, d),
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF1FA855)),
                  ),
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
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.icon(onPressed: () => productDialog(context, store), icon: const Icon(Icons.add), label: const Text('أضف منتج')),
      const SizedBox(height: 6),
      const Text('منتجاتك تطلع بصفحة محلك داخل «الأسواق»، حتى الزبون يعرف الأسعار قبل ما يجي.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      const SizedBox(height: 10),
      if (list.isEmpty) const EmptyState(icon: Icons.inventory_2_outlined, text: 'بعدك ما ضفت منتجات'),
      for (final o in list)
        AppCard(
          child: Row(children: [
            InkWell(
              onTap: () async {
                final id = await pickAndUpload(context, owner: store.id);
                if (id != null) app.setOfferImage(o, id);
              },
              child: SizedBox(width: 56, height: 56, child: OfferImage(offer: o, height: 56, radius: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                PriceTag(price: o.price, original: o.originalPrice, size: 14),
                if (o.expiresLabel.isNotEmpty) Text(o.expiresLabel, style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
              ]),
            ),
            Switch(value: o.active, onChanged: (v) => app.setOfferActive(o, v)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') productDialog(context, store, edit: o);
                if (v == 'del') app.deleteShopProduct(o);
              },
              itemBuilder: (c) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'del', child: Text('حذف'))],
            ),
          ]),
        ),
    ]);
  }
}

Future<void> productDialog(BuildContext context, Store store, {Offer? edit}) async {
  final name = TextEditingController(text: edit?.title ?? '');
  final price = TextEditingController(text: edit == null ? '' : '${edit.price}');
  final old = TextEditingController(text: edit == null || edit.originalPrice <= edit.price ? '' : '${edit.originalPrice}');
  final cat = TextEditingController(text: edit?.expiresLabel ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(edit == null ? 'منتج جديد' : 'تعديل المنتج'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المنتج')),
          const SizedBox(height: 10),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (د.ع)')),
          const SizedBox(height: 10),
          TextField(controller: old, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر قبل العرض (اختياري)')),
          if (edit == null) ...[
            const SizedBox(height: 10),
            TextField(controller: cat, decoration: const InputDecoration(labelText: 'الصنف (اختياري)', hintText: 'مثلاً: مشروبات، ألبان')),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
      ],
    ),
  );
  final p = parseInt(price.text) ?? 0;
  final op = parseInt(old.text);
  if (ok == true && name.text.trim().isNotEmpty && p > 0) {
    if (edit == null) {
      app.addShopProduct(store, name: name.text, price: p, oldPrice: op, category: cat.text);
    } else {
      app.updateShopProduct(edit, name: name.text, price: p, oldPrice: op);
    }
  } else if (ok == true && context.mounted) {
    toast(context, 'اكتب الاسم والسعر');
  }
}
