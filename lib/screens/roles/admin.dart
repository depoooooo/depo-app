import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'supervisor.dart';

/// واجهة المدير العام: كل صلاحيات المشرف + التقارير والإعدادات والمشرفين وسجل العمليات
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = app.joinRequests.where((r) => r.status == 'pending').length;
    final openC = app.complaints.where((c) => c.status == 'open').length;
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        appBar: roleAppBar('واجهة المدير العام',
            bottom: roleTabs(['التقارير', 'الإعدادات', 'المشرفين', 'طلبات الانضمام ($pending)', 'الطلبات', 'محادثات الدعم', 'الشكاوى ($openC)', 'المستخدمين', 'العروض والمحلات', 'سجل العمليات'])),
        // ignore: prefer_const_constructors
        body: TabBarView(children: [
          ReportsTab(),
          _SettingsTab(),
          _SupervisorsTab(),
          JoinRequestsTab(),
          OrdersMonitorTab(),
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
          child: Text('$label: وفّرنا للزبائن ${iqd(saved)} وأنقذنا ${delivered.fold(0, (s, o) => s + o.lines.fold(0, (a, l) => a + l.qty))} وجبة ومنتج',
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
  late final TextEditingController promo;
  late final TextEditingController campaign;
  bool firstFree = true;

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
    };
    promo = TextEditingController(text: s.promoText);
    campaign = TextEditingController(text: s.campaignName);
    firstFree = s.firstOrderFree;
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    promo.dispose();
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
    s.promoText = promo.text.trim();
    s.campaignName = campaign.text.trim().isEmpty ? s.campaignName : campaign.text.trim();
    s.firstOrderFree = firstFree;
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
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: promo, decoration: const InputDecoration(labelText: 'نص الشريط البرتقالي فوق (فارغ = مطفي)')),
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
