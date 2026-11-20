import 'dart:math';
import 'package:flutter/material.dart';

/// أيقونات الشريط السفلي: ممتلئة ومدوّرة وسميكة (بأسلوب التطبيقات الحديثة)، مرسومة خصيصاً لديبو
enum NavGlyph { home, categories, cart, orders, profile }

class NavIcon extends StatelessWidget {
  final NavGlyph glyph;
  final Color color;
  final double size;
  const NavIcon(this.glyph, {super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _NavPainter(glyph, color));
}

class _NavPainter extends CustomPainter {
  final NavGlyph g;
  final Color color;
  _NavPainter(this.g, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // نرسم على شبكة 24×24
    canvas.scale(s);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    // القصّ نرسمه بلون خلفية الشريط (أضمن من عمليات دمج المسارات على كل الأجهزة)
    final cut = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    switch (g) {
      case NavGlyph.home:
        // بيت مدوّر ويه شبّاك دائري
        final house = Path()
          ..moveTo(12, 2.6)
          ..cubicTo(12.6, 2.6, 13.1, 2.8, 13.6, 3.2)
          ..lineTo(20.6, 9.3)
          ..cubicTo(21.2, 9.8, 21.5, 10.5, 21.5, 11.3)
          ..lineTo(21.5, 19.0)
          ..cubicTo(21.5, 20.4, 20.4, 21.5, 19.0, 21.5)
          ..lineTo(5.0, 21.5)
          ..cubicTo(3.6, 21.5, 2.5, 20.4, 2.5, 19.0)
          ..lineTo(2.5, 11.3)
          ..cubicTo(2.5, 10.5, 2.8, 9.8, 3.4, 9.3)
          ..lineTo(10.4, 3.2)
          ..cubicTo(10.9, 2.8, 11.4, 2.6, 12, 2.6)
          ..close();
        canvas.drawPath(house, fill);
        canvas.drawCircle(const Offset(12, 14.2), 3.0, cut);
      case NavGlyph.categories:
        // ثلاث مربعات مدوّرة ودائرة
        const r = Radius.circular(2.4);
        canvas.drawRRect(RRect.fromLTRBR(2.5, 2.5, 10.8, 10.8, r), fill);
        canvas.drawRRect(RRect.fromLTRBR(2.5, 13.2, 10.8, 21.5, r), fill);
        canvas.drawRRect(RRect.fromLTRBR(13.2, 13.2, 21.5, 21.5, r), fill);
        canvas.drawCircle(const Offset(17.35, 6.65), 4.3, fill);
      case NavGlyph.cart:
        // كيس تسوّق ويه علّاقة وابتسامة
        final body = Path()
          ..addRRect(RRect.fromLTRBAndCorners(3.2, 7.4, 20.8, 21.5,
              topLeft: const Radius.circular(2.2), topRight: const Radius.circular(2.2), bottomLeft: const Radius.circular(3.4), bottomRight: const Radius.circular(3.4)));
        final smile = Path()
          ..moveTo(8.4, 12.2)
          ..cubicTo(8.4, 14.4, 10.0, 16.0, 12.0, 16.0)
          ..cubicTo(14.0, 16.0, 15.6, 14.4, 15.6, 12.2);
        final smileStroke = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        canvas.drawPath(body, fill);
        canvas.drawPath(smile, smileStroke);
        final handle = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTRB(8.0, 2.4, 16.0, 11.0), pi, pi, false, handle);
      case NavGlyph.orders:
        // ورقة طلب ويه خطوط
        canvas.drawRRect(RRect.fromLTRBR(4.0, 2.5, 20.0, 21.5, const Radius.circular(3.2)), fill);
        canvas.drawRRect(RRect.fromLTRBR(7.6, 7.2, 16.4, 9.2, const Radius.circular(1)), cut);
        canvas.drawRRect(RRect.fromLTRBR(7.6, 11.0, 16.4, 13.0, const Radius.circular(1)), cut);
        canvas.drawRRect(RRect.fromLTRBR(7.6, 14.8, 12.8, 16.8, const Radius.circular(1)), cut);
      case NavGlyph.profile:
        // دائرة ممتلئة بداخلها شخص مقصوص
        canvas.drawCircle(const Offset(12, 12), 9.6, fill);
        canvas.drawCircle(const Offset(12, 9.4), 3.3, cut);
        final shoulders = Path()
          ..moveTo(5.6, 18.6)
          ..cubicTo(6.8, 15.6, 9.2, 14.2, 12, 14.2)
          ..cubicTo(14.8, 14.2, 17.2, 15.6, 18.4, 18.6)
          ..cubicTo(16.7, 20.4, 14.5, 21.4, 12, 21.4)
          ..cubicTo(9.5, 21.4, 7.3, 20.4, 5.6, 18.6)
          ..close();
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9.6)));
        canvas.drawPath(shoulders, cut);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_NavPainter old) => old.g != g || old.color != color;
}
