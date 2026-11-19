import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'admin.dart';
import '../chat_screen.dart';

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

/// واجهة المشرف: التبويبات حسب أقسامه بس
class SupervisorHome extends StatelessWidget {
  const SupervisorHome({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final pending = app.joinRequests.where((r) => r.status == 'pending' && app.canSeeJoin(r)).length;
    final openC = app.complaints.where((c) => c.status == 'open').length;
    final tabs = <(String, Widget)>[
      if (app.canAny([Perm.partnerships, Perm.quality, Perm.operations])) ('طلبات الانضمام ($pending)', JoinRequestsTab()),
      if (app.canAny([Perm.operations, Perm.support, Perm.finance])) ('الطلبات', OrdersMonitorTab()),
      if (app.can(Perm.support)) ('محادثات الدعم${_unreadSupport()}', SupportChatsTab()),
      if (app.canAny([Perm.support, Perm.quality])) ('الشكاوى ($openC)', ComplaintsTab()),
      if (app.canAny([Perm.tech, Perm.support, Perm.operations])) ('المستخدمين', UsersTab()),
      if (app.canAny([Perm.quality, Perm.partnerships, Perm.sales])) ('العروض والمحلات', OffersStoresTab()),
      if (app.can(Perm.marketing)) ('التسويق', MarketingTab()),
      if (app.canAny([Perm.finance, Perm.sales])) ('التقارير', ReportsTab()),
      if (app.can(Perm.tech)) ('سجل العمليات', AuditTab()),
    ]; // ignore: prefer_const_constructors
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: roleAppBar('واجهة المشرف'),
        body: const EmptyState(icon: Icons.lock_outline_rounded, text: 'بعد ما انحددت أقسامك. تواصل ويه المدير العام حتى يفتحلك الصلاحيات.'),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: roleAppBar(
          'المشرف: ${app.permsOf(me).map((p) => permNames[p]).join(' • ')}',
          bottom: roleTabs([for (final t in tabs) t.$1]),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

/// إعدادات التسويق (قسم التسويق)
class MarketingTab extends StatefulWidget {
  const MarketingTab({super.key});

  @override
  State<MarketingTab> createState() => _MarketingTabState();
}

class _MarketingTabState extends State<MarketingTab> {
  late final promo = TextEditingController(text: app.settings.promoText);
  late final campaign = TextEditingController(text: app.settings.campaignName);
  late final minDisc = TextEditingController(text: '${app.settings.campaignMinDiscount}');
  late bool firstFree = app.settings.firstOrderFree;

  @override
  void dispose() {
    promo.dispose();
    campaign.dispose();
    minDisc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        TextField(controller: promo, decoration: const InputDecoration(labelText: 'نص الشريط البرتقالي فوق (فارغ = مطفي)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: campaign, decoration: const InputDecoration(labelText: 'اسم الحملة'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: minDisc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقل خصم للحملة %'))),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            app.saveMarketing(
              firstOrderFree: firstFree,
              promoText: promo.text.trim(),
              campaignName: campaign.text.trim(),
              campaignMinDiscount: parseInt(minDisc.text) ?? app.settings.campaignMinDiscount,
            );
            toast(context, 'انحفظت إعدادات التسويق');
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class JoinRequestsTab extends StatelessWidget {
  const JoinRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final list = app.joinRequests.where(app.canSeeJoin).toList();
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
              if (r.docs.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in r.docs.entries)
                    InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (c) => Dialog(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Padding(padding: const EdgeInsets.all(12), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w900))),
                            AppImage(imageId: e.value, height: 380, fallback: const SizedBox(height: 120, child: Center(child: Text('الصورة ما انفتحت')))),
                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
                          ]),
                        ),
                      ),
                      child: Column(children: [
                        AppImage(imageId: e.value, height: 64, width: 64, radius: 10, fallback: const SizedBox(width: 64, height: 64, child: Icon(Icons.image_not_supported_outlined))),
                        SizedBox(width: 70, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                      ]),
                    ),
                ]),
              ],
              if (r.note.isNotEmpty) Text('السبب: ${r.note}', style: const TextStyle(fontSize: 12, color: DepoColors.danger)),
              if (r.status == 'pending') ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (app.canDecideJoin(r)) ...[
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
                  ],
                  if (r.type != Role.courier && app.can(Perm.quality)) ...[
                    Expanded(child: OutlinedButton(onPressed: () => _inspection(context, r), child: const Text('تفتيش'))),
                    const SizedBox(width: 8),
                  ],
                  if (app.canDecideJoin(r, viaInspection: true))
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
                      app.approveJoin(r, viaInspection: true);
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
        if (app.couriersCash.isNotEmpty && app.canAny([Perm.operations, Perm.finance])) ...[
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
              if (o.isOpen && app.canAny([Perm.operations, Perm.support]))
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
                      if (ok == true) app.staffCancel(o, 'ألغاه الدعم');
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
                  if (c.health && app.can(Perm.quality))
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
              if (app.canManage(u) && (app.canSuspendUsers || [Role.customer, Role.courier, Role.supervisor, Role.admin].any((r) => app.canSetRole(r) && r != u.role)))
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
                    if (app.canSuspendUsers) PopupMenuItem(value: 'suspend', child: Text(u.suspended ? 'تفعيل الحساب' : 'إيقاف الحساب')),
                    for (final r in [Role.customer, Role.courier, Role.supervisor, Role.admin])
                      if (app.canSetRole(r) && r != u.role) PopupMenuItem(value: r.name, child: Text('اجعله ${roleNames[r]}')),
                  ],
                ),
            ]),
          ),
        const Text('ترقية المطاعم والتجار تصير من «طلبات الانضمام». المشرف يكدر يخلي الحساب مندوب أو زبون بس، والمدير العام وحده يرفع المشرفين ويحدد أقسامهم.',
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
              if (app.can(Perm.sales))
                IconButton(
                  tooltip: s.sponsored ? 'إلغاء الظهور المميز' : 'ظهور مميز (ممول)',
                  onPressed: () => app.setStoreSponsored(s, !s.sponsored),
                  icon: Icon(s.sponsored ? Icons.star_rounded : Icons.star_outline_rounded, color: DepoColors.accent),
                ),
              if (app.canAny([Perm.quality, Perm.partnerships]))
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
              if (app.can(Perm.quality))
                TextButton(onPressed: () => app.setOfferHidden(o, !o.hidden), child: Text(o.hidden ? 'إظهار' : 'إخفاء')),
            ]),
          ),
      ],
    );
  }
}


String _unreadSupport() {
  final n = app.supportChats.where((c) => c.unreadFor(staff: true) > 0).length;
  return n > 0 ? ' ($n)' : '';
}

/// محادثات الدعم داخل التطبيق (زبائن، مطاعم، تجار، مندوبين)
class SupportChatsTab extends StatelessWidget {
  const SupportChatsTab({super.key});

  @override
  Widget build(BuildContext context) => ChatListView(source: () => app.supportChats);
}
