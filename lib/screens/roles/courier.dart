import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../orders.dart';

/// واجهة المندوب
class CourierHome extends StatelessWidget {
  const CourierHome({super.key});

  static const cashCap = 100000; // سقف النقد — يضبطه المدير لاحقاً

  @override
  Widget build(BuildContext context) {
    final cash = app.courierCash;
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
              subtitle: const Text('إذن الموقع بالخلفية ينطلب بالتطبيق على التلفون بس'),
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
                  child: Text('وصلت السقف. سلّم النقد لـ Depo حتى تجيك مهام جديدة.', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
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
                  FilledButton(onPressed: () => app.takeTask(o), child: const Text('قبول المهمة')),
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
        TextButton(onPressed: () => toast(context, 'تسجيل «تعذّر التسليم» ويه صورة يتفعل ويه Firebase'), child: const Text('تعذّر التسليم')),
      ]);
    }
    return const SizedBox.shrink();
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
            onPressed: () {
              if (ctl.text.trim() == o.pickupCode) {
                app.setStatus(o, OrderStatus.delivered);
                Navigator.pop(c);
                toast(context, 'تم التسليم واستلمت ${iqd(o.total)}');
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
