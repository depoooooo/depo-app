import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/offer_cards.dart';

/// تبويب «الأقسام»: أنواع المطاعم وأصناف الماركت
class CategoriesScreen extends StatelessWidget {
  final int initialTab;
  final bool embedded;
  const CategoriesScreen({super.key, this.initialTab = 0, this.embedded = true});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأقسام'),
          automaticallyImplyLeading: !embedded,
          bottom: const TabBar(
            labelStyle: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w900, fontSize: 15),
            tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.restaurant_rounded, size: 18), SizedBox(width: 6), Text('رواجع المطاعم')])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_basket_rounded, size: 18), SizedBox(width: 6), Text('الماركت')])),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => TabBarView(children: [
            CatGrid(cats: restaurantCats, market: false),
            CatGrid(cats: marketCats, market: true),
          ]),
        ),
      ),
    );
  }
}

/// كم عرض متوفر بهذا القسم
int countIn(Cat c, {required bool market}) {
  if (market) {
    final ids = app.storesOfType(StoreType.merchant).map((s) => s.id).toSet();
    return app.offers.where((o) => o.visible && ids.contains(o.storeId) && categoryOf(o) == c.name).length;
  }
  final ids = app.storesOfType(StoreType.restaurant).where((s) => cuisineOf(s) == c.name).map((s) => s.id).toSet();
  return app.offers.where((o) => o.visible && ids.contains(o.storeId)).length;
}

class CatGrid extends StatelessWidget {
  final List<Cat> cats;
  final bool market;
  final int? limit;
  final bool shrink;
  const CatGrid({super.key, required this.cats, required this.market, this.limit, this.shrink = false});

  @override
  Widget build(BuildContext context) {
    final list = limit == null ? cats : cats.take(limit!).toList();
    return GridView.builder(
      shrinkWrap: shrink,
      physics: shrink ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.all(shrink ? 0 : 16),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 10, mainAxisExtent: 118),
      itemBuilder: (context, i) => CatTile(cat: list[i], market: market),
    );
  }
}

class CatTile extends StatelessWidget {
  final Cat cat;
  final bool market;
  const CatTile({super.key, required this.cat, required this.market});

  @override
  Widget build(BuildContext context) {
    final n = countIn(cat, market: market);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryResults(cat: cat, market: market))),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 72,
            height: 72,
            // ويه صورة: بدون خلفية ولا حدود (نفس لون التطبيق) فالعنصر الشفاف يطلع كأنه أيقونة
            decoration: cat.imageId.isEmpty
                ? BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [cat.color.withValues(alpha: 0.18), cat.color.withValues(alpha: 0.35)]),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: cat.imageId.isEmpty
                ? Icon(cat.icon, size: 36, color: cat.color)
                : AppImage(imageId: cat.imageId, height: 72, width: 72, fit: BoxFit.contain, fallback: Icon(cat.icon, size: 36, color: cat.color)),
          ),
          if (n > 0)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: DepoColors.accent, borderRadius: BorderRadius.circular(10)),
                child: Text('$n', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(cat.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.3)),
      ]),
    );
  }
}

/// نتائج قسم
class CategoryResults extends StatelessWidget {
  final Cat cat;
  final bool market;
  const CategoryResults({super.key, required this.cat, required this.market});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final List<Widget> body;
        if (market) {
          final ids = app.storesOfType(StoreType.merchant).map((s) => s.id).toSet();
          final list = app.offers.where((o) => o.visible && ids.contains(o.storeId) && categoryOf(o) == cat.name).toList()
            ..sort((a, b) => b.discountPercent - a.discountPercent);
          body = list.isEmpty
              ? [EmptyState(icon: cat.icon, text: 'ماكو عروض بـ «${cat.name}» هسه. ارجع بعد شوية.')]
              : [ProductGrid(products: list)];
        } else {
          final stores = app.storesOfType(StoreType.restaurant).where((s) => cuisineOf(s) == cat.name).toList()
            ..sort((a, b) => app.offersOf(b.id).length - app.offersOf(a.id).length);
          final ids = stores.map((s) => s.id).toSet();
          final offers = app.offers.where((o) => o.visible && ids.contains(o.storeId)).toList();
          body = [
            if (offers.isNotEmpty) ...[
              const Text('الرواجع المتوفرة هسه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ProductGrid(products: offers),
              const SizedBox(height: 16),
            ],
            Text('مطاعم ${cat.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (stores.isEmpty) EmptyState(icon: cat.icon, text: 'بعد ماكو مطاعم ${cat.name} بديبو.'),
            for (final s in stores) StoreTile(store: s),
          ];
        }
        return Scaffold(
          appBar: AppBar(title: Row(mainAxisSize: MainAxisSize.min, children: [Icon(cat.icon, color: cat.color), const SizedBox(width: 8), Text(cat.name)])),
          body: ListView(padding: const EdgeInsets.all(16), children: body),
        );
      },
    );
  }
}

/// اختيار قسم (chips)
class CatPicker extends StatelessWidget {
  final List<Cat> cats;
  final String value;
  final ValueChanged<String> onChanged;
  const CatPicker({super.key, required this.cats, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final c in cats)
        ChoiceChip(
          avatar: Icon(c.icon, size: 18, color: value == c.name ? Colors.white : c.color),
          label: Text(c.name),
          labelStyle: TextStyle(fontWeight: FontWeight.w800, color: value == c.name ? Colors.white : DepoColors.ink),
          selectedColor: c.color,
          showCheckmark: false,
          selected: value == c.name,
          onSelected: (_) => onChanged(c.name),
        ),
    ]);
  }
}


/// شريط أقسام أفقي بدوائر (للرئيسية)
class CatStrip extends StatelessWidget {
  final List<Cat> cats;
  final bool market;
  const CatStrip({super.key, required this.cats, required this.market});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = cats[i];
          final n = countIn(c, market: market);
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryResults(cat: c, market: market))),
            child: SizedBox(
              width: 64,
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  // مربع بحواف ناعمة: الصورة/الأيقونة تبين كاملة بدون قص
                  Container(
                    width: 56,
                    height: 56,
                    decoration: c.imageId.isEmpty
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2F2F4)),
                            gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Colors.white, c.color.withValues(alpha: 0.18)]),
                          )
                        : null, // ويه صورة: بدون خلفية ولا حدود
                    child: c.imageId.isEmpty
                        ? Icon(c.icon, size: 28, color: c.color)
                        : AppImage(imageId: c.imageId, height: 56, width: 56, fit: BoxFit.contain, fallback: Icon(c.icon, size: 28, color: c.color)),
                  ),
                  if (n > 0)
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                        decoration: BoxDecoration(color: DepoColors.accent, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                        child: Text('$n', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ]),
                const SizedBox(height: 5),
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
