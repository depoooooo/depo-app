import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// جمل تنكتب وتنمسح بشريط البحث (حرف حرف)
class TypewriterHint extends StatefulWidget {
  final List<String> phrases;
  const TypewriterHint({super.key, required this.phrases});

  @override
  State<TypewriterHint> createState() => _TypewriterHintState();
}

class _TypewriterHintState extends State<TypewriterHint> {
  int phrase = 0;
  int chars = 0;
  bool deleting = false;
  bool cursorOn = true;
  Timer? _t;
  Timer? _blink;

  @override
  void initState() {
    super.initState();
    _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => cursorOn = !cursorOn);
    });
    _schedule(const Duration(milliseconds: 400));
  }

  void _schedule(Duration d) {
    _t?.cancel();
    _t = Timer(d, _tick);
  }

  void _tick() {
    if (!mounted || widget.phrases.isEmpty) return;
    final text = widget.phrases[phrase % widget.phrases.length];
    setState(() {
      if (!deleting) {
        chars++;
        if (chars >= text.characters.length) {
          chars = text.characters.length;
          deleting = true;
          _schedule(const Duration(milliseconds: 1700)); // يبقى شوية
          return;
        }
        _schedule(const Duration(milliseconds: 75));
      } else {
        chars--;
        if (chars <= 0) {
          chars = 0;
          deleting = false;
          phrase++;
          _schedule(const Duration(milliseconds: 350));
          return;
        }
        _schedule(const Duration(milliseconds: 35));
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.phrases.isEmpty ? '' : widget.phrases[phrase % widget.phrases.length];
    final shown = text.characters.take(chars).toString();
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: shown),
        TextSpan(text: '|', style: TextStyle(color: cursorOn ? DepoColors.dark : Colors.transparent, fontWeight: FontWeight.w300)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: DepoColors.muted),
    );
  }
}

