import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, cart]),
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: [HomeScreen(), CategoriesScreen(), CartScreen(embedded: true), OrdersScreen(), AccountScreen()], // ignore: prefer_const_constructors
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: setIndex,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'الأقسام'),
            NavigationDestination(
              icon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag_outlined)),
              selectedIcon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag)),
              label: 'السلة',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: app.myOrders.where((o) => o.isOpen).isNotEmpty,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              label: 'طلباتي',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}
