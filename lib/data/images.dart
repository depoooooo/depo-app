import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
    final bytes = await x.readAsBytes();
    if (bytes.length > 700 * 1024) throw Exception('الصورة كبيرة، جرّب وحدة ثانية');
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
