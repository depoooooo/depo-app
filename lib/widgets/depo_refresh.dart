import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

enum _Mode { idle, drag, armed, loading, done }

/// السحب للتحديث بشعار ديبو: «اسحب للتحديث» ← «أفلت للتحديث» ← «جاري التحديث…» ← «تم التحديث ✓»
class DepoRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  const DepoRefresh({super.key, required this.child, required this.onRefresh});

  @override
  State<DepoRefresh> createState() => _DepoRefreshState();
}

class _DepoRefreshState extends State<DepoRefresh> with TickerProviderStateMixin {
  static const armAt = 90.0;
  static const maxPull = 150.0;
  double pull = 0;
  _Mode mode = _Mode.idle;
  bool dragging = false;
  late final AnimationController settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Animation<double>? _settleAnim;

  @override
  void initState() {
    super.initState();
    settle.addListener(() {
      if (_settleAnim != null) setState(() => pull = _settleAnim!.value);
    });
  }

  @override
  void dispose() {
    settle.dispose();
    spin.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _settleAnim = Tween(begin: pull, end: target).animate(CurvedAnimation(parent: settle, curve: Curves.easeOutCubic));
    settle.forward(from: 0);
  }

  void _setPull(double v) {
    if (mode == _Mode.loading || mode == _Mode.done) return;
    pull = v.clamp(0.0, maxPull);
    final m = pull <= 0 ? _Mode.idle : (pull >= armAt ? _Mode.armed : _Mode.drag);
    if (m == _Mode.armed && mode != _Mode.armed) spin.repeat();
    if (m != _Mode.armed && mode == _Mode.armed) spin.stop();
    setState(() => mode = m);
  }

  Future<void> _release() async {
    dragging = false;
    if (mode == _Mode.armed) {
      setState(() => mode = _Mode.loading);
      spin.repeat();
      _animateTo(armAt);
      try {
        await widget.onRefresh();
      } catch (_) {}
      if (!mounted) return;
      setState(() => mode = _Mode.done);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      spin.stop();
      _animateTo(0);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => mode = _Mode.idle);
    } else if (mode != _Mode.loading && mode != _Mode.done) {
      _animateTo(0);
      setState(() => mode = _Mode.idle);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      dragging = n.dragDetails != null;
    } else if (n is OverscrollNotification) {
      // أندرويد/الويب: السحب فوق أول القائمة
      if (n.dragDetails != null && n.overscroll < 0 && n.metrics.pixels <= n.metrics.minScrollExtent) {
        dragging = true;
        _setPull(pull + (-n.overscroll) * (1 - pull / (maxPull * 1.4)));
      }
    } else if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels < n.metrics.minScrollExtent) {
        // تمرير مرن (iOS)
        _setPull(n.metrics.minScrollExtent - n.metrics.pixels);
      } else if (pull > 0 && n.dragDetails != null && (n.scrollDelta ?? 0) > 0) {
        _setPull(pull - n.scrollDelta!);
      }
      if (n.dragDetails == null && dragging && pull > 0) _release();
    } else if (n is ScrollEndNotification) {
      if (pull > 0) _release();
    } else if (n is UserScrollNotification) {
      if (n.direction.name == 'idle' && pull > 0) _release();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = (pull / armAt).clamp(0.0, 1.0);
    final text = switch (mode) {
      _Mode.armed => 'أفلت للتحديث',
      _Mode.loading => 'جاري التحديث…',
      _Mode.done => 'تم التحديث ✓',
      _ => 'اسحب للتحديث',
    };
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(children: [
        if (pull > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pull,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                maxHeight: armAt + 30,
                child: Opacity(
                  opacity: t,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 60,
                      width: 160,
                      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                        if (mode == _Mode.armed || mode == _Mode.loading || mode == _Mode.done)
                          AnimatedBuilder(
                            animation: spin,
                            builder: (context, _) => CustomPaint(size: const Size(160, 60), painter: _Sparkles(spin.value)),
                          ),
                        Transform.scale(
                          scale: 0.55 + 0.5 * t + (mode == _Mode.armed ? 0.08 : 0),
                          child: Image.asset('assets/logo/depo-ar-teal.png', height: 40),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: mode == _Mode.done ? DepoColors.success : DepoColors.dark)),
                  ]),
                ),
              ),
            ),
          ),
        Transform.translate(offset: Offset(0, pull), child: widget.child),
      ]),
    );
  }
}

/// نقاط صغيرة تلمع حول الشعار
class _Sparkles extends CustomPainter {
  final double v;
  _Sparkles(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const colors = [DepoColors.brand, DepoColors.accent, DepoColors.dark, Color(0xFFEC4899)];
    for (var i = 0; i < 10; i++) {
      final a = (i / 10) * 2 * pi + v * 2 * pi * (i.isEven ? 1 : -1) * 0.5;
      final r = 46.0 + 10 * sin(v * 2 * pi + i);
      final p = c + Offset(cos(a) * r * 1.4, sin(a) * r * 0.55);
      final s = 1.5 + 1.5 * (0.5 + 0.5 * sin(v * 4 * pi + i * 1.7));
      canvas.drawCircle(p, s, Paint()..color = colors[i % colors.length].withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_Sparkles old) => old.v != v;
}
