import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'store_page.dart';

/// المحلات اللي أتابعها
class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.me;
    final list = me == null ? <Store>[] : me.follows.map(app.storeById).whereType<Store>().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('محلاتي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me == null) ...[
            const EmptyState(icon: Icons.favorite_border, text: 'سجّل حتى تتابع مطاعمك ومحلاتك المفضلة، ويوصلك إشعارهم أول ناس.'),
            FilledButton(onPressed: () => ensureLoggedIn(context), child: const Text('تسجيل الدخول')),
          ] else if (list.isEmpty)
            const EmptyState(icon: Icons.favorite_border, text: 'بعدك ما تتابع أي محل. افتح صفحة أي مطعم واضغط «تابع ونبّهني».')
          else ...[
            for (final s in list)
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(storeId: s.id))),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: DepoColors.soft, borderRadius: BorderRadius.circular(14)),
                    child: Icon(s.type == StoreType.restaurant ? Icons.restaurant : Icons.storefront, color: DepoColors.dark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(s.usuallyPublishes.isEmpty ? 'عروض يومية' : s.usuallyPublishes,
                          style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                    ]),
                  ),
                  app.offersOf(s.id).isNotEmpty
                      ? const Badge2('عنده عروض هسه', bg: DepoColors.brand)
                      : const Text('ماكو هسه', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
                ]),
              ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('المحلات اللي تتابعها يوصلك إشعارها أول ناس، مهما كانت بعيدة',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
            ),
          ],
        ],
      ),
    );
  }
}
