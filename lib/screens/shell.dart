import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav_icons.dart';
import 'account.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'home.dart';
import 'orders.dart';

/// واجهة الزبون: الشريط السفلي بخمس أقسام
class Shell extends StatefulWidget {
  const Shell({super.key});

  static void goTo(BuildContext context, int index) {
    context.findAncestorStateOfType<_ShellState>()?.setIndex(index);
  }

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  void setIndex(int i) => setState(() => index = i);

  @override
  void initState() {
    super.initState();
    if (app.reloginNeeded) {
      app.reloginNeeded = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, 'فعّلنا رمز التحقق الحقيقي لحماية حسابك — سجّل دخول مرة ثانية من «حسابي»');
      });
    }
  }

  // الصفحات تنبني مرة وحدة، وكل صفحة تتحدث لحالها (مو كل التطبيق ويه كل تغيير)
  late final List<Widget> pages = [
    const HomeScreen(),
    const CategoriesScreen(),
    const CartScreen(embedded: true),
    ListenableBuilder(listenable: app, builder: (_, __) => const OrdersScreen()),
    ListenableBuilder(listenable: app, builder: (_, __) => const AccountScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // شريط «ماكو اتصال» — يختفي لحاله أول ما يتصل
        ListenableBuilder(
          listenable: app,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: !app.offline
                ? const SizedBox(width: double.infinity)
                : Material(
                    color: DepoColors.ink,
                    child: SafeArea(
                      bottom: false,
                      child: InkWell(
                        onTap: app.retryConnect,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 10),
                            Expanded(child: Text('ماكو اتصال بالإنترنت — نحاول نتصل…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                            Text('أعد المحاولة', style: TextStyle(color: Color(0xFF7FE3EC), fontWeight: FontWeight.w800, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: index, children: [
            for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == index, child: pages[i]),
          ]),
        ),
      ]),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([app, cart]),
        builder: (context, _) => _BottomBar(
          index: index,
          onTap: setIndex,
          items: [
            const _NavItem(NavGlyph.home, 'الرئيسية'),
            const _NavItem(NavGlyph.categories, 'الأقسام'),
            _NavItem(NavGlyph.cart, 'السلة', badge: cart.count),
            _NavItem(NavGlyph.orders, 'طلباتي', dot: app.myOrders.any((o) => o.isOpen)),
            const _NavItem(NavGlyph.profile, 'حسابي'),
          ],
        ),
      ),
    );
  }
}


class _NavItem {
  final NavGlyph glyph;
  final String label;
  final int badge;
  final bool dot;
  const _NavItem(this.glyph, this.label, {this.badge = 0, this.dot = false});
}

/// الشريط السفلي (نظيف مثل التطبيقات العالمية): خلفية بيضاء، خط رفيع فوق،
/// أيقونات رفيعة رمادية، والمختار أيقونة ممتلئة بلون ديبو ويه اسمه
class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  const _BottomBar({required this.index, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EEEF))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].label,
                  child: InkResponse(
                    onTap: () => onTap(i),
                    radius: 36,
                    highlightShape: BoxShape.circle,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Badge(
                        isLabelVisible: items[i].badge > 0 || items[i].dot,
                        smallSize: 8,
                        backgroundColor: DepoColors.accent,
                        label: items[i].badge > 0 ? Text('${items[i].badge}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)) : null,
                        child: AnimatedScale(
                          scale: i == index ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: NavIcon(items[i].glyph, size: 28, color: i == index ? DepoColors.dark : const Color(0xFFA3B1B4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                          color: i == index ? DepoColors.dark : const Color(0xFF8A9A9D),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
