import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import 'following.dart';
import 'chat_screen.dart';
import '../widgets/debt_ui.dart';
import 'address/address_ui.dart';
import 'shop/markets.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'join.dart';
import 'roles/role_home.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = app.me;
    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('حسابي'), automaticallyImplyLeading: false),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const EmptyState(icon: Icons.person_outline, text: 'سجّل برقم تلفونك حتى تطلب وتتابع مطاعمك وتجمع نقاط'),
          FilledButton(onPressed: () => ensureLoggedIn(context), child: const Text('تسجيل الدخول')),
          const SizedBox(height: 24),
          if (!app.online) const _DemoHelp(),
        ]),
      );
    }
    final saved = app.impactOf(u.phone).saved; // نفس رقم كارت التوفير
    final pending = app.myJoinRequest;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: DepoColors.brand, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Row(children: [
                const CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.person, color: DepoColors.dark, size: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name.isEmpty ? 'بدون اسم' : u.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    Text(u.phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
                    if (u.role != Role.customer) Badge2(roleNames[u.role]!, bg: Colors.white, fg: DepoColors.dark),
                  ]),
                ),
                IconButton(tooltip: 'تعديل الاسم', onPressed: () => _editName(context), icon: const Icon(Icons.edit_outlined)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Stat(iqd(saved), 'وفّرتها'),
                const SizedBox(width: 8),
                _Stat('${app.impactOf(u.phone).orders}', 'طلب'),
                const SizedBox(width: 8),
                _Stat('${u.points}', 'نقطة'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          const SaverCard(),
          if (u.role != Role.customer)
            AppCard(
              color: DepoColors.ink,
              borderColor: DepoColors.ink,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleHome())),
              child: Row(children: [
                const Icon(Icons.swap_horiz, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('بدّل لواجهة ${roleNames[u.role]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    if (app.myStore != null) Text(app.myStore!.fullName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_left, color: Colors.white),
              ]),
            )
          else if (pending != null)
            AppCard(
              color: const Color(0xFFFFF6E5),
              child: Text('طلب انضمامك كـ${roleNames[pending.type]} قيد المراجعة. المشرف يراجعه ويرتب زيارة تفتيش خلال 72 ساعة.',
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.6)),
            )
          else
            AppCard(
              borderColor: DepoColors.dark,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen())),
              child: const Row(children: [
                Icon(Icons.add_business_outlined, color: DepoColors.dark),
                SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('انضم إلى Depo', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('كمطعم أو تاجر أو مندوب', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
                  ]),
                ),
                Icon(Icons.chevron_left),
              ]),
            ),
          const MarketsTile(),
          _MenuItem(Icons.favorite_border, 'محلاتي (${u.follows.length})', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FollowingScreen()))),
          _MenuItem(Icons.notifications_none, 'الإشعارات (${u.notifications.length})', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _MenuItem(Icons.location_on_outlined, 'عناويني', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen()))),
          _MenuItem(Icons.ios_share_rounded, 'شارك ديبو ويه أصدقائك', () => _invite(context)),
          _MenuItem(Icons.support_agent, _supportLabel(), () => openSupport(context)),
          _MenuItem(Icons.settings_outlined, 'الإعدادات', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _MenuItem(Icons.logout, 'تسجيل الخروج', () {
            app.logout();
            toast(context, 'سجّلت خروج');
          }),
          const SizedBox(height: 16),
          if (!app.online) const _DemoHelp(),
        ],
      ),
    );
  }

  void _invite(BuildContext context) {
    shareText(context, 'جرّب ديبو: أكل المطاعم ومنتجات الماركت بنص السعر بالموصل، وتوفّر ويه كل طلب.\nhttps://depoooooo.github.io/depo-app/');
  }

  void _editName(BuildContext context) {
    final ctl = TextEditingController(text: app.me?.name ?? '');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('الاسم'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              app.updateName(ctl.text.trim());
              Navigator.pop(c);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String v;
  final String l;
  const _Stat(this.v, this.l);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          FittedBox(child: Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: DepoColors.dark),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        const Icon(Icons.chevron_left, color: DepoColors.muted),
      ]),
    );
  }
}

/// شرح سريع للتجربة لحد ما نربط Firebase
class _DemoHelp extends StatelessWidget {
  const _DemoHelp();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(14)),
      child: const Text(
        'نسخة تجريبية: البيانات تنحفظ على هذا الجهاز بس.\n'
        '• أول رقم حقيقي يسجّل بالجهاز يصير «المدير العام».\n'
        '• تكدر تسجّل خروج وتدخل برقم ثاني حتى تجرب كزبون أو كمحل.\n'
        '• حسابات تجريبية جاهزة: مطعم الشواء 07000000001 • سوق النور 07000000004 • مندوب 07000000009',
        style: TextStyle(fontSize: 12, height: 1.7),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    app.markNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final list = app.me?.notifications ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: list.isEmpty
          ? const EmptyState(icon: Icons.notifications_none, text: 'ماكو إشعارات بعد')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final n in list)
                  AppCard(child: Row(children: [const Icon(Icons.notifications_active_outlined, color: DepoColors.dark), const SizedBox(width: 10), Expanded(child: Text(n))])),
              ],
            ),
    );
  }
}

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.places;
        return Scaffold(
          appBar: AppBar(title: const Text('عناويني')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in list)
                AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddressFormScreen(address: a.copy()))),
                  child: Row(children: [
                    Icon(a.hasMap ? Icons.location_on_outlined : Icons.location_off_outlined, color: DepoColors.dark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.name.isEmpty ? 'عنوان' : a.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(a.short, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                        if (!a.hasMap) const Text('بدون خريطة — اضغط وحدده', style: TextStyle(fontSize: 11, color: DepoColors.danger)),
                      ]),
                    ),
                    const Icon(Icons.edit_outlined, size: 20, color: DepoColors.muted),
                  ]),
                ),
              FilledButton.icon(
                onPressed: () => addAddressFlow(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة عنوان'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(children: [
              Icon(app.online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: app.online ? DepoColors.success : DepoColors.danger),
              const SizedBox(width: 10),
              Expanded(child: Text('السيرفر: ${app.cloudStatus}')),
            ]),
          ),
          const AppCard(child: Text('اللغة: العربية (الإنكليزية بمرحلة لاحقة)')),
          const AppCard(child: Text('نطاق إشعارات الرواجع: تلقائي (المتابَعين والقريبين أول شي)')),
          const AppCard(child: Text('شروط الاستخدام وسياسة الخصوصية — تنضاف قبل الإطلاق')),
          const SizedBox(height: 12),
          if (app.canResetDemo) OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('مسح البيانات التجريبية؟'),
                  content: Text(app.online ? 'تنمسح كل الحسابات والطلبات بالسيرفر لكل الأجهزة، وترجع البيانات التجريبية.' : 'يرجع التطبيق مثل أول مرة وتنمسح كل الحسابات والطلبات على هذا الجهاز.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('امسح')),
                  ],
                ),
              );
              if (ok == true) {
                await app.resetDemo();
                if (context.mounted) {
                  toast(context, 'رجعت البيانات التجريبية');
                  Navigator.pop(context);
                }
              }
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('مسح البيانات التجريبية'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: DepoColors.danger, side: const BorderSide(color: DepoColors.danger)),
            onPressed: () async {
              if (!app.loggedIn) return toast(context, 'ما مسجّل دخول');
              if (app.me!.role != Role.customer) return toast(context, 'حسابك ${roleNames[app.me!.role]}. تواصل ويه الإدارة حتى ينحذف.');
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('تحذف حسابك نهائياً؟'),
                  content: const Text('تنمسح معلوماتك وعناوينك ونقاطك ومتابعاتك. الطلبات القديمة تبقى بدون اسمك للحسابات.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: DepoColors.danger, minimumSize: const Size(0, 44)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('احذف'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              final open = app.myOrders.any((o) => o.isOpen);
              if (open) {
                if (context.mounted) toast(context, 'عندك طلب مفتوح. انتظر يخلص بعدين احذف الحساب.');
                return;
              }
              app.deleteMyAccount();
              if (context.mounted) {
                toast(context, 'انحذف حسابك');
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }
}

String _supportLabel() {
  final mine = app.chats.where((c) => c.kind != 'support' ? false : c.userPhone == app.currentPhone);
  final n = mine.fold(0, (s, c) => s + c.unreadFor(staff: false));
  return n > 0 ? 'الدعم ($n رسالة جديدة)' : 'الدعم';
}


/// خانة «الأسواق» الوحدة: ديوني عند المحلات + الأسواق القريبة + محلي
class MarketsTile extends StatelessWidget {
  const MarketsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final debts = app.myDebtAccounts.fold(0, (s, d) => s + app.summaryOf(d.id).remaining);
    final shop = app.myShop;
    final sub = [
      if (debts > 0) 'ديونك ${iqd(debts)}' else 'ديوني عند المحلات',
      shop == null ? 'افتح محلك مجاناً' : 'محلي: ${shop.name}',
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketsScreen())),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0E4A44), Color(0xFF061F1C)])),
            child: Row(children: [
              const CircleAvatar(radius: 22, backgroundColor: Color(0x332EE6E0), child: Icon(Icons.storefront_rounded, color: Color(0xFF2EE6E0))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الأسواق', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_left, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}


/// «شكد وفّرت»: مستوى الموفّر حسب مجموع التوفير بكل الطلبات، التقدّم، والمشاركة
class SaverCard extends StatelessWidget {
  const SaverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final i = app.impactOf(app.currentPhone);
    final lvl = saverLevelOf(i.saved);
    final c = Color(lvl.color);
    final progress = lvl.next == 0 ? 1.0 : (i.saved - lvl.from) / (lvl.next - lvl.from);
    final nextName = lvl.next == 0 ? '' : saverLevels.firstWhere((l) => l.from == lvl.next).name;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color.lerp(c, Colors.white, 0.35)!, c]),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.savings_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lvl.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color.lerp(c, DepoColors.ink, 0.35))),
              Text(i.orders == 0 ? 'اطلب من المطاعم أو الماركت وشوف شكد توفّر' : 'وفّرت ${iqd(i.saved)} من ${i.orders} ${i.orders == 1 ? 'طلب' : 'طلبات'}',
                  style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
            ]),
          ),
          IconButton(
            tooltip: 'شارك إنجازك',
            onPressed: i.saved == 0 ? null : () => shareText(context, app.impactShareText(i)),
            icon: const Icon(Icons.ios_share_rounded, color: DepoColors.dark),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: DepoColors.line, color: c),
        ),
        const SizedBox(height: 6),
        Text(
          lvl.next == 0 ? 'وصلت لأعلى مستوى — بطل التوفير!' : 'باقي ${iqd(lvl.next - i.saved)} توفير حتى تصير «$nextName»',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}
