import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

AppBar roleAppBar(String title, {PreferredSizeWidget? bottom}) => AppBar(
      backgroundColor: DepoColors.ink,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
      title: Text(title),
      bottom: bottom,
    );

TabBar roleTabs(List<String> labels) => TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: DepoColors.brand,
      labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800),
      tabs: [for (final l in labels) Tab(text: l)],
    );

/// واجهة المشرف
class SupervisorHome extends StatelessWidget {
  const SupervisorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = app.joinRequests.where((r) => r.status == 'pending').length;
    final openC = app.complaints.where((c) => c.status == 'open').length;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: roleAppBar('واجهة المشرف', bottom: roleTabs(['طلبات الانضمام ($pending)', 'الطلبات', 'الشكاوى ($openC)', 'المستخدمين', 'العروض والمحلات'])),
        // ignore: prefer_const_constructors
        body: TabBarView(children: [JoinRequestsTab(), OrdersMonitorTab(), ComplaintsTab(), UsersTab(), OffersStoresTab()]),
      ),
    );
  }
}

class JoinRequestsTab extends StatelessWidget {
  const JoinRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final list = app.joinRequests;
    if (list.isEmpty) return const EmptyState(icon: Icons.how_to_reg_outlined, text: 'ماكو طلبات انضمام');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in list)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(r.type == Role.restaurant ? Icons.restaurant : (r.type == Role.merchant ? Icons.storefront : Icons.delivery_dining), color: DepoColors.dark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.storeName.isEmpty ? r.name : '${r.storeName} — ${r.area}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                Badge2(r.status == 'pending' ? 'جديد' : (r.status == 'approved' ? 'مقبول' : 'مرفوض'),
                    bg: r.status == 'pending' ? DepoColors.accent : DepoColors.soft),
              ]),
              Text('${roleNames[r.type]} • ${r.name} • ${r.phone} • ${timeAgo(r.createdAt)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              if (r.details.isNotEmpty) Text(r.details, style: const TextStyle(fontSize: 12)),
              if (r.note.isNotEmpty) Text('السبب: ${r.note}', style: const TextStyle(fontSize: 12, color: DepoColors.danger)),
              if (r.status == 'pending') ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        app.approveJoin(r);
                        toast(context, 'تمت الموافقة وتحوّلت واجهة الحساب');
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('موافقة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _inspection(context, r), child: const Text('تفتيش'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _reject(context, r), child: const Text('رفض'))),
                ]),
              ],
            ]),
          ),
      ],
    );
  }

  void _inspection(BuildContext context, JoinRequest r) {
    const items = ['إجازة صحية وسجل تجاري', 'نظافة المطبخ أو المحل', 'مكان التخزين نظيف', 'الثلاجات تشتغل زين', 'التواريخ واضحة على المنتجات', 'العمال عدهم شهادات صحية', 'مكان مناسب للتسليم'];
    final checked = <String>{};
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('قائمة التفتيش'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final i in items)
                CheckboxListTile(
                  value: checked.contains(i),
                  onChanged: (v) => set(() => v == true ? checked.add(i) : checked.remove(i)),
                  title: Text(i, style: const TextStyle(fontSize: 13)),
                  dense: true,
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
            FilledButton(
              onPressed: checked.length == items.length
                  ? () {
                      app.approveJoin(r);
                      Navigator.pop(c);
                      toast(context, 'نجح التفتيش وانقبل الطلب');
                    }
                  : null,
              child: Text('نجح (${checked.length}/${items.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _reject(BuildContext context, JoinRequest r) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: ctl, decoration: const InputDecoration(hintText: 'مثلاً: الإجازة الصحية منتهية')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              app.rejectJoin(r, ctl.text.trim());
              Navigator.pop(c);
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}

class OrdersMonitorTab extends StatelessWidget {
  const OrdersMonitorTab({super.key});

  @override
  Widget build(BuildContext context) {
    final open = app.orders.where((o) => o.isOpen).toList();
    final late = open.where((o) => DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(o.createdAt)).inMinutes > 40).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatGrid([StatTile('طلبات مفتوحة', '${open.length}'), StatTile('متأخرة (+40 د)', '${late.length}')]),
        const SizedBox(height: 10),
        if (app.couriersCash.isNotEmpty) ...[
          const SectionTitle('النقد عند المندوبين'),
          for (final e in app.couriersCash.entries)
            AppCard(
              child: Row(children: [
                const Icon(Icons.delivery_dining, color: DepoColors.dark),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.userByPhone(e.key)?.name ?? e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${e.key} • بيده ${iqd(e.value)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                  ]),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('استلمت النقد؟'),
                        content: Text('تأكد إنك استلمت ${iqd(e.value)} من المندوب قبل ما تصفّر حسابه.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('إي، استلمت')),
                        ],
                      ),
                    );
                    if (ok == true) app.settleCourier(e.key);
                  },
                  child: const Text('استلمت'),
                ),
              ]),
            ),
          const SizedBox(height: 6),
        ],
        if (app.orders.isEmpty) const EmptyState(icon: Icons.receipt_long_outlined, text: 'ماكو طلبات بعد'),
        for (final o in app.orders.take(50))
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Badge2(orderStatusNames[o.status]!, bg: o.isOpen ? DepoColors.brand : DepoColors.soft),
                const Spacer(),
                Text(timeAgo(o.createdAt), style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
              ]),
              Text('${app.storeById(o.storeId)?.fullName ?? ''} ← ${o.customerName} (${o.customerPhone})', style: const TextStyle(fontSize: 12)),
              Text('${iqd(o.total)} • عمولة ${iqd(o.commission)} • ${o.pickup ? 'استلام ذاتي' : 'توصيل'}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              if (o.isOpen)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('إلغاء الطلب #${o.id}؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الطلب')),
                          ],
                        ),
                      );
                      if (ok == true) app.setStatus(o, OrderStatus.cancelled, reason: 'ألغاه الدعم');
                    },
                    child: const Text('إلغاء الطلب'),
                  ),
                ),
            ]),
          ),
      ],
    );
  }
}

class ComplaintsTab extends StatelessWidget {
  const ComplaintsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final list = [...app.complaints]..sort((a, b) => (b.health ? 1 : 0) - (a.health ? 1 : 0));
    if (list.isEmpty) return const EmptyState(icon: Icons.report_outlined, text: 'ماكو شكاوى');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in list)
          AppCard(
            color: c.health && c.status == 'open' ? const Color(0xFFFDECED) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (c.health) const Badge2('صحية — عاجل', bg: DepoColors.danger, fg: Colors.white),
                if (c.health) const SizedBox(width: 6),
                Expanded(child: Text('${c.type} — طلب #${c.orderId}', style: const TextStyle(fontWeight: FontWeight.w900))),
                Badge2(c.status == 'open' ? 'مفتوحة' : 'مغلقة', bg: c.status == 'open' ? DepoColors.accent : DepoColors.soft),
              ]),
              if (c.text.isNotEmpty) Text(c.text),
              Text('${c.phone} • ${timeAgo(c.createdAt)}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              if (c.status == 'open')
                Row(children: [
                  TextButton(onPressed: () => app.closeComplaint(c), child: const Text('تمت المعالجة')),
                  if (c.health)
                    TextButton(
                      onPressed: () {
                        final o = app.orderById(c.orderId);
                        if (o != null) {
                          for (final l in o.lines) {
                            for (final of in app.offers.where((x) => x.id == l.offerId)) {
                              app.setOfferHidden(of, true);
                            }
                          }
                        }
                        toast(context, 'انشال العرض من التطبيق');
                      },
                      child: const Text('اسحب العرض فوراً'),
                    ),
                ]),
            ]),
          ),
      ],
    );
  }
}

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = app.users.where((u) => q.isEmpty || u.phone.contains(q) || u.name.contains(q)).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث برقم أو اسم'), onChanged: (v) => setState(() => q = v.trim())),
        const SizedBox(height: 10),
        for (final u in list)
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name.isEmpty ? u.phone : u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${u.phone} • ${roleNames[u.role]}${u.suspended ? ' • موقوف' : ''}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
              if (app.canManage(u))
                PopupMenuButton<String>(
                  tooltip: 'إجراءات',
                  onSelected: (v) {
                    if (v == 'suspend') {
                      app.setUserSuspended(u, !u.suspended);
                    } else {
                      final role = Role.values.firstWhere((r) => r.name == v);
                      app.setRole(u, role);
                    }
                  },
                  itemBuilder: (c) => [
                    PopupMenuItem(value: 'suspend', child: Text(u.suspended ? 'تفعيل الحساب' : 'إيقاف الحساب')),
                    for (final r in [Role.customer, Role.courier, Role.supervisor, Role.admin])
                      if (app.canSetRole(r) && r != u.role) PopupMenuItem(value: r.name, child: Text('اجعله ${roleNames[r]}')),
                  ],
                ),
            ]),
          ),
        const Text('ترقية المطاعم والتجار تصير من «طلبات الانضمام» حتى ينربط المحل بالحساب. والمشرف ما يكدر يرفع مشرف ثاني.',
            style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      ],
    );
  }
}

class OffersStoresTab extends StatelessWidget {
  const OffersStoresTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('المحلات'),
        for (final s in app.stores)
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('★ ${s.rating.toStringAsFixed(1)} (${s.ratingCount}) • ${s.type == StoreType.restaurant ? 'مطعم' : 'تاجر'}${s.suspended ? ' • موقوف' : ''}',
                      style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
              TextButton(onPressed: () => app.setStoreSuspended(s, !s.suspended), child: Text(s.suspended ? 'تفعيل' : 'إيقاف')),
            ]),
          ),
        const SizedBox(height: 8),
        const SectionTitle('العروض'),
        for (final o in app.offers.take(60))
          AppCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${app.storeById(o.storeId)?.name ?? ''} • ${iqd(o.price)} • باقي ${o.quantityLeft}${o.hidden ? ' • مخفي' : ''}',
                      style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
              TextButton(onPressed: () => app.setOfferHidden(o, !o.hidden), child: Text(o.hidden ? 'إظهار' : 'إخفاء')),
            ]),
          ),
      ],
    );
  }
}
