import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
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
      body: IndexedStack(index: index, children: [
        for (var i = 0; i < pages.length; i++) TickerMode(enabled: i == index, child: pages[i]),
      ]),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([app, cart]),
        builder: (context, _) => _BottomBar(
          index: index,
          onTap: setIndex,
          items: [
            const _NavItem(Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
            const _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'الأقسام'),
            _NavItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'السلة', badge: cart.count),
            _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'طلباتي', dot: app.myOrders.any((o) => o.isOpen)),
            const _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'حسابي'),
          ],
        ),
      ),
    );
  }
}


class _NavItem {
  final IconData icon, active;
  final String label;
  final int badge;
  final bool dot;
  const _NavItem(this.icon, this.active, this.label, {this.badge = 0, this.dot = false});
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c),
                          child: Icon(
                            i == index ? items[i].active : items[i].icon,
                            key: ValueKey(i == index),
                            size: 27,
                            color: i == index ? DepoColors.dark : const Color(0xFF8A9A9D),
                          ),
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
