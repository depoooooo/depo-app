import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// قراءة موقع من الـ GPS
class GeoFix {
  final double lat, lng;
  final double accuracy; // متر
  final bool mocked; // موقع مزيّف (تطبيق تغيير الموقع)
  final int at;
  const GeoFix(this.lat, this.lng, this.accuracy, this.mocked, this.at);
}

class GeoResult {
  final GeoFix? fix;
  final String error;
  const GeoResult(this.fix, [this.error = '']);
}

class Geo {
  /// يجيب الموقع الحالي (يطلب الإذن إذا يحتاج)
  static Future<GeoResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const GeoResult(null, 'شغّل الموقع (GPS) بالتلفون وجرّب مرة ثانية');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return const GeoResult(null, 'لازم تسمح لديبو يوصل للموقع');
      if (p == LocationPermission.deniedForever) return const GeoResult(null, 'الموقع ممنوع لديبو. اسمحله من إعدادات التلفون ← التطبيقات ← ديبو ← الأذونات');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
      );
      return GeoResult(GeoFix(pos.latitude, pos.longitude, pos.accuracy, pos.isMocked, DateTime.now().millisecondsSinceEpoch));
    } catch (_) {
      return const GeoResult(null, 'ما گدرنا نحدد الموقع. اطلع لمكان مفتوح وجرّب مرة ثانية');
    }
  }

  /// المسافة بخط مستقيم بالكيلومتر (معادلة هافرساين)
  static double straightKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(min(1.0, sqrt(a)));
  }
}
