import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../../widgets/offer_cards.dart';
import '../chat_screen.dart';
import 'jm_ui.dart';
import 'my_debts.dart';
import 'my_shop.dart';

/// «الأسواق»: خانة وحدة بحسابي — ديوني، محلي، وأسواق الحي
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.shops
            .where((s) => q.isEmpty || s.name.contains(q) || s.area.contains(q) || app.offersOf(s.id).any((o) => o.title.contains(q)))
            .toList()
          ..sort((a, b) => app.offersOf(b.id).length - app.offersOf(a.id).length);
        return JmScaffold(
          title: 'الأسواق',
          actions: [
            JmCircleBtn(icon: Icons.storefront_outlined, tooltip: 'محلي', onTap: () => _push(context, const MyShopScreen())),
            JmCircleBtn(icon: Icons.add, tooltip: 'إنشاء محل', onTap: () => _push(context, const MyShopScreen())),
          ],
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            JmButton(label: 'ديوني عند المحلات', icon: Icons.person_outline, color: Jm.green, fg: Colors.white, onTap: () => _push(context, const MyDebtsScreen())),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Jm.text),
              decoration: const InputDecoration(hintText: 'ابحث عن محل أو منتج'),
              onChanged: (v) => setState(() => q = v.trim()),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              JmEmpty(icon: Icons.storefront_outlined, title: 'لا توجد محلات بعد', text: 'كن أول من ينشئ محلاً من «محلي» ويظهر هنا', onTap: () => _push(context, const MyShopScreen()))
            else
              for (final s in list) _ShopRow(store: s),
          ]),
        );
      },
    );
  }
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class _ShopRow extends StatelessWidget {
  final Store store;
  const _ShopRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final n = app.offersOf(store.id).length;
    return JmCard(
      onTap: () => _push(context, ShopPublicPage(storeId: store.id)),
      child: Row(children: [
        JmAvatar(
          letter: store.name.characters.first,
          image: store.imageId.isEmpty ? null : AppImage(imageId: store.imageId, height: 52, width: 52, fallback: const SizedBox()),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(store.area, style: const TextStyle(fontSize: 12, color: Jm.sub)),
            if (store.usuallyPublishes.isNotEmpty) Text(store.usuallyPublishes, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Jm.faint)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$n', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Jm.cyan)),
          const Text('منتج', style: TextStyle(fontSize: 11, color: Jm.sub)),
        ]),
      ]),
    );
  }
}

/// صفحة المحل للزبون: البنر، الأصناف، المنتجات بأسعارها، الطلب
class ShopPublicPage extends StatefulWidget {
  final String storeId;
  const ShopPublicPage({super.key, required this.storeId});

  @override
  State<ShopPublicPage> createState() => _ShopPublicPageState();
}

class _ShopPublicPageState extends State<ShopPublicPage> {
  String cat = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, cart]),
      builder: (context, _) {
        final s = app.storeById(widget.storeId);
        if (s == null) return const JmScaffold(title: 'المحل', body: SizedBox());
        final all = app.offersOf(s.id);
        final cats = <String>{for (final o in all) o.category.isEmpty ? 'أخرى' : o.category}.toList();
        final list = cat.isEmpty ? all : all.where((o) => (o.category.isEmpty ? 'أخرى' : o.category) == cat).toList();
        return JmScaffold(
          title: s.name,
          subtitle: s.area,
          leading: JmAvatar(
            letter: s.name.characters.first,
            image: s.imageId.isEmpty ? null : AppImage(imageId: s.imageId, height: 52, width: 52, fallback: const SizedBox()),
          ),
          actions: [
            if (s.phone.isNotEmpty) JmCircleBtn(icon: Icons.phone_outlined, tooltip: 'اتصال', onTap: () => callPhone(context, s.phone)),
            if (!app.ownsStore(s.id)) JmCircleBtn(icon: Icons.chat_bubble_outline, tooltip: 'راسل المحل', onTap: () => openShopChat(context, s.id)),
          ],
          bottom: cart.isEmpty || cart.storeId != s.id
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: JmButton(
                      label: 'السلة (${cart.count}) • ${iqd(cart.total)}',
                      icon: Icons.shopping_bag_outlined,
                      onTap: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                  ),
                ),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            if (s.promoImageId.isNotEmpty || s.promoText.isNotEmpty)
              JmCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 120,
                  child: Stack(fit: StackFit.expand, children: [
                    if (s.promoImageId.isNotEmpty) AppImage(imageId: s.promoImageId, height: 120, fallback: const SizedBox()),
                    if (s.promoImageId.isEmpty) Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Jm.green, Color(0xFF0B5D3A)]))),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Jm.red, borderRadius: BorderRadius.circular(10)),
                          child: const Text('عرض خاص', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        if (s.promoText.isNotEmpty) Text(s.promoText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 6)])),
                      ]),
                    ),
                  ]),
                ),
              ),
            if (s.usuallyPublishes.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s.usuallyPublishes, style: const TextStyle(color: Jm.sub))),
            if (s.mapLink.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: JmButton(label: 'الاتجاهات للمحل', icon: Icons.near_me_outlined, outlined: true, height: 46, onTap: () => openLink(context, s.mapLink)),
              ),
            if (cats.length > 1)
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in ['', ...cats])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(c.isEmpty ? 'الكل' : c),
                        selected: cat == c,
                        showCheckmark: false,
                        selectedColor: Jm.cyan,
                        backgroundColor: const Color(0x14FFFFFF),
                        labelStyle: TextStyle(fontWeight: FontWeight.w800, color: cat == c ? const Color(0xFF042624) : Jm.text),
                        side: const BorderSide(color: Jm.line),
                        onSelected: (_) => setState(() => cat = c),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 10),
            if (list.isEmpty) const JmEmpty(icon: Icons.inventory_2_outlined, title: 'لا توجد منتجات', text: 'المحل بعده ما ضاف منتجات'),
            for (final o in list)
              JmCard(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 64, height: 64, child: OfferImage(offer: o, height: 64))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (o.description.isNotEmpty) Text(o.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Jm.sub)),
                      Text(iqd(o.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Jm.cyan)),
                    ]),
                  ),
                  if (!app.ownsStore(s.id)) AddButton(offer: o),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
