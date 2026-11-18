import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme.dart';

class TrackingScreen extends StatefulWidget {
  final int totalToPay;
  const TrackingScreen({super.key, required this.totalToPay});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final String orderNo = (1000 + Random().nextInt(9000)).toString();
  late final String pickupCode = (1000 + Random().nextInt(9000)).toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => cart.clear());
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['تم الطلب', 'المحل قبل', 'يجهّز', 'بالطريق', 'وصل'];
    const done = 3;
    return Scaffold(
      appBar: AppBar(title: Text('طلبك رقم #$orderNo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الوصول المتوقع', style: TextStyle(color: DepoColors.muted)),
              const Text('خلال 20–40 دقيقة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Column(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: i < done ? DepoColors.dark : DepoColors.line,
                        child: i < done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(steps[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i < done ? FontWeight.w800 : FontWeight.w500,
                            color: i < done ? DepoColors.ink : DepoColors.muted,
                          )),
                    ]),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Row(children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: DepoColors.soft,
                child: Icon(Icons.delivery_dining, color: DepoColors.dark),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المندوب بالطريق', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('تكدر تتصل بيه من التطبيق', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
              IconButton.filled(tooltip: 'اتصل بالمندوب', onPressed: () {}, icon: const Icon(Icons.phone)),
            ]),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(children: [
              const Text('رمز الاستلام', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(pickupCode,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8, color: DepoColors.dark)),
              const Text('اعرضه للمندوب أو للمحل وقت التسليم',
                  style: TextStyle(fontSize: 12, color: DepoColors.muted)),
              TextButton(onPressed: () {}, child: const Text('خلّي صديقك يستلم')),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('الدفع: ${iqd(widget.totalToPay)} نقداً عند الاستلام',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('رجوع للرئيسية'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DepoColors.line),
      ),
      child: child,
    );
  }
}
