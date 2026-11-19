import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/images.dart';
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
        if (original > price)
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

/// مكان الصورة لحد ما تجي صور حقيقية: لون وأيقونة حسب نوع الأكل
class ImagePlaceholder extends StatelessWidget {
  final double height;
  final bool box;
  final double radius;
  final String seed;
  const ImagePlaceholder({super.key, this.height = 110, this.box = false, this.radius = 14, this.seed = ''});

  static const _palettes = [
    [Color(0xFFFFE8CC), Color(0xFFFFD199)], // برتقالي
    [Color(0xFFDFF7F9), Color(0xFFB5EBF1)], // فيروزي
    [Color(0xFFFFE3E3), Color(0xFFFFC2C2)], // وردي
    [Color(0xFFE8F5E1), Color(0xFFC8E8B5)], // أخضر
    [Color(0xFFFFF3C4), Color(0xFFFFE38A)], // أصفر
    [Color(0xFFEDE7FB), Color(0xFFD4C8F5)], // بنفسجي
  ];

  IconData get _icon {
    final t = seed;
    if (box) return Icons.inventory_2_rounded;
    if (t.contains('صمون') || t.contains('خبز') || t.contains('معجنات') || t.contains('بسكت')) return Icons.bakery_dining_rounded;
    if (t.contains('كنافة') || t.contains('حلو') || t.contains('كيك')) return Icons.cake_rounded;
    if (t.contains('فروج') || t.contains('دجاج') || t.contains('مشاوي') || t.contains('كبة')) return Icons.kebab_dining_rounded;
    if (t.contains('لبن') || t.contains('حليب')) return Icons.local_drink_rounded;
    if (t.contains('غسيل') || t.contains('منظف')) return Icons.local_laundry_service_rounded;
    return Icons.restaurant_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = _palettes[seed.isEmpty ? 1 : seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length];
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: p),
      ),
      alignment: Alignment.center,
      child: Icon(_icon, color: DepoColors.ink.withValues(alpha: 0.55), size: height * 0.38,
          semanticLabel: box ? 'صورة الصندوق' : 'صورة الوجبة'),
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

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.onTap, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color ?? Colors.white,
        elevation: 0.6,
        shadowColor: const Color(0x2206363C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor ?? const Color(0xFFE8F4F6), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 48, color: DepoColors.brand),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: DepoColors.muted, height: 1.6)),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DepoColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

/// شبكة إحصائيات بعمودين
class StatGrid extends StatelessWidget {
  final List<StatTile> tiles;
  const StatGrid(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: tiles,
    );
  }
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontFamily: 'Tajawal'))));
}

int? parseInt(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return int.tryParse(b.toString().replaceAll(',', '').replaceAll('٬', '').trim());
}

/// صورة من Firebase (برقمها)، وإذا ماكو صورة يطلع البديل
class AppImage extends StatefulWidget {
  final String imageId;
  final double height;
  final double? width;
  final double radius;
  final Widget fallback;
  const AppImage({super.key, required this.imageId, required this.fallback, this.height = 110, this.width, this.radius = 0});

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  Future<Uint8List?>? _f;

  void _load() => _f = widget.imageId.isEmpty ? null : Images.get(widget.imageId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AppImage old) {
    super.didUpdateWidget(old);
    if (old.imageId != widget.imageId) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_f == null) return widget.fallback;
    final cached = Images.cached(widget.imageId);
    Widget img(Uint8List b) => ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Image.memory(b, height: widget.height, width: widget.width ?? double.infinity, fit: BoxFit.cover, gaplessPlayback: true),
        );
    if (cached != null) return img(cached);
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        if (snap.data != null) return img(snap.data!);
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(color: DepoColors.soft, borderRadius: BorderRadius.circular(widget.radius)),
          );
        }
        return widget.fallback;
      },
    );
  }
}

/// صورة العرض: الحقيقية إذا موجودة، وإلا الملوّنة
class OfferImage extends StatelessWidget {
  final Offer offer;
  final double height;
  final double radius;
  const OfferImage({super.key, required this.offer, this.height = 112, this.radius = 0});

  @override
  Widget build(BuildContext context) => AppImage(
        imageId: offer.imageId,
        height: height,
        radius: radius,
        fallback: ImagePlaceholder(height: height, box: offer.surpriseBox, radius: radius, seed: offer.title),
      );
}

/// يسأل عن عنوان: الحي + أقرب نقطة دالة
Future<String?> askAddress(BuildContext context) async {
  final area = TextEditingController();
  final near = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('عنوان التوصيل'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: area, autofocus: true, decoration: const InputDecoration(labelText: 'الحي', hintText: 'مثلاً: النور، الزهور، المثنى')),
        const SizedBox(height: 10),
        TextField(controller: near, decoration: const InputDecoration(labelText: 'أقرب نقطة دالة', hintText: 'مثلاً: قرب جامع النور، بيت رقم 12')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            final a = area.text.trim();
            if (a.length < 2) return;
            final n = near.text.trim();
            Navigator.pop(c, n.isEmpty ? 'حي $a' : 'حي $a — $n');
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  area.dispose();
  near.dispose();
  return r;
}

/// يختار صورة ويرفعها، ويرجّع رقمها (أو null)
Future<String?> pickAndUpload(BuildContext context, {String owner = '', double maxSide = 800, int quality = 60}) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('صوّر هسه'), onTap: () => Navigator.pop(c, true)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('من المعرض'), onTap: () => Navigator.pop(c, false)),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (camera == null) return null;
  try {
    final b = await Images.pick(camera: camera, maxSide: maxSide, quality: quality);
    if (b == null) return null;
    return await Images.put(b, owner: owner);
  } catch (e) {
    if (context.mounted) toast(context, 'ما انرفعت الصورة: $e');
    return null;
  }
}


Future<String?> clipboardText() async {
  final d = await Clipboard.getData(Clipboard.kTextPlain);
  return d?.text;
}
