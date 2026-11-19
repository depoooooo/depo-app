import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../theme.dart';

/// مفتاح «رواجع المطاعم / الماركت»: حبّة بيضاء تنزلق ويه السحب، أيقونة بدائرة، وسطر يوضّح كل قسم
class ModeSwitch extends StatelessWidget {
  final TabController controller;
  const ModeSwitch({super.key, required this.controller});

  static const _items = [
    (Icons.restaurant_rounded, 'رواجع المطاعم', 'أكل اليوم بنص السعر'),
    (Icons.shopping_basket_rounded, 'الماركت', 'بضاعة بأرخص سعر'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: AnimatedBuilder(
        animation: controller.animation!,
        builder: (context, _) {
          final t = controller.animation!.value.clamp(0.0, 1.0);
          return Stack(children: [
            // الحبّة البيضاء
            Align(
              alignment: AlignmentDirectional(lerpDouble(-1, 1, t)!, 0),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x2606363C), blurRadius: 10, offset: Offset(0, 3))],
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _Seg(
                    icon: _items[i].$1,
                    title: _items[i].$2,
                    sub: _items[i].$3,
                    on: 1 - (t - i).abs().clamp(0.0, 1.0), // 1 = مختار
                    onTap: () => controller.animateTo(i),
                  ),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final double on;
  final VoidCallback onTap;
  const _Seg({required this.icon, required this.title, required this.sub, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on > 0.5,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color.lerp(Colors.white.withValues(alpha: 0.5), DepoColors.dark, on),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: Color.lerp(DepoColors.dark, Colors.white, on)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: on > 0.5 ? FontWeight.w900 : FontWeight.w700, color: DepoColors.ink, height: 1.2)),
                Opacity(
                  opacity: 0.55 + 0.45 * on,
                  child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: DepoColors.ink, height: 1.2)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
