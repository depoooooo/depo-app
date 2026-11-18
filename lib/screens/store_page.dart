import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'home.dart';

/// صفحة المطعم أو المتجر: متابعة + كل عروضه، ويكدر الزبون يطلب منها مباشرة
class StorePage extends StatelessWidget {
  final String storeId;
  const StorePage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.storeById(storeId);
        if (s == null) return const Scaffold(body: Center(child: Text('المحل مو موجود')));
        final list = app.offersOf(s.id);
        final following = app.isFollowing(s.id);
        final isRest = s.type == StoreType.restaurant;
        return Scaffold(
          appBar: AppBar(title: Text(s.fullName)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: DepoColors.brand, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Icon(isRest ? Icons.restaurant : Icons.storefront, color: DepoColors.dark, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('★ ${s.rating.toStringAsFixed(1)} (${s.ratingCount}) • ${app.followersOf(s.id)} متابع • ${s.distanceKm} كم',
                            style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: following
                          ? FilledButton.icon(
                              onPressed: () => app.toggleFollow(s.id),
                              icon: const Icon(Icons.check),
                              label: const Text('متابَع'),
                            )
                          : OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                              onPressed: () async {
                                if (await ensureLoggedIn(context, reason: 'سجّل حتى تتابع المحل ويوصلك إشعاره')) {
                                  app.toggleFollow(s.id);
                                  if (context.mounted) toast(context, 'راح يوصلك إشعار أول ما ${s.name} ينشر');
                                }
                              },
                              icon: const Icon(Icons.notifications_active_outlined),
                              label: const Text('تابع ونبّهني'),
                            ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              if (s.usuallyPublishes.isNotEmpty)
                AppCard(
                  child: Row(children: [
                    const Icon(Icons.schedule, color: DepoColors.dark),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.usuallyPublishes, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                ),
              SectionTitle(isRest ? 'رواجع اليوم (${list.length})' : 'العروض (${list.length})'),
              if (list.isEmpty)
                EmptyState(icon: Icons.hourglass_empty, text: isRest ? 'ماكو رواجع هسه. تابع المطعم حتى يوصلك إشعار أول ما ينشر.' : 'ماكو عروض هسه.'),
              if (isRest)
                Wrap(spacing: 12, runSpacing: 12, children: [for (final o in list) MiniOffer(offer: o)])
              else
                ProductGrid(products: list),
            ],
          ),
        );
      },
    );
  }
}
