import 'package:flutter/material.dart';
import '../theme.dart';

/// «سمايلات ديبو»: بدل الإيموجي العادي، أيقونة بمربع ناعم بألوان هوية ديبو
class DepoGlyph extends StatelessWidget {
  final String emoji;
  final double size;
  const DepoGlyph(this.emoji, {super.key, this.size = 22});

  static const _teal = [Color(0xFF4BCDDB), Color(0xFF0E7F8A)];
  static const _ink = [Color(0xFF0E7F8A), Color(0xFF06363C)];
  static const _warm = [Color(0xFFFFC24B), Color(0xFFF07B24)];
  static const _rose = [Color(0xFFFF8A8E), Color(0xFFE5484D)];
  static const _mint = [Color(0xFF5BE0A5), Color(0xFF17A06A)];

  /// الإيموجي ← (أيقونة، تدرّج)
  static const Map<String, (IconData, List<Color>)> map = {
    '🔥': (Icons.local_fire_department_rounded, _warm),
    '⚡': (Icons.bolt_rounded, _warm),
    '💥': (Icons.flare_rounded, _warm),
    '⭐': (Icons.star_rounded, _warm),
    '🌟': (Icons.star_rounded, _warm),
    '🎁': (Icons.redeem_rounded, _teal),
    '🎉': (Icons.celebration_rounded, _teal),
    '🥳': (Icons.celebration_rounded, _teal),
    '🍽️': (Icons.restaurant_rounded, _teal),
    '🍽': (Icons.restaurant_rounded, _teal),
    '🛒': (Icons.shopping_basket_rounded, _teal),
    '🛍️': (Icons.shopping_bag_rounded, _teal),
    '🛵': (Icons.delivery_dining_rounded, _teal),
    '🚀': (Icons.rocket_launch_rounded, _teal),
    '📍': (Icons.location_on_rounded, _teal),
    '⏰': (Icons.alarm_rounded, _ink),
    '⏳': (Icons.hourglass_bottom_rounded, _ink),
    '🔔': (Icons.notifications_rounded, _ink),
    '🛎️': (Icons.room_service_rounded, _ink),
    '💬': (Icons.chat_bubble_rounded, _ink),
    '💰': (Icons.payments_rounded, _mint),
    '💸': (Icons.savings_rounded, _mint),
    '💵': (Icons.payments_rounded, _mint),
    '✅': (Icons.check_rounded, _mint),
    '🌱': (Icons.eco_rounded, _mint),
    '♻️': (Icons.recycling_rounded, _mint),
    '❤️': (Icons.favorite_rounded, _rose),
    '❤': (Icons.favorite_rounded, _rose),
    '😍': (Icons.favorite_rounded, _rose),
    '⚠️': (Icons.priority_high_rounded, _rose),
    '🍕': (Icons.local_pizza_rounded, _warm),
    '🍔': (Icons.lunch_dining_rounded, _warm),
    '☕': (Icons.coffee_rounded, _ink),
    '🍰': (Icons.cake_rounded, _rose),
  };

  @override
  Widget build(BuildContext context) {
    final g = map[emoji] ?? (Icons.auto_awesome_rounded, _teal);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: g.$2),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [BoxShadow(color: g.$2.last.withValues(alpha: 0.35), blurRadius: size * 0.25, offset: Offset(0, size * 0.08))],
      ),
      child: Stack(alignment: Alignment.center, children: [
        // لمعة خفيفة (نفس روح الشعار)
        Positioned(
          top: size * 0.1,
          right: size * 0.14,
          child: Container(width: size * 0.16, height: size * 0.16, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45), shape: BoxShape.circle)),
        ),
        Icon(g.$1, size: size * 0.62, color: Colors.white),
      ]),
    );
  }
}

final _emojiRe = RegExp(
  r'(?:[\u{1F000}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|[\u{2B00}-\u{2BFF}])\u{FE0F}?',
  unicode: true,
);

/// نص يتحوّل بيه الإيموجي لسمايلات ديبو
class DepoText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  const DepoText(this.text, {super.key, this.style, this.maxLines, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final st = DefaultTextStyle.of(context).style.merge(style);
    final fs = st.fontSize ?? 14;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _emojiRe.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final e = m.group(0)!;
      // ✓ ★ وأمثالها رموز عادية — تبقى
      if (e == '✓' || e == '★' || e == '✔' || e == '☆') {
        spans.add(TextSpan(text: e));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: fs * 0.12), child: DepoGlyph(e, size: fs * 1.15)),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: st, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, textAlign: textAlign);
  }
}
