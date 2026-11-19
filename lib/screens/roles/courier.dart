import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../orders.dart';
import '../../widgets/debt_ui.dart';
import 'finance_tab.dart';

/// واجهة المندوب
class CourierHome extends StatelessWidget {
  const CourierHome({super.key});

  @override
  Widget build(BuildContext context) {
    final cash = app.courierCash;
    final cashCap = app.settings.courierCashCap;
    final overCap = cash >= cashCap;
    final available = app.courierAvailable && !overCap;
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
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Expanded(child: Text('النقد اللي بيدك')), Text('${iqd(cash)} / ${iqd(cashCap)}', style: const TextStyle(fontWeight: FontWeight.w900))]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (cash / cashCap).clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(4)),
              if (overCap)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('وصلت السقف. سلّم النقد للمشرف حتى تجيك مهام جديدة.', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800)),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('المشرف يصفّر الرصيد من يستلم منك النقد', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
                ),
            ]),
          ),
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
              OrderTile(
                order: o,
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('استلم من: ${app.storeById(o.storeId)?.fullName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('سلّم إلى: ${o.address}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('حصّل من الزبون: ${iqd(o.total)}', style: const TextStyle(color: DepoColors.dark, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: () async {
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
        onPressed: () => app.setStatus(o, OrderStatus.onTheWay),
        icon: const Icon(Icons.check),
        label: const Text('استلمت من المحل — بالطريق'),
      );
    }
    if (o.status == OrderStatus.onTheWay) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('العنوان: ${o.address}'),
        Text('حصّل: ${iqd(o.total)} نقداً', style: const TextStyle(fontWeight: FontWeight.w900)),
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
        content: TextField(controller: ctl, keyboardType: TextInputType.number, textDirection: TextDirection.ltr, maxLength: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (ctl.text.trim() == o.pickupCode) {
                Navigator.pop(c);
                final km = await askKm(context, o.distanceKm, title: 'كم كيلومتر كانت التوصيلة؟');
                if (km != null) app.setDeliveryKm(o, km);
                app.setStatus(o, OrderStatus.delivered);
                if (context.mounted) toast(context, 'تم التسليم واستلمت ${iqd(o.total)} • أجرتك ${iqd(o.courierPay)}');
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


/// أرباح المندوب: هذا الشهر + الشهور السابقة وحالة تسويتها
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
        Text('${now.orders.length} توصيلة • ${now.km.toStringAsFixed(1)} كم • التسوية آخر الشهر', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
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
