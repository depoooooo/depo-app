import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'account.dart';
import 'cart_screen.dart';
import 'following.dart';
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
          children: [HomeScreen(), FollowingScreen(), CartScreen(embedded: true), OrdersScreen(), AccountScreen()], // ignore: prefer_const_constructors
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: setIndex,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'أتابعها'),
            NavigationDestination(
              icon: Badge(isLabelVisible: cart.count > 0, label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag_outlined)),
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
