import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';
import '../theme.dart';
import 'common.dart';

/// كل شهر بلون (يتكرر كل 12 شهر) حتى يبين بالعين إنه شهر مختلف
const _monthPalette = [
  Color(0xFF3B82F6), // 1 أزرق
  Color(0xFF8B5CF6), // 2 بنفسجي
  Color(0xFF10B981), // 3 أخضر
  Color(0xFFF59E0B), // 4 برتقالي
  Color(0xFFEC4899), // 5 وردي
  Color(0xFF06B6D4), // 6 سماوي
  Color(0xFFEF4444), // 7 أحمر
  Color(0xFF84CC16), // 8 ليموني
  Color(0xFFE11D48), // 9 قرمزي
  Color(0xFF2563EB), // 10 أزرق غامق
  Color(0xFF16A34A), // 11 أخضر غامق
  Color(0xFF9333EA), // 12 أرجواني
];

Color monthColor(String month) {
  final m = int.tryParse(month.split('/').last) ?? 1;
  return _monthPalette[(m - 1) % 12];
}

const _monthNames = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];

String monthLabel(String month) {
  final p = month.split('/');
  if (p.length != 2) return month;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_monthNames[(m - 1) % 12]} ${p[0]}';
}

String dateLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}/${d.month}/${d.day}';
}

class MonthChip extends StatelessWidget {
  final String month;
  final bool selected;
  final VoidCallback? onTap;
  const MonthChip(this.month, {super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = monthColor(month);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c, width: selected ? 2 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: selected ? Colors.white : c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(monthLabel(month), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: selected ? Colors.white : DepoColors.ink)),
        ]),
      ),
    );
  }
}

/// حركات الدفتر مقسّمة حسب الشهر، وكل شهر بلونه
class DebtEntriesList extends StatelessWidget {
  final List<DebtEntry> entries;
  final void Function(DebtEntry)? onLongPress;
  const DebtEntriesList({super.key, required this.entries, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, text: 'ماكو حركات بعد');
    final months = <String>[];
    for (final e in entries) {
      if (!months.contains(e.month)) months.add(e.month);
    }
    months.sort((a, b) => b.compareTo(a));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final m in months) ...[
        _MonthHeader(month: m, entries: entries.where((e) => e.month == m && !e.voided).toList()),
        for (final e in entries.where((e) => e.month == m)) _EntryTile(e: e, onLongPress: onLongPress),
        const SizedBox(height: 6),
      ],
    ]);
  }
}

class _MonthHeader extends StatelessWidget {
  final String month;
  final List<DebtEntry> entries;
  const _MonthHeader({required this.month, required this.entries});

  @override
  Widget build(BuildContext context) {
    final c = monthColor(month);
    final orders = entries.where((e) => !e.payment).fold(0, (s, e) => s + e.amount);
    final paid = entries.where((e) => e.payment).fold(0, (s, e) => s + e.amount);
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 5, height: 22, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(monthLabel(month), style: TextStyle(fontWeight: FontWeight.w900, color: c)),
        const Spacer(),
        Text('طلبات ${iqd(orders)}${paid > 0 ? ' • دفع ${iqd(paid)}' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final DebtEntry e;
  final void Function(DebtEntry)? onLongPress;
  const _EntryTile({required this.e, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = monthColor(e.month);
    final strike = e.voided ? TextDecoration.lineThrough : null;
    final overdue = !e.payment && e.dueAt > 0 && e.dueAt < DateTime.now().millisecondsSinceEpoch;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: onLongPress == null || e.voided ? null : () => onLongPress!(e),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 6, color: e.payment ? DepoColors.success : c),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(e.payment ? Icons.south_west_rounded : Icons.north_east_rounded, size: 18, color: e.payment ? DepoColors.success : DepoColors.danger),
                      const SizedBox(width: 6),
                      Text(e.payment ? 'دفعة' : 'طلب', style: TextStyle(fontWeight: FontWeight.w900, decoration: strike)),
                      if (e.voided) ...[const SizedBox(width: 6), const Badge2('ملغية', bg: DepoColors.soft, fg: DepoColors.muted)],
                      const Spacer(),
                      Text('${e.payment ? '-' : '+'}${iqd(e.amount)}',
                          style: TextStyle(fontWeight: FontWeight.w900, decoration: strike, color: e.payment ? DepoColors.success : DepoColors.ink)),
                    ]),
                    for (final i in e.items)
                      Text('• ${i.name} ×${i.qty} — ${iqd(i.total)}', style: TextStyle(fontSize: 12, color: DepoColors.muted, decoration: strike)),
                    if (e.note.isNotEmpty) Text(e.note, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(dateLabel(e.createdAt), style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
                      if (!e.payment && e.dueAt > 0) ...[
                        const Spacer(),
                        Badge2('يستحق ${dateLabel(e.dueAt)}', bg: overdue ? const Color(0xFFFDECED) : DepoColors.soft, fg: overdue ? DepoColors.danger : DepoColors.dark),
                      ],
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// بطاقة الملخص (المتبقي + نسبة التسديد)
class DebtSummaryCard extends StatelessWidget {
  final String title;
  final int remaining, paid, ordered, overdue;
  final int nextDue;
  const DebtSummaryCard({super.key, required this.title, required this.remaining, required this.paid, required this.ordered, this.overdue = 0, this.nextDue = 0});

  @override
  Widget build(BuildContext context) {
    final pct = ordered == 0 ? 0.0 : (paid / ordered).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DepoColors.ink, Color(0xFF0A5F68)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(iqd(remaining), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: const Color(0x44FFFFFF), color: DepoColors.brand),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('مسدّد ${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${iqd(paid)} من ${iqd(ordered)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        if (overdue > 0 || nextDue > 0) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (overdue > 0) Badge2('متأخر ${iqd(overdue)}', bg: const Color(0xFFFFE1E1), fg: DepoColors.danger),
            if (nextDue > 0) Badge2('أقرب موعد ${dateLabel(nextDue)}', bg: Colors.white, fg: DepoColors.dark),
          ]),
        ],
      ]),
    );
  }
}

// ---------- مساعدات الاتصال والواتساب ----------
String _intl(String phone) {
  final p = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('0')) return '964${p.substring(1)}';
  return p;
}

Future<void> openWhatsApp(BuildContext context, String phone, String text) async {
  final uri = Uri.parse('https://wa.me/${phone.isEmpty ? '' : _intl(phone)}?text=${Uri.encodeComponent(text)}');
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw 'x';
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, 'ما انفتح الواتساب، فنسخنا الرسالة. الصقها بنفسك.');
  }
}

Future<void> callPhone(BuildContext context, String phone) async {
  try {
    if (!await launchUrl(Uri.parse('tel:$phone'))) throw 'x';
  } catch (_) {
    if (context.mounted) toast(context, 'ما انفتح الاتصال');
  }
}

Future<void> copyText(BuildContext context, String text, {String done = 'انسخ'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, done);
}
