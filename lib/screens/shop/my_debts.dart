import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../auth.dart';
import 'debtor_screen.dart';
import 'jm_ui.dart';

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
    if (code.text.trim().isEmpty) return jmToast(context, 'اكتب الرمز');
    if (!await ensureLoggedIn(context, reason: 'سجّل حتى نربط ديونك بحسابك') || !mounted) return;
    final err = app.linkDebtCode(code.text);
    if (err != null) return jmToast(context, err);
    code.clear();
    jmToast(context, 'انضاف! هسه تشوف ديونك');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.myDebtAccounts;
        final total = list.fold(0, (s, d) => s + app.summaryOf(d.id).remaining);
        return JmScaffold(
          title: 'ديوني عند المحلات',
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            JmCard(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: CircleAvatar(radius: 24, backgroundColor: Color(0x2619C9B7), child: Icon(Icons.lock_outline_rounded, color: Jm.cyan))),
                const SizedBox(height: 10),
                const Text('أدخل رمز المحل', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('الرمز من 8 خانات أعطاك إياه صاحب المحل لتطّلع على ديونك وتفاصيلها',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Jm.sub, height: 1.5)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: code,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 9,
                      style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w900, color: Jm.text),
                      decoration: const InputDecoration(hintText: 'XXXX-XXXX', counterText: ''),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Jm.cyan,
                        side: const BorderSide(color: Jm.line),
                        backgroundColor: const Color(0x14FFFFFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final t = await clipboardText();
                        if (t != null) code.text = t.trim().toUpperCase();
                      },
                      child: const Text('لصق', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                JmButton(label: 'عرض ديوني', onTap: _add, height: 48),
              ]),
            ),
            if (list.isNotEmpty) ...[
              JmAmountCard(
                label: 'مجموع ديوني بكل المحلات',
                amount: iqd(total),
                sub: list.length == 1 ? 'عند محل واحد' : 'عند ${list.length} محلات',
              ),
              for (final d in list) _Account(d: d),
            ] else
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('ديونك تبقى خاصة بيك: محد يشوفها غير إنت وصاحب المحل.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Jm.faint)),
              ),
          ]),
        );
      },
    );
  }
}

class _Account extends StatelessWidget {
  final Debtor d;
  const _Account({required this.d});

  @override
  Widget build(BuildContext context) {
    final st = app.storeById(d.storeId);
    final sum = app.summaryOf(d.id);
    final late = sum.overdue > 0;
    return JmCard(
      border: late ? Jm.red.withValues(alpha: 0.6) : null,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DebtorScreen(debtorId: d.id, readOnly: true))),
      child: Row(children: [
        JmAvatar(
          letter: (st?.name ?? 'م').characters.first,
          size: 46,
          image: st == null || st.imageId.isEmpty ? null : AppImage(imageId: st.imageId, height: 46, width: 46, fallback: const SizedBox()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st?.name ?? 'محل', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(
              late ? 'متأخر ${iqd(sum.overdue)}' : (sum.nextDue > 0 ? 'أقرب موعد ${dateLabel(sum.nextDue)}' : 'مسدّد ${sum.paidPercent}%'),
              style: TextStyle(fontSize: 12, color: late ? const Color(0xFFFF8A8E) : Jm.sub, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        Text(iqd(sum.remaining), style: TextStyle(fontWeight: FontWeight.w900, color: sum.remaining > 0 ? const Color(0xFFFF8A8E) : const Color(0xFF4ADE80))),
        PopupMenuButton<String>(
          iconColor: Jm.sub,
          onSelected: (_) => app.unlinkDebtCode(d.code),
          itemBuilder: (c) => const [PopupMenuItem(value: 'x', child: Text('شيله من قائمتي'))],
        ),
      ]),
    );
  }
}
