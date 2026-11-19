import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud.dart';

/// الصور: تنضغط بالتلفون (~800 بكسل) وتنحفظ بـ Firestore بقسم images.
/// (Firebase Storage يحتاج خطة Blaze، فبالمرحلة الأولى نستخدم Firestore)
class Images {
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _loading = {};
  static final _rnd = Random();

  /// يختار صورة من الكاميرا أو المعرض ويضغطها
  static Future<Uint8List?> pick({required bool camera, double maxSide = 800, int quality = 60}) async {
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    if (x == null) return null;
    final raw = await x.readAsBytes();
    // ضغط مضمون: أي صيغة (PNG/HEIC/WebP...) وأي حجم تتحول JPG أصغر من الحد
    final bytes = await compute(shrinkImage, {'bytes': raw, 'maxSide': maxSide.round(), 'quality': quality});
    if (bytes == null) throw Exception('ما گدرنا نقرأ الصورة، جرّب وحدة ثانية');
    return bytes;
  }

  /// يرفع الصورة ويرجّع رقمها
  static Future<String> put(Uint8List bytes, {String owner = ''}) async {
    final id = 'img${DateTime.now().millisecondsSinceEpoch}${_rnd.nextInt(9999)}';
    final data = base64Encode(bytes);
    if (Cloud.enabled) {
      await Cloud.db!.collection('images').doc(id).set({'data': data, 'owner': owner, 'at': DateTime.now().millisecondsSinceEpoch});
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('depo_img_$id', data);
    }
    _cache[id] = bytes;
    return id;
  }

  static Uint8List? cached(String id) => _cache[id];

  static Future<Uint8List?> get(String id) {
    if (id.isEmpty) return Future.value(null);
    final c = _cache[id];
    if (c != null) return Future.value(c);
    return _loading[id] ??= _fetch(id);
  }

  static Future<Uint8List?> _fetch(String id) async {
    try {
      String? data;
      if (Cloud.enabled) {
        // من النسخة المحلية أول (فوري)، وإذا ماكو من السيرفر
        try {
          final c = await Cloud.db!.collection('images').doc(id).get(const GetOptions(source: Source.cache));
          data = c.data()?['data'] as String?;
        } catch (_) {}
        if (data == null) {
          final d = await Cloud.db!.collection('images').doc(id).get();
          data = d.data()?['data'] as String?;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        data = prefs.getString('depo_img_$id');
      }
      if (data == null) return null;
      final b = base64Decode(data);
      _cache[id] = b;
      return b;
    } catch (_) {
      return null;
    } finally {
      _loading.remove(id);
    }
  }
}


/// أقصى حجم للصورة بعد الضغط (Firestore يتحمّل 1 ميگا للسجل، والصورة تكبر 33% بالحفظ)
const maxImageBytes = 500 * 1024;

/// يصغّر ويضغط الصورة لحد ما تصير أقل من [maxImageBytes]. يشتغل بخلفية (compute) حتى ما يعلّق التطبيق.
Uint8List? shrinkImage(Map<String, Object> a) {
  final raw = a['bytes'] as Uint8List;
  final maxSide = a['maxSide'] as int;
  final startQ = (a['quality'] as int).clamp(40, 90);
  final isJpg = raw.length > 3 && raw[0] == 0xFF && raw[1] == 0xD8;
  if (isJpg && raw.length <= maxImageBytes) return raw; // جاهزة
  var im = img.decodeImage(raw);
  if (im == null) return null;
  // الشفافية تصير خلفية بيضاء (JPG ما بيه شفافية)
  if (im.hasAlpha) {
    final bg = img.Image(width: im.width, height: im.height);
    img.fill(bg, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(bg, im);
    im = bg;
  }
  var side = maxSide;
  Uint8List? best;
  for (var round = 0; round < 6; round++) {
    final big = im.width > im.height ? im.width : im.height;
    final scaled = big > side ? (im.width >= im.height ? img.copyResize(im, width: side) : img.copyResize(im, height: side)) : im;
    for (var q = startQ; q >= 35; q -= 10) {
      final out = img.encodeJpg(scaled, quality: q);
      if (best == null || out.length < best.length) best = out;
      if (out.length <= maxImageBytes) return out;
    }
    side = (side * 0.8).round();
  }
  return best != null && best.length <= maxImageBytes ? best : null;
}
