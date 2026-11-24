import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'supervisor.dart';
import 'content_tab.dart';
import 'finance_tab.dart';
import 'couriers_monitor.dart';
import '../../main.dart' show errorLog;
import '../../widgets/debt_ui.dart' show copyText;

/// واجهة المدير العام: كل صلاحيات المشرف + التقارير والإعدادات والمشرفين وسجل العمليات
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = app.joinRequests.where((r) => r.status == 'pending').length;
    final openC = app.complaints.where((c) => c.status == 'open').length;
    return DefaultTabController(
      length: 13,
      child: Scaffold(
        appBar: roleAppBar('واجهة المدير العام',
            bottom: roleTabs(['التقارير', 'الحسابات', 'الإعدادات', 'المحتوى', 'المشرفين', 'طلبات الانضمام ($pending)', 'الطلبات', 'المندوبين', 'محادثات الدعم', 'الشكاوى ($openC)', 'المستخدمين', 'العروض والمحلات', 'سجل العمليات'])),
        // ignore: prefer_const_constructors
        body: TabBarView(children: [
          ReportsTab(),
          FinanceTab(),
          _SettingsTab(),
          ContentTab(),
          _SupervisorsTab(),
          JoinRequestsTab(),
          OrdersMonitorTab(),
          CouriersMonitorTab(),
          SupportChatsTab(),
          ComplaintsTab(),
          UsersTab(),
          OffersStoresTab(),
          AuditTab(),
        ]),
      ),
    );
  }
}

enum _Period { today, week, month, all }

const _periodNames = {
  _Period.today: 'اليوم',
  _Period.week: 'هالأسبوع',
  _Period.month: 'هالشهر',
  _Period.all: 'الكل',
};

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  _Period period = _Period.month;

  /// بداية الفترة (الأسبوع يبدي من السبت)
  int get _from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case _Period.today:
        return today.millisecondsSinceEpoch;
      case _Period.week:
        final back = (today.weekday - DateTime.saturday) % 7;
        return today.subtract(Duration(days: back)).millisecondsSinceEpoch;
      case _Period.month:
        return DateTime(now.year, now.month).millisecondsSinceEpoch;
      case _Period.all:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final inRange = app.orders.where((o) => o.createdAt >= from).toList();
    final delivered = inRange.where((o) => o.status == OrderStatus.delivered).toList();
    final gmv = delivered.fold(0, (s, o) => s + o.itemsTotal);
    final comm = delivered.fold(0, (s, o) => s + o.commission);
    final saved = delivered.fold(0, (s, o) => s + (o.originalTotal - o.itemsTotal));
    final rawaji = delivered.where((o) => app.storeById(o.storeId)?.type == StoreType.restaurant).length;
    final open = app.orders.where((o) => o.isOpen).length;
    final cancelled = inRange.where((o) => o.status == OrderStatus.rejected || o.status == OrderStatus.cancelled).length;
    final customers = app.users.where((u) => u.role == Role.customer).toList();
    final newCustomers = customers.where((u) => u.createdAt >= from).length;
    final avg = delivered.isEmpty ? 0 : (gmv / delivered.length).round();
    final label = _periodNames[period]!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Period>(
          showSelectedIcon: false,
          segments: [for (final p in _Period.values) ButtonSegment(value: p, label: Text(_periodNames[p]!))],
          selected: {period},
          onSelectionChanged: (v) => setState(() => period = v.first),
        ),
        const SizedBox(height: 12),
        StatGrid([
          StatTile('المبيعات ($label)', iqd(gmv)),
          StatTile('عمولات Depo', iqd(comm)),
          StatTile('طلبات مُسلّمة', '${delivered.length}'),
          StatTile('متوسط الطلب', iqd(avg)),
          StatTile('طلبات رواجع', '$rawaji'),
          StatTile('طلبات ماركت', '${delivered.length - rawaji}'),
          StatTile('مرفوضة / ملغية', '$cancelled'),
          StatTile('مفتوحة هسه', '$open'),
          StatTile('زبائن جدد', '$newCustomers'),
          StatTile('كل الزبائن', '${customers.length}'),
        ]),
        const SizedBox(height: 10),
        AppCard(
          color: DepoColors.successBg,
          borderColor: DepoColors.successBg,
          child: Text('$label: وفّرنا للزبائن ${iqd(saved)} وبعنا ${delivered.fold(0, (s, o) => s + o.lines.fold(0, (a, l) => a + l.qty))} وجبة ومنتج',
              style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
        ),
        SectionTitle('حسب المحل ($label)'),
        for (final s in [...app.stores]..sort((a, b) => _sales(b.id, delivered) - _sales(a.id, delivered)))
          AppCard(
            child: Builder(builder: (context) {
              final os = delivered.where((o) => o.storeId == s.id).toList();
              final sales = os.fold(0, (a, o) => a + o.itemsTotal);
              final c = os.fold(0, (a, o) => a + o.commission);
              return Row(children: [
                Expanded(child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('${os.length} طلب • ${iqd(sales)} • عمولة ${iqd(c)}', style: const TextStyle(fontSize: 12)),
              ]);
            }),
          ),
        const Text('الأرقام تحسب الطلبات المُسلّمة بس. «مفتوحة هسه» ما تتأثر بالفترة.',
            style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      ],
    );
  }

  int _sales(String storeId, List<Order> delivered) =>
      delivered.where((o) => o.storeId == storeId).fold(0, (a, o) => a + o.itemsTotal);
}

class _SettingsTab extends StatefulWidget {
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final Map<String, TextEditingController> c;
  late final TextEditingController campaign;
  bool firstFree = true;
  late bool allowPickup = app.settings.allowPickup;
  late bool allowStoreDelivery = app.settings.allowStoreDelivery;
  late bool loyaltyOn = app.settings.loyaltyOn;
  late bool scratchOn = app.settings.scratchOn;

  @override
  void initState() {
    super.initState();
    final s = app.settings;
    c = {
      'restaurantCommission': TextEditingController(text: '${s.restaurantCommission}'),
      'minCommission': TextEditingController(text: '${s.minCommission}'),
      'merchantCommission': TextEditingController(text: '${s.merchantCommission}'),
      'freeDays': TextEditingController(text: '${s.freeDays}'),
      'deliveryFee': TextEditingController(text: '${s.deliveryFee}'),
      'freeDeliveryThreshold': TextEditingController(text: '${s.freeDeliveryThreshold}'),
      'stage1Km': TextEditingController(text: '${s.stage1Km}'),
      'stage2Km': TextEditingController(text: '${s.stage2Km}'),
      'stage2Minutes': TextEditingController(text: '${s.stage2Minutes}'),
      'stage3Minutes': TextEditingController(text: '${s.stage3Minutes}'),
      'campaignMinDiscount': TextEditingController(text: '${s.campaignMinDiscount}'),
      'courierBasePay': TextEditingController(text: '${s.courierBasePay}'),
      'courierPerKm': TextEditingController(text: '${s.courierPerKm}'),
      'courierMinPay': TextEditingController(text: '${s.courierMinPay}'),
      'courierMaxKm': TextEditingController(text: '${s.courierMaxKm}'),
      'courierMaxPay': TextEditingController(text: '${s.courierMaxPay}'),
      'walletMinTopup': TextEditingController(text: '${s.walletMinTopup}'),
      'walletLowAlert': TextEditingController(text: '${s.walletLowAlert}'),
      'paymentMethods': TextEditingController(text: s.paymentMethods),
      'restaurantMarkup': TextEditingController(text: '${s.restaurantMarkup}'),
      'merchantMarkup': TextEditingController(text: '${s.merchantMarkup}'),
      'roadFactor': TextEditingController(text: '${s.roadFactor}'),
      'gpsMaxAccuracy': TextEditingController(text: '${s.gpsMaxAccuracy}'),
      'peakBonus': TextEditingController(text: '${s.peakBonus}'),
      'peakHours': TextEditingController(text: s.peakHours),
      'stampsNeeded': TextEditingController(text: '${s.stampsNeeded}'),
      'stampReward': TextEditingController(text: '${s.stampReward}'),
      'stampRewardCap': TextEditingController(text: '${s.stampRewardCap}'),
      'stampExpiryDays': TextEditingController(text: '${s.stampExpiryDays}'),
      'scratchPrizes': TextEditingController(text: s.scratchPrizes),
      'scratchMinOrder': TextEditingController(text: '${s.scratchMinOrder}'),
      'couponDays': TextEditingController(text: '${s.couponDays}'),
    };
    campaign = TextEditingController(text: s.campaignName);
    firstFree = s.firstOrderFree;
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    campaign.dispose();
    super.dispose();
  }

  Widget f(String key, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c[key], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label)),
      );

  void _save() {
    int v(String k, int def) => parseInt(c[k]!.text) ?? def;
    final s = app.settings;
    s.restaurantCommission = v('restaurantCommission', s.restaurantCommission);
    s.minCommission = v('minCommission', s.minCommission);
    s.merchantCommission = v('merchantCommission', s.merchantCommission);
    s.freeDays = v('freeDays', s.freeDays);
    s.deliveryFee = v('deliveryFee', s.deliveryFee);
    s.freeDeliveryThreshold = v('freeDeliveryThreshold', s.freeDeliveryThreshold);
    s.stage1Km = v('stage1Km', s.stage1Km);
    s.stage2Km = v('stage2Km', s.stage2Km);
    s.stage2Minutes = v('stage2Minutes', s.stage2Minutes);
    s.stage3Minutes = v('stage3Minutes', s.stage3Minutes);
    s.campaignMinDiscount = v('campaignMinDiscount', s.campaignMinDiscount);
    s.courierBasePay = v('courierBasePay', s.courierBasePay);
    s.courierPerKm = v('courierPerKm', s.courierPerKm);
    s.courierMinPay = v('courierMinPay', s.courierMinPay);
    s.courierMaxKm = v('courierMaxKm', s.courierMaxKm).clamp(1, 200);
    s.courierMaxPay = v('courierMaxPay', s.courierMaxPay);
    if (s.courierMaxPay < s.courierMinPay) s.courierMaxPay = s.courierMinPay;
    s.walletMinTopup = v('walletMinTopup', s.walletMinTopup);
    s.walletLowAlert = v('walletLowAlert', s.walletLowAlert);
    s.paymentMethods = c['paymentMethods']!.text.replaceAll('،', ',').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
    s.roadFactor = v('roadFactor', s.roadFactor).clamp(100, 250);
    s.gpsMaxAccuracy = v('gpsMaxAccuracy', s.gpsMaxAccuracy).clamp(20, 1000);
    s.peakBonus = c['peakBonus']!.text.trim().isEmpty ? 0 : v('peakBonus', s.peakBonus); // فارغة = صفر
    final ph = c['peakHours']!.text.replaceAll(' ', '').replaceAll('،', ',');
    if (RegExp(r'^(\d{1,2}-\d{1,2})(,\d{1,2}-\d{1,2})*$').hasMatch(ph) || ph.isEmpty) s.peakHours = ph;
    s.campaignName = campaign.text.trim().isEmpty ? s.campaignName : campaign.text.trim();
    s.firstOrderFree = firstFree;
    s.restaurantMarkup = c['restaurantMarkup']!.text.trim().isEmpty ? 0 : v('restaurantMarkup', s.restaurantMarkup).clamp(0, 100);
    s.merchantMarkup = c['merchantMarkup']!.text.trim().isEmpty ? 0 : v('merchantMarkup', s.merchantMarkup).clamp(0, 100);
    s.allowPickup = allowPickup;
    s.allowStoreDelivery = allowStoreDelivery;
    s.loyaltyOn = loyaltyOn;
    s.scratchOn = scratchOn;
    s.stampsNeeded = v('stampsNeeded', s.stampsNeeded).clamp(2, 20);
    s.stampReward = v('stampReward', s.stampReward).clamp(1, 100);
    s.stampRewardCap = v('stampRewardCap', s.stampRewardCap).clamp(250, 1000000);
    s.stampExpiryDays = v('stampExpiryDays', s.stampExpiryDays).clamp(1, 365);
    final pr = c['scratchPrizes']!.text.replaceAll(' ', '').replaceAll('،', ',');
    if (RegExp(r'^\d+:\d+(,\d+:\d+)*$').hasMatch(pr)) s.scratchPrizes = pr;
    s.scratchMinOrder = v('scratchMinOrder', s.scratchMinOrder);
    s.couponDays = v('couponDays', s.couponDays).clamp(1, 90);
    app.saveSettings();
    toast(context, 'انحفظت الإعدادات وتسري على الطلبات الجديدة');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('العمولات'),
        Row(children: [Expanded(child: f('restaurantCommission', 'عمولة المطاعم %')), const SizedBox(width: 10), Expanded(child: f('minCommission', 'الحد الأدنى (د.ع)'))]),
        Row(children: [Expanded(child: f('merchantCommission', 'عمولة التجار %')), const SizedBox(width: 10), Expanded(child: f('freeDays', 'الشهر المجاني (يوم)'))]),
        const SectionTitle('التوصيل'),
        Row(children: [Expanded(child: f('deliveryFee', 'رسم التوصيل')), const SizedBox(width: 10), Expanded(child: f('freeDeliveryThreshold', 'توصيل مجاني فوق'))]),
        const SectionTitle('أجرة المندوب (حسب المسافة)'),
        Row(children: [Expanded(child: f('courierBasePay', 'ثابت لكل طلب')), const SizedBox(width: 10), Expanded(child: f('courierPerKm', 'لكل كيلومتر'))]),
        Row(children: [Expanded(child: f('courierMinPay', 'الحد الأدنى للأجرة')), const SizedBox(width: 10), Expanded(child: f('courierMaxKm', 'أقصى مسافة تنحسب (كم)'))]),
        Row(children: [Expanded(child: f('courierMaxPay', 'أعلى أجرة للتوصيلة')), const SizedBox(width: 10), const Expanded(child: SizedBox())]),
        const SectionTitle('رصيد المندوب (دفع مقدّم)'),
        Row(children: [Expanded(child: f('walletMinTopup', 'أقل مبلغ شحن')), const SizedBox(width: 10), Expanded(child: f('walletLowAlert', 'تنبيه إذا الرصيد أقل من'))]),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: c['paymentMethods'], decoration: const InputDecoration(labelText: 'طرق الدفع للشحن', helperText: 'مفصولة بفاصلة، مثل: زين كاش,FIB,كي كارد,كاش بالمكتب')),
        ),
        const Text('المندوب يشحن رصيد، وكل توصيلة يستلم الكاش من الزبون وينخصم مبلغ الطلب من رصيده. ما يقبل مهمة إذا رصيده ما يكفيها.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: f('roadFactor', 'معامل الطرق % (130 = الطريق أطول 30%)')), const SizedBox(width: 10), Expanded(child: f('gpsMaxAccuracy', 'أسوأ دقة GPS مقبولة (متر)'))]),
        const Text('المسافة = الخط المستقيم بين المحل ومكان التسليم (GPS) × معامل الطرق.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: f('peakBonus', 'مكافأة الذروة لكل توصيلة')),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: c['peakHours'], textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'ساعات الذروة', helperText: 'مثل: 12-15,19-23')),
            ),
          ),
        ]),
        Builder(builder: (context) {
          final t = AppSettings(
            courierBasePay: parseInt(c['courierBasePay']!.text) ?? 0,
            courierPerKm: parseInt(c['courierPerKm']!.text) ?? 0,
            courierMinPay: parseInt(c['courierMinPay']!.text) ?? 0,
            courierMaxKm: parseInt(c['courierMaxKm']!.text) ?? 30,
          );
          return Text('مثال: 2 كم = ${iqd(t.courierPayFor(2))} • 5 كم = ${iqd(t.courierPayFor(5))} • 10 كم = ${iqd(t.courierPayFor(10))}\nالأجرة تتقرّب لأقرب 250 وما تنزل عن الحد الأدنى. التعديل يسري على التوصيلات الجديدة بس، والقديمة تبقى بتسعيرتها. التسوية شهرية من تبويب «الحسابات».',
              style: const TextStyle(fontSize: 12, color: DepoColors.muted));
        }),
        const SizedBox(height: 8),
        const SectionTitle('زيادة الأسعار (مخفية)'),
        Row(children: [Expanded(child: f('restaurantMarkup', 'نسبة زيادة المطاعم %')), const SizedBox(width: 10), Expanded(child: f('merchantMarkup', 'نسبة زيادة الماركت %'))]),
        Builder(builder: (context) {
          final r = parseInt(c['restaurantMarkup']!.text) ?? 0;
          final x = r <= 0 ? 20000 : ((20000 * (100 + r) / 100) / 250).ceil() * 250;
          return Text('مثال: المطعم يكتب 20,000 ← الزبون يشوف ويدفع ${iqd(x)}. المحل يشوف سعره هو بس، والعمولة تنحسب على سعره. الزيادة تتقرّب لأقرب 250 وتسري على الطلبات الجديدة.',
              style: const TextStyle(fontSize: 12, color: DepoColors.muted));
        }),
        const SizedBox(height: 8),
        const SectionTitle('طرق الاستلام'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              value: allowPickup,
              onChanged: (v) => setState(() => allowPickup = v),
              title: const Text('«أستلم بنفسي» من المحل', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('مطفي = كل الطلبات توصيل بمندوبي ديبو'),
            ),
            SwitchListTile(
              value: allowStoreDelivery,
              onChanged: (v) => setState(() => allowStoreDelivery = v),
              title: const Text('التوصيل بمندوب المحل', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('مطفي = زر «أوصله بمندوبي» ما يطلع للمحل'),
            ),
          ]),
        ),
        const SectionTitle('الولاء (لعبة الأختام وكروت الخدش)'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: loyaltyOn,
              onChanged: (v) => setState(() => loyaltyOn = v),
              title: const Text('بطاقة أختام بكل محل', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('كل طلب يوصل = ختم، وتكمل البطاقة = خصم'),
            ),
            f('stampsNeeded', 'كم ختم حتى الهدية'),
            f('stampReward', 'خصم الهدية %'),
            f('stampRewardCap', 'أعلى خصم للهدية (د.ع)'),
            f('stampExpiryDays', 'الأختام تنتهي إذا ما طلب خلال (يوم)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: scratchOn,
              onChanged: (v) => setState(() => scratchOn = v),
              title: const Text('كرت خدش بعد كل طلب', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('يطلع للزبون قسيمة عشوائية'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: c['scratchPrizes'],
                decoration: const InputDecoration(labelText: 'جوائز الخدش (مبلغ:وزن)', helperText: 'مثال 250:45,500:30,1000:17 — الوزن الأكبر يطلع أكثر. 0 = حظ أوفر'),
              ),
            ),
            f('scratchMinOrder', 'أقل طلب حتى تنفع القسيمة (د.ع)'),
            f('couponDays', 'صلاحية القسيمة (يوم)'),
            Builder(builder: (_) {
              final t = app.scratchTable;
              final w = t.fold(0, (a, e) => a + e.$2);
              final avg = w == 0 ? 0 : t.fold(0, (a, e) => a + e.$1 * e.$2) ~/ w;
              return Text('معدّل كلفة الكرت ≈ ${iqd(avg)} (قبل ما ينحفظ التعديل). الهدايا والقسائم على ديبو، والمحل ياخذ حقه كامل.',
                  style: const TextStyle(fontSize: 12, color: DepoColors.muted));
            }),
          ]),
        ),
        const SectionTitle('العروض والحملات'),
        AppCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            value: firstFree,
            onChanged: (v) => setState(() => firstFree = v),
            title: const Text('توصيل مجاني لأول طلب', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('لكل زبون جديد'),
          ),
        ),
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: campaign, decoration: const InputDecoration(labelText: 'اسم الحملة')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: f('campaignMinDiscount', 'أقل خصم للحملة %')),
        ]),
        const SectionTitle('مراحل إشعار الرواجع'),
        Row(children: [Expanded(child: f('stage1Km', 'المرحلة 1: كم')), const SizedBox(width: 10), Expanded(child: f('stage2Km', 'المرحلة 2: كم'))]),
        Row(children: [Expanded(child: f('stage2Minutes', 'المرحلة 2 بعد (دقيقة)')), const SizedBox(width: 10), Expanded(child: f('stage3Minutes', 'المرحلة 3 بعد (دقيقة)'))]),
        const Text('المرحلة 3 = كل الموصل. المتابعين يوصلهم الإشعار بأول مرحلة دائماً.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('حفظ الإعدادات')),
        if (app.hasDemoData) ...[
          const SizedBox(height: 24),
          const SectionTitle('قبل الإطلاق'),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: DepoColors.danger, side: const BorderSide(color: DepoColors.danger)),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('تحذف البيانات التجريبية؟'),
                  content: const Text('تنشال المحلات والحسابات التجريبية (أرقام 0700000…) وعروضها وطلباتها. الحسابات الحقيقية تبقى.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                    FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
                  ],
                ),
              );
              if (ok == true) {
                app.removeDemoData();
                if (context.mounted) toast(context, 'انحذفت البيانات التجريبية');
              }
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('حذف البيانات التجريبية'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('سجل الأخطاء (${errorLog.length})'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: errorLog.isEmpty
                      ? const Text('ماكو أخطاء بهذي الجلسة ✓')
                      : ListView(shrinkWrap: true, children: [
                          for (final e in errorLog.reversed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(e, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11))),
                        ]),
                ),
                actions: [
                  if (errorLog.isNotEmpty) TextButton(onPressed: () => copyText(c, errorLog.reversed.join('\n\n'), done: 'انسخ السجل'), child: const Text('نسخ')),
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('سد')),
                ],
              ),
            ),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('سجل الأخطاء (للدعم الفني)'),
          ),
        ],
      ],
    );
  }
}

class _SupervisorsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sups = app.users.where((u) => u.role == Role.supervisor).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.person_add_alt), label: const Text('أضف مشرف برقم التلفون')),
        const SizedBox(height: 6),
        const Text('الشخص لازم يكون مسجّل بالتطبيق أول. كل مشرف تحدد أقسامه، وما يشوف غير صلاحياتها.',
            style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 10),
        if (sups.isEmpty) const EmptyState(icon: Icons.supervisor_account_outlined, text: 'ماكو مشرفين بعد'),
        for (final u in sups)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${u.name.isEmpty ? u.phone : u.name} — ${u.phone}', style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(tooltip: 'الأقسام', onPressed: () => editPerms(context, u), icon: const Icon(Icons.tune_rounded)),
                TextButton(onPressed: () => app.setRole(u, Role.customer), child: const Text('شيل الإشراف')),
              ]),
              if (u.perms.isEmpty)
                const Text('بدون أقسام — ما يشوف شي لحد ما تحدد أقسامه', style: TextStyle(fontSize: 12, color: DepoColors.danger, fontWeight: FontWeight.w700))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final p in app.permsOf(u)) Badge2(permNames[p]!, bg: DepoColors.soft, fg: DepoColors.dark),
                ]),
            ]),
          ),
      ],
    );
  }

  void _add(BuildContext context) {
    final ctl = TextEditingController(text: '07');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رقم المشرف'),
        content: TextField(controller: ctl, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () {
              final u = app.userByPhone(ctl.text.trim());
              if (u == null) {
                toast(context, 'هذا الرقم مو مسجّل بالتطبيق');
              } else if (u.phone == app.currentPhone) {
                toast(context, 'هذا رقمك أنت');
              } else {
                app.setRole(u, Role.supervisor);
                Navigator.pop(c);
                editPerms(context, u);
              }
            },
            child: const Text('التالي: الأقسام'),
          ),
        ],
      ),
    );
  }
}

/// نافذة تحديد أقسام المشرف
Future<void> editPerms(BuildContext context, AppUser u) async {
  final sel = app.permsOf(u);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('أقسام ${u.name.isEmpty ? u.phone : u.name}'),
        content: SizedBox(
          width: 420,
          child: ListView(shrinkWrap: true, children: [
            for (final p in Perm.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sel.contains(p),
                onChanged: (v) => set(() => v == true ? sel.add(p) : sel.remove(p)),
                title: Text(permNames[p]!, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(permDesc[p]!, style: const TextStyle(fontSize: 12)),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
        ],
      ),
    ),
  );
  if (ok == true) {
    app.setPerms(u, sel);
    if (context.mounted) toast(context, 'انحفظت الأقسام');
  }
}

class AuditTab extends StatelessWidget {
  const AuditTab({super.key});
  @override
  Widget build(BuildContext context) {
    if (app.audit.isEmpty) return const EmptyState(icon: Icons.history, text: 'ماكو عمليات مسجلة بعد');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('السجل ما ينحذف ولا ينعدّل', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        for (final a in app.audit) AppCard(child: Text(a, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
