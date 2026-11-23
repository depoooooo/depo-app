import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

/// خريطة ويز داخل التطبيق (بدون فتح تطبيق ويز وبدون تحميله): زحمة الطرق الحية ودبوس على الموقع
class WazeMap extends StatefulWidget {
  final double lat, lng;
  final int zoom;
  final double height;
  const WazeMap({super.key, required this.lat, required this.lng, this.zoom = 16, this.height = 220});

  static String url(double lat, double lng, int zoom) =>
      'https://embed.waze.com/iframe?zoom=$zoom&lat=${lat.toStringAsFixed(6)}&lon=${lng.toStringAsFixed(6)}&pin=1';

  @override
  State<WazeMap> createState() => _WazeMapState();
}

class _WazeMapState extends State<WazeMap> {
  WebViewController? _c;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(DepoColors.soft)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => loading = false);
        },
        // نبقى داخل الخريطة: أي رابط يحاول يفتح تطبيق ويز أو صفحة ثانية ينمنع
        onNavigationRequest: (r) => r.url.startsWith('https://embed.waze.com/') ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadRequest(Uri.parse(WazeMap.url(widget.lat, widget.lng, widget.zoom)));
  }

  @override
  void didUpdateWidget(WazeMap old) {
    super.didUpdateWidget(old);
    if (_c != null && (old.lat != widget.lat || old.lng != widget.lng)) {
      _c!.loadRequest(Uri.parse(WazeMap.url(widget.lat, widget.lng, widget.zoom)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null) {
      // نسخة الويب: الخريطة بصفحتها
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('خريطة ويز تشتغل بتطبيق الأندرويد', style: TextStyle(color: DepoColors.muted))),
      );
    }
    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        WebViewWidget(controller: _c!),
        if (loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
