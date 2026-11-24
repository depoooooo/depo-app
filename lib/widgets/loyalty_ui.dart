import 'dart:math';
import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import 'common.dart';

/// بطاقة الأختام لمحل واحد — تنعرض بصفحة المحل والسلة والحساب
class StampCard extends StatelessWidget {
  final Store store;
  final bool compact;
  const StampCard({super.key, required this.store, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final st = app.settings;
    if (!st.loyaltyOn) return const SizedBox.shrink();
    final n = st.stampsNeeded;
    final have = app.stampsOf(store.id);
    final ready = have >= n;
    final filled = ready ? n : have;
    final left = n - filled;
    final days = app.stampDaysLeft(store.id);
    final title = ready
        ? 'هديتك جاهزة! خصم ${st.stampReward}% على طلبك الجاي'
        : have == 0
            ? 'اطلب $n مرات من ${store.name} وخذ خصم ${st.stampReward}%'
            : left == 1
                ? 'باقي طلب واحد بس على هديتك!'
                : 'باقي $left طلبات على خصم ${st.stampReward}%';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ready ? const [Color(0xFFFFC24B), Color(0xFFF07B24)] : const [Color(0xFF0E7F8A), Color(0xFF06363C)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: (ready ? DepoColors.accent : DepoColors.dark).withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.loyalty_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
        ]),
        const SizedBox(height: 10),
        _StampRow(n: n, filled: filled),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: filled / n),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: Colors.white24, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ready
              ? 'الخصم ينطبق تلقائياً بالطلب (لحد ${iqd(st.stampRewardCap)})'
              : have > 0
                  ? 'أختامك تنتهي بعد $days يوم إذا ما طلبت — لا تضيّعها'
                  : 'كل طلب يوصلك = ختم. والهدية علينا',
          style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _StampRow extends StatelessWidget {
  final int n, filled;
  const _StampRow({required this.n, required this.filled});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < n; i++) ...[
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: i < filled ? 1 : 0),
              duration: Duration(milliseconds: 350 + i * 120),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.white12, Colors.white, v.clamp(0, 1)),
                  border: Border.all(color: Colors.white54, width: 1.5),
                ),
                child: Center(
                  child: i == n - 1 && i >= filled
                      ? const Icon(Icons.redeem_rounded, color: Colors.white, size: 20)
                      : Transform.scale(
                          scale: v.clamp(0, 1.3),
                          child: const Icon(Icons.check_rounded, color: DepoColors.dark, size: 20),
                        ),
                ),
              ),
            ),
          ),
        ),
        if (i < n - 1) const SizedBox(width: 6),
      ],
    ]);
  }
}

/// شارة صغيرة تطلع بالبانر: «كرت خدش ينتظرك»
class ScratchPrompt extends StatelessWidget {
  final bool inset;
  const ScratchPrompt({super.key, this.inset = true});
  @override
  Widget build(BuildContext context) {
    final n = app.me?.scratchPending ?? 0;
    if (!app.settings.scratchOn || n <= 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openScratch(context),
      child: Container(
        margin: EdgeInsets.fromLTRB(inset ? 16 : 0, 8, inset ? 16 : 0, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFC24B), Color(0xFFF07B24)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: DepoColors.accent.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          const _Wiggle(child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n == 1 ? 'عندك كرت خدش!' : 'عندك $n كروت خدش!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              Text('اخدشه وشوف شكد ربحت — لحد ${iqd(app.scratchTable.map((e) => e.$1).fold(0, max))}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Text('اخدش', style: TextStyle(color: Color(0xFFF07B24), fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }
}

class _Wiggle extends StatefulWidget {
  final Widget child;
  const _Wiggle({required this.child});
  @override
  State<_Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<_Wiggle> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final t = c.value;
          final a = t < .3 ? sin(t / .3 * pi * 4) * .18 : 0.0;
          return Transform.rotate(angle: a, child: child);
        },
        child: widget.child,
      );
}

Future<void> openScratch(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScratchSheet(),
    );

class _ScratchSheet extends StatefulWidget {
  const _ScratchSheet();
  @override
  State<_ScratchSheet> createState() => _ScratchSheetState();
}

class _ScratchSheetState extends State<_ScratchSheet> {
  int? prize; // اللي طلع
  bool loading = true, failed = false, revealed = false;
  final cells = <int>{};
  static const cols = 24, rows = 15;

  @override
  void initState() {
    super.initState();
    _draw();
  }

  // الجائزة تنحدد وتنحفظ قبل الخدش — حتى لو سكّر الكرت ما تضيع
  Future<void> _draw() async {
    final p = await app.scratchCard();
    if (!mounted) return;
    setState(() {
      prize = p;
      loading = false;
      failed = p == null;
    });
  }

  void _scratch(Offset p, Size s) {
    if (revealed) return;
    setState(() {
      final cx = (p.dx / s.width * cols).floor(), cy = (p.dy / s.height * rows).floor();
      for (var dx = -2; dx <= 2; dx++) {
        for (var dy = -2; dy <= 2; dy++) {
          if (dx * dx + dy * dy > 6) continue;
          final x = cx + dx, y = cy + dy;
          if (x >= 0 && y >= 0 && x < cols && y < rows) cells.add(y * cols + x);
        }
      }
      if (cells.length > cols * rows * .55) revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final more = (app.me?.scratchPending ?? 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: DepoColors.line, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        Text(revealed ? (prize! > 0 ? 'مبروك!' : 'حظ أوفر المرة الجاية') : 'اخدش بإصبعك',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DepoColors.ink)),
        const SizedBox(height: 4),
        const Text('كل طلب يوصلك يعطيك كرت جديد', style: TextStyle(color: DepoColors.muted, fontSize: 12.5)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1.6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : failed
                    ? const Center(child: Text('ما كدرنا نفتح الكرت. تأكد من الإنترنت وجرّب بعدين', textAlign: TextAlign.center))
                    : LayoutBuilder(builder: (_, box) {
                        final size = Size(box.maxWidth, box.maxHeight);
                        return GestureDetector(
                          onPanStart: (d) => _scratch(d.localPosition, size),
                          onPanUpdate: (d) => _scratch(d.localPosition, size),
                          child: Stack(fit: StackFit.expand, children: [
                            _Prize(prize: prize!),
                            AnimatedOpacity(
                              opacity: revealed ? 0 : 1,
                              duration: const Duration(milliseconds: 450),
                              child: CustomPaint(painter: _CoverPainter(cells), size: size),
                            ),
                          ]),
                        );
                      }),
          ),
        ),
        const SizedBox(height: 16),
        if (revealed && prize! > 0)
          Text('انضافت قسيمة ${iqd(prize!)} لحسابك — تنطبق تلقائياً على طلب فوق ${iqd(app.settings.scratchMinOrder)} خلال ${app.settings.couponDays} أيام',
              textAlign: TextAlign.center, style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w800, fontSize: 13)),
        if (revealed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                if (more > 0) openScratch(context);
              },
              child: Text(more > 0 ? 'اخدش الكرت الجاي ($more)' : 'يلا نطلب'),
            ),
          ),
        ] else if (!loading && !failed)
          TextButton(onPressed: () => setState(() => revealed = true), child: const Text('اكشف مرة وحدة')),
      ]),
    );
  }
}

class _Prize extends StatelessWidget {
  final int prize;
  const _Prize({required this.prize});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFE3F8FA), Color(0xFFFFF4DE)])),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(prize > 0 ? Icons.celebration_rounded : Icons.sentiment_satisfied_rounded, size: 44, color: prize > 0 ? DepoColors.accent : DepoColors.muted),
          const SizedBox(height: 6),
          Text(prize > 0 ? 'ربحت ${iqd(prize)}' : 'ولا يهمك', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: DepoColors.ink)),
          if (prize > 0) const Text('خصم على طلبك الجاي', style: TextStyle(color: DepoColors.muted, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// طبقة الخدش: نرسمها بس على الخلايا اللي ما انخدشت (clip — يشتغل على كل الأجهزة)
class _CoverPainter extends CustomPainter {
  final Set<int> gone;
  _CoverPainter(this.gone);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final cw = size.width / _ScratchSheetState.cols, ch = size.height / _ScratchSheetState.rows;
    final clip = Path();
    for (var y = 0; y < _ScratchSheetState.rows; y++) {
      for (var x = 0; x < _ScratchSheetState.cols; x++) {
        if (!gone.contains(y * _ScratchSheetState.cols + x)) clip.addRect(Rect.fromLTWH(x * cw - .5, y * ch - .5, cw + 1, ch + 1));
      }
    }
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(r, Paint()..shader = const LinearGradient(colors: [Color(0xFF4BCDDB), Color(0xFF0E7F8A)]).createShader(r));
    final dots = Paint()..color = Colors.white24;
    for (var x = 12.0; x < size.width; x += 22) {
      for (var y = 12.0; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 2, dots);
      }
    }
    final tp = TextPainter(
      text: const TextSpan(text: 'اخدش هنا', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) => true;
}

/// قسائمي + بطاقاتي — قسم بشاشة الحساب
class LoyaltyWallet extends StatelessWidget {
  final bool inset;
  const LoyaltyWallet({super.key, this.inset = true});
  @override
  Widget build(BuildContext context) {
    if (!app.settings.loyaltyOn || !app.loggedIn) return const SizedBox.shrink();
    final stores = app.myStampStores;
    final coupons = app.myCoupons;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ScratchPrompt(inset: inset),
      Padding(
        padding: EdgeInsets.fromLTRB(inset ? 16 : 0, 10, inset ? 16 : 0, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('بطاقات الولاء وهداياك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          if (coupons.isNotEmpty)
            SizedBox(
              height: 74,
              child: ListView(scrollDirection: Axis.horizontal, children: [for (final c in coupons) CouponChip(c)]),
            ),
          if (stores.isEmpty && coupons.isEmpty)
            AppCard(
              child: Text('كل طلب يوصلك من أي محل يعطيك ختم + كرت خدش. ${app.settings.stampsNeeded} أختام من نفس المحل = خصم ${app.settings.stampReward}%',
                  style: const TextStyle(color: DepoColors.muted, fontWeight: FontWeight.w700)),
            ),
          for (final s in stores) StampCard(store: s, compact: true),
        ]),
      ),
    ]);
  }
}

class CouponChip extends StatelessWidget {
  final Coupon c;
  const CouponChip(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final days = ((c.expiresAt - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil();
    return Container(
      width: 170,
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DepoColors.accent, width: 1.4),
      ),
      child: Row(children: [
        const Icon(Icons.confirmation_number_rounded, color: DepoColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('خصم ${iqd(c.amount)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(days <= 1 ? 'تنتهي اليوم!' : 'باقي $days أيام', style: TextStyle(fontSize: 11.5, color: days <= 2 ? DepoColors.danger : DepoColors.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
