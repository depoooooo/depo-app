import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../orders.dart';
import '../../widgets/debt_ui.dart';
import 'finance_tab.dart';
import '../../widgets/geo_ui.dart';

/// واجهة المندوب
class CourierHome extends StatelessWidget {
  const CourierHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.currentPhone ?? '';
    final avail = app.walletAvailable(me);
    final available = app.courierAvailable;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: DepoColors.ink,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        title: const Text('واجهة المندوب'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: app.courierAvailable,
              onChanged: app.setCourierAvailable,
              title: Text(app.courierAvailable ? 'متاح للتوصيل' : 'غير متاح', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('لازم تكون متاح حتى تشوف المهام الجديدة'),
            ),
          ),
          const _WalletCard(),
          const _TierCard(),
          const _Earnings(),
          const SectionTitle('مهامي'),
          if (app.myTasks.isEmpty) const Text('ماكو مهام حالية', style: TextStyle(color: DepoColors.muted)),
          for (final o in app.myTasks) OrderTile(order: o, trailing: _myTaskActions(context, o)),
          const SizedBox(height: 8),
          const SectionTitle('مهام متاحة'),
          if (!available)
            const Text('فعّل «متاح للتوصيل» حتى تشوف المهام', style: TextStyle(color: DepoColors.muted))
          else if (app.availableTasks.isEmpty)
            const EmptyState(icon: Icons.delivery_dining, text: 'ماكو مهام هسه. أول ما محل يجهّز طلب توصيل، يطلع هنا.')
          else
            for (final o in app.availableTasks)
              if (app.taskLockedFor(o) > 0)
                _LockedTask(order: o)
              else
              OrderTile(
                order: o,
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('استلم من: ${app.storeById(o.storeId)?.fullName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('سلّم إلى: ${o.address}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('حصّل من الزبون: ${iqd(o.total)} كاش (ينخصم من رصيدك وأجرتك تنضاف)', style: const TextStyle(color: DepoColors.dark, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (avail < o.total)
                    Text('رصيدك المتاح (${iqd(avail)}) ما يكفي هذا الطلب — اشحن رصيد', style: const TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
                  FilledButton(
                    onPressed: avail < o.total
                        ? null
                        : () async {
                            final ok = await app.takeTask(o);
                            if (context.mounted) toast(context, ok ? 'المهمة صارت إلك' : 'سبقك مندوب ثاني على هاي المهمة');
                          },
                    child: const Text('قبول المهمة'),
                  ),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _myTaskActions(BuildContext context, Order o) {
    if (o.status == OrderStatus.preparing || o.status == OrderStatus.accepted) {
      return const Text('المحل بعده يجهّز الطلب…', style: TextStyle(fontWeight: FontWeight.w700));
    }
    if (o.status == OrderStatus.ready) {
      return FilledButton.icon(
        onPressed: () async {
          final r = await locateWithProgress(context);
          app.courierPickedUp(o, r.fix);
          if (r.fix == null && context.mounted) toast(context, '${r.error}\nكمّل عادي، بس شغّل الموقع قبل التسليم حتى تنحسب أجرتك صح');
        },
        icon: const Icon(Icons.check),
        label: const Text('استلمت من المحل — بالطريق'),
      );
    }
    if (o.status == OrderStatus.onTheWay) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('العنوان: ${o.address}'),
        Text('حصّل: ${iqd(o.total)} نقداً', style: const TextStyle(fontWeight: FontWeight.w900)),
        if (o.custLat != 0)
          TextButton.icon(
            onPressed: () => openLink(context, 'https://www.google.com/maps/dir/?api=1&destination=${o.custLat},${o.custLng}&travelmode=driving'),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('موقع الزبون على الخريطة'),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(onPressed: () => _deliver(context, o), icon: const Icon(Icons.password), label: const Text('تأكيد التسليم برمز الزبون')),
        TextButton(onPressed: () => _fail(context, o), child: const Text('تعذّر التسليم')),
      ]);
    }
    return const SizedBox.shrink();
  }

  void _fail(BuildContext context, Order o) {
    const reasons = ['الزبون ما يرد', 'العنوان غلط أو ما موجود', 'الزبون رفض يستلم'];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ليش تعذّر التسليم؟', style: TextStyle(fontWeight: FontWeight.w900)),
          for (final r in reasons)
            ListTile(
              title: Text(r),
              onTap: () {
                Navigator.pop(c);
                app.failDelivery(o, r);
                toast(context, 'انسجّل، والمشرف يتابع وياك. رجّع الطلب للمحل.');
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _deliver(BuildContext context, Order o) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رمز الزبون (4 أرقام)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, maxLength: 4),
          const Text('بعد الرمز نحدد موقعك حتى تنحسب المسافة وأجرتك تلقائياً', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (ctl.text.trim() != o.pickupCode) return toast(context, 'الرمز غلط');
              Navigator.pop(c);
              await _finishDelivery(context, o);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  /// يحدد الموقع ويسلّم. إذا الـ GPS ما اشتغل: إعادة المحاولة أو كتابة المسافة (تنعلّم للمراجعة)
  Future<void> _finishDelivery(BuildContext context, Order o) async {
    while (context.mounted) {
      final r = await locateWithProgress(context, text: 'جاري تحديد مكان التسليم…');
      if (!context.mounted) return;
      if (r.fix != null) {
        app.courierDelivered(o, r.fix);
        toast(context, 'تم التسليم واستلمت ${iqd(o.total)} • المسافة ${o.distanceKm.toStringAsFixed(1)} كم • أجرتك ${iqd(o.courierPay)}');
        return;
      }
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('ما گدرنا نحدد موقعك'),
          content: Text('${r.error}\n\nإذا كتبت المسافة بنفسك، الأجرة تتأخر لحد ما المالية تراجعها.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 'manual'), child: const Text('أكتب المسافة')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, 'retry'), child: const Text('جرّب مرة ثانية')),
          ],
        ),
      );
      if (!context.mounted || choice == null) return;
      if (choice == 'manual') {
        final km = await askKm(context, o.distanceKm, title: 'كم كيلومتر كانت التوصيلة؟');
        if (km == null || !context.mounted) return;
        app.courierDelivered(o, null, manualKm: km);
        toast(context, 'تم التسليم واستلمت ${iqd(o.total)} • المسافة تنتظر مراجعة المالية');
        return;
      }
    }
  }
}


/// أرباح المندوب: هذا الشهر + الشهور السابقة وحالة تسويتها
/// مستواي: تقييمي ونسبة المكافأة/الخصم وشكد باقي للمستوى الجاي
class _TierCard extends StatelessWidget {
  const _TierCard();
  @override
  Widget build(BuildContext context) {
    final s = app.settings;
    if (!s.ratingTiersOn || app.currentPhone == null) return const SizedBox.shrink();
    final me = app.currentPhone!;
    final t = app.tierOf(me);
    final sc = app.courierScore(me);
    final next = app.nextTierOf(me);
    final tiers = app.courierTiers;
    final colors = t.isNew
        ? const [Color(0xFF4BCDDB), Color(0xFF0E7F8A)]
        : t.pct < 0
            ? const [Color(0xFFFF8A8E), Color(0xFFE5484D)]
            : t.rank == 0
                ? const [Color(0xFFFFC24B), Color(0xFFF07B24)]
                : t.rank == 1
                    ? const [Color(0xFFB8C6CC), Color(0xFF6B7F86)]
                    : const [Color(0xFF0E7F8A), Color(0xFF06363C)];
    String hint;
    double prog;
    if (t.isNew) {
      hint = 'باقي ${s.ratingMinCount - sc.$2} تقييم حتى يتحدد مستواك';
      prog = sc.$2 / s.ratingMinCount;
    } else if (next == null) {
      hint = 'أنت بالقمة! حافظ على ${t.minStars.toStringAsFixed(1)} ★ وفوق حتى تبقى ${t.name}';
      prog = 1;
    } else {
      hint = 'وصّل لـ ${next.minStars.toStringAsFixed(1)} ★ وتصير «${next.name}» = ${tierPctText(next.pct)}';
      final lo = t.minStars, hi = next.minStars;
      prog = hi <= lo ? 0 : ((sc.$1 - lo) / (hi - lo)).clamp(0, 1).toDouble();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(t.pct < 0 ? Icons.warning_amber_rounded : Icons.workspace_premium_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مستواك: ${t.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(t.isNew ? 'أجرتك العادية لحد ما يتحدد مستواك' : '${tierPctText(t.pct)} على كل توصيلة',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
          if (sc.$2 > 0)
            Column(children: [
              Text(sc.$1.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('★ (${sc.$2})', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: prog, minHeight: 7, backgroundColor: Colors.white24, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(hint, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        if (app.priorityDelayOf(me) == 0 && !t.isNew)
          const Text('تشوف الطلبات الجديدة قبل غيرك', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))
        else if (s.ratingPrioritySec > 0)
          Text('الطلبات الجديدة توصلك بعد ${app.priorityDelayOf(me)} ثانية — «${tiers.first.name}» يشوفها أول',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in tiers)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: x.name == t.name ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${x.name} ${x.minStars.toStringAsFixed(1)}★ ${x.pct > 0 ? '+' : ''}${x.pct}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: x.name == t.name ? colors.last : Colors.white)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('ينحسب من آخر ${s.ratingWindow} تقييم. سرعة وأدب ويه الزبون = نجوم أكثر = كروة أعلى',
            style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
      ]),
    );
  }
}

/// طلب جديد محجوز للمستويات الأعلى — يفتح للمندوب بعد العدّاد
class _LockedTask extends StatefulWidget {
  final Order order;
  const _LockedTask({required this.order});
  @override
  State<_LockedTask> createState() => _LockedTaskState();
}

class _LockedTaskState extends State<_LockedTask> {
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (app.taskLockedFor(widget.order) <= 0) {
        t?.cancel();
        app.refreshUi();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = app.taskLockedFor(widget.order);
    final top = app.courierTiers.first.name;
    return AppCard(
      color: const Color(0xFFFFF6E5),
      child: Row(children: [
        const Icon(Icons.lock_clock_rounded, color: Color(0xFF8A5A00)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('طلب جديد من ${app.storeById(widget.order.storeId)?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('محجوز لمندوبين «$top» — يفتح إلك بعد $left ثانية', style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A00), fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _Earnings extends StatelessWidget {
  const _Earnings();

  @override
  Widget build(BuildContext context) {
    final list = app.myCourierStatements();
    if (list.isEmpty) return const SizedBox();
    final now = list.first;
    final s = app.settings;
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourierStatementScreen(phone: app.currentPhone!, month: now.month))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('أجوري · ${monthLabel(now.month)}', style: const TextStyle(fontWeight: FontWeight.w900))),
          Text(iqd(now.earned), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.dark)),
        ]),
        Text('${now.orders.length} توصيلة • ${now.km.toStringAsFixed(1)} كم • ${now.walletPaid == now.earned ? 'انضافت لرصيدك مباشرة' : 'التسوية آخر الشهر'}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
        if (!s.ratingTiersOn && app.courierRatingOf(app.currentPhone!).$2 > 0)
          Text('تقييمك من الزبائن: ${app.courierRatingOf(app.currentPhone!).$1.toStringAsFixed(1)} ★ (${app.courierRatingOf(app.currentPhone!).$2} تقييم)',
              style: const TextStyle(fontSize: 12, color: DepoColors.dark, fontWeight: FontWeight.w700)),
        if (s.peakBonus > 0 && s.peakHours.isNotEmpty) Text('وقت الذروة (${s.peakHours}): + ${iqd(s.peakBonus)} لكل توصيلة', style: const TextStyle(fontSize: 11, color: Color(0xFF8A5A00), fontWeight: FontWeight.w700)),
        Text('الأجرة = ${iqd(s.courierBasePay)} + ${iqd(s.courierPerKm)} لكل كم، تقريب لأقرب 250، وأقل شي ${iqd(s.courierMinPay)}', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
        const Text('اضغط حتى تشوف كل توصيلة وشلون انحسبت أجرتها', style: TextStyle(fontSize: 11, color: DepoColors.dark, fontWeight: FontWeight.w700)),
        for (final x in list.skip(1).take(3))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: Text(monthLabel(x.month), style: const TextStyle(fontSize: 12))),
              Text(iqd(x.earned), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              StatusBadge(x.balance),
            ]),
          ),
      ]),
    );
  }
}


/// رصيد المندوب (دفع مقدّم): يشحن بطرق الدفع، وكل توصيلة ينخصم مبلغ الطلب لأن الكاش صار بيده
class _WalletCard extends StatelessWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context) {
    final p = app.currentPhone ?? '';
    final s = app.settings;
    final bal = app.walletBalance(p);
    final reserved = app.walletReserved(p);
    final low = bal < s.walletLowAlert;
    final pending = app.topupRequests(phone: p);
    final moves = app.walletMoves(p);
    return AppCard(
      borderColor: low ? DepoColors.danger : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('رصيدي', style: TextStyle(fontWeight: FontWeight.w900))),
          Text(iqd(bal), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: low ? DepoColors.danger : DepoColors.dark)),
        ]),
        if (reserved > 0) Text('منها ${iqd(reserved)} محجوزة لمهامك الحالية • المتاح ${iqd(bal - reserved)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 4),
        Text(
          low
              ? (bal <= 0 ? 'رصيدك خلص — اشحن حتى تقبل مهام جديدة' : 'رصيدك قليل — اشحن قريباً حتى ما توقف المهام')
              : 'كل توصيلة: تستلم الكاش من الزبون فينخصم من رصيدك، وأجرتك تنضاف لرصيدك مباشرة',
          style: TextStyle(fontSize: 12, color: low ? DepoColors.danger : DepoColors.muted, fontWeight: low ? FontWeight.w800 : FontWeight.w500),
        ),
        const SizedBox(height: 10),
        if (pending.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFF8A5A00)),
              const SizedBox(width: 8),
              Expanded(child: Text('طلب شحن ${iqd(pending.first.amount)} بانتظار تأكيد المالية', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A5A00)))),
            ]),
          )
        else
          FilledButton.icon(onPressed: () => _topup(context), icon: const Icon(Icons.add_card_rounded), label: const Text('اشحن رصيد')),
        if (moves.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          for (final m in moves.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                Text('${m.amount > 0 ? '+' : '−'} ${iqd(m.amount.abs())}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: m.amount > 0 ? DepoColors.success : DepoColors.danger)),
              ]),
            ),
        ],
      ]),
    );
  }

  Future<void> _topup(BuildContext context) async {
    final s = app.settings;
    final amount = TextEditingController(text: '${s.walletMinTopup}');
    final ref = TextEditingController();
    final methods = s.paymentMethods.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    var method = methods.isEmpty ? 'كاش بالمكتب' : methods.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('اشحن رصيد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('أقل مبلغ ${iqd(s.walletMinTopup)} — وتگدر تشحن أكثر', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              const SizedBox(height: 8),
              TextField(controller: amount, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), decoration: const InputDecoration(suffixText: 'د.ع')),
              const SizedBox(height: 10),
              const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 6, children: [
                for (final m in methods.isEmpty ? ['كاش بالمكتب'] : methods) ChoiceChip(label: Text(m), selected: method == m, onSelected: (_) => set(() => method = m)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: ref, decoration: const InputDecoration(labelText: 'رقم العملية / الوصل (إن وجد)')),
              const SizedBox(height: 6),
              const Text('حوّل المبلغ أول، وبعدها اطلب. الرصيد ينضاف بعد ما تأكده المالية.', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('اطلب الشحن')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = app.requestTopup(parseInt(amount.text) ?? 0, method, ref.text);
    toast(context, err ?? 'انرسل طلب الشحن — ينضاف بعد تأكيد المالية');
  }
}
