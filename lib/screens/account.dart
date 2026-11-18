import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import 'following.dart';
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
          const _DemoHelp(),
        ]),
      );
    }
    final delivered = app.myOrders.where((o) => o.status == OrderStatus.delivered).toList();
    final saved = delivered.fold(0, (s, o) => s + (o.originalTotal - o.itemsTotal));
    final meals = delivered.fold(0, (s, o) => s + o.lines.fold(0, (a, l) => a + l.qty));
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
                _Stat('$meals', 'وجبة ومنتج أنقذتها'),
                const SizedBox(width: 8),
                _Stat('${u.points}', 'نقطة'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
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
          _MenuItem(Icons.favorite_border, 'محلاتي (${u.follows.length})', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FollowingScreen()))),
          _MenuItem(Icons.notifications_none, 'الإشعارات (${u.notifications.length})', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          _MenuItem(Icons.location_on_outlined, 'عناويني', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen()))),
          _MenuItem(Icons.card_giftcard, 'دعوة صديق', () => _invite(context)),
          _MenuItem(Icons.support_agent, 'الدعم', () => toast(context, 'الدعم عبر واتساب يتفعل قبل الإطلاق')),
          _MenuItem(Icons.settings_outlined, 'الإعدادات', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          _MenuItem(Icons.logout, 'تسجيل الخروج', () {
            app.logout();
            toast(context, 'سجّلت خروج');
          }),
          const SizedBox(height: 16),
          const _DemoHelp(),
        ],
      ),
    );
  }

  void _invite(BuildContext context) {
    final code = 'DEPO${app.me!.phone.substring(app.me!.phone.length - 4)}';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ادعُ صديقك'),
        content: Text('رمز الدعوة مالتك: $code\n\nلما صديقك يطلب أول مرة بهذا الرمز، الاثنين تاخذون نقاط.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('تمام'))],
      ),
    );
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
        final list = app.me?.addresses ?? const <String>[];
        return Scaffold(
          appBar: AppBar(title: const Text('عناويني')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in list)
                AppCard(
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, color: DepoColors.dark),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a)),
                    IconButton(tooltip: 'حذف', onPressed: () => app.removeAddress(a), icon: const Icon(Icons.delete_outline)),
                  ]),
                ),
              FilledButton.icon(
                onPressed: () {
                  final ctl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('عنوان جديد'),
                      content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(hintText: 'مثلاً: حي النور — قرب الجامع')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
                        FilledButton(
                          onPressed: () {
                            if (ctl.text.trim().isNotEmpty) app.addAddress(ctl.text.trim());
                            Navigator.pop(c);
                          },
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('أضف عنوان'),
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
            onPressed: () => toast(context, 'حذف الحساب يتفعل ويه Firebase'),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('حذف الحساب'),
          ),
        ],
      ),
    );
  }
}
