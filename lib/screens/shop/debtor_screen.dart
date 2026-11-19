import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../chat_screen.dart';

/// صفحة زبون بالدفتر. readOnly = الزبون نفسه يشوف ديونه
class DebtorScreen extends StatelessWidget {
  final String debtorId;
  final bool readOnly;
  const DebtorScreen({super.key, required this.debtorId, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final d = app.debtorById(debtorId);
        if (d == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.person_off_outlined, text: 'هذا الحساب مو موجود'));
        final store = app.storeById(d.storeId);
        final owner = !readOnly && app.ownsStore(d.storeId);
        final sum = app.summaryOf(d.id);
        final entries = app.entriesOf(d.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(readOnly ? (store?.name ?? 'ديوني') : d.name),
            actions: [
              if (owner)
                IconButton(tooltip: 'تعديل', onPressed: () => _edit(context, d), icon: const Icon(Icons.edit_outlined)),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (readOnly && store != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('حسابك باسم «${d.name}» عند ${store.fullName}', style: const TextStyle(color: DepoColors.muted)),
              ),
            DebtSummaryCard(
              title: readOnly ? 'المتبقي عليك' : 'المتبقي على الزبون',
              remaining: sum.remaining,
              paid: sum.paid,
              ordered: sum.ordered,
              overdue: sum.overdue,
              nextDue: sum.nextDue,
            ),
            const SizedBox(height: 12),
            if (owner) ...[
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: DepoColors.danger),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtOrderScreen(store: store!, debtor: d))),
                    icon: const Icon(Icons.south_rounded),
                    label: const Text('طلب جديد'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: DepoColors.success),
                    onPressed: sum.remaining > 0 ? () => recordPayment(context, d) : null,
                    icon: const Icon(Icons.north_rounded),
                    label: const Text('تسجيل دفعة'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (d.phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => callPhone(context, d.phone),
                      icon: const Icon(Icons.phone),
                      label: const Text('اتصال'),
                    ),
                  ),
                if (d.phone.isNotEmpty) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: sum.remaining > 0 ? () => sendDebtReminder(context, d) : null,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('إرسال تذكير'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _CodeCard(d: d),
            ] else if (store != null) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => openShopChat(context, store.id),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('راسل المحل'),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('الحركات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              if (owner) const Text('اضغط مطوّل على حركة حتى تلغيها', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
            ]),
            const SizedBox(height: 6),
            DebtEntriesList(entries: entries, onLongPress: owner ? (e) => _void(context, e) : null),
          ]),
        );
      },
    );
  }

  Future<void> _void(BuildContext context, DebtEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تلغي ${e.payment ? 'الدفعة' : 'الطلب'} (${iqd(e.amount)})؟'),
        content: const Text('تبقى ظاهرة بالدفتر بشطب، بس ما تنحسب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: DepoColors.danger), onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الحركة')),
        ],
      ),
    );
    if (ok == true) app.voidDebtEntry(e);
  }

  Future<void> _edit(BuildContext context, Debtor d) async {
    final name = TextEditingController(text: d.name);
    final phone = TextEditingController(text: d.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('معلومات الزبون'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) app.updateDebtor(d, name: name.text, phone: phone.text);
  }
}

/// رمز الزبون: نسخ، إرسال، تغيير
class _CodeCard extends StatelessWidget {
  final Debtor d;
  const _CodeCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final store = app.storeById(d.storeId);
    final msg = 'هلا ${d.name} 👋\nتكدر تشوف ديونك عند ${store?.name ?? 'المحل'} وكل تفاصيلها من تطبيق ديبو:\n'
        'حسابي ← ديوني عند المحلات ← اكتب الرمز:\n${d.code}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: DepoColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('رمز الزبون لمتابعة ديونه', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 4),
        SelectableText(d.code,
            textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, color: DepoColors.dark)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextButton.icon(onPressed: () => copyText(context, d.code, done: 'انسخ الرمز'), icon: const Icon(Icons.copy, size: 18), label: const Text('نسخ'))),
          Expanded(child: TextButton.icon(onPressed: () => copyText(context, msg, done: 'انسخت رسالة فيها الرمز وطريقة الاستخدام'), icon: const Icon(Icons.share_outlined, size: 18), label: const Text('رسالة جاهزة'))),
          Expanded(
            child: TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('تغيّر الرمز؟'),
                    content: const Text('الرمز القديم يبطل، والزبون يحتاج الرمز الجديد حتى يشوف ديونه.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                      FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('غيّره')),
                    ],
                  ),
                );
                if (ok == true) app.regenerateDebtCode(d);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تغيير'),
            ),
          ),
        ]),
        const Text('الزبون يفتح «ديوني عند المحلات» بديبو ويكتب الرمز، فيشوف ديونه ومواعيدها للقراءة بس.',
            style: TextStyle(fontSize: 11, color: DepoColors.muted)),
      ]),
    );
  }
}

/// تذكير داخل التطبيق (إشعار) — يوصل للزبون إذا ضاف رمزه بديبو
Future<void> sendDebtReminder(BuildContext context, Debtor d) async {
  final n = app.remindDebtor(d);
  toast(context, n > 0 ? 'وصل التذكير للزبون كإشعار بالتطبيق' : 'الزبون بعده ما ضاف رمزه بديبو، فما يوصله التذكير. انطيه الرمز أول من «رمز الزبون».');
}

Future<Debtor?> addDebtorDialog(BuildContext context, Store store) async {
  final name = TextEditingController();
  final phone = TextEditingController(text: '07');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('زبون جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الزبون')),
        const SizedBox(height: 10),
        TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('إضافة')),
      ],
    ),
  );
  if (ok != true) return null;
  final p = phone.text.trim() == '07' ? '' : phone.text.trim();
  final d = app.addDebtor(store.id, name: name.text, phone: p);
  if (d == null && context.mounted) toast(context, 'اكتب اسم الزبون');
  return d;
}

/// يختار زبون (أو يضيف جديد) وبعدين ينفّذ
Future<void> pickDebtorThen(BuildContext context, Store store, void Function(Debtor) then) async {
  final list = app.debtorsOf(store.id).where((d) => app.summaryOf(d.id).remaining > 0).toList();
  if (list.isEmpty) return toast(context, 'ماكو زبون عليه دين');
  final d = await showModalBottomSheet<Debtor>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('اختار الزبون', style: TextStyle(fontWeight: FontWeight.w900))),
          for (final x in list)
            ListTile(
              title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text(iqd(app.summaryOf(x.id).remaining), style: const TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w900)),
              onTap: () => Navigator.pop(c, x),
            ),
        ]),
      ),
    ),
  );
  if (d != null) then(d);
}

Future<void> recordPayment(BuildContext context, Debtor d) async {
  final rem = app.summaryOf(d.id).remaining;
  if (rem <= 0) return toast(context, 'ماكو دين على هذا الزبون');
  final amount = TextEditingController();
  final note = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('تسجيل دفعة · ${d.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DepoColors.success)),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: DepoColors.success, side: const BorderSide(color: DepoColors.success)),
          onPressed: () => amount.text = '$rem',
          child: Text('تسديد كامل المتبقي · ${iqd(rem)}'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: amount,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          decoration: const InputDecoration(labelText: 'المبلغ (د.ع)'),
        ),
        const SizedBox(height: 10),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
        const SizedBox(height: 12),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: DepoColors.success), onPressed: () => Navigator.pop(c, true), child: const Text('حفظ الدفعة')),
      ]),
    ),
  );
  if (ok != true) return;
  final a = parseInt(amount.text) ?? 0;
  final done = app.addDebtPayment(d, a, note: note.text);
  if (context.mounted) {
    toast(context, done <= 0 ? 'اكتب مبلغ صحيح' : (done < a ? 'انسجّل ${iqd(done)} بس (هذا كل المتبقي)' : 'انسجّلت الدفعة'));
  }
}

/// طلب جديد على الدفتر: الأصناف + الشهر (بلونه) + موعد التسديد
class DebtOrderScreen extends StatefulWidget {
  final Store store;
  final Debtor? debtor;
  const DebtOrderScreen({super.key, required this.store, this.debtor});

  @override
  State<DebtOrderScreen> createState() => _DebtOrderScreenState();
}

class _Line {
  final name = TextEditingController();
  final price = TextEditingController();
  final qty = TextEditingController(text: '1');
  void dispose() {
    name.dispose();
    price.dispose();
    qty.dispose();
  }
}

class _DebtOrderScreenState extends State<DebtOrderScreen> {
  Debtor? debtor;
  final lines = [_Line()];
  final note = TextEditingController();
  late String month = monthKey(DateTime.now());
  int dueAt = 0;
  String dueLabel = 'بدون';

  @override
  void initState() {
    super.initState();
    debtor = widget.debtor;
  }

  @override
  void dispose() {
    for (final l in lines) {
      l.dispose();
    }
    note.dispose();
    super.dispose();
  }

  List<String> get months {
    final now = DateTime.now();
    return [for (var i = 0; i < 4; i++) monthKey(DateTime(now.year, now.month - i))];
  }

  int get total => lines.fold(0, (s, l) => s + (parseInt(l.price.text) ?? 0) * (parseInt(l.qty.text) ?? 1));

  void _due(String label, Duration? d) => setState(() {
        dueLabel = label;
        dueAt = d == null ? 0 : DateTime.now().add(d).millisecondsSinceEpoch;
      });

  @override
  Widget build(BuildContext context) {
    final customers = app.debtorsOf(widget.store.id);
    return Scaffold(
      appBar: AppBar(title: Text(debtor == null ? 'طلب جديد' : 'طلب جديد · ${debtor!.name}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.debtor == null) ...[
          const Text('الزبون', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(debtor?.id),
                initialValue: debtor?.id,
                isExpanded: true,
                hint: const Text('اختار زبون'),
                items: [for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => debtor = app.debtorById(v ?? '')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'زبون جديد',
              onPressed: () async {
                final d = await addDebtorDialog(context, widget.store);
                if (d != null) setState(() => debtor = d);
              },
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ]),
          const SizedBox(height: 14),
        ],
        const Text('شنو اللي طلبه الزبون؟', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 5, child: TextField(controller: l.name, decoration: const InputDecoration(labelText: 'الصنف', isDense: true))),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: TextField(controller: l.price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', isDense: true), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: TextField(controller: l.qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد', isDense: true), onChanged: (_) => setState(() {}))),
              if (lines.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    lines.remove(l);
                    l.dispose();
                  }),
                  icon: const Icon(Icons.close),
                ),
            ]),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: DepoColors.danger, side: const BorderSide(color: DepoColors.danger)),
          onPressed: () => setState(() => lines.add(_Line())),
          icon: const Icon(Icons.add),
          label: const Text('إضافة صنف آخر'),
        ),
        const SizedBox(height: 10),
        Text('المجموع: ${iqd(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DepoColors.danger)),
        const SizedBox(height: 14),
        const Text('شهر الدين', style: TextStyle(fontWeight: FontWeight.w900)),
        const Text('كل شهر بلون حتى تفرّقها بالدفتر بنظرة', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final m in months) MonthChip(m, selected: month == m, onTap: () => setState(() => month = m))]),
        const SizedBox(height: 14),
        const Text('موعد التسديد', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in {
            'بدون': null,
            'بعد أسبوع': const Duration(days: 7),
            'بعد شهر': const Duration(days: 30),
            'بعد شهرين': const Duration(days: 60),
          }.entries)
            ChoiceChip(label: Text(e.key), selected: dueLabel == e.key, onSelected: (_) => _due(e.key, e.value)),
          ChoiceChip(
            label: Text(dueLabel.startsWith('20') ? dueLabel : 'تاريخ محدد'),
            selected: dueLabel.startsWith('20'),
            onSelected: (_) async {
              final now = DateTime.now();
              final p = await showDatePicker(context: context, firstDate: now, lastDate: DateTime(now.year + 2), initialDate: now.add(const Duration(days: 14)));
              if (p != null) {
                setState(() {
                  dueAt = DateTime(p.year, p.month, p.day, 23, 59).millisecondsSinceEpoch;
                  dueLabel = dateLabel(dueAt);
                });
              }
            },
          ),
        ]),
        const SizedBox(height: 14),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DepoColors.danger),
          onPressed: () {
            if (debtor == null) return toast(context, 'اختار الزبون');
            final items = [
              for (final l in lines)
                if (l.name.text.trim().isNotEmpty && (parseInt(l.price.text) ?? 0) > 0)
                  DebtItem(name: l.name.text.trim(), price: parseInt(l.price.text)!, qty: (parseInt(l.qty.text) ?? 1).clamp(1, 9999)),
            ];
            if (items.isEmpty) return toast(context, 'اكتب صنف وسعره');
            app.addDebtOrder(debtor!, items: items, month: month, dueAt: dueAt, note: note.text);
            toast(context, 'انسجّل الطلب');
            Navigator.pop(context);
          },
          child: const Text('حفظ الطلب'),
        ),
      ]),
    );
  }
}
