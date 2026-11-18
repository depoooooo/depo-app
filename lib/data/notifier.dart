import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/offer_detail.dart';
import '../theme.dart';
import 'app_state.dart';
import 'models.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// الإشعارات على شاشة التلفون (المرحلة الحالية: تشتغل والتطبيق مفتوح أو بالخلفية).
///
/// الإشعار المتدرّج يتحسب على جهاز كل زبون:
///  - المتابِع، أو المطعم ضمن [stage1Km]: فوراً
///  - ضمن [stage2Km]: بعد [stage2Minutes] دقايق
///  - باقي الموصل: بعد [stage3Minutes] دقايق
/// وإذا خلص العرض قبل وقته، ما يوصل الإشعار.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _started = false;
  static final Set<String> _done = {}; // عروض انبلّغ عنها
  static final Map<String, Timer> _timers = {};
  static String? _lastSeenTop; // آخر إشعار شافه المستخدم بقائمته
  static String? _lastPhone;
  static int _nextId = 1;
  static final int _startedAt = DateTime.now().millisecondsSinceEpoch;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    _done.addAll(prefs.getStringList('depo_notified_offers') ?? const []);
    if (!kIsWeb) {
      try {
        await _plugin.initialize(
          const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
          onDidReceiveNotificationResponse: (r) => _open(r.payload),
        );
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        _ready = true;
      } catch (_) {
        _ready = false;
      }
    }
    app.addListener(_check);
    _check();
  }

  static void _open(String? payload) {
    if (payload == null || !payload.startsWith('offer:')) return;
    final o = app.offerById(payload.substring(6));
    if (o == null) return;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => OfferDetailScreen(offer: o)));
  }

  static void _check() {
    if (!app.loaded) return;
    _checkOffers();
    _checkInbox();
  }

  // ---------- عروض الرواجع الجديدة ----------
  static void _checkOffers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final me = app.me;
    final st = app.settings;
    for (final o in app.offers) {
      if (_done.contains(o.id) || _timers.containsKey(o.id)) continue;
      final s = app.storeById(o.storeId);
      if (s == null || s.suspended || !o.visible) continue;
      if (me?.storeId == s.id) continue; // عرضي أني
      // بس العروض الجديدة (آخر نص ساعة، وانضافت بعد ما فتحنا التطبيق أو قبله بشوية)
      if (now - o.createdAt > 30 * 60 * 1000 || o.createdAt < _startedAt - 30 * 60 * 1000) {
        _done.add(o.id);
        continue;
      }
      final follower = me?.follows.contains(s.id) ?? false;
      int delayMin;
      if (follower) {
        delayMin = 0;
      } else if (s.type != StoreType.restaurant) {
        _done.add(o.id); // الماركت: للمتابعين بس
        continue;
      } else if (s.distanceKm <= st.stage1Km) {
        delayMin = 0;
      } else if (s.distanceKm <= st.stage2Km) {
        delayMin = st.stage2Minutes;
      } else {
        delayMin = st.stage3Minutes;
      }
      final fireAt = o.createdAt + delayMin * 60 * 1000;
      final wait = fireAt - now;
      if (wait <= 0) {
        _fireOffer(o.id, follower);
      } else {
        _timers[o.id] = Timer(Duration(milliseconds: wait), () {
          _timers.remove(o.id);
          _fireOffer(o.id, follower);
        });
      }
    }
  }

  static void _fireOffer(String id, bool follower) {
    final o = app.offerById(id);
    final s = o == null ? null : app.storeById(o.storeId);
    _markDone(id);
    if (o == null || s == null || !o.visible) return; // خلص قبل وقته
    final title = follower ? '${s.name} نشر رواجع! ❤️' : 'رواجع قريبة: ${s.name} 🔥';
    final body = '${o.title} بـ ${iqd(o.price)} بدل ${iqd(o.originalPrice)} — باقي ${o.quantityLeft}';
    _show(title, body, payload: 'offer:${o.id}');
  }

  static Future<void> _markDone(String id) async {
    _done.add(id);
    final prefs = await SharedPreferences.getInstance();
    final list = _done.toList();
    await prefs.setStringList('depo_notified_offers', list.length > 300 ? list.sublist(list.length - 300) : list);
  }

  // ---------- إشعارات الحساب (طلب جديد، حالة الطلب، الموافقة...) ----------
  static void _checkInbox() {
    final me = app.me;
    if (me == null) {
      _lastPhone = null;
      return;
    }
    final list = me.notifications;
    if (_lastPhone != me.phone) {
      // أول مرة لهذا الحساب: نعتبر الموجود مقروء
      _lastPhone = me.phone;
      _lastSeenTop = list.isEmpty ? null : list.first;
      return;
    }
    if (list.isEmpty || list.first == _lastSeenTop) return;
    final fresh = <String>[];
    for (final t in list) {
      if (t == _lastSeenTop) break;
      fresh.add(t);
      if (fresh.length >= 5) break;
    }
    _lastSeenTop = list.first;
    for (final t in fresh.reversed) {
      if (t.contains(' نشر: ')) continue; // عروض المتابَعين تنبلّغ من فوق
      _show(_titleFor(t), t);
    }
  }

  static String _titleFor(String t) {
    if (t.startsWith('طلب جديد')) return 'طلب جديد! 🛎️';
    if (t.startsWith('طلبك')) return 'تحديث طلبك';
    if (t.contains('انضمام')) return 'طلبات الانضمام';
    if (t.contains('عاجل')) return 'عاجل ⚠️';
    return 'ديبو';
  }

  static Future<void> _show(String title, String body, {String? payload}) async {
    // داخل التطبيق: شريط تحت
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: DepoColors.ink,
        duration: const Duration(seconds: 5),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w900, color: DepoColors.accent)),
          Text(body, style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
        ]),
        action: payload == null ? null : SnackBarAction(label: 'شوف', textColor: DepoColors.brand, onPressed: () => _open(payload)),
      ));
    // على شاشة التلفون
    if (!_ready) return;
    try {
      await _plugin.show(
        _nextId++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'depo_main',
            'إشعارات ديبو',
            channelDescription: 'الرواجع الجديدة وتحديثات الطلبات',
            importance: Importance.high,
            priority: Priority.high,
            color: DepoColors.brand,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}
