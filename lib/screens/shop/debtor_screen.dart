import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../chat_screen.dart';
import 'jm_ui.dart';

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
        if (d == null) {
          return const JmScaffold(title: 'الحساب', body: JmEmpty(icon: Icons.person_off_outlined, title: 'هذا الحساب مو موجود', text: 'يمكن صاحب المحل غيّر الرمز'));
        }
        final store = app.storeById(d.storeId);
        final owner = !readOnly && app.ownsStore(d.storeId);
        final sum = app.summaryOf(d.id);
        final entries = app.entriesOf(d.id);
        final linked = app.users.any((u) => u.debtCodes.contains(d.code));
        final pct = sum.ordered == 0 ? 0.0 : (sum.paid / sum.ordered).clamp(0.0, 1.0);
        return JmScaffold(
          title: readOnly ? (store?.name ?? 'ديوني') : d.name,
          subtitle: readOnly ? 'حسابك باسم «${d.name}»' : (d.phone.isEmpty ? null : d.phone),
          leading: readOnly
              ? JmAvatar(
                  letter: (store?.name ?? 'م').characters.first,
                  image: store == null || store.imageId.isEmpty ? null : AppImage(imageId: store.imageId, height: 52, width: 52, fallback: const SizedBox()),
                )
              : JmAvatar(letter: d.name.characters.first, color: Jm.yellow),
          actions: [if (owner) JmCircleBtn(icon: Icons.settings_outlined, tooltip: 'معلومات الزبون', onTap: () => _edit(context, d))],
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            JmCard(
              color: const Color(0x26000000),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(readOnly ? 'المتبقي عليك' : 'المتبقي على الزبون', style: const TextStyle(fontSize: 13, color: Jm.sub)),
                const SizedBox(height: 4),
                Text(iqd(sum.remaining), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: const Color(0xFFD9534F), color: const Color(0xFF4ADE80)),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text('سدّد ${iqd(sum.paid)}', style: const TextStyle(fontSize: 12, color: Color(0xFF4ADE80), fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('من ${iqd(sum.ordered)}', style: const TextStyle(fontSize: 12, color: Color(0xFFFF8A8E))),
                ]),
                if (sum.overdue > 0 || sum.nextDue > 0) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: Jm.line)),
                      child: Text(
                        sum.overdue > 0 ? 'متأخر ${iqd(sum.overdue)} من ${dateLabel(sum.oldestOverdue)}' : 'أقرب موعد استحقاق ${dateLabel(sum.nextDue)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sum.overdue > 0 ? const Color(0xFFFF8A8E) : Jm.text),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            if (owner) ...[
              Row(children: [
                Expanded(
                  child: JmButton(
                    label: 'طلب جديد',
                    icon: Icons.arrow_downward,
                    color: Jm.red,
                    fg: Colors.white,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtOrderScreen(store: store!, debtor: d))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: JmButton(label: 'تسجيل دفعة', icon: Icons.arrow_upward, color: Jm.green, fg: Colors.white, onTap: sum.remaining > 0 ? () => recordPayment(context, d) : null),
                ),
              ]),
              const SizedBox(height: 10),
              if (d.phone.isNotEmpty) ...[
                JmButton(label: 'اتصال', outlined: true, height: 46, onTap: () => callPhone(context, d.phone)),
                const SizedBox(height: 10),
              ],
              JmCard(
                onTap: sum.remaining > 0 ? () => sendDebtReminder(context, d) : null,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('إرسال تذكير للزبون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(
                        !linked ? 'غير مفعّل: لم يُدخل الزبون رمزه بعد' : (sum.remaining > 0 ? 'يوصله إشعار داخل ديبو' : 'ماكو دين حتى نذكّره'),
                        style: const TextStyle(fontSize: 12, color: Jm.sub),
                      ),
                    ]),
                  ),
                  CircleAvatar(radius: 18, backgroundColor: const Color(0x14FFFFFF), child: Icon(Icons.inbox_outlined, size: 20, color: linked ? Jm.cyan : Jm.sub)),
                ]),
              ),
              _CodeCard(d: d),
            ] else if (store != null && !owner) ...[
              JmButton(label: 'راسل المحل', icon: Icons.chat_bubble_outline, outlined: true, height: 46, onTap: () => openShopChat(context, store.id)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            Row(children: [
              const Expanded(child: Text('الطلبات الحالية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              if (owner && entries.any((e) => !e.voided))
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF8A8E), backgroundColor: const Color(0x26E5484D), shape: const StadiumBorder()),
                  onPressed: () => _voidAll(context, d),
                  child: const Text('حذف الكل', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
            ]),
            if (owner) const Text('اضغط مطوّلاً على أي حركة حتى تلغيها', style: TextStyle(fontSize: 11, color: Jm.faint)),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('ماكو حركات بعد', textAlign: TextAlign.center, style: TextStyle(color: Jm.sub)))
            else
              DebtEntriesList(entries: entries, onLongPress: owner ? (e) => _void(context, e) : null),
          ]),
        );
      },
    );
  }

  Future<void> _voidAll(BuildContext context, Debtor d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تحذف كل حركات الزبون؟'),
        content: const Text('تبقى ظاهرة بشطب، بس ما تنحسب، ويصير المتبقي صفر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: Jm.red), onPressed: () => Navigator.pop(c, true), child: const Text('حذف الكل')),
        ],
      ),
    );
    if (ok == true) app.voidAllOf(d);
  }

  Future<void> _void(BuildContext context, DebtEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('تلغي ${e.payment ? 'الدفعة' : 'الطلب'} (${iqd(e.amount)})؟'),
        content: const Text('تبقى ظاهرة بالدفتر بشطب، بس ما تنحسب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: Jm.red), onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الحركة')),
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
    final msg = 'رمز متابعة ديونك لدى ${store?.name ?? 'المحل'}: ${d.code}\n'
        'افتح تطبيق ديبو ← حسابي ← الأسواق ← ديوني عند المحلات، واكتب الرمز.';
    Widget btn(String t, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Jm.text,
                side: const BorderSide(color: Jm.line),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        );
    return JmCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('رمز الزبون لمتابعة ديونه', style: TextStyle(fontSize: 12, color: Jm.sub)),
        const SizedBox(height: 8),
        SelectableText(d.code,
            textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 5, color: Jm.cyan)),
        const SizedBox(height: 12),
        Row(children: [
          btn('نسخ الرمز', () => copyText(context, d.code, done: 'انسخ الرمز')),
          btn('إرسال للزبون', () => shareText(context, msg)),
          btn('تغيير', () async {
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
          }),
        ]),
        const SizedBox(height: 10),
        const Text('يفتح الزبون «الأسواق» من القائمة ثم «ديوني عند المحلات» ويكتب الرمز، فيرى ديونه ومواعيدها للقراءة فقط.',
            style: TextStyle(fontSize: 11, color: Jm.faint, height: 1.5)),
      ]),
    );
  }
}

/// تذكير داخل التطبيق (إشعار) — يوصل للزبون إذا ضاف رمزه بديبو
Future<void> sendDebtReminder(BuildContext context, Debtor d) async {
  final n = app.remindDebtor(d);
  jmToast(context, n > 0 ? 'وصل التذكير للزبون كإشعار بالتطبيق' : 'الزبون بعده ما ضاف رمزه بديبو، فما يوصله التذكير. انطيه الرمز أول من «رمز الزبون».');
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
  if (list.isEmpty) return jmToast(context, 'ماكو زبون عليه دين');
  final d = await showModalBottomSheet<Debtor>(
    context: context,
    showDragHandle: true,
    backgroundColor: Jm.bgMid,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(12), child: Text('اختار الزبون', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Jm.text))),
          for (final x in list)
            ListTile(
              title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Jm.text)),
              trailing: Text(iqd(app.summaryOf(x.id).remaining), style: const TextStyle(color: Color(0xFFFF8A8E), fontWeight: FontWeight.w900)),
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
  if (rem <= 0) return jmToast(context, 'ماكو دين على هذا الزبون');
  final amount = TextEditingController();
  final note = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Jm.bgMid,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(c).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x331FA85A), borderRadius: BorderRadius.circular(16)),
          child: Text('تسجيل دفعة · ${d.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4ADE80))),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4ADE80),
            side: const BorderSide(color: Color(0xFF4ADE80)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
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
        JmButton(label: 'حفظ الدفعة', color: Jm.green, fg: Colors.white, onTap: () => Navigator.pop(c, true)),
      ]),
    ),
  );
  if (ok != true) return;
  final a = parseInt(amount.text) ?? 0;
  final done = app.addDebtPayment(d, a, note: note.text);
  if (context.mounted) {
    jmToast(context, done <= 0 ? 'اكتب مبلغ صحيح' : (done < a ? 'انسجّل ${iqd(done)} بس (هذا كل المتبقي)' : 'انسجّلت الدفعة'));
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
  final lines = [_Line()];
  final note = TextEditingController();
  late final name = TextEditingController(text: widget.debtor?.name ?? '');
  late final phone = TextEditingController(text: widget.debtor?.phone ?? '');
  late String month = monthKey(DateTime.now());
  int dueAt = 0;
  String dueLabel = '';

  @override
  void dispose() {
    for (final l in lines) {
      l.dispose();
    }
    note.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  List<String> get months {
    final now = DateTime.now();
    return [for (var i = 0; i < 4; i++) monthKey(DateTime(now.year, now.month - i))];
  }

  int get total => lines.fold(0, (s, l) => s + (parseInt(l.price.text) ?? 0) * (parseInt(l.qty.text) ?? 1));

  void _due(String label, Duration? d) => setState(() {
        if (dueLabel == label) {
          dueLabel = '';
          dueAt = 0;
          return;
        }
        dueLabel = label;
        dueAt = d == null ? 0 : DateTime.now().add(d).millisecondsSinceEpoch;
      });

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)));

  Widget _chip(String t, bool on, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFF6B6B) : const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? const Color(0xFFFF6B6B) : Jm.line),
          ),
          child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Jm.text)),
        ),
      );

  void _save() {
    final items = [
      for (final l in lines)
        if (l.name.text.trim().isNotEmpty && (parseInt(l.price.text) ?? 0) > 0)
          DebtItem(name: l.name.text.trim(), price: parseInt(l.price.text)!, qty: (parseInt(l.qty.text) ?? 1).clamp(1, 9999)),
    ];
    if (name.text.trim().length < 2) return jmToast(context, 'اكتب اسم الزبون');
    if (items.isEmpty) return jmToast(context, 'اكتب الصنف وسعره');
    final d = widget.debtor ?? app.findOrAddDebtor(widget.store.id, name: name.text, phone: phone.text);
    if (d == null) return jmToast(context, 'ما انحفظ، جرّب مرة ثانية');
    app.addDebtOrder(d, items: items, month: month, dueAt: dueAt, note: note.text);
    Navigator.pop(context);
    jmToast(context, 'تم تسجيل الطلب');
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = app.debtorsOf(widget.store.id);
    return JmScaffold(
      title: widget.store.name,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0x33E5484D), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x44E5484D))),
          child: const Row(children: [
            Expanded(child: Text('طلب جديد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFF6B6B)))),
            CircleAvatar(radius: 14, backgroundColor: Color(0x44E5484D), child: Icon(Icons.arrow_downward, size: 16, color: Color(0xFFFF6B6B))),
          ]),
        ),
        _label('اسم الزبون'),
        if (widget.debtor != null)
          JmCard(child: Text(widget.debtor!.name, style: const TextStyle(fontWeight: FontWeight.w900)))
        else ...[
          TextField(controller: name, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'مثال: أبو علي'), onChanged: (_) => setState(() {})),
          if (name.text.trim().isNotEmpty)
            Wrap(spacing: 6, children: [
              for (final s in suggestions.where((x) => x.name.contains(name.text.trim()) && x.name != name.text.trim()).take(4))
                ActionChip(
                  label: Text(s.name),
                  backgroundColor: const Color(0x14FFFFFF),
                  side: const BorderSide(color: Jm.line),
                  onPressed: () => setState(() {
                    name.text = s.name;
                    phone.text = s.phone;
                  }),
                ),
            ]),
          _label('رقم الهاتف (اختياري)'),
          TextField(controller: phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: '07xxxxxxxxx')),
        ],
        _label('ما الذي طلبه الزبون؟'),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(flex: 5, child: TextField(controller: l.name, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'اسم الصنف أو الطلب'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(controller: l.price, keyboardType: TextInputType.number, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'السعر'), onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() {
                  if (lines.length == 1) {
                    l.name.clear();
                    l.price.clear();
                    return;
                  }
                  lines.remove(l);
                  l.dispose();
                }),
                icon: const CircleAvatar(radius: 14, backgroundColor: Color(0x14FFFFFF), child: Icon(Icons.close, size: 16, color: Jm.sub)),
              ),
            ]),
          ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => lines.add(_Line())),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFF6B6B))),
            child: const Text('+ إضافة صنف آخر', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFFF6B6B))),
          ),
        ),
        if (total > 0) Padding(padding: const EdgeInsets.only(top: 14), child: Text('المجموع: ${iqd(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF6B6B)))),
        _label('شهر الدين'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in months)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => month = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: month == m ? const Color(0xFFFF6B6B) : const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: month == m ? Colors.white : monthColor(m), width: month == m ? 1.5 : 1.2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(m, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Jm.text)),
                  const SizedBox(width: 6),
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: monthColor(m), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: month == m ? 1.5 : 0))),
                ]),
              ),
            ),
        ]),
        _label('موعد الاستحقاق'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in {'بعد أسبوع': const Duration(days: 7), 'بعد شهر': const Duration(days: 30), 'بعد شهرين': const Duration(days: 60)}.entries)
            _chip(e.key, dueLabel == e.key, () => _due(e.key, e.value)),
          _chip(dueLabel.startsWith('20') ? dueLabel : 'تاريخ محدد', dueLabel.startsWith('20'), () async {
            final now = DateTime.now();
            final p = await showDatePicker(context: context, firstDate: now, lastDate: DateTime(now.year + 2), initialDate: now.add(const Duration(days: 14)));
            if (p != null) {
              setState(() {
                dueAt = DateTime(p.year, p.month, p.day, 23, 59).millisecondsSinceEpoch;
                dueLabel = dateLabel(dueAt);
              });
            }
          }),
        ]),
        _label('ملاحظة (اختياري)'),
        TextField(controller: note, style: const TextStyle(color: Jm.text), decoration: const InputDecoration(hintText: 'مثلاً: يسدد أول الشهر')),
        const SizedBox(height: 22),
        JmButton(label: 'حفظ الطلب', color: Jm.red, fg: Colors.white, onTap: _save),
      ]),
    );
  }
}
