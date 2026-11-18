import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud.dart';
import 'models.dart';

/// حالة التطبيق: البيانات تنحفظ بـ Firebase (Firestore) وتتزامن بين كل الأجهزة.
/// إذا ماكو اتصال بالسيرفر، تشتغل محلياً على الجهاز.
class AppState extends ChangeNotifier {
  static const _key = 'depo_state_v1';
  final _rnd = Random();

  List<AppUser> users = [];
  List<Store> stores = [];
  List<Offer> offers = [];
  List<Order> orders = [];
  List<JoinRequest> joinRequests = [];
  List<Complaint> complaints = [];
  List<String> audit = [];
  AppSettings settings = AppSettings();
  String? currentPhone;
  bool courierAvailable = true;
  bool loaded = false;

  // ---------------- التخزين ----------------
  /// الأقسام اللي تنحفظ بالسيرفر (كل قسم = collection بـ Firestore)
  static const _cols = ['users', 'stores', 'offers', 'orders', 'joinRequests', 'complaints', 'meta'];

  /// آخر نسخة نعرفها من كل مستند بالسيرفر (للمقارنة وكتابة الي تغيّر بس)
  final Map<String, Map<String, String>> _synced = {for (final c in _cols) c: {}};
  final Map<String, Map<String, int>> _ts = {for (final c in _cols) c: {}};
  final List<StreamSubscription> _subs = [];
  bool get online => Cloud.enabled;
  String get cloudStatus => Cloud.status;

  Timer? _tick;

  Future<void> load() async {
    // كل دقيقة نحدّث الشاشات (العروض اللي خلص وقتها تختفي، والعدّاد ينقص)
    _tick ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (Cloud.enabled && Cloud.status.startsWith('تعذر الحفظ')) _save(); // نعيد المحاولة
      notifyListeners();
    });
    final prefs = await SharedPreferences.getInstance();
    currentPhone = prefs.getString('depo_phone');
    courierAvailable = prefs.getBool('depo_courier_available') ?? true;
    if (await Cloud.init()) {
      try {
        await _loadCloud();
        await loadSeen();
        loaded = true;
        notifyListeners();
        return;
      } catch (e) {
        Cloud.enabled = false;
        Cloud.status = 'محلي — تعذر تحميل البيانات: $e';
      }
    }
    _loadLocal(prefs);
    await loadSeen();
    loaded = true;
    notifyListeners();
  }

  void _loadLocal(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) {
      _seed();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      List<Map<String, dynamic>> l(String k) =>
          (j[k] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      users = l('users').map(AppUser.fromJson).toList();
      stores = l('stores').map(Store.fromJson).toList();
      offers = l('offers').map(Offer.fromJson).toList();
      orders = l('orders').map(Order.fromJson).toList();
      joinRequests = l('joinRequests').map(JoinRequest.fromJson).toList();
      complaints = l('complaints').map(Complaint.fromJson).toList();
      audit = List<String>.from(j['audit'] ?? const []);
      settings = AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] ?? const {}));
      currentPhone ??= j['currentPhone'] as String?;
    } catch (_) {
      _seed();
    }
  }

  // ---- Firestore ----
  Future<void> _loadCloud() async {
    final db = Cloud.db!;
    final first = <String, fs.QuerySnapshot<Map<String, dynamic>>>{};
    for (final c in _cols) {
      first[c] = await db.collection(c).get().timeout(const Duration(seconds: 15));
    }
    if (first['stores']!.docs.isEmpty && first['users']!.docs.isEmpty) {
      // أول مرة: نرفع البيانات التجريبية للسيرفر
      _seed();
      await _pushCloud();
    } else {
      for (final c in _cols) {
        _applyDocs(c, first[c]!.docs);
      }
    }
    for (final c in _cols) {
      _subs.add(db.collection(c).snapshots().listen((qs) {
        _applyDocs(c, qs.docs);
        notifyListeners();
      }, onError: (e) {
        Cloud.status = 'انقطع الاتصال: $e';
        notifyListeners();
      }));
    }
  }

  /// كل الأقسام بشكل: رقم المستند -> بياناته
  Map<String, Map<String, dynamic>> _docsOf(String c) {
    switch (c) {
      case 'users':
        return {for (final x in users) x.phone: x.toJson()};
      case 'stores':
        return {for (final x in stores) x.id: x.toJson()};
      case 'offers':
        return {for (final x in offers) x.id: x.toJson()};
      case 'orders':
        return {for (final x in orders) x.id: x.toJson()};
      case 'joinRequests':
        return {for (final x in joinRequests) x.id: x.toJson()};
      case 'complaints':
        return {for (final x in complaints) x.id: x.toJson()};
      case 'meta':
        return {
          'settings': settings.toJson(),
          'audit': {'items': audit},
        };
    }
    return {};
  }

  /// الأقسام الي الجديد بيها ينضاف بالأول (الأحدث فوق)
  static const _newestFirst = {'offers', 'orders', 'joinRequests', 'complaints'};

  void _applyDocs(String c, List<fs.QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final list = docs.toList()
      ..sort((a, b) {
        final ta = (a.data()['_ts'] ?? 0) as num, tb = (b.data()['_ts'] ?? 0) as num;
        return _newestFirst.contains(c) ? tb.compareTo(ta) : ta.compareTo(tb);
      });
    T keep<T>(String id, Map<String, dynamic> d, T Function(Map<String, dynamic>) from, T? old) {
      final fresh = from(_clean(d));
      // إذا ما تغيّر نخلي نفس الكائن (حتى الشاشات المفتوحة ما تضيع)
      if (old != null && jsonEncode((old as dynamic).toJson()) == jsonEncode((fresh as dynamic).toJson())) return old;
      return fresh;
    }

    _synced[c]!.clear();
    _ts[c]!.clear();
    for (final d in list) {
      _ts[c]![d.id] = ((d.data()['_ts'] ?? 0) as num).toInt();
    }
    switch (c) {
      case 'users':
        final old = {for (final x in users) x.phone: x};
        users = [for (final d in list) keep(d.id, d.data(), AppUser.fromJson, old[d.id])];
      case 'stores':
        final old = {for (final x in stores) x.id: x};
        stores = [for (final d in list) keep(d.id, d.data(), Store.fromJson, old[d.id])];
      case 'offers':
        final old = {for (final x in offers) x.id: x};
        offers = [for (final d in list) keep(d.id, d.data(), Offer.fromJson, old[d.id])];
      case 'orders':
        final old = {for (final x in orders) x.id: x};
        orders = [for (final d in list) keep(d.id, d.data(), Order.fromJson, old[d.id])];
      case 'joinRequests':
        final old = {for (final x in joinRequests) x.id: x};
        joinRequests = [for (final d in list) keep(d.id, d.data(), JoinRequest.fromJson, old[d.id])];
      case 'complaints':
        final old = {for (final x in complaints) x.id: x};
        complaints = [for (final d in list) keep(d.id, d.data(), Complaint.fromJson, old[d.id])];
      case 'meta':
        for (final d in list) {
          if (d.id == 'settings') settings = AppSettings.fromJson(_clean(d.data()));
          if (d.id == 'audit') audit = List<String>.from(d.data()['items'] ?? const []);
        }
    }
    // نحفظ النسخة «الموحّدة» حتى ما نرجع نكتب نفس الشي
    _docsOf(c).forEach((id, v) => _synced[c]![id] = jsonEncode(v));
  }

  Map<String, dynamic> _clean(Map<String, dynamic> d) => Map<String, dynamic>.from(d)..remove('_ts');

  /// يكتب للسيرفر بس المستندات الي تغيّرت، ويحذف الي انمسحت
  Future<void> _pushCloud() async {
    final db = Cloud.db!;
    var batch = db.batch();
    var n = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // نحفظ النسخة القديمة حتى إذا فشل الحفظ نرجعها، فتنكتب بالمحاولة الجاية
    final undo = <void Function()>[];
    try {
      for (final c in _cols) {
        final cur = _docsOf(c);
        final ids = cur.keys.toList();
        for (var i = 0; i < ids.length; i++) {
          final id = ids[i];
          final enc = jsonEncode(cur[id]);
          final old = _synced[c]![id];
          if (old == enc) continue;
          final ts = _ts[c]![id] ??= _newestFirst.contains(c) ? now - i : now + i;
          batch.set(db.collection(c).doc(id), {...cur[id]!, '_ts': ts});
          _synced[c]![id] = enc;
          undo.add(() => old == null ? _synced[c]!.remove(id) : _synced[c]![id] = old);
          if (++n >= 450) {
            await batch.commit();
            batch = db.batch();
            n = 0;
            undo.clear();
          }
        }
        for (final id in _synced[c]!.keys.where((k) => !cur.containsKey(k)).toList()) {
          final old = _synced[c]![id];
          batch.delete(db.collection(c).doc(id));
          _synced[c]!.remove(id);
          undo.add(() => _synced[c]![id] = old!);
          n++;
        }
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      for (final u in undo) {
        u();
      }
      rethrow;
    }
  }

  /// بعد عملية بـ transaction: نعتبر المستند محفوظ حتى ما ننكتب فوقه
  void _markSynced(String c, String id, {int? ts}) {
    final doc = _docsOf(c)[id];
    if (doc == null) return;
    _synced[c]![id] = jsonEncode(doc);
    if (ts != null) _ts[c]![id] = ts;
  }

  Future<void> _save() async {
    // السيرفر أول (بدون انتظار قبله) حتى ما يجي تحديث من جهاز ثاني ويمسح تغييرنا قبل ما ينحفظ
    Future<void>? push;
    if (Cloud.enabled) {
      push = _pushCloud().then((_) {
        if (Cloud.status.startsWith('تعذر الحفظ')) {
          Cloud.status = 'متصل بالسيرفر ✓';
          notifyListeners();
        }
      }).catchError((Object e) {
        Cloud.status = 'تعذر الحفظ بالسيرفر — راح نعيد المحاولة';
        notifyListeners();
      });
    }
    final prefs = await SharedPreferences.getInstance();
    if (currentPhone == null) {
      await prefs.remove('depo_phone');
    } else {
      await prefs.setString('depo_phone', currentPhone!);
    }
    await prefs.setBool('depo_courier_available', courierAvailable);
    if (push != null) {
      await push;
      return;
    }
    await prefs.setString(
      _key,
      jsonEncode({
        'users': users.map((e) => e.toJson()).toList(),
        'stores': stores.map((e) => e.toJson()).toList(),
        'offers': offers.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'joinRequests': joinRequests.map((e) => e.toJson()).toList(),
        'complaints': complaints.map((e) => e.toJson()).toList(),
        'audit': audit,
        'settings': settings.toJson(),
      }),
    );
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  /// يشيل البيانات التجريبية بس (المحلات والحسابات 0700000…) ويخلي الحقيقية — قبل الإطلاق
  bool get hasDemoData => stores.any((s) => s.ownerPhone.startsWith('0700000'));
  void removeDemoData() {
    if (me?.role != Role.admin) return;
    final demoStores = stores.where((s) => s.ownerPhone.startsWith('0700000')).map((s) => s.id).toSet();
    offers.removeWhere((o) => demoStores.contains(o.storeId));
    orders.removeWhere((o) => demoStores.contains(o.storeId));
    stores.removeWhere((s) => demoStores.contains(s.id));
    users.removeWhere((u) => u.phone.startsWith('0700000'));
    for (final u in users) {
      u.follows.removeWhere(demoStores.contains);
    }
    _log('حذف البيانات التجريبية');
    _changed();
  }

  /// يمسح كل البيانات ويرجع للبيانات التجريبية (بالسيرفر: المدير بس)
  bool get canResetDemo => !online || me?.role == Role.admin;
  Future<void> resetDemo() async {
    if (!canResetDemo) return;
    users = [];
    stores = [];
    offers = [];
    orders = [];
    joinRequests = [];
    complaints = [];
    audit = [];
    settings = AppSettings();
    currentPhone = null;
    _seed();
    _changed();
  }

  Offer? offerById(String id) {
    for (final o in offers) {
      if (o.id == id) return o;
    }
    return null;
  }

  String _id(String p) => '$p${DateTime.now().millisecondsSinceEpoch}${_rnd.nextInt(999)}';

  // ---------------- الحساب ----------------
  AppUser? get me => currentPhone == null ? null : userByPhone(currentPhone!);
  bool get loggedIn => me != null;
  AppUser? userByPhone(String phone) {
    for (final u in users) {
      if (u.phone == phone) return u;
    }
    return null;
  }

  /// يسجّل دخول أو ينشئ حساب جديد. أول حساب حقيقي بالجهاز يصير المدير العام (للتجربة بس).
  bool isNewUser(String phone) => userByPhone(phone) == null;

  /// الحسابات اللي تحتاج رمز سري (غير الزبون). الأرقام التجريبية مستثناة.
  bool needsPin(AppUser u) => u.role != Role.customer && !u.phone.startsWith('0700000');

  String _hash(String phone, String pin) => sha256.convert(utf8.encode('depo-v1:$phone:$pin')).toString();
  bool checkPin(AppUser u, String pin) => u.pinHash.isNotEmpty && u.pinHash == _hash(u.phone, pin);
  void setPin(AppUser u, String pin) {
    u.pinHash = _hash(u.phone, pin);
    _changed();
  }

  void login(String phone, {String name = ''}) {
    var u = userByPhone(phone);
    if (u != null && u.suspended) return;
    if (u == null) {
      final noRealUsers = users.where((x) => !x.phone.startsWith('0700000')).isEmpty;
      u = AppUser(phone: phone, name: name, role: noRealUsers ? Role.admin : Role.customer);
      users.add(u);
      _log('تسجيل حساب جديد: $phone${u.role == Role.admin ? ' (المدير العام)' : ''}');
    } else if (name.isNotEmpty) {
      u.name = name;
    }
    currentPhone = phone;
    _seenTop = null;
    loadSeen();
    _changed();
  }

  /// حذف حساب الزبون (مطلوب من متجر Google Play)
  void deleteMyAccount() {
    final u = me;
    if (u == null || u.role != Role.customer) return;
    for (final o in orders.where((o) => o.customerPhone == u.phone)) {
      o.customerName = 'حساب محذوف';
      o.address = '';
    }
    joinRequests.removeWhere((r) => r.phone == u.phone && r.status == 'pending');
    users.remove(u);
    _log('حذف حساب زبون');
    currentPhone = null;
    _seenTop = null;
    cart.clear();
    _changed();
  }

  void updateName(String name) {
    final t = name.trim();
    if (t.length < 2 || t.length > 40) return;
    me?.name = t;
    _changed();
  }

  void logout() {
    currentPhone = null;
    _seenTop = null;
    cart.clear();
    _changed();
  }

  void notify(String phone, String text) {
    final u = userByPhone(phone);
    if (u == null) return;
    u.notifications.insert(0, text);
    if (u.notifications.length > 50) u.notifications.removeLast();
  }

  void _log(String text) {
    final who = me == null ? 'النظام' : '${me!.name.isEmpty ? me!.phone : me!.name} (${roleNames[me!.role]})';
    final t = DateTime.now();
    audit.insert(0, '${t.year}/${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')} — $who: $text');
    if (audit.length > 300) audit.removeLast();
  }

  // ---------------- المحلات والعروض ----------------
  Store? storeById(String id) {
    for (final s in stores) {
      if (s.id == id) return s;
    }
    return null;
  }

  Store? get myStore => me?.storeId == null ? null : storeById(me!.storeId!);
  List<Offer> offersOf(String storeId, {bool onlyVisible = true}) =>
      offers.where((o) => o.storeId == storeId && (!onlyVisible || o.visible)).toList();
  List<Store> storesOfType(StoreType t) => stores.where((s) => s.type == t && !s.suspended).toList();
  int followersOf(String storeId) => users.where((u) => u.follows.contains(storeId)).length;

  bool isFollowing(String storeId) => me?.follows.contains(storeId) ?? false;
  void toggleFollow(String storeId) {
    final u = me;
    if (u == null) return;
    if (!u.follows.remove(storeId)) u.follows.add(storeId);
    _changed();
  }

  /// باقي كم يوم من الشهر المجاني (0 = خلص)
  int freeDaysLeft(Store s) {
    if (s.type != StoreType.restaurant) return 0;
    final days = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(s.approvedAt)).inDays;
    return max(0, settings.freeDays - days);
  }

  /// العمولة: المطاعم 15% بحد أدنى 750 (وأول شهر مجاني)، والتجار 15%
  int commissionFor(Store s, int itemsTotal) {
    if (s.type == StoreType.restaurant) {
      if (freeDaysLeft(s) > 0) return 0;
      return max((itemsTotal * settings.restaurantCommission / 100).round(), settings.minCommission);
    }
    return (itemsTotal * settings.merchantCommission / 100).round();
  }

  void publishOffer(Offer o) {
    final s = storeById(o.storeId);
    if (s == null || s.suspended || me?.storeId != s.id) return;
    offers.insert(0, o);
    {
      // إشعار بقائمة المتابعين؛ والإشعار المتدرّج على الشاشة يتحسب بجهاز كل زبون (notifier.dart)
      for (final u in users.where((u) => u.follows.contains(s.id))) {
        notify(u.phone, '${s.fullName} نشر: ${o.title} بـ ${iqd(o.price)}');
      }
      _log('نشر عرض «${o.title}» — ${s.name}');
    }
    _changed();
  }

  Offer newOffer({
    required String storeId,
    required String title,
    required int originalPrice,
    required int price,
    required int qty,
    required String expiresLabel,
    bool surpriseBox = false,
    String pickupWindow = '',
    Storage storage = Storage.normal,
    String description = '',
    String imageId = '',
    int expiresAt = 0,
  }) =>
      Offer(
        expiresAt: expiresAt,
        id: _id('o'),
        storeId: storeId,
        title: title,
        originalPrice: originalPrice,
        price: price,
        quantityLeft: qty,
        expiresLabel: expiresLabel,
        surpriseBox: surpriseBox,
        pickupWindow: pickupWindow,
        storage: storage,
        description: description,
        imageId: imageId,
      );

  /// ينشر نفس عرض قديم من جديد (بكمية جديدة) — للنشر السريع
  void repostOffer(Offer old, int qty) {
    publishOffer(newOffer(
      storeId: old.storeId,
      title: old.title,
      originalPrice: old.originalPrice,
      price: old.price,
      qty: qty,
      expiresLabel: old.expiresLabel,
      surpriseBox: old.surpriseBox,
      pickupWindow: old.pickupWindow,
      storage: old.storage,
      description: old.description,
      imageId: old.imageId,
      expiresAt: old.expiresAt > 0 ? DateTime.now().millisecondsSinceEpoch + (old.expiresAt - old.createdAt) : 0,
    ));
  }

  /// آخر العروض المختلفة اللي نشرها المحل (للنشر بضغطة)
  List<Offer> recentTemplates(String storeId) {
    final seen = <String>{};
    final out = <Offer>[];
    for (final o in offers.where((o) => o.storeId == storeId)) {
      if (seen.add(o.title)) out.add(o);
      if (out.length >= 4) break;
    }
    return out;
  }

  void setStoreImage(Store s, String imageId) {
    s.imageId = imageId;
    _changed();
  }

  void setOfferImage(Offer o, String imageId) {
    o.imageId = imageId;
    _changed();
  }

  void setOfferActive(Offer o, bool active) {
    o.active = active;
    _changed();
  }

  void setOfferQty(Offer o, int qty) {
    o.quantityLeft = max(0, qty);
    _changed();
  }

  void setOfferHidden(Offer o, bool hidden) {
    o.hidden = hidden;
    _log('${hidden ? 'إخفاء' : 'إظهار'} عرض «${o.title}»');
    _changed();
  }

  // ---------------- التوصيل والعروض ----------------
  /// أول طلب للزبون (أو زائر بعده ما طلب)
  bool get eligibleFirstOrder =>
      settings.firstOrderFree &&
      !orders.any((o) => o.customerPhone == currentPhone && o.status != OrderStatus.cancelled && o.status != OrderStatus.rejected);

  int deliveryFeeFor(int itemsTotal) =>
      itemsTotal >= settings.freeDeliveryThreshold || eligibleFirstOrder ? 0 : settings.deliveryFee;

  // ---------------- الإشعارات المقروءة ----------------
  String? _seenTop;
  int get unreadCount {
    final l = me?.notifications ?? const <String>[];
    if (l.isEmpty) return 0;
    final i = _seenTop == null ? -1 : l.indexOf(_seenTop!);
    return i < 0 ? l.length : i;
  }

  Future<void> loadSeen() async {
    if (currentPhone == null) return;
    final prefs = await SharedPreferences.getInstance();
    _seenTop = prefs.getString('depo_seen_$currentPhone');
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    final l = me?.notifications ?? const <String>[];
    if (l.isEmpty || currentPhone == null) return;
    _seenTop = l.first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('depo_seen_$currentPhone', l.first);
    notifyListeners();
  }

  // ---------------- الطلبات ----------------
  /// رقم طلب فريد (8 حروف/أرقام) حتى ما يتكرر بين الأجهزة
  String _orderId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(32).toUpperCase();
    final r = List.generate(3, (_) => chars[_rnd.nextInt(chars.length)]).join();
    return '${t.substring(t.length - 5)}$r';
  }

  /// يتأكد إن الطلب ممكن، ويرجّع سبب المنع (أو null)
  String? checkCart() {
    final u = me;
    if (u == null) return 'سجّل دخول أول';
    if (u.suspended) return 'حسابك موقوف. تواصل ويه الدعم.';
    if (cart.isEmpty || cart.storeId == null) return 'السلة فارغة';
    final s = storeById(cart.storeId!);
    if (s == null || s.suspended) return 'المحل مو متوفر هسه';
    if (s.ownerPhone == u.phone) return 'ما تكدر تطلب من محلك';
    for (final l in cart.lines) {
      final of = offerById(l.offer.id);
      if (of == null || !of.visible) return '«${l.offer.title}» خلص أو انتهى وقته. شيله من السلة.';
      if (of.quantityLeft < l.qty) return 'باقي من «${of.title}» ${of.quantityLeft} بس. قلّل الكمية.';
    }
    return null;
  }

  /// يأكد الطلب. بالسيرفر: الكميات تنقص بعملية وحدة (transaction) حتى ما ينباع نفس الشي لزبونين.
  /// يرمي [OrderError] إذا ما ينفع.
  Future<Order> placeOrder({required bool pickup, required String address}) async {
    final err = checkCart();
    if (err != null) throw OrderError(err);
    final u = me!;
    final s = storeById(cart.storeId!)!;
    final items = cart.total;
    final fee = pickup ? 0 : deliveryFeeFor(items);
    final o = Order(
      id: _orderId(),
      customerPhone: u.phone,
      customerName: u.name,
      storeId: s.id,
      lines: cart.lines
          .map((l) => OrderLine(offerId: l.offer.id, title: l.offer.title, price: l.offer.price, originalPrice: l.offer.originalPrice, qty: l.qty))
          .toList(),
      deliveryFee: fee,
      pickup: pickup,
      address: pickup ? '' : address,
      pickupCode: (1000 + _rnd.nextInt(9000)).toString(),
      commission: commissionFor(s, items),
    );
    final want = {for (final l in cart.lines) l.offer.id: l.qty};

    if (Cloud.enabled) {
      final db = Cloud.db!;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fresh = <String, Map<String, dynamic>>{};
      String? fail;
      try {
        await db.runTransaction((tx) async {
          fresh.clear();
          fail = null;
          for (final id in want.keys) {
            final snap = await tx.get(db.collection('offers').doc(id));
            final d = snap.data();
            if (d == null) {
              fail = 'عرض بالسلة انحذف. حدّث السلة.';
              return;
            }
            final of = Offer.fromJson(Map<String, dynamic>.from(d)..remove('_ts'));
            if (!of.visible) {
              fail = '«${of.title}» خلص أو انتهى وقته.';
              return;
            }
            if (of.quantityLeft < want[id]!) {
              fail = 'باقي من «${of.title}» ${of.quantityLeft} بس.';
              return;
            }
            fresh[id] = d;
          }
          for (final id in want.keys) {
            final d = fresh[id]!;
            tx.update(db.collection('offers').doc(id), {
              'quantityLeft': (d['quantityLeft'] as int) - want[id]!,
              'orderedThisWeek': ((d['orderedThisWeek'] ?? 0) as int) + want[id]!,
            });
          }
          tx.set(db.collection('orders').doc(o.id), {...o.toJson(), '_ts': ts});
        }).timeout(const Duration(seconds: 20));
      } catch (e) {
        throw OrderError('ما وصل الطلب للسيرفر. تأكد من الإنترنت وجرّب مرة ثانية.');
      }
      if (fail != null) throw OrderError(fail!);
      // نحدّث النسخة المحلية بنفس اللي انكتب
      for (final id in want.keys) {
        final of = offerById(id);
        if (of != null) {
          of.quantityLeft = (fresh[id]!['quantityLeft'] as int) - want[id]!;
          of.orderedThisWeek = ((fresh[id]!['orderedThisWeek'] ?? 0) as int) + want[id]!;
          _markSynced('offers', id);
        }
      }
      // ممكن السيرفر سبقنا ودزّ الطلب بالـ listener، فما نضيفه مرتين
      if (orderById(o.id) == null) orders.insert(0, o);
      _markSynced('orders', o.id, ts: ts);
    } else {
      for (final l in cart.lines) {
        final of = offerById(l.offer.id) ?? l.offer;
        of.quantityLeft = max(0, of.quantityLeft - l.qty);
        of.orderedThisWeek += l.qty;
      }
      orders.insert(0, o);
    }
    notify(s.ownerPhone, 'طلب جديد #${o.id} — ${iqd(o.itemsTotal)}');
    cart.clear();
    _changed();
    return orderById(o.id) ?? o;
  }

  List<Order> get myOrders => orders.where((o) => o.customerPhone == currentPhone).toList();
  List<Order> ordersOfStore(String storeId) => orders.where((o) => o.storeId == storeId).toList();
  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// يغيّر حالة الطلب. الطلب المنتهي (مُسلّم/مرفوض/ملغي) ما تتغير حالته.
  /// [restock]: ترجع الكمية للعرض (لا، إذا الأكل طلع من المحل)
  bool setStatus(Order o, OrderStatus st, {String reason = '', bool restock = true}) {
    if (!o.isOpen || o.status == st) return false;
    o.status = st;
    if (reason.isNotEmpty) o.rejectReason = reason;
    if ((st == OrderStatus.rejected || st == OrderStatus.cancelled) && restock) {
      for (final l in o.lines) {
        final of = offerById(l.offerId);
        if (of != null) of.quantityLeft += l.qty;
      }
    }
    if (st == OrderStatus.delivered) {
      final u = userByPhone(o.customerPhone);
      if (u != null) u.points += (o.itemsTotal / 1000).floor();
    }
    notify(o.customerPhone, 'طلبك #${o.id}: ${orderStatusNames[st]}${reason.isEmpty ? '' : ' — $reason'}');
    if (o.courierPhone != null && o.courierPhone != currentPhone && (st == OrderStatus.cancelled || st == OrderStatus.rejected)) {
      notify(o.courierPhone!, 'انلغى الطلب #${o.id}${reason.isEmpty ? '' : ' — $reason'}');
    }
    _changed();
    return true;
  }

  /// التوصيل بمندوب المحل نفسه (قرار معتمد)
  void deliverBySelf(Order o) {
    if (o.pickup || o.courierPhone != null || o.status != OrderStatus.ready) return;
    o.courierPhone = currentPhone;
    setStatus(o, OrderStatus.onTheWay);
  }

  /// تعذّر التسليم: ينلغي بدون ما ترجع الكمية، والمشرفين يوصلهم تنبيه
  void failDelivery(Order o, String reason) {
    if (setStatus(o, OrderStatus.cancelled, reason: 'تعذّر التسليم: $reason', restock: false)) {
      for (final s in users.where((x) => x.role == Role.supervisor || x.role == Role.admin)) {
        notify(s.phone, 'تعذّر تسليم الطلب #${o.id} — $reason');
      }
      _log('تعذّر تسليم #${o.id}: $reason');
      _changed();
    }
  }

  void rateOrder(Order o, int stars) {
    if (o.rating > 0 || o.status != OrderStatus.delivered || o.customerPhone != currentPhone) return;
    o.rating = stars.clamp(1, 5);
    final s = storeById(o.storeId);
    if (s != null) {
      s.rating = ((s.rating * s.ratingCount) + stars) / (s.ratingCount + 1);
      s.ratingCount += 1;
      // إيقاف تلقائي إذا نزل تحت 3.5 بعد 10 تقييمات
      if (s.ratingCount >= 10 && s.rating < 3.5) {
        s.suspended = true;
        _log('إيقاف تلقائي لـ ${s.name} (التقييم ${s.rating.toStringAsFixed(1)})');
      }
    }
    _changed();
  }

  // ---------------- المندوب ----------------
  List<Order> get availableTasks => orders
      .where((o) => !o.pickup && o.courierPhone == null && (o.status == OrderStatus.ready || o.status == OrderStatus.preparing))
      .toList();
  List<Order> get myTasks => orders.where((o) => o.courierPhone == currentPhone && o.isOpen).toList();

  /// النقد اللي بيد المندوب وبعده ما سلّمه لـ Depo
  int cashOf(String phone) => orders
      .where((o) => o.courierPhone == phone && o.status == OrderStatus.delivered && !o.cashSettled)
      .fold(0, (s, o) => s + o.total);
  int get courierCash => currentPhone == null ? 0 : cashOf(currentPhone!);

  /// المندوبين اللي بيدهم نقد (للمشرف)
  Map<String, int> get couriersCash {
    final m = <String, int>{};
    for (final o in orders.where((o) => o.courierPhone != null && o.status == OrderStatus.delivered && !o.cashSettled)) {
      m[o.courierPhone!] = (m[o.courierPhone!] ?? 0) + o.total;
    }
    return m;
  }

  /// المشرف استلم النقد من المندوب
  void settleCourier(String phone) {
    final amount = cashOf(phone);
    for (final o in orders.where((o) => o.courierPhone == phone && o.status == OrderStatus.delivered)) {
      o.cashSettled = true;
    }
    notify(phone, 'انستلم منك ${iqd(amount)} — صفّرنا حسابك النقدي');
    _log('استلام نقد ${iqd(amount)} من المندوب $phone');
    _changed();
  }

  void setCourierAvailable(bool v) {
    courierAvailable = v;
    _changed();
  }

  /// المندوب ياخذ المهمة. بالسيرفر نتأكد ما أخذها غيره بنفس اللحظة.
  Future<bool> takeTask(Order o) async {
    if (o.courierPhone != null || currentPhone == null) return false;
    if (Cloud.enabled) {
      final db = Cloud.db!;
      try {
        final ok = await db.runTransaction<bool>((tx) async {
          final ref = db.collection('orders').doc(o.id);
          final d = (await tx.get(ref)).data();
          if (d == null || d['courierPhone'] != null) return false;
          final st = d['status'];
          if (st != 'ready' && st != 'preparing') return false;
          tx.update(ref, {'courierPhone': currentPhone});
          return true;
        }).timeout(const Duration(seconds: 15));
        if (!ok) return false;
        o.courierPhone = currentPhone;
        _markSynced('orders', o.id);
        notifyListeners();
        return true;
      } catch (_) {
        return false;
      }
    }
    o.courierPhone = currentPhone;
    _changed();
    return true;
  }

  // ---------------- الانضمام ----------------
  JoinRequest? get myJoinRequest {
    for (final r in joinRequests) {
      if (r.phone == currentPhone && r.status == 'pending') return r;
    }
    return null;
  }

  /// سبب منع طلب الانضمام (أو null)
  String? joinBlocker() {
    final u = me;
    if (u == null) return 'سجّل دخول أول';
    if (u.role != Role.customer) return 'حسابك أصلاً ${roleNames[u.role]}';
    if (myJoinRequest != null) return 'عندك طلب قيد المراجعة';
    return null;
  }

  void submitJoin({required Role type, required String storeName, required String area, String details = '', Map<String, String> docs = const {}}) {
    if (joinBlocker() != null) return;
    final u = me!;
    joinRequests.insert(
      0,
      JoinRequest(id: _id('j'), phone: u.phone, name: u.name, type: type, storeName: storeName, area: area, details: details, docs: Map.of(docs)),
    );
    for (final s in users.where((x) => x.role == Role.supervisor || x.role == Role.admin)) {
      notify(s.phone, 'طلب انضمام جديد: ${roleNames[type]} — ${storeName.isEmpty ? u.name : storeName}');
    }
    _changed();
  }

  void approveJoin(JoinRequest r) {
    final u = userByPhone(r.phone);
    if (u == null || r.status != 'pending') return;
    if (!canSetRole(r.type)) return;
    r.status = 'approved';
    u.role = r.type;
    final existing = u.storeId == null ? null : storeById(u.storeId!);
    final wantType = r.type == Role.restaurant ? StoreType.restaurant : StoreType.merchant;
    if ((r.type == Role.restaurant || r.type == Role.merchant) && existing != null && existing.type == wantType) {
      existing.suspended = false; // نرجع نفس المحل
    } else if (r.type == Role.restaurant || r.type == Role.merchant) {
      final s = Store(
        id: _id('s'),
        name: r.storeName,
        area: r.area,
        type: r.type == Role.restaurant ? StoreType.restaurant : StoreType.merchant,
        ownerPhone: u.phone,
        eta: r.type == Role.restaurant ? '20–40 د' : 'اليوم',
      );
      stores.add(s);
      u.storeId = s.id;
    }
    notify(u.phone, 'تمت الموافقة على طلبك! صار حسابك ${roleNames[r.type]}. افتح «حسابي» وبدّل للواجهة الجديدة.');
    _log('موافقة على انضمام ${roleNames[r.type]}: ${r.storeName.isEmpty ? r.name : r.storeName} (${r.phone})');
    _changed();
  }

  void rejectJoin(JoinRequest r, String note) {
    r.status = 'rejected';
    r.note = note;
    notify(r.phone, 'طلب الانضمام ما انقبل${note.isEmpty ? '' : ': $note'}');
    _log('رفض انضمام ${r.phone}${note.isEmpty ? '' : ' — $note'}');
    _changed();
  }

  // ---------------- الإدارة ----------------
  /// المشرف ما يكدر يرفع مشرف ثاني — المدير بس
  bool canSetRole(Role target) {
    final r = me?.role;
    if (r == Role.admin) return true;
    if (r == Role.supervisor) return target != Role.supervisor && target != Role.admin;
    return false;
  }

  /// منو يكدر يدير هذا الحساب: المدير يدير الكل (إلا نفسه)، والمشرف يدير اللي تحت المشرف بس
  bool canManage(AppUser u) {
    final m = me;
    if (m == null || u.phone == m.phone) return false;
    if (m.role == Role.admin) return true;
    if (m.role == Role.supervisor) return u.role != Role.supervisor && u.role != Role.admin;
    return false;
  }

  void setRole(AppUser u, Role role) {
    if (!canSetRole(role) || !canManage(u)) return;
    u.role = role;
    _log('تغيير دور ${u.phone} إلى ${roleNames[role]}');
    notify(u.phone, 'صار حسابك: ${roleNames[role]}');
    _changed();
  }

  void setUserSuspended(AppUser u, bool v) {
    if (!canManage(u)) return;
    u.suspended = v;
    _log('${v ? 'إيقاف' : 'تفعيل'} الحساب ${u.phone}');
    _changed();
  }

  void setStoreSuspended(Store s, bool v) {
    s.suspended = v;
    _log('${v ? 'إيقاف' : 'تفعيل'} المحل ${s.name}');
    _changed();
  }

  void addComplaint({required Order o, required String type, required String text}) {
    final health = type.contains('منتهي') || type.contains('صحية');
    complaints.insert(0, Complaint(id: _id('c'), orderId: o.id, phone: o.customerPhone, type: type, text: text, health: health));
    if (health) {
      for (final s in users.where((x) => x.role == Role.supervisor || x.role == Role.admin)) {
        notify(s.phone, 'عاجل: شكوى صحية على الطلب #${o.id}');
      }
    }
    _changed();
  }

  void closeComplaint(Complaint c) {
    c.status = 'closed';
    _log('إغلاق شكوى على الطلب #${c.orderId}');
    _changed();
  }

  void saveSettings() {
    _log('تعديل الإعدادات (العمولات/التوصيل/الإشعارات)');
    _changed();
  }

  void addAddress(String a) {
    final u = me;
    final t = a.trim();
    if (u == null || t.isEmpty || u.addresses.contains(t)) return;
    u.addresses.insert(0, t.length > 150 ? t.substring(0, 150) : t);
    if (u.addresses.length > 10) u.addresses.removeLast();
    _changed();
  }

  void removeAddress(String a) {
    me?.addresses.remove(a);
    _changed();
  }

  // ---------------- التقارير ----------------
  List<Order> get deliveredOrders => orders.where((o) => o.status == OrderStatus.delivered).toList();
  int get gmv => deliveredOrders.fold(0, (s, o) => s + o.itemsTotal);
  int get totalCommission => deliveredOrders.fold(0, (s, o) => s + o.commission);
  int get savedForCustomers => deliveredOrders.fold(0, (s, o) => s + (o.originalTotal - o.itemsTotal));

  // ---------------- البيانات التجريبية ----------------
  void _seed() {
    final owners = ['07000000001', '07000000002', '07000000003', '07000000004', '07000000005'];
    stores = [
      Store(id: 's1', name: 'مطعم الشواء', area: 'الزهور', type: StoreType.restaurant, ownerPhone: owners[0], rating: 4.7, ratingCount: 312, distanceKm: 1.2, usuallyPublishes: 'عادةً ينشر رواجع الساعة 10 بالليل', sponsored: true, approvedAt: DateTime.now().subtract(const Duration(days: 12)).millisecondsSinceEpoch),
      Store(id: 's2', name: 'فرن المعجنات', area: 'المجموعة الثقافية', type: StoreType.restaurant, ownerPhone: owners[1], rating: 4.8, ratingCount: 540, distanceKm: 2.0, eta: '25–40 د', usuallyPublishes: 'عادةً ينشر رواجع الساعة 9 بالليل', approvedAt: DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch),
      Store(id: 's3', name: 'محل الحلويات', area: 'النور', type: StoreType.restaurant, ownerPhone: owners[2], rating: 4.6, ratingCount: 198, distanceKm: 3.0, eta: '30–40 د', usuallyPublishes: 'عادةً ينشر رواجع الساعة 11 بالليل', approvedAt: DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch),
      Store(id: 'm1', name: 'سوق النور', area: 'النور', type: StoreType.merchant, ownerPhone: owners[3], rating: 4.5, ratingCount: 120, distanceKm: 2.4, eta: 'اليوم'),
      Store(id: 'm2', name: 'هايبر الساحل', area: 'الساحل الأيسر', type: StoreType.merchant, ownerPhone: owners[4], rating: 4.4, ratingCount: 88, distanceKm: 4.0, eta: 'اليوم'),
    ];
    users = [
      AppUser(phone: owners[0], name: 'صاحب مطعم الشواء', role: Role.restaurant, storeId: 's1'),
      AppUser(phone: owners[1], name: 'صاحب فرن المعجنات', role: Role.restaurant, storeId: 's2'),
      AppUser(phone: owners[2], name: 'صاحب محل الحلويات', role: Role.restaurant, storeId: 's3'),
      AppUser(phone: owners[3], name: 'صاحب سوق النور', role: Role.merchant, storeId: 'm1'),
      AppUser(phone: owners[4], name: 'صاحب هايبر الساحل', role: Role.merchant, storeId: 'm2'),
      AppUser(phone: '07000000009', name: 'مندوب تجريبي', role: Role.courier),
    ];
    Offer of(String id, String sid, String t, int o, int p, int q, String e, {bool box = false, String pw = '', int w = 0, Storage st = Storage.normal, String d = ''}) =>
        Offer(id: id, storeId: sid, title: t, originalPrice: o, price: p, quantityLeft: q, expiresLabel: e, surpriseBox: box, pickupWindow: pw, orderedThisWeek: w, storage: st, description: d);
    offers = [
      of('o1', 's1', 'صندوق مشاوي', 15000, 5000, 2, 'باقي 45 د', box: true, pw: '10–11 م', w: 48, d: 'وجبات مشاوي انلغى طلبها أو زادت آخر اليوم. المحتوى ممكن يتغير حسب الموجود، بس قيمته الأصلية ما تقل عن 15,000 دينار.'),
      of('o2', 's1', 'نص فروج', 10000, 4000, 3, 'باقي 45 د', pw: '10–11 م', w: 30),
      of('o3', 's1', 'كبة موصلية', 8000, 3000, 4, 'باقي 45 د', pw: '10–11 م', w: 22),
      of('o4', 's2', 'صندوق معجنات', 9000, 3000, 5, 'باقي ساعة', box: true, pw: '9–10 م', w: 86),
      of('o5', 's2', 'صمون حار ×10', 2500, 1000, 8, 'باقي ساعة', pw: '9–10 م', w: 120),
      of('o6', 's3', 'كنافة', 10000, 4000, 3, 'باقي ساعتين', pw: '11–12 م', w: 40),
      of('o7', 's3', 'صندوق حلويات', 16000, 5000, 2, 'باقي ساعتين', box: true, pw: '11–12 م', w: 35),
      of('p1', 'm1', 'لبن 1 لتر — كرتونة 6', 9000, 4500, 40, 'ينتهي بعد 4 أيام', w: 320, st: Storage.chilled),
      of('p2', 'm1', 'بسكت شوكولاتة ×6', 2500, 1000, 60, 'ينتهي بعد 5 أيام', w: 210),
      of('p3', 'm2', 'صدور دجاج 1 كغم', 12000, 7000, 25, 'ينتهي بعد 9 أيام', w: 95, st: Storage.frozen),
      of('p4', 'm2', 'مسحوق غسيل 3 كغم', 14000, 8500, 30, 'ينتهي بعد 3 أسابيع', w: 41),
    ];
  }
}

final app = AppState();

class OrderError implements Exception {
  final String message;
  OrderError(this.message);
  @override
  String toString() => message;
}
