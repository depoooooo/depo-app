import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme.dart';

class PriceTag extends StatelessWidget {
  final int price;
  final int original;
  final double size;
  const PriceTag({super.key, required this.price, required this.original, this.size = 17});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(iqd(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w900)),
        Text(
          iqd(original),
          style: const TextStyle(
            fontSize: 12,
            color: DepoColors.muted,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

class Badge2 extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Badge2(this.text, {super.key, this.bg = DepoColors.accent, this.fg = DepoColors.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

/// مكان الصورة لحد ما تجي صور حقيقية
class ImagePlaceholder extends StatelessWidget {
  final double height;
  final bool box;
  final double radius;
  const ImagePlaceholder({super.key, this.height = 110, this.box = false, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(colors: [DepoColors.soft, Color(0xFFC9F1F6)]),
      ),
      alignment: Alignment.center,
      child: Icon(
        box ? Icons.inventory_2_outlined : Icons.restaurant_outlined,
        color: DepoColors.dark,
        size: 32,
        semanticLabel: box ? 'صورة الصندوق' : 'صورة الوجبة',
      ),
    );
  }
}

class StorageChip extends StatelessWidget {
  final Storage storage;
  const StorageChip(this.storage, {super.key});

  @override
  Widget build(BuildContext context) {
    if (storage == Storage.normal) return const SizedBox.shrink();
    final label = storage == Storage.chilled ? 'مبرّد' : 'مجمّد';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xFFE6F1FE), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(storage == Storage.chilled ? Icons.thermostat : Icons.ac_unit,
            size: 12, color: const Color(0xFF1D4F91)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1D4F91))),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final VoidCallback? onAll;
  const SectionTitle(this.text, {super.key, this.onAll});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      if (onAll != null)
        TextButton(onPressed: onAll, child: const Text('الكل', style: TextStyle(fontWeight: FontWeight.w700))),
    ]);
  }
}
