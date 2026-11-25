import 'package:flutter/material.dart';
import '../../theme.dart';

/// ألوان قسم الأسواق — نفس هوية ديبو (فاتح + فيروزي)
class Jm {
  static const bgTop = DepoColors.bg;
  static const bgMid = DepoColors.bg;
  static const bgBottom = DepoColors.bg;
  static const card = Colors.white;
  static const cardSolid = Colors.white;
  static const line = DepoColors.line;
  static const text = DepoColors.ink;
  static const sub = DepoColors.muted;
  static const faint = Color(0xFF7F9A9E);
  static const cyan = DepoColors.dark; // الأزرار والأرقام
  static const green = Color(0xFF17A06A);
  static const red = Color(0xFFE5484D);
  static const yellow = DepoColors.accent;
  static const onCyan = Colors.white;
}

/// نفس ثيم التطبيق، بس حقول الإدخال بيضاء وناعمة
ThemeData jmTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Jm.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Jm.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Jm.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DepoColors.brand, width: 1.5)),
    ),
  );
}

/// شاشة بنفس شكل شاشات ديبو: شريط علوي + عنوان بالوسط
class JmScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading; // صورة المحل جنب العنوان
  final List<Widget> actions;
  final Widget body;
  final Widget? bottom;
  final Color? titleColor;
  const JmScaffold({super.key, required this.title, this.subtitle, this.leading, this.actions = const [], required this.body, this.bottom, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: jmTheme(context),
      child: Scaffold(
        backgroundColor: DepoColors.bg,
        bottomNavigationBar: bottom,
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[SizedBox(width: 34, height: 34, child: FittedBox(child: leading!)), const SizedBox(width: 8)],
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: titleColor ?? DepoColors.ink)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: DepoColors.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          actions: [for (final a in actions) Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: a), const SizedBox(width: 6)],
        ),
        body: body,
      ),
    );
  }
}

class JmCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const JmCircleBtn({super.key, required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: DepoColors.soft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20, color: DepoColors.dark)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// كارت شبه شفاف بحدود رفيعة
class JmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool dashed;
  final Color? color;
  final Color? border;
  const JmCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.dashed = false, this.color, this.border});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color ?? Jm.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border ?? (dashed ? DepoColors.brand : Jm.line), width: dashed ? 1.2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// زر كبير ملوّن
class JmButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color fg;
  final VoidCallback? onTap;
  final bool outlined;
  final double height;
  const JmButton({super.key, required this.label, this.icon, this.color = Jm.cyan, this.fg = Colors.white, this.onTap, this.outlined = false, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w900, color: outlined ? Jm.text : fg);
    return SizedBox(
      height: height,
      child: Material(
        color: outlined ? Colors.white : (onTap == null ? color.withValues(alpha: 0.4) : color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: outlined ? const BorderSide(color: Jm.line) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: style),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20, color: outlined ? Jm.text : fg)],
            ]),
          ),
        ),
      ),
    );
  }
}

/// أزرار اختيار متساوية (تبويبات/فلترة)
class JmSegment extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  const JmSegment({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == index ? DepoColors.dark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == index ? DepoColors.dark : Jm.line),
              ),
              child: Text(items[i], style: TextStyle(fontWeight: i == index ? FontWeight.w900 : FontWeight.w600, color: i == index ? Colors.white : Jm.sub)),
            ),
          ),
        ),
        if (i < items.length - 1) const SizedBox(width: 8),
      ],
    ]);
  }
}

/// حالة فارغة داخل كارت منقّط
class JmEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;
  const JmEmpty({super.key, required this.icon, required this.title, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return JmCard(
      dashed: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(children: [
        CircleAvatar(radius: 26, backgroundColor: DepoColors.soft, child: Icon(icon, color: Jm.cyan)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Jm.sub, height: 1.5)),
      ]),
    );
  }
}

/// كارت المبلغ الكبير
class JmAmountCard extends StatelessWidget {
  final String label;
  final String amount;
  final String sub;
  final Widget? extra;
  const JmAmountCard({super.key, required this.label, required this.amount, required this.sub, this.extra});

  @override
  Widget build(BuildContext context) {
    return JmCard(
      color: DepoColors.soft,
      border: DepoColors.brand,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Jm.sub)),
        const SizedBox(height: 6),
        Text(amount, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 12, color: Jm.sub)),
        if (extra != null) ...[const SizedBox(height: 10), extra!],
      ]),
    );
  }
}

/// كارت صغير بسهم (المحصّل / متأخر)
class JmStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool up;
  const JmStat({super.key, required this.label, required this.value, required this.sub, required this.up});

  @override
  Widget build(BuildContext context) {
    final c = up ? Jm.green : Jm.red;
    return JmCard(
      color: up ? DepoColors.successBg : const Color(0xFFFDECED),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 14, backgroundColor: c.withValues(alpha: 0.25), child: Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: c)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Jm.sub)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Jm.faint)),
      ]),
    );
  }
}

/// toast بستايل جمّارة
void jmToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Jm.cyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 24),
      content: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w800)),
    ));
}

/// دائرة صورة المحل (حرف أول إذا ماكو صورة)
class JmAvatar extends StatelessWidget {
  final String letter;
  final Widget? image;
  final double size;
  final Color color;
  const JmAvatar({super.key, required this.letter, this.image, this.size = 52, this.color = DepoColors.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white, width: 2)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image ?? Text(letter, style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}

const jmMuted = DepoColors.muted;
