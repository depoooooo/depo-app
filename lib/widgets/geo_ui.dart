import 'package:flutter/material.dart';
import '../data/geo.dart';

/// يجيب الموقع ويه نافذة «جاري تحديد موقعك»
Future<GeoResult> locateWithProgress(BuildContext context, {String text = 'جاري تحديد موقعك…'}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
      ),
    ),
  );
  final r = await Geo.current();
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  return r;
}
