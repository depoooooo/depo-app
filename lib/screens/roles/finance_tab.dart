import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';

/// تبويب «الحسابات»: أرباح ديبو، كشوفات المطاعم والتجار والمندوبين، النقد، والتسوية الشهرية
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  String? month;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final months = app.financeMonths;
        final m = month != null && months.contains(month) ? month! : months.first;
        final r = app.monthReport(m);
        final stores = app.storeStatements(m);
        final couriers = app.courierStatements(m);
        final current = app.isCurrentMonth(m);
        final cashPhones = {
          for (final o in app.orders) if (o.status == OrderStatus.delivered && o.courierPhone != null && app.paidCourier(o) && !o.walletMode) o.courierPhone!,
        }.toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
          SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final x in months)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(label: Text(monthLabel(x)), selected: x == m, showCheckmark: false, onSelected: (_) => setState(() => month = x)),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          // ---------- الربح ----------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [DepoColors.ink, Color(0xFF0A5F68)]), borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('صافي ربح ديبو · ${monthLabel(m)}', style: const TextStyle(color: Colors.white70)),
              Text(iqd(r.profit), style: TextStyle(color: r.profit >= 0 ? Colors.white : const Color(0xFFFF9C9C), fontSize: 30, fontWeight: FontWeight.w900)),
              Text('${r.orders.length} طلب مُسلّم', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (current) const Text('الشهر بعده ما خلص — الأرقام تتحدث مع كل طلب، والتسوية بعد نهايته', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(children: [
              const _Head('شلون انحسب الربح'),
              MoneyRow('عمولات المطاعم والتجار', r.commission, sign: '+'),
              if (r.markup > 0) MoneyRow('زيادة الأسعار (المخفية)', r.markup, sign: '+'),
              MoneyRow('رسوم التوصيل اللي دفعها الزبائن لمندوبي ديبو', r.deliveryFees, sign: '+'),
              MoneyRow('أجور المندوبين (حسب الكيلومتر)', r.courierPay, sign: '−', color: DepoColors.danger),
              const Divider(),
              MoneyRow('صافي ربح ديبو', r.profit, bold: true, color: r.profit >= 0 ? DepoColors.success : DepoColors.danger),
              if (r.freeDeliveryCost > 0) Note('منها ${iqd(r.freeDeliveryCost)} أجور لطلبات توصيلها مجاني للزبون (ديبو تحمّلتها).'),
            ]),
          ),
          // ---------- معادلة التوازن ----------
          AppCard(
            borderColor: r.imbalance == 0 ? DepoColors.success : DepoColors.danger,
            child: Column(children: [
              Row(children: [
                Icon(r.imbalance == 0 ? Icons.verified : Icons.error_outline, color: r.imbalance == 0 ? DepoColors.success : DepoColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(r.imbalance == 0 ? 'التدقيق: الحساب متوازن بالدينار' : 'التدقيق: فرق ${iqd(r.imbalance)} — راجع الطلبات', style: const TextStyle(fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 6),
              MoneyRow('كل اللي دفعه الزبائن (بضاعة + توصيل)', r.customersPaid),
              MoneyRow('= حصة المحلات (بسعرها − عمولة + توصيل مندوبهم)', r.storesShare),
              MoneyRow('+ أجور المندوبين', r.courierPay),
              MoneyRow('+ ربح ديبو', r.profit),
              MoneyRow('المجموع', r.storesShare + r.courierPay + r.profit, bold: true),
            ]),
          ),
          StatGrid([
            StatTile('المبيعات (بضاعة)', iqd(r.sales)),
            StatTile('العمولات', iqd(r.commission)),
            StatTile('رسوم توصيل ديبو', iqd(r.deliveryFees)),
            StatTile('أجور المندوبين', iqd(r.courierPay)),
          ]),
          if (r.orders.any((o) => o.kmNeedsReview))
            AppCard(
              color: const Color(0xFFFFF6E5),
              child: Row(children: [
                const Icon(Icons.rule, color: Color(0xFF8A5A00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${r.orders.where((o) => o.kmNeedsReview).length} توصيلة مسافتها تحتاج مراجعة (بدون GPS أو GPS مشكوك). افتح كشف المندوب وراجعها قبل التسوية.',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
            ),
          // ---------- بانتظار التسوية ----------
          SectionTitle('بانتظار التسوية · ${monthLabel(m)}'),
          AppCard(
            child: Column(children: [
              MoneyRow('باقي ندفعه للمطاعم والتجار', r.payToStores, color: DepoColors.danger),
              MoneyRow('باقي نستلمه من المطاعم والتجار', r.collectFromStores, color: DepoColors.success),
              MoneyRow('باقي ندفعه أجور مندوبين', r.payToCouriers, color: DepoColors.danger),
              if (current) const Note('التسوية تنفتح بعد ما يخلص الشهر.'),
            ]),
          ),
          // ---------- المحلات ----------
          SectionTitle('المطاعم والتجار (${stores.length})'),
          if (stores.isEmpty) const Note('ماكو طلبات مُسلّمة بهذا الشهر'),
          for (final st in stores)
            AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoreStatementScreen(storeId: st.store.id, month: m))),
              child: Row(children: [
                Initial(st.store.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.store.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${st.orders.length} طلب • مبيعات ${iqd(st.sales)} • عمولة ${iqd(st.commission)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(st.net >= 0 ? 'له ${iqd(st.net)}' : 'عليه ${iqd(-st.net)}', style: TextStyle(fontWeight: FontWeight.w900, color: st.net >= 0 ? DepoColors.danger : DepoColors.success)),
                  StatusBadge(st.balance),
                ]),
              ]),
            ),
          // ---------- المندوبين ----------
          SectionTitle('أجور المندوبين (${couriers.length})'),
          if (couriers.isEmpty) const Note('ماكو توصيلات بهذا الشهر'),
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
                    if (c.orders.any((o) => o.kmNeedsReview))
                      Text('${c.orders.where((o) => o.kmNeedsReview).length} تحتاج مراجعة', style: const TextStyle(fontSize: 11, color: Color(0xFF8A5A00), fontWeight: FontWeight.w800)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(iqd(c.earned), style: const TextStyle(fontWeight: FontWeight.w900)),
                  StatusBadge(c.balance),
                ]),
              ]),
            ),
          // ---------- رصيد المندوبين ----------
          SectionTitle('شحن رصيد المندوبين${app.topupRequests().isEmpty ? '' : ' (${app.topupRequests().length} بانتظار)'}'),
          const Note('المندوب يحوّل المبلغ بطريقة دفع ويطلب الشحن. تأكد إن الفلوس وصلت قبل «تأكيد».'),
          for (final r in app.topupRequests())
            AppCard(
              borderColor: DepoColors.accent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(app.userByPhone(r.target)?.name ?? r.target, style: const TextStyle(fontWeight: FontWeight.w900))),
                  Text(iqd(r.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ]),
                Note('${r.note} • ${dateTimeLabel(r.at)}'),
                if (app.canFinance)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: DepoColors.danger, side: const BorderSide(color: DepoColors.danger)),
                        onPressed: () async {
                          final err = await app.decideTopup(r, approve: false, reason: 'ما وصل المبلغ');
                          if (context.mounted) toast(context, err ?? 'انرفض الطلب');
                        },
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: () async {
                          if (!await confirmDialog(context, 'تأكد الشحن؟', 'وصلك ${iqd(r.amount)} من ${app.userByPhone(r.target)?.name ?? r.target}؟', ok: 'إي، وصل')) return;
                          final err = await app.decideTopup(r, approve: true);
                          if (context.mounted) toast(context, err ?? 'انضاف الرصيد');
                        },
                        child: const Text('تأكيد'),
                      ),
                    ),
                  ]),
              ]),
            ),
          for (final p in app.walletCouriers)
            AppCard(
              child: Row(children: [
                const CircleAvatar(backgroundColor: DepoColors.soft, child: Icon(Icons.account_balance_wallet_outlined, color: DepoColors.dark)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.userByPhone(p)?.name ?? p, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('شحن ${iqd(app.walletTopups(p))} − طلبات ${iqd(app.walletUsed(p))}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                  ]),
                ),
                Text(iqd(app.walletBalance(p)), style: TextStyle(fontWeight: FontWeight.w900, color: app.walletBalance(p) < app.settings.walletLowAlert ? DepoColors.danger : DepoColors.dark)),
              ]),
            ),
          // ---------- النقد ----------
          const SectionTitle('النقد بيد المندوبين (كل الشهور)'),
          const Note('المندوب يحصّل من الزبون البضاعة + التوصيل، ويسلّمها لديبو. الاستلام من تبويب «الطلبات» ← «استلمت».'),
          if (cashPhones.isEmpty) const Note('ماكو نقد'),
          for (final p in cashPhones) _CashCard(phone: p),
          // ---------- السجل ----------
          const SectionTitle('سجل التسويات والاستلامات'),
          if (app.settlements.isEmpty) const Note('بعد ما صارت تسويات'),
          for (final s in app.settlements.take(60)) SettlementTile(s: s),
        ]);
      },
    );
  }
}

class _CashCard extends StatelessWidget {
  final String phone;
  const _CashCard({required this.phone});

  @override
  Widget build(BuildContext context) {
    final collected = app.cashCollectedBy(phone);
    final handed = app.cashHandedBy(phone);
    final held = app.cashOf(phone);
    final ok = collected - handed == held;
    return AppCard(
      borderColor: ok ? null : DepoColors.danger,
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(app.userByPhone(phone)?.name ?? phone, style: const TextStyle(fontWeight: FontWeight.w900))),
          Text('بيده ${iqd(held)}', style: TextStyle(fontWeight: FontWeight.w900, color: held > 0 ? DepoColors.danger : DepoColors.success)),
        ]),
        MoneyRow('حصّل من الزبائن', collected),
        MoneyRow('سلّم لديبو', handed, sign: '−'),
        MoneyRow('الباقي بيده', collected - handed, bold: true),
        if (!ok) Note('تنبيه: سجل الاستلام (${iqd(collected - handed)}) ما يطابق الطلبات المعلّمة (${iqd(held)}). بلّغ الدعم الفني.', color: DepoColors.danger),
      ]),
    );
  }
}

// ======================= عناصر مشتركة =======================
class MoneyRow extends StatelessWidget {
  final String label;
  final int value;
  final String sign;
  final bool bold;
  final Color? color;
  const MoneyRow(this.label, this.value, {super.key, this.sign = '', this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w600))),
          const SizedBox(width: 8),
          Text('$sign${sign.isEmpty ? '' : ' '}${iqd(value)}', textDirection: TextDirection.rtl, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: FontWeight.w900, color: color ?? DepoColors.ink)),
        ]),
      );
}

class Note extends StatelessWidget {
  final String text;
  final Color? color;
  const Note(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Text(text, style: TextStyle(fontSize: 12, color: color ?? DepoColors.muted, height: 1.5))),
      );
}

class _Head extends StatelessWidget {
  final String text;
  const _Head(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.dark))),
      );
}

class Initial extends StatelessWidget {
  final String name;
  const Initial(this.name, {super.key});
  @override
  Widget build(BuildContext context) =>
      CircleAvatar(backgroundColor: DepoColors.soft, child: Text(name.isEmpty ? '؟' : name.characters.first, style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.dark)));
}

class StatusBadge extends StatelessWidget {
  final Balance b;
  const StatusBadge(this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final done = b.remaining == 0;
    final partial = !done && b.payments.isNotEmpty;
    return Badge2(
      b.status,
      bg: done ? DepoColors.successBg : (partial ? const Color(0xFFFDECED) : const Color(0xFFFFF6E5)),
      fg: done ? DepoColors.success : (partial ? DepoColors.danger : const Color(0xFF8A5A00)),
    );
  }
}

class SettlementTile extends StatelessWidget {
  final Settlement s;
  const SettlementTile({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final who = s.kind == 'store' ? (app.storeById(s.target)?.name ?? s.target) : (app.userByPhone(s.target)?.name ?? s.target);
    final what = switch (s.kind) {
      'store' => s.amount > 0 ? 'دفعنا للمحل' : 'استلمنا من المحل',
      'courier' => 'دفعنا أجور المندوب',
      'topup' => 'شحن رصيد المندوب',
      'topup_req' => 'طلب شحن رصيد (بانتظار)',
      'topup_rej' => 'طلب شحن مرفوض',
      _ => 'استلمنا نقد من المندوب (${s.orderIds.length} طلب)',
    };
    return AppCard(
      child: Row(children: [
        Icon(s.kind == 'store' ? Icons.storefront_outlined : (s.kind == 'cash' ? Icons.payments_outlined : Icons.delivery_dining), color: DepoColors.dark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$who • $what', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Text('${s.kind == 'cash' ? '' : 'عن ${monthLabel(s.month)} • '}${dateTimeLabel(s.at)} • بواسطة ${s.by}${s.note.isEmpty ? '' : '\n${s.note}'}',
                style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          ]),
        ),
        Text(iqd(s.amount.abs()), style: TextStyle(fontWeight: FontWeight.w900, color: s.kind.startsWith('topup') ? (s.kind == 'topup' ? DepoColors.success : DepoColors.muted) : (s.amount > 0 ? DepoColors.danger : DepoColors.success))),
        if (app.me?.role == Role.admin)
          IconButton(
            tooltip: 'إلغاء',
            icon: const Icon(Icons.undo, size: 18),
            onPressed: () async {
              final body = s.kind == 'cash'
                  ? 'الطلبات (${s.orderIds.length}) ترجع «بيد المندوب» والمبلغ ${iqd(s.amount.abs())} يرجع عليه.'
                  : 'المبلغ ${iqd(s.amount.abs())} يرجع «باقي» بالكشف. استخدمها بس إذا انسجلت بالغلط.';
              if (!await confirmDialog(context, 'تلغي هذا السجل؟', body)) return;
              final err = await app.undoSettlement(s);
              if (context.mounted) toast(context, err ?? 'انلغى السجل');
            },
          ),
      ]),
    );
  }
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

/// نافذة التسوية: المبلغ (افتراضياً كل الباقي) + ملاحظة، ويتأكد مرتين
Future<void> settleDialog(BuildContext context, {required String kind, required String target, required String month, required Balance b, required String whoName}) async {
  final rem = b.remaining;
  final amount = TextEditingController(text: '${rem.abs()}');
  final note = TextEditingController();
  final pay = rem > 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final a = parseInt(amount.text) ?? 0;
        final left = rem.abs() - a;
        return AlertDialog(
          title: Text(pay ? 'دفع لـ $whoName' : 'استلام من $whoName'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('عن ${monthLabel(month)}'),
              MoneyRow('المستحق', b.due.abs()),
              if (b.paid != 0) MoneyRow('انسوّى قبل', b.paid.abs(), sign: '−'),
              MoneyRow('الباقي', rem.abs(), bold: true),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                decoration: InputDecoration(labelText: pay ? 'المبلغ اللي سلّمته' : 'المبلغ اللي استلمته', suffixText: 'د.ع'),
                onChanged: (_) => set(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                a <= 0 ? 'اكتب المبلغ' : (left < 0 ? 'المبلغ أكثر من الباقي' : (left == 0 ? 'الحساب يصير مسدّد بالكامل ✓' : 'يبقى ${iqd(left)} (تسوية جزئية)')),
                style: TextStyle(fontWeight: FontWeight.w800, color: a <= 0 || left < 0 ? DepoColors.danger : DepoColors.success),
              ),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري): رقم الوصل، طريقة الدفع…')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: a <= 0 || left < 0 ? null : () => Navigator.pop(c, true),
              child: const Text('تسجيل'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  final a = parseInt(amount.text) ?? 0;
  final sure = await confirmDialog(context, 'متأكد؟', '${pay ? 'سلّمت' : 'استلمت'} ${iqd(a)} ${pay ? 'إلى' : 'من'} $whoName عن ${monthLabel(month)}.\nهذا ينسجل باسمك بسجل العمليات.', ok: 'إي، متأكد');
  if (!sure) return;
  final err = await app.addSettlement(kind: kind, target: target, month: month, amount: pay ? a : -a, remaining: rem, note: note.text);
  if (context.mounted) toast(context, err ?? 'انسجلت التسوية');
}

String _howCollected(Order o) => app.paidCourier(o) ? 'مندوب ديبو' : (o.pickup ? 'استلام ذاتي' : 'مندوب المحل');

// ======================= كشف المحل =======================
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
        final staff = app.canFinance;
        return Scaffold(
          appBar: AppBar(
            title: Text('${s.name} · ${monthLabel(month)}'),
            actions: [IconButton(tooltip: 'نسخ الكشف', onPressed: () => copyText(context, app.storeStatementText(st), done: 'انسخ الكشف'), icon: const Icon(Icons.copy_all_outlined))],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            StatementSummary(st: st),
            if (staff && st.balance.remaining != 0) ...[
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: app.isCurrentMonth(month)
                    ? null
                    : () => settleDialog(context, kind: 'store', target: s.id, month: month, b: st.balance, whoName: s.name),
                icon: const Icon(Icons.task_alt),
                label: Text(app.isCurrentMonth(month)
                    ? 'التسوية بعد نهاية الشهر'
                    : (st.balance.remaining > 0 ? 'تسجيل دفع للمحل (${iqd(st.balance.remaining)})' : 'تسجيل استلام من المحل (${iqd(-st.balance.remaining)})')),
              ),
            ],
            SectionTitle('الطلبات (${st.orders.length})'),
            const Note('لكل طلب: منو حصّل الفلوس، العمولة وشلون انحسبت، وأثره على الصافي.'),
            for (final o in st.orders) _StoreOrderTile(o: o),
          ]),
        );
      },
    );
  }
}

class _StoreOrderTile extends StatelessWidget {
  final Order o;
  const _StoreOrderTile({required this.o});

  @override
  Widget build(BuildContext context) {
    final depo = app.paidCourier(o);
    final effect = depo ? o.itemsBase - o.commission : -o.commission - o.markup;
    final staff = app.canFinance; // الزيادة المخفية تبين للمالية بس، مو للمحل
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('#${o.id} • ${dateTimeLabel(o.deliveredAt > 0 ? o.deliveredAt : o.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Badge2(_howCollected(o), bg: depo ? DepoColors.soft : const Color(0xFFFFF6E5), fg: depo ? DepoColors.dark : const Color(0xFF8A5A00)),
        ]),
        const SizedBox(height: 4),
        MoneyRow('البضاعة (بسعر المحل)', o.itemsBase),
        if (staff && o.markup > 0) MoneyRow('زيادة ديبو (دفعها الزبون، مخفية عن المحل)', o.markup, color: DepoColors.success),
        if (o.deliveryFee > 0) MoneyRow(depo ? 'رسم التوصيل (لديبو)' : 'رسم التوصيل (للمحل)', o.deliveryFee),
        MoneyRow('العمولة', o.commission, sign: '−', color: DepoColors.danger),
        if (o.commissionRule.isNotEmpty) Note(o.commissionRule),
        MoneyRow(
          depo ? 'ديبو حصّلت ${iqd(o.itemsBase)} من حق المحل ← تدفع له' : 'المحل حصّل بنفسه ← العمولة عليه',
          effect.abs(),
          sign: effect >= 0 ? '+' : '−',
          bold: true,
          color: effect >= 0 ? DepoColors.dark : DepoColors.danger,
        ),
      ]),
    );
  }
}

/// ملخص كشف المحل خطوة بخطوة (يستخدمه المدير والمحل)
class StatementSummary extends StatelessWidget {
  final StoreStatement st;
  const StatementSummary({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final b = st.balance;
    return AppCard(
      child: Column(children: [
        Note('${st.orders.length} طلب: ${st.depoOrders.length} وصّلها مندوب ديبو، ${st.storeOrders.length} استلام ذاتي أو مندوب المحل'),
        MoneyRow('المبيعات (بضاعة)', st.sales),
        MoneyRow('عمولة ديبو', st.commission, sign: '−', color: DepoColors.danger),
        MoneyRow('ربح المحل من البضاعة', st.storeEarnings, bold: true),
        const Divider(),
        const _Head('منو يدفع لمنو'),
        MoneyRow('(أ) بضاعة حصّلها مندوب ديبو (ترجع للمحل)', st.depoGoods),
        MoneyRow('(ب) كل العمولة (تنخصم)', st.commission, sign: '−', color: DepoColors.danger),
        MoneyRow(st.net >= 0 ? 'الصافي (أ − ب): ديبو تدفع للمحل' : 'الصافي (أ − ب): المحل يدفع لديبو', st.net.abs(), bold: true, color: st.net >= 0 ? DepoColors.dark : DepoColors.danger),
        if (st.storeOrders.isNotEmpty) Note('المحل حصّل بنفسه ${iqd(st.storeCollected)} من الزبائن (بضاعة${st.storeOrders.any((o) => o.deliveryFee > 0) ? ' + توصيل مندوبه' : ''}).'),
        if (b.payments.isNotEmpty) ...[
          const Divider(),
          const _Head('التسويات'),
          for (final p in b.payments.reversed)
            MoneyRow('${p.amount > 0 ? 'دفعنا' : 'استلمنا'} ${dateTimeLabel(p.at)}${p.note.isEmpty ? '' : ' • ${p.note}'}', p.amount.abs(), sign: '−'),
          MoneyRow('الباقي', b.remaining.abs(), bold: true, color: b.remaining == 0 ? DepoColors.success : DepoColors.danger),
        ],
        const SizedBox(height: 6),
        Row(children: [
          StatusBadge(b),
          const Spacer(),
          Text(app.isCurrentMonth(st.month) ? 'الشهر جاري — التسوية بعد نهايته' : 'التسوية شهرية', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
        ]),
      ]),
    );
  }
}

// ======================= كشف المندوب =======================
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
        final b = st.balance;
        final canEdit = b.payments.isEmpty && (app.canFinance || app.canAny([Perm.operations]));
        final name = app.userByPhone(phone)?.name ?? phone;
        return Scaffold(
          appBar: AppBar(
            title: Text('$name · ${monthLabel(month)}'),
            actions: [IconButton(tooltip: 'نسخ الكشف', onPressed: () => copyText(context, app.courierStatementText(st), done: 'انسخ الكشف'), icon: const Icon(Icons.copy_all_outlined))],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Column(children: [
                Note('${st.orders.length} توصيلة • ${st.km.toStringAsFixed(1)} كم${app.courierRatingOf(phone).$2 == 0 ? '' : ' • التقييم ${app.courierRatingOf(phone).$1.toStringAsFixed(1)} ★ (${app.courierRatingOf(phone).$2})'}'),
                MoneyRow('كل الأجور', st.earned, bold: true, color: DepoColors.dark),
                if (st.walletPaid > 0) MoneyRow('انضافت لمحفظته مباشرة', st.walletPaid, sign: '−'),
                if (st.walletPaid > 0) MoneyRow('مستحق بالتسوية الشهرية', b.due, bold: true),
                for (final p in b.payments.reversed) MoneyRow('استلم ${dateTimeLabel(p.at)}${p.note.isEmpty ? '' : ' • ${p.note}'}', p.amount, sign: '−'),
                if (b.payments.isNotEmpty) MoneyRow('الباقي', b.remaining, bold: true, color: b.remaining == 0 ? DepoColors.success : DepoColors.danger),
                const Divider(),
                MoneyRow('رصيده هسه', app.walletBalance(phone), color: DepoColors.dark),
                if (app.cashOf(phone) > 0) MoneyRow('نقد قديم بيده (قبل نظام الرصيد)', app.cashOf(phone), color: DepoColors.danger),
                const Note('الأجور تنحسب لكل طلب بتسعيرة يوم التسليم، وموضّحة تحت طلب طلب.'),
                Row(children: [StatusBadge(b), const Spacer()]),
              ]),
            ),
            if (app.canFinance && b.remaining != 0)
              FilledButton.icon(
                onPressed: app.isCurrentMonth(month) ? null : () => settleDialog(context, kind: 'courier', target: phone, month: month, b: b, whoName: name),
                icon: const Icon(Icons.task_alt),
                label: Text(app.isCurrentMonth(month) ? 'التسوية بعد نهاية الشهر' : 'تسجيل دفع أجور (${iqd(b.remaining)})'),
              ),
            SectionTitle('التوصيلات (${st.orders.length})'),
            if (canEdit) const Note('المسافة تنحسب بالـ GPS. إذا وحدة غلط اضغط عليها وعدّلها، أو اعتمدها بـ «المسافة صحيحة». التعديل قبل تسوية الشهر بس، وينسجل باسمك.'),
            if (st.orders.any((o) => o.kmNeedsReview))
              AppCard(
                color: const Color(0xFFFFF6E5),
                child: Text('${st.orders.where((o) => o.kmNeedsReview).length} توصيلة تحتاج مراجعة — التسوية تنقفل لحد ما تنراجع كلها.',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            for (final o in st.orders)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('#${o.id} • ${app.storeById(o.storeId)?.name ?? ''} • ${dateTimeLabel(o.deliveredAt)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    InkWell(
                      onTap: canEdit ? () => _editKm(context, o) : null,
                      child: Badge2('${o.distanceKm.toStringAsFixed(1)} كم${canEdit ? ' ✎' : ''}',
                          bg: o.kmNeedsReview ? const Color(0xFFFFF6E5) : DepoColors.soft, fg: o.kmNeedsReview ? const Color(0xFF8A5A00) : DepoColors.dark),
                    ),
                  ]),
                  Note('المسافة: ${app.kmSourceText(o)}', color: o.kmNeedsReview ? const Color(0xFF8A5A00) : null),
                  Note('الأجرة: ${CourierPay.of(o.payRule, app.settings).explain(o.distanceKm)}${o.peakBonus > 0 ? ' + مكافأة الذروة ${iqd(o.peakBonus)}' : ''}'),
                  MoneyRow('الأجرة', o.courierPay, bold: true),
                  MoneyRow(o.walletMode ? 'حصّل من الزبون (انخصم من رصيده)' : 'حصّل من الزبون (يسلّمه لديبو)', o.total),
                  Wrap(spacing: 8, children: [
                    if (o.endLat != 0)
                      TextButton.icon(
                        onPressed: () => openLink(context, 'https://www.google.com/maps/dir/?api=1&origin=${o.startLat},${o.startLng}&destination=${o.endLat},${o.endLng}&travelmode=driving'),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('شوف المسار'),
                      ),
                    if (o.kmNeedsReview && (app.canFinance || app.canAny([Perm.operations])) && b.payments.isEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () => app.approveKm(o),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('المسافة صحيحة'),
                      ),
                  ]),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _editKm(BuildContext context, Order o) async {
    final km = await askKm(context, o.distanceKm, title: 'مسافة الطلب #${o.id}', rule: o.payRule);
    if (km == null) return;
    final err = app.setOrderDistance(o, km);
    if (context.mounted) toast(context, err ?? 'انعدلت المسافة والأجرة');
  }
}

/// يسأل عن المسافة بالكيلومتر ويبين الأجرة وشلون انحسبت
Future<double?> askKm(BuildContext context, double initial, {String title = 'المسافة', List<int> rule = const []}) async {
  final ctl = TextEditingController(text: initial > 0 ? initial.toStringAsFixed(1) : '');
  final cp = CourierPay.of(rule, app.settings);
  return showDialog<double>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final km = double.tryParse(ctl.text.trim().replaceAll(',', '.').replaceAll('٫', '.')) ?? -1;
        final valid = km >= 0;
        return AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(suffixText: 'كم', hintText: '0.0'),
              onChanged: (_) => set(() {}),
            ),
            const SizedBox(height: 8),
            if (valid) ...[
              Text('الأجرة: ${iqd(cp.pay(km))}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DepoColors.dark)),
              Text(cp.explain(km), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
            ] else
              const Text('اكتب رقم، مثلاً 3.5', style: TextStyle(color: DepoColors.danger)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: valid ? () => Navigator.pop(c, km) : null, child: const Text('حفظ')),
          ],
        );
      },
    ),
  );
}
