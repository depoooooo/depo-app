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
      length: 9,
      child: Scaffold(
        appBar: roleAppBar('واجهة المدير العام',
            bottom: roleTabs(['التقارير', 'الإعدادات', 'المشرفين', 'طلبات الانضمام ($pending)', 'الطلبات', 'الشكاوى ($openC)', 'المستخدمين', 'العروض والمحلات', 'سجل العمليات'])),
        // ignore: prefer_const_constructors
        body: TabBarView(children: [
          _ReportsTab(),
          _SettingsTab(),
          _SupervisorsTab(),
          JoinRequestsTab(),
          OrdersMonitorTab(),
          ComplaintsTab(),
          UsersTab(),
          OffersStoresTab(),
          _AuditTab(),
        ]),
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final delivered = app.deliveredOrders;
    final rawaji = delivered.where((o) => app.storeById(o.storeId)?.type == StoreType.restaurant).length;
    final open = app.orders.where((o) => o.isOpen).length;
    final customers = app.users.where((u) => u.role == Role.customer).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatGrid([
          StatTile('مجموع المبيعات (GMV)', iqd(app.gmv)),
          StatTile('عمولات Depo', iqd(app.totalCommission)),
          StatTile('طلبات مُسلّمة', '${delivered.length}'),
          StatTile('طلبات مفتوحة', '${open}'),
          StatTile('طلبات رواجع', '$rawaji'),
          StatTile('طلبات ماركت', '${delivered.length - rawaji}'),
          StatTile('الزبائن', '$customers'),
          StatTile('المحلات', '${app.stores.length}'),
        ]),
        const SizedBox(height: 10),
        AppCard(
          color: DepoColors.successBg,
          borderColor: DepoColors.successBg,
          child: Text('وفّرنا للزبائن ${iqd(app.savedForCustomers)} وأنقذنا ${delivered.fold(0, (s, o) => s + o.lines.fold(0, (a, l) => a + l.qty))} وجبة ومنتج',
              style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800)),
        ),
        const SectionTitle('حسب المحل'),
        for (final s in app.stores)
          AppCard(
            child: Builder(builder: (context) {
              final os = app.ordersOfStore(s.id).where((o) => o.status == OrderStatus.delivered).toList();
              final sales = os.fold(0, (a, o) => a + o.itemsTotal);
              final comm = os.fold(0, (a, o) => a + o.commission);
              return Row(children: [
                Expanded(child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('${os.length} طلب • ${iqd(sales)} • عمولة ${iqd(comm)}', style: const TextStyle(fontSize: 12)),
              ]);
            }),
          ),
        const Text('التقارير التفصيلية والتصدير لـ Excel تنضاف ويه لوحة الويب.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      ],
    );
  }
}

class _SettingsTab extends StatefulWidget {
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final Map<String, TextEditingController> c;

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
    };
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
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
        const SectionTitle('مراحل إشعار الرواجع'),
        Row(children: [Expanded(child: f('stage1Km', 'المرحلة 1: كم')), const SizedBox(width: 10), Expanded(child: f('stage2Km', 'المرحلة 2: كم'))]),
        Row(children: [Expanded(child: f('stage2Minutes', 'المرحلة 2 بعد (دقيقة)')), const SizedBox(width: 10), Expanded(child: f('stage3Minutes', 'المرحلة 3 بعد (دقيقة)'))]),
        const Text('المرحلة 3 = كل الموصل. المتابعين يوصلهم الإشعار بأول مرحلة دائماً.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('حفظ الإعدادات')),
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
        const Text('الشخص لازم يكون مسجّل بالتطبيق أول. المدير العام بس يرفع المشرفين.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 10),
        if (sups.isEmpty) const EmptyState(icon: Icons.supervisor_account_outlined, text: 'ماكو مشرفين بعد'),
        for (final u in sups)
          AppCard(
            child: Row(children: [
              Expanded(child: Text('${u.name.isEmpty ? u.phone : u.name} — ${u.phone}', style: const TextStyle(fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => app.setRole(u, Role.customer), child: const Text('شيل الصلاحية')),
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
            onPressed: () {
              final u = app.userByPhone(ctl.text.trim());
              if (u == null) {
                toast(context, 'هذا الرقم مو مسجّل بالتطبيق');
              } else {
                app.setRole(u, Role.supervisor);
                Navigator.pop(c);
                toast(context, 'صار مشرف');
              }
            },
            child: const Text('رفع'),
          ),
        ],
      ),
    );
  }
}

class _AuditTab extends StatelessWidget {
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
