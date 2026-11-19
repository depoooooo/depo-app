import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../../widgets/offer_cards.dart';
import '../auth.dart';
import 'debtor_screen.dart';

/// «ديوني عند المحلات»: الزبون يكتب الرمز اللي انطاه صاحب المحل ويشوف ديونه
class MyDebtsScreen extends StatefulWidget {
  const MyDebtsScreen({super.key});

  @override
  State<MyDebtsScreen> createState() => _MyDebtsScreenState();
}

class _MyDebtsScreenState extends State<MyDebtsScreen> {
  final code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (!await ensureLoggedIn(context, reason: 'سجّل حتى نربط ديونك بحسابك') || !mounted) return;
    final err = app.linkDebtCode(code.text);
    if (err != null) return toast(context, err);
    code.clear();
    toast(context, 'انضاف! هسه تشوف ديونك');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.myDebtAccounts;
        final total = list.fold(0, (s, d) => s + app.summaryOf(d.id).remaining);
        return Scaffold(
          appBar: AppBar(title: const Text('ديوني عند المحلات')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: DepoColors.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.lock_outline_rounded, color: DepoColors.dark, size: 32),
                const SizedBox(height: 6),
                const Text('دخّل رمز المحل', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('الرمز من 8 خانات يعطيك إياه صاحب المحل حتى تطّلع على ديونك وتفاصيلها',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: code,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 9,
                      style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(hintText: 'XXXX-XXXX', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'لصق',
                    onPressed: () async {
                      final t = await clipboardText();
                      if (t != null) code.text = t.trim().toUpperCase();
                    },
                    icon: const Icon(Icons.content_paste),
                  ),
                ]),
                const SizedBox(height: 10),
                FilledButton(onPressed: _add, child: const Text('عرض ديوني')),
              ]),
            ),
            const SizedBox(height: 16),
            if (list.isNotEmpty) ...[
              DebtSummaryCard(
                title: 'مجموع ديوني بكل المحلات',
                remaining: total,
                paid: list.fold(0, (s, d) => s + app.summaryOf(d.id).paid),
                ordered: list.fold(0, (s, d) => s + app.summaryOf(d.id).ordered),
                overdue: list.fold(0, (s, d) => s + app.summaryOf(d.id).overdue),
              ),
              const SizedBox(height: 12),
            ],
            for (final d in list)
              Builder(builder: (context) {
                final st = app.storeById(d.storeId);
                final sum = app.summaryOf(d.id);
                return AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id, readOnly: true))),
                  child: Row(children: [
                    if (st != null) StoreAvatar(store: st, size: 46),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(st?.name ?? 'محل', style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(
                          sum.overdue > 0 ? 'متأخر ${iqd(sum.overdue)}' : (sum.nextDue > 0 ? 'الموعد ${dateLabel(sum.nextDue)}' : 'مسدّد ${sum.paidPercent}%'),
                          style: TextStyle(fontSize: 12, color: sum.overdue > 0 ? DepoColors.danger : DepoColors.muted, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                    Text(iqd(sum.remaining), style: TextStyle(fontWeight: FontWeight.w900, color: sum.remaining > 0 ? DepoColors.danger : DepoColors.success)),
                    PopupMenuButton<String>(
                      onSelected: (_) => app.unlinkDebtCode(d.code),
                      itemBuilder: (c) => const [PopupMenuItem(value: 'x', child: Text('شيله من قائمتي'))],
                    ),
                  ]),
                );
              }),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('ديونك تبقى خاصة بيك: محد يشوفها غير إنت وصاحب المحل.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
              ),
          ]),
        );
      },
    );
  }
}
