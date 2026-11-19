import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home.dart';
import 'store_page.dart';

/// البحث: الأكثر بحثاً حولك + المجموعات + النتائج والفلاتر
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Collection { none, bakery, under3000, sweets }

class _SearchScreenState extends State<SearchScreen> {
  final q = TextEditingController();
  _Collection collection = _Collection.none;
  bool onlyBoxes = false;
  bool sortByDiscount = false;

  static const trending = ['صمون', 'كبة', 'فروج', 'كنافة', 'لبن', 'معجنات'];
  List<String> recent = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => recent = p.getStringList('depo_recent_search') ?? []);
    });
  }

  /// يحفظ الكلمة بـ «آخر شي دوّرت عليه»
  Future<void> _remember([String? word]) async {
    final t = (word ?? q.text).trim();
    if (t.length < 2) return;
    recent = [t, ...recent.where((x) => x != t)].take(8).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('depo_recent_search', recent);
  }

  Future<void> _clearRecent() async {
    setState(() => recent = []);
    final p = await SharedPreferences.getInstance();
    await p.remove('depo_recent_search');
  }

  void _use(String t) {
    setState(() => q.text = t);
    _remember(t);
  }

  @override
  void dispose() {
    _remember();
    q.dispose();
    super.dispose();
  }

  List<Offer> get results {
    var list = app.offers.where((o) {
      final s = app.storeById(o.storeId);
      return o.visible && s != null && !s.suspended && s.type != StoreType.shop;
    }).toList();
    final text = q.text.trim();
    if (text.isNotEmpty) {
      list = list.where((o) {
        final s = app.storeById(o.storeId)!;
        return o.title.contains(text) || s.name.contains(text) || s.area.contains(text);
      }).toList();
    }
    switch (collection) {
      case _Collection.bakery:
        list = list.where((o) => app.storeById(o.storeId)!.name.contains('فرن') || o.title.contains('صمون') || o.title.contains('معجنات')).toList();
      case _Collection.under3000:
        list = list.where((o) => o.price <= 3000).toList();
      case _Collection.sweets:
        list = list.where((o) => app.storeById(o.storeId)!.name.contains('حلويات') || o.title.contains('كنافة')).toList();
      case _Collection.none:
        break;
    }
    if (onlyBoxes) list = list.where((o) => o.surpriseBox).toList();
    if (sortByDiscount) list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    return list;
  }

  bool get searching => q.text.trim().isNotEmpty || collection != _Collection.none;

  @override
  Widget build(BuildContext context) {
    final res = searching ? results : <Offer>[];
    final stores = q.text.trim().isEmpty ? <Store>[] : app.stores.where((s) => !s.suspended && s.type != StoreType.shop && (s.name.contains(q.text.trim()) || s.area.contains(q.text.trim()))).toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: q,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'دوّر على مطعم أو وجبة أو منتج', isDense: true, prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _remember(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChip(label: const Text('صناديق مفاجأة بس'), selected: onlyBoxes, onSelected: (v) => setState(() => onlyBoxes = v)),
            FilterChip(label: const Text('الأكثر خصم'), selected: sortByDiscount, onSelected: (v) => setState(() => sortByDiscount = v)),
          ]),
          const SizedBox(height: 12),
          if (!searching) ...[
            if (recent.isNotEmpty) ...[
              Row(children: [
                const Expanded(child: Text('آخر شي دوّرت عليه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                TextButton(onPressed: _clearRecent, child: const Text('مسح')),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in recent)
                  ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 18),
                    label: Text(t),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () => _use(t),
                  ),
              ]),
              const SizedBox(height: 16),
            ],
            const Text('الأكثر بحثاً حولك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in trending)
                ActionChip(avatar: const Icon(Icons.search, size: 16), label: Text(t), onPressed: () => _use(t)),
            ]),
            const SizedBox(height: 16),
            const Text('المجموعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _CollectionTile('رواجع الأفران', 'صمون وخبز ومعجنات', Icons.bakery_dining, DepoColors.soft, () => setState(() => collection = _Collection.bakery)),
                _CollectionTile('تحت 3,000 دينار', 'أرخص العروض', Icons.payments_outlined, const Color(0xFFFFF6E5), () => setState(() => collection = _Collection.under3000)),
                _CollectionTile('حلويات آخر الليل', 'من 10 بالليل', Icons.icecream_outlined, const Color(0xFFFDECED), () => setState(() => collection = _Collection.sweets)),
                _CollectionTile('اكسب نقاط', 'ادعُ صديقك من «حسابي»', Icons.card_giftcard, DepoColors.successBg, () => toast(context, 'من «حسابي» ← دعوة صديق')),
              ],
            ),
          ] else ...[
            if (collection != _Collection.none)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(label: const Text('مجموعة مختارة'), onDeleted: () => setState(() => collection = _Collection.none)),
              ),
            for (final s in stores)
              AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(storeId: s.id))),
                child: Row(children: [
                  Icon(s.type == StoreType.restaurant ? Icons.restaurant : Icons.storefront, color: DepoColors.dark),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w800))),
                  const Icon(Icons.chevron_left),
                ]),
              ),
            if (res.isEmpty && stores.isEmpty)
              const EmptyState(icon: Icons.search_off, text: 'ما لكينا شي. جرّب كلمة ثانية.'),
            if (res.isNotEmpty) ProductGrid(products: res),
          ],
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  const _CollectionTile(this.title, this.sub, this.icon, this.bg, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: DepoColors.dark, size: 28),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(sub, style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          ]),
        ),
      ),
    );
  }
}
