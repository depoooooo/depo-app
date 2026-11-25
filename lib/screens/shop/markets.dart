import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../../widgets/offer_cards.dart';
import '../chat_screen.dart';
import 'jm_ui.dart';
import '../cart_screen.dart';
import 'my_debts.dart';
import '../../theme.dart';
import 'my_shop.dart';

/// «الأسواق»: بحث، اختصارات (ديوني / محلي)، ومحلات الحي — بنفس هوية ديبو
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
      listenable: Listenable.merge([app, cart]),
      builder: (context, _) {
        final shops = app.shops
            .where((s) => q.isEmpty || s.name.contains(q) || s.area.contains(q) || app.offersOf(s.id).any((o) => o.title.contains(q)))
            .toList()
          ..sort((a, b) => app.offersOf(b.id).length - app.offersOf(a.id).length);
        final ids = app.shops.map((s) => s.id).toSet();
        final products = q.isEmpty ? <Offer>[] : app.offers.where((o) => o.visible && ids.contains(o.storeId) && o.title.contains(q)).take(20).toList();
        final debts = app.myDebtAccounts.fold(0, (s, d) => s + app.summaryOf(d.id).remaining);
        final mine = app.myShop;
        return JmScaffold(
          title: 'الأسواق',
          bottom: _CartBar(),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            TextField(
              decoration: const InputDecoration(hintText: 'ابحث عن محل أو منتج', prefixIcon: Icon(Icons.search_rounded, color: DepoColors.dark)),
              onChanged: (v) => setState(() => q = v.trim()),
            ),
            const SizedBox(height: 14),
            if (q.isEmpty) ...[
              Row(children: [
                Expanded(
                  child: _QuickTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'ديوني',
                    sub: debts > 0 ? 'عليك ${iqd(debts)}' : 'حساباتي عند المحلات',
                    alert: debts > 0,
                    onTap: () => _push(context, const MyDebtsScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickTile(
                    icon: mine == null ? Icons.add_business_rounded : Icons.storefront_rounded,
                    title: mine == null ? 'افتح محلك' : 'محلي',
                    sub: mine == null ? 'مجاناً وبدقيقة' : mine.name,
                    onTap: () => _push(context, const MyShopScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
            ],
            if (products.isNotEmpty) ...[
              const SectionTitle('منتجات'),
              ProductGrid(products: products),
              const SizedBox(height: 10),
            ],
            SectionTitle(q.isEmpty ? 'محلات الحي (${shops.length})' : 'محلات (${shops.length})'),
            if (shops.isEmpty)
              JmEmpty(
                icon: Icons.storefront_outlined,
                title: q.isEmpty ? 'لا توجد محلات بعد' : 'ما لقينا شي',
                text: q.isEmpty ? 'كن أول من يفتح محله ويظهر هنا' : 'جرّب كلمة ثانية',
                onTap: q.isEmpty ? () => _push(context, const MyShopScreen()) : null,
              )
            else
              for (final s in shops) _ShopRow(store: s),
          ]),
        );
      },
    );
  }
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// شريط السلة تحت (إذا بالسلة شي)
class _CartBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => _push(context, const CartScreen()),
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text('السلة (${cart.count}) • ${iqd(cart.total)}'),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool alert;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.title, required this.sub, required this.onTap, this.alert = false});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0.8,
        shadowColor: const Color(0x2206363C),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: alert ? const Color(0xFFFDECED) : DepoColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: alert ? DepoColors.danger : DepoColors.dark),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: alert ? DepoColors.danger : DepoColors.muted, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _ShopRow extends StatelessWidget {
  final Store store;
  const _ShopRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final list = app.offersOf(store.id);
    final withImg = list.where((o) => o.imageId.isNotEmpty).toList();
    final ph = Container(width: 96, color: DepoColors.soft, child: const Icon(Icons.storefront_rounded, color: DepoColors.brand, size: 36));
    final cover = store.imageId.isNotEmpty
        ? AppImage(imageId: store.imageId, height: 96, width: 96, fallback: ph)
        : withImg.isNotEmpty
            ? SizedBox(width: 96, child: OfferImage(offer: withImg.first, height: 96))
            : ph;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0.8,
        shadowColor: const Color(0x2206363C),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _push(context, ShopPublicPage(storeId: store.id)),
          child: SizedBox(
            height: 96,
            child: Row(children: [
              cover,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: DepoColors.muted),
                      const SizedBox(width: 2),
                      Expanded(child: Text(store.area.isEmpty ? 'الموصل' : store.area, maxLines: 1, style: const TextStyle(fontSize: 12, color: DepoColors.muted))),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      Badge2('${list.length} منتج', bg: DepoColors.soft, fg: DepoColors.dark),
                      if (store.promoText.isNotEmpty) Badge2('عرض خاص', bg: const Color(0xFFFFF4DE), fg: const Color(0xFF8A5A00)),
                    ]),
                  ]),
                ),
              ),
              const Padding(padding: EdgeInsetsDirectional.only(end: 10), child: Icon(Icons.chevron_left, color: DepoColors.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// صفحة المحل للزبون: بنر، أزرار، أصناف، ومنتجات بشبكة مثل باقي التطبيق
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
        final owner = app.ownsStore(s.id);
        return JmScaffold(
          title: s.name,
          bottom: _CartBar(),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            // البنر + صورة المحل
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 150,
                child: Stack(fit: StackFit.expand, children: [
                  if (s.promoImageId.isNotEmpty)
                    AppImage(imageId: s.promoImageId, height: 150, fallback: const SizedBox())
                  else
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [DepoColors.brand, DepoColors.dark]))),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x9906363C)])),
                  ),
                  PositionedDirectional(
                    start: 12,
                    end: 12,
                    bottom: 12,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      JmAvatar(
                        letter: s.name.characters.first,
                        size: 56,
                        image: s.imageId.isEmpty ? null : AppImage(imageId: s.imageId, height: 56, width: 56, fallback: const SizedBox()),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (s.promoText.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: DepoColors.accent, borderRadius: BorderRadius.circular(10)),
                              child: Text(s.promoText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                          Text(s.area.isEmpty ? 'الموصل' : s.area, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            // أزرار سريعة
            Row(children: [
              if (s.phone.isNotEmpty) _Pill(icon: Icons.phone_rounded, label: 'اتصال', onTap: () => callPhone(context, s.phone)),
              if (!owner) _Pill(icon: Icons.chat_bubble_rounded, label: 'راسل', onTap: () => openShopChat(context, s.id)),
              if (s.mapLink.isNotEmpty) _Pill(icon: Icons.near_me_rounded, label: 'الاتجاهات', onTap: () => openLink(context, s.mapLink)),
            ]),
            if (s.usuallyPublishes.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.usuallyPublishes, style: const TextStyle(color: DepoColors.muted, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
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
                        selectedColor: DepoColors.dark,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(fontWeight: FontWeight.w800, color: cat == c ? Colors.white : DepoColors.ink),
                        side: BorderSide(color: cat == c ? DepoColors.dark : DepoColors.line),
                        onSelected: (_) => setState(() => cat = c),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 10),
            if (list.isEmpty)
              const JmEmpty(icon: Icons.inventory_2_outlined, title: 'لا توجد منتجات', text: 'المحل بعده ما ضاف منتجات')
            else
              ProductGrid(products: list),
          ]),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Pill({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: DepoColors.line)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 18, color: DepoColors.dark),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: DepoColors.ink)),
                ]),
              ),
            ),
          ),
        ),
      );
}
