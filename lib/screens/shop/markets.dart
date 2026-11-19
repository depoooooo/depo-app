import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/offer_cards.dart';

/// «الأسواق القريبة»: محلات الحي بأسعارها — تطلب وتستلم، أو يوصّلك صاحب المحل
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
        final list = app.shops.where((s) => q.isEmpty || s.name.contains(q) || s.area.contains(q) || app.offersOf(s.id).any((o) => o.title.contains(q))).toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return Scaffold(
          appBar: AppBar(title: const Text('الأسواق القريبة')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن محل أو منتج'), onChanged: (v) => setState(() => q = v.trim())),
            const SizedBox(height: 8),
            const Text('اعرف الأسعار قبل ما تروح، واطلب واستلم من المحل أو خلّي صاحبه يوصّلك.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
            const SizedBox(height: 12),
            if (list.isEmpty) const EmptyState(icon: Icons.storefront_outlined, text: 'بعد ماكو أسواق هنا. أول ما محل يفتح متجره يطلع هنا.'),
            for (final s in list) StoreTile(store: s),
          ]),
        );
      },
    );
  }
}
