import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';

/// تبويب «الحسابات»: أرباح ديبو، كشوفات المطاعم والتجار والمندوبين، والتسوية الشهرية
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  String? month;

  @override
  Widget build(BuildContext context) {
    final months = app.financeMonths;
    final m = month != null && months.contains(month) ? month! : months.first;
    final r = app.monthReport(m);
    final stores = app.storeStatements(m);
    final couriers = app.courierStatements(m);
    final current = m == monthKey(DateTime.now());
    final cash = app.couriersCash.values.fold(0, (s, v) => s + v);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
      SizedBox(
        height: 42,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final x in months)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(monthLabel(x)),
                selected: x == m,
                showCheckmark: false,
                onSelected: (_) => setState(() => month = x),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [DepoColors.ink, Color(0xFF0A5F68)]), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('صافي ربح ديبو · ${monthLabel(m)}', style: const TextStyle(color: Colors.white70)),
          Text(iqd(r.profit), style: TextStyle(color: r.profit >= 0 ? Colors.white : const Color(0xFFFF9C9C), fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('العمولات ${iqd(r.commission)} + رسوم التوصيل ${iqd(r.deliveryFees)} − أجور المندوبين ${iqd(r.courierPay)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (current) const Padding(padding: EdgeInsets.only(top: 6), child: Text('الشهر بعده ما خلص — الأرقام تتحدث مع كل طلب', style: TextStyle(color: Colors.white54, fontSize: 11))),
        ]),
      ),
      const SizedBox(height: 12),
      StatGrid([
        StatTile('الطلبات المُسلّمة', '${r.orders}'),
        StatTile('المبيعات', iqd(r.sales)),
        StatTile('العمولات', iqd(r.commission)),
        StatTile('رسوم التوصيل المحصّلة', iqd(r.deliveryFees)),
        StatTile('أجور المندوبين', iqd(r.courierPay)),
        StatTile('كلفة التوصيل المجاني', iqd(r.freeDeliveryCost)),
      ]),
      const SectionTitle('بانتظار التسوية'),
      AppCard(
        child: Column(children: [
          _row('ندفع للمطاعم والتجار', iqd(r.payToStores), DepoColors.danger),
          _row('نستلم من المطاعم والتجار', iqd(r.collectFromStores), DepoColors.success),
          _row('ندفع أجور المندوبين', iqd(r.payToCouriers), DepoColors.danger),
          const Divider(),
          _row('النقد بيد المندوبين هسه (كل الشهور)', iqd(cash), DepoColors.ink),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('استلام النقد اليومي من المندوبين من تبويب «الطلبات».', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
          ),
        ]),
      ),
      SectionTitle('المطاعم والتجار (${stores.length})'),
      if (stores.isEmpty) const Text('ماكو طلبات مُسلّمة بهذا الشهر', style: TextStyle(color: DepoColors.muted)),
      for (final st in stores)
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreStatementScreen(storeId: st.store.id, month: m))),
          child: Row(children: [
            StoreAvatarMini(name: st.store.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.store.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${st.orders.length} طلب • مبيعات ${iqd(st.sales)} • عمولة ${iqd(st.commission)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              ]),
            ),
            _netBadge(st.net, st.settled),
          ]),
        ),
      SectionTitle('المندوبين (${couriers.length})'),
      if (couriers.isEmpty) const Text('ماكو توصيلات بهذا الشهر', style: TextStyle(color: DepoColors.muted)),
      for (final c in couriers)
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourierStatementScreen(phone: c.phone, month: m))),
          child: Row(children: [
            const CircleAvatar(backgroundColor: DepoColors.soft, child: Icon(Icons.delivery_dining, color: DepoColors.dark)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.userByPhone(c.phone)?.name ?? c.phone, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${c.orders.length} توصيلة • ${c.km.toStringAsFixed(1)} كم', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(iqd(c.earned), style: const TextStyle(fontWeight: FontWeight.w900)),
              Badge2(c.settled ? 'مسدّد' : 'بانتظار', bg: c.settled ? DepoColors.successBg : const Color(0xFFFFF6E5), fg: c.settled ? DepoColors.success : const Color(0xFF8A5A00)),
            ]),
          ]),
        ),
      const SectionTitle('سجل التسويات'),
      if (app.settlements.isEmpty) const Text('بعد ما صارت تسويات', style: TextStyle(color: DepoColors.muted)),
      for (final s in app.settlements.take(30))
        AppCard(
          child: Row(children: [
            Icon(s.kind == 'store' ? Icons.storefront_outlined : Icons.delivery_dining, color: DepoColors.dark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.kind == 'store' ? (app.storeById(s.target)?.name ?? s.target) : (app.userByPhone(s.target)?.name ?? s.target), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${monthLabel(s.month)} • ${dateLabel(s.at)} • ${s.by}${s.note.isEmpty ? '' : ' • ${s.note}'}', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
              ]),
            ),
            Text(s.amount >= 0 ? 'دفعنا ${iqd(s.amount)}' : 'استلمنا ${iqd(-s.amount)}',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: s.amount >= 0 ? DepoColors.danger : DepoColors.success)),
            if (app.me?.role == Role.admin)
              IconButton(
                tooltip: 'إلغاء التسوية',
                icon: const Icon(Icons.undo, size: 18),
                onPressed: () async {
                  if (await confirmDialog(context, 'تلغي هذه التسوية؟', 'ترجع بانتظار التسوية. استخدمها بس إذا انسجلت بالغلط.')) app.undoSettlement(s);
                },
              ),
          ]),
        ),
    ]);
  }
}

Widget _row(String label, String value, Color color, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600))),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
      ]),
    );

Widget _netBadge(int net, bool settled) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(net >= 0 ? 'له ${iqd(net)}' : 'عليه ${iqd(-net)}', style: TextStyle(fontWeight: FontWeight.w900, color: net >= 0 ? DepoColors.danger : DepoColors.success)),
      Badge2(settled ? 'مسدّد' : 'بانتظار', bg: settled ? DepoColors.successBg : const Color(0xFFFFF6E5), fg: settled ? DepoColors.success : const Color(0xFF8A5A00)),
    ]);

class StoreAvatarMini extends StatelessWidget {
  final String name;
  const StoreAvatarMini({super.key, required this.name});
  @override
  Widget build(BuildContext context) =>
      CircleAvatar(backgroundColor: DepoColors.soft, child: Text(name.isEmpty ? '؟' : name.characters.first, style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.dark)));
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'إي'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// سطر طلب بالكشف
class _OrderLineTile extends StatelessWidget {
  final Order o;
  final List<Widget> extra;
  final Widget? trailing;
  const _OrderLineTile({required this.o, this.extra = const [], this.trailing});

  @override
  Widget build(BuildContext context) {
    final how = o.pickup ? 'استلام ذاتي' : (app.selfDelivered(o) ? 'مندوب المحل' : 'مندوب ديبو');
    return AppCard(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${o.id} • ${dateLabel(o.deliveredAt > 0 ? o.deliveredAt : o.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('$how • بضاعة ${iqd(o.itemsTotal)} • توصيل ${iqd(o.deliveryFee)} • عمولة ${iqd(o.commission)}', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
            ...extra,
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// كشف مطعم/تاجر لشهر (للمدير والمالية، وللمحل نفسه بدون زر التسوية)
class StoreStatementScreen extends StatelessWidget {
  final String storeId;
  final String month;
  const StoreStatementScreen({super.key, required this.storeId, required this.month});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.storeById(storeId);
        if (s == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.store, text: 'المحل مو موجود'));
        final st = app.storeStatement(s, month);
        final current = month == monthKey(DateTime.now());
        return Scaffold(
          appBar: AppBar(title: Text('${s.name} · ${monthLabel(month)}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            StatementSummary(st: st),
            const SizedBox(height: 12),
            if (app.canFinance && !st.settled && st.orders.isNotEmpty)
              FilledButton.icon(
                onPressed: () async {
                  final body = '${st.net >= 0 ? 'تأكد إنك سلّمت ${iqd(st.net)} للمحل' : 'تأكد إنك استلمت ${iqd(-st.net)} من المحل'}.'
                      '${current ? '\n\nانتبه: الشهر بعده ما خلص، والطلبات الجاية بهذا الشهر تبقى بدون تسوية.' : ''}';
                  if (await confirmDialog(context, 'تسوية ${monthLabel(month)}؟', body, ok: 'تمت التسوية')) app.settleStoreMonth(st);
                },
                icon: const Icon(Icons.task_alt),
                label: Text(st.net >= 0 ? 'سلّمنا المحل ${iqd(st.net)}' : 'استلمنا من المحل ${iqd(-st.net)}'),
              ),
            SectionTitle('الطلبات (${st.orders.length})'),
            for (final o in st.orders) _OrderLineTile(o: o),
          ]),
        );
      },
    );
  }
}

/// ملخص كشف المحل (يستخدمه المدير والمحل)
class StatementSummary extends StatelessWidget {
  final StoreStatement st;
  const StatementSummary({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(children: [
        _row('المبيعات', iqd(st.sales), DepoColors.ink),
        _row('عمولة ديبو', '− ${iqd(st.commission)}', DepoColors.danger),
        _row('حصّلها مندوب ديبو (بضاعة)', iqd(st.collectedByDepo), DepoColors.ink),
        _row('حصّلها المحل بنفسه', iqd(st.collectedByStore), DepoColors.ink),
        const Divider(),
        _row(st.net >= 0 ? 'ديبو تدفع للمحل' : 'المحل يدفع لديبو', iqd(st.net.abs()), st.net >= 0 ? DepoColors.dark : DepoColors.danger, bold: true),
        const SizedBox(height: 6),
        Row(children: [
          Icon(st.settled ? Icons.verified : Icons.schedule, size: 16, color: st.settled ? DepoColors.success : DepoColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              st.settled ? 'تمت التسوية ${dateLabel(st.settlement!.at)}' : 'التسوية شهرية: بعد نهاية الشهر',
              style: TextStyle(fontSize: 12, color: st.settled ? DepoColors.success : DepoColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// كشف مندوب لشهر: كل توصيلة بمسافتها وأجرتها
class CourierStatementScreen extends StatelessWidget {
  final String phone;
  final String month;
  const CourierStatementScreen({super.key, required this.phone, required this.month});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final st = app.courierStatement(phone, month);
        final canEdit = !st.settled && (app.canFinance || app.canAny([Perm.operations]));
        final s = app.settings;
        return Scaffold(
          appBar: AppBar(title: Text('${app.userByPhone(phone)?.name ?? phone} · ${monthLabel(month)}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Column(children: [
                _row('عدد التوصيلات', '${st.orders.length}', DepoColors.ink),
                _row('المسافة الكلية', '${st.km.toStringAsFixed(1)} كم', DepoColors.ink),
                const Divider(),
                _row('الأجور المستحقة', iqd(st.earned), DepoColors.dark, bold: true),
                _row('النقد بيده هسه', iqd(app.cashOf(phone)), DepoColors.danger),
                const SizedBox(height: 4),
                Text('الأجرة = ${iqd(s.courierBasePay)} + ${iqd(s.courierPerKm)} لكل كم، وأقل شي ${iqd(s.courierMinPay)}',
                    style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
                if (st.settled) Text('تمت التسوية ${dateLabel(st.settlement!.at)}', style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 10),
            if (app.canFinance && !st.settled && st.orders.isNotEmpty)
              FilledButton.icon(
                onPressed: () async {
                  if (await confirmDialog(context, 'تسوية أجور ${monthLabel(month)}؟', 'تأكد إنك سلّمت المندوب ${iqd(st.earned)}.', ok: 'تمت التسوية')) app.settleCourierMonth(st);
                },
                icon: const Icon(Icons.task_alt),
                label: Text('سلّمنا المندوب ${iqd(st.earned)}'),
              ),
            SectionTitle('التوصيلات (${st.orders.length})'),
            if (canEdit) const Text('اضغط على المسافة حتى تعدّلها إذا كانت غلط', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
            for (final o in st.orders)
              _OrderLineTile(
                o: o,
                extra: [Text(app.storeById(o.storeId)?.name ?? '', style: const TextStyle(fontSize: 11, color: DepoColors.muted))],
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(iqd(o.courierPay), style: const TextStyle(fontWeight: FontWeight.w900)),
                  InkWell(
                    onTap: canEdit ? () => _editKm(context, o) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${o.distanceKm.toStringAsFixed(1)} كم${canEdit ? ' ✎' : ''}', style: const TextStyle(fontSize: 12, color: DepoColors.dark, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _editKm(BuildContext context, Order o) async {
    final km = await askKm(context, o.distanceKm, title: 'مسافة الطلب #${o.id}');
    if (km != null && !app.setOrderDistance(o, km) && context.mounted) toast(context, 'ما ينعدل (يمكن انسوّى الشهر)');
  }
}

/// يسأل عن المسافة بالكيلومتر
Future<double?> askKm(BuildContext context, double initial, {String title = 'المسافة'}) async {
  final ctl = TextEditingController(text: initial > 0 ? initial.toStringAsFixed(1) : '');
  final s = app.settings;
  final r = await showDialog<double>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final km = double.tryParse(ctl.text.replaceAll(',', '.').replaceAll('٫', '.')) ?? 0;
        return AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(suffixText: 'كم'),
              onChanged: (_) => set(() {}),
            ),
            const SizedBox(height: 8),
            Text('الأجرة: ${iqd(s.courierPayFor(km))}', style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.dark)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, km), child: const Text('حفظ')),
          ],
        );
      },
    ),
  );
  return r;
}
