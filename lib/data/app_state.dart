import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud.dart';
import 'content.dart';
import 'geo.dart';
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
  List<Debtor> debtors = [];
  List<DebtEntry> debts = [];
  List<Chat> chats = [];
  List<Complaint> complaints = [];
  List<String> audit = [];
  List<Settlement> settlements = [];
  AppSettings settings = AppSettings();
  ContentConfig content = ContentConfig.defaults();
  String? currentPhone;
  bool courierAvailable = true;
  bool loaded = false;

  // ---------------- التخزين ----------------
  /// الأقسام اللي تنحفظ بالسيرفر (كل قسم = collection بـ Firestore)
  static const _cols = ['users', 'stores', 'offers', 'orders', 'joinRequests', 'complaints', 'meta', 'debtors', 'debts', 'chats', 'settlements'];

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
    // آخر محتوى معروف (حتى شاشة البداية والرئيسية تطلع صح فوراً)
    final cached = prefs.getString('depo_content_cache');
    if (cached != null) {
      try {
        content = ContentConfig.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      } catch (_) {}
    }
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
      debtors = l('debtors').map(Debtor.fromJson).toList();
      debts = l('debts').map(DebtEntry.fromJson).toList();
      chats = l('chats').map(Chat.fromJson).toList();
      complaints = l('complaints').map(Complaint.fromJson).toList();
      audit = List<String>.from(j['audit'] ?? const []);
      settlements = l('settlements').map(Settlement.fromJson).toList();
      settings = AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] ?? const {}));
      if (j['content'] is Map) content = ContentConfig.fromJson(Map<String, dynamic>.from(j['content'] as Map));
      currentPhone ??= j['currentPhone'] as String?;
    } catch (_) {
      _seed();
    }
  }

  // ---- Firestore ----
  /// السحب للتحديث: نجيب آخر نسخة من السيرفر (والتغييرات توصل لحالها أصلاً)
  Future<void> refreshFromServer() async {
    final started = DateTime.now();
    if (Cloud.enabled) {
      try {
        final db = Cloud.db!;
        for (final c in _cols) {
          final qs = await db.collection(c).get(const fs.GetOptions(source: fs.Source.server)).timeout(const Duration(seconds: 12));
          _applyDocs(c, qs.docs);
        }
        if (Cloud.status.startsWith('تعذر') || Cloud.status.startsWith('انقطع')) Cloud.status = 'متصل بالسيرفر ✓';
      } catch (_) {}
    }
    // نخلي الحركة تبين شوية حتى لو التحديث سريع
    final left = const Duration(milliseconds: 700) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    notifyListeners();
  }

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
      case 'debtors':
        return {for (final x in debtors) x.id: x.toJson()};
      case 'debts':
        return {for (final x in debts) x.id: x.toJson()};
      case 'chats':
        return {for (final x in chats) x.id: x.toJson()};
      case 'settlements':
        return {for (final x in settlements) x.id: x.toJson()};
      case 'complaints':
        return {for (final x in complaints) x.id: x.toJson()};
      case 'meta':
        return {
          'settings': settings.toJson(),
          'audit': {'items': audit},
          'content': content.toJson(),
        };
    }
    return {};
  }

  /// الأقسام الي الجديد بيها ينضاف بالأول (الأحدث فوق)
  static const _newestFirst = {'offers', 'orders', 'joinRequests', 'complaints', 'debts'};

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
      case 'debtors':
        final old = {for (final x in debtors) x.id: x};
        debtors = [for (final d in list) keep(d.id, d.data(), Debtor.fromJson, old[d.id])];
      case 'debts':
        final old = {for (final x in debts) x.id: x};
        debts = [for (final d in list) keep(d.id, d.data(), DebtEntry.fromJson, old[d.id])];
      case 'chats':
        final old = {for (final x in chats) x.id: x};
        chats = [for (final d in list) keep(d.id, d.data(), Chat.fromJson, old[d.id])];
      case 'settlements':
        final old = {for (final x in settlements) x.id: x};
        settlements = [for (final d in list) keep(d.id, d.data(), Settlement.fromJson, old[d.id])]..sort((a, b) => b.at.compareTo(a.at));
      case 'complaints':
        final old = {for (final x in complaints) x.id: x};
        complaints = [for (final d in list) keep(d.id, d.data(), Complaint.fromJson, old[d.id])];
      case 'meta':
        for (final d in list) {
          if (d.id == 'settings') settings = AppSettings.fromJson(_clean(d.data()));
          if (d.id == 'audit') audit = List<String>.from(d.data()['items'] ?? const []);
          if (d.id == 'content') {
            content = ContentConfig.fromJson(_clean(d.data()));
            SharedPreferences.getInstance().then((p) => p.setString('depo_content_cache', jsonEncode(content.toJson())));
          }
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
        'debtors': debtors.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'chats': chats.map((e) => e.toJson()).toList(),
        'complaints': complaints.map((e) => e.toJson()).toList(),
        'audit': audit,
        'settlements': settlements.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
        'content': content.toJson(),
      }),
    );
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  void _changedPublic() => _changed();
  void _logPublic(String t) => _log(t);

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
    debtors = [];
    debts = [];
    chats = [];
    complaints = [];
    settlements = [];
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
  int commissionFor(Store s, int itemsTotal) => commissionWithRule(s, itemsTotal).$1;

  /// العمولة + شرح كيف انحسبت. العمولة ما تعبر سعر البضاعة أبداً.
  (int, String) commissionWithRule(Store s, int itemsTotal) {
    if (s.type == StoreType.shop) return (0, 'المتجر المجاني بدون عمولة');
    if (s.type == StoreType.restaurant) {
      if (freeDaysLeft(s) > 0) return (0, 'الشهر المجاني (بدون عمولة)');
      final pct = settings.restaurantCommission;
      final byPct = (itemsTotal * pct / 100).round();
      if (byPct >= settings.minCommission) return (byPct, '$pct% من ${iqd(itemsTotal)}');
      final c = min(settings.minCommission, itemsTotal);
      return (c, '$pct% = ${iqd(byPct)} أقل من الحد الأدنى، فانحسب ${iqd(c)}');
    }
    final pct = settings.merchantCommission;
    return ((itemsTotal * pct / 100).round(), '$pct% من ${iqd(itemsTotal)}');
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
    String category = '',
  }) =>
      Offer(
        expiresAt: expiresAt,
        category: category,
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
      category: old.category,
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

  /// نوع المطعم (للأقسام): صاحبه أو الشراكات/الجودة
  void setStoreCuisine(Store s, String cuisine) {
    if (!(me?.storeId == s.id || canAny([Perm.partnerships, Perm.quality]))) return;
    s.cuisine = cuisine;
    _changed();
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
    if (!can(Perm.quality)) return;
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
  Future<Order> placeOrder({required bool pickup, required String address, GeoFix? location}) async {
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
      commission: commissionWithRule(s, items).$1,
      commissionRule: commissionWithRule(s, items).$2,
      distanceKm: pickup ? 0 : s.distanceKm,
      custLat: pickup || location == null ? 0 : location.lat,
      custLng: pickup || location == null ? 0 : location.lng,
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
            final unlimited = (d['quantityLeft'] as int) >= 9000;
            tx.update(db.collection('offers').doc(id), {
              'quantityLeft': unlimited ? d['quantityLeft'] : (d['quantityLeft'] as int) - want[id]!,
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
          final q = fresh[id]!['quantityLeft'] as int;
          of.quantityLeft = q >= 9000 ? q : q - want[id]!;
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
        if (!of.unlimited) of.quantityLeft = max(0, of.quantityLeft - l.qty);
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
      o.deliveredAt = DateTime.now().millisecondsSinceEpoch;
      if (paidCourier(o)) {
        final cp = CourierPay.of(const [], settings);
        o.payRule = cp.rule;
        o.distanceKm = cp.kmOf(o.distanceKm);
        o.courierPay = cp.pay(o.distanceKm);
      } else {
        o.courierPay = 0;
      }
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
      .where((o) => storeById(o.storeId)?.type != StoreType.shop) // الأسواق توصّل بمندوبها
      .toList();
  List<Order> get myTasks => orders.where((o) => o.courierPhone == currentPhone && o.isOpen).toList();

  /// المحل وصّل بنفسه (مو مندوب ديبو)
  bool selfDelivered(Order o) => !o.pickup && o.courierPhone != null && o.courierPhone == storeById(o.storeId)?.ownerPhone;

  /// الطلب ينطي أجرة لمندوب ديبو
  bool paidCourier(Order o) => !o.pickup && o.courierPhone != null && !selfDelivered(o);

  /// النقد اللي بيد المندوب وبعده ما سلّمه لـ Depo
  int cashOf(String phone) => orders
      .where((o) => o.courierPhone == phone && o.status == OrderStatus.delivered && !o.cashSettled && !selfDelivered(o))
      .fold(0, (s, o) => s + o.total);
  int get courierCash => currentPhone == null ? 0 : cashOf(currentPhone!);

  /// المندوبين اللي بيدهم نقد (للمشرف)
  Map<String, int> get couriersCash {
    final m = <String, int>{};
    for (final o in orders.where((o) => o.courierPhone != null && o.status == OrderStatus.delivered && !o.cashSettled && !selfDelivered(o))) {
      m[o.courierPhone!] = (m[o.courierPhone!] ?? 0) + o.total;
    }
    return m;
  }

  /// المشرف استلم النقد من المندوب
  void settleCourier(String phone) {
    if (!canAny([Perm.operations, Perm.finance])) return;
    final list = orders.where((o) => o.courierPhone == phone && o.status == OrderStatus.delivered && !o.cashSettled && !selfDelivered(o)).toList();
    if (list.isEmpty) return;
    final amount = list.fold(0, (s, o) => s + o.total);
    for (final o in list) {
      o.cashSettled = true;
    }
    final by = me == null ? '' : (me!.name.isEmpty ? me!.phone : me!.name);
    settlements.insert(0, Settlement(
      id: 'cash${DateTime.now().millisecondsSinceEpoch}',
      kind: 'cash',
      target: phone,
      month: monthKey(DateTime.now()),
      amount: -amount,
      at: DateTime.now().millisecondsSinceEpoch,
      by: by,
      orderIds: [for (final o in list) o.id],
    ));
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

  void submitJoin({required Role type, required String storeName, required String area, String details = '', Map<String, String> docs = const {}, String cuisine = ''}) {
    if (joinBlocker() != null) return;
    final u = me!;
    joinRequests.insert(
      0,
      JoinRequest(id: _id('j'), phone: u.phone, name: u.name, type: type, storeName: storeName, area: area, details: details, docs: Map.of(docs), cuisine: cuisine),
    );
    for (final s in users.where((x) => x.role == Role.supervisor || x.role == Role.admin)) {
      notify(s.phone, 'طلب انضمام جديد: ${roleNames[type]} — ${storeName.isEmpty ? u.name : storeName}');
    }
    _changed();
  }

  void approveJoin(JoinRequest r, {bool viaInspection = false}) {
    final u = userByPhone(r.phone);
    if (u == null || r.status != 'pending') return;
    if (!canDecideJoin(r, viaInspection: viaInspection)) return;
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
        cuisine: r.type == Role.restaurant ? r.cuisine : '',
      );
      stores.add(s);
      u.storeId = s.id;
    }
    notify(u.phone, 'تمت الموافقة على طلبك! صار حسابك ${roleNames[r.type]}. افتح «حسابي» وبدّل للواجهة الجديدة.');
    _log('موافقة على انضمام ${roleNames[r.type]}: ${r.storeName.isEmpty ? r.name : r.storeName} (${r.phone})');
    _changed();
  }

  void rejectJoin(JoinRequest r, String note) {
    if (r.status != 'pending' || !canDecideJoin(r, viaInspection: true)) return;
    r.status = 'rejected';
    r.note = note;
    notify(r.phone, 'طلب الانضمام ما انقبل${note.isEmpty ? '' : ': $note'}');
    _log('رفض انضمام ${r.phone}${note.isEmpty ? '' : ' — $note'}');
    _changed();
  }

  // ---------------- الإدارة ----------------
  /// هل الحساب الحالي عنده صلاحية هذا القسم؟ (المدير: كلشي)
  bool can(Perm p) {
    final m = me;
    if (m == null || m.suspended) return false;
    if (m.role == Role.admin) return true;
    return m.role == Role.supervisor && m.perms.contains(p.name);
  }

  bool canAny(List<Perm> ps) => ps.any(can);

  Set<Perm> permsOf(AppUser u) => {for (final p in Perm.values) if (u.perms.contains(p.name)) p};

  /// المدير بس يحدد أقسام المشرف
  void setPerms(AppUser u, Set<Perm> ps) {
    if (me?.role != Role.admin || u.role != Role.supervisor) return;
    u.perms = [for (final p in Perm.values) if (ps.contains(p)) p.name];
    _log('أقسام المشرف ${u.phone}: ${ps.isEmpty ? 'بدون' : ps.map((p) => permNames[p]).join('، ')}');
    notify(u.phone, 'تحدّثت أقسامك: ${ps.isEmpty ? 'بدون' : ps.map((p) => permNames[p]).join('، ')}');
    _changed();
  }

  /// منو يكدر يقرر بطلب الانضمام: المندوبين = العمليات، المحلات = الشراكات (والجودة عن طريق التفتيش)
  bool canDecideJoin(JoinRequest r, {bool viaInspection = false}) {
    if (r.type == Role.courier) return can(Perm.operations);
    return can(Perm.partnerships) || (viaInspection && can(Perm.quality));
  }

  bool canSeeJoin(JoinRequest r) => r.type == Role.courier ? can(Perm.operations) : canAny([Perm.partnerships, Perm.quality]);

  void setStoreSponsored(Store s, bool v) {
    if (!can(Perm.sales)) return;
    s.sponsored = v;
    _log('${v ? 'تمويل' : 'إلغاء تمويل'} ظهور ${s.name}');
    _changed();
  }

  /// إلغاء طلب من الدعم أو العمليات
  void staffCancel(Order o, String reason) {
    if (!canAny([Perm.operations, Perm.support])) return;
    if (setStatus(o, OrderStatus.cancelled, reason: reason)) _log('إلغاء الطلب #${o.id}: $reason');
  }

  /// المشرف ما يكدر يرفع مشرف ثاني — المدير بس
  /// المدير: أي دور. المشرف: التقنية (زبون/مندوب)، العمليات (مندوب/زبون). رفع المحلات من طلبات الانضمام بس.
  bool canSetRole(Role target) {
    final r = me?.role;
    if (r == Role.admin) return true;
    if (r != Role.supervisor) return false;
    if (target != Role.customer && target != Role.courier) return false;
    return canAny([Perm.tech, Perm.operations]);
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
    if (role != Role.supervisor) u.perms = [];
    _log('تغيير دور ${u.phone} إلى ${roleNames[role]}');
    notify(u.phone, 'صار حسابك: ${roleNames[role]}');
    _changed();
  }

  bool get canSuspendUsers => canAny([Perm.tech, Perm.support]);

  void setUserSuspended(AppUser u, bool v) {
    if (!canManage(u) || !canSuspendUsers) return;
    u.suspended = v;
    _log('${v ? 'إيقاف' : 'تفعيل'} الحساب ${u.phone}');
    _changed();
  }

  void setStoreSuspended(Store s, bool v) {
    if (!canAny([Perm.quality, Perm.partnerships])) return;
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
    if (!canAny([Perm.support, Perm.quality])) return;
    c.status = 'closed';
    _log('إغلاق شكوى على الطلب #${c.orderId}');
    _changed();
  }

  // ---------------- المحتوى (يتعدل من داخل التطبيق) ----------------
  bool get canEditBanners => canAny([Perm.design, Perm.marketing]);
  bool get canEditContent => can(Perm.design);

  void saveBanners(List<BannerItem> list) {
    if (!canEditBanners) return;
    content.banners = list;
    _log('تعديل البنرات');
    _changed();
  }

  void saveCats({required bool market, required List<CatItem> list}) {
    if (!canEditContent) return;
    if (market) {
      content.marketCats = list;
    } else {
      content.restCats = list;
    }
    _log('تعديل ${market ? 'أصناف الماركت' : 'أقسام المطاعم'}');
    _changed();
  }

  void savePhrases(List<String> list) {
    if (!canEditContent) return;
    content.searchPhrases = list.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    _log('تعديل جمل البحث');
    _changed();
  }

  void saveSplash(String l1, String l2) {
    if (!canEditContent) return;
    content.splash1 = l1.trim();
    content.splash2 = l2.trim();
    _log('تعديل جملة شاشة البداية');
    _changed();
  }

  void saveSections(Map<String, bool> m) {
    if (!canEditContent) return;
    content.sections = Map.of(m);
    _log('تعديل أجزاء الرئيسية');
    _changed();
  }

  /// إعدادات التسويق (الشريط، أول طلب، الحملة) — قسم التسويق
  void saveMarketing({required bool firstOrderFree, required String campaignName, required int campaignMinDiscount}) {
    if (!can(Perm.marketing)) return;
    settings
      ..firstOrderFree = firstOrderFree
      ..campaignName = campaignName.isEmpty ? settings.campaignName : campaignName
      ..campaignMinDiscount = campaignMinDiscount.clamp(10, 95);
    _log('تعديل إعدادات التسويق');
    _changed();
  }

  void saveSettings() {
    if (me?.role != Role.admin) return;
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
      Store(id: 's1', name: 'مطعم الشواء', area: 'الزهور', type: StoreType.restaurant, ownerPhone: owners[0], rating: 4.7, ratingCount: 312, distanceKm: 1.2, usuallyPublishes: 'عادةً ينشر رواجع الساعة 10 بالليل', cuisine: 'مشاوي', sponsored: true, approvedAt: DateTime.now().subtract(const Duration(days: 12)).millisecondsSinceEpoch),
      Store(id: 's2', name: 'فرن المعجنات', area: 'المجموعة الثقافية', type: StoreType.restaurant, ownerPhone: owners[1], rating: 4.8, ratingCount: 540, distanceKm: 2.0, eta: '25–40 د', usuallyPublishes: 'عادةً ينشر رواجع الساعة 9 بالليل', cuisine: 'معجنات وأفران', approvedAt: DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch),
      Store(id: 's3', name: 'محل الحلويات', area: 'النور', type: StoreType.restaurant, ownerPhone: owners[2], rating: 4.6, ratingCount: 198, distanceKm: 3.0, eta: '30–40 د', usuallyPublishes: 'عادةً ينشر رواجع الساعة 11 بالليل', cuisine: 'حلويات', approvedAt: DateTime.now().subtract(const Duration(days: 45)).millisecondsSinceEpoch),
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
    Offer of(String id, String sid, String t, int o, int p, int q, String e, {bool box = false, String pw = '', int w = 0, Storage st = Storage.normal, String d = '', String c = ''}) =>
        Offer(id: id, storeId: sid, title: t, originalPrice: o, price: p, quantityLeft: q, expiresLabel: e, surpriseBox: box, pickupWindow: pw, orderedThisWeek: w, storage: st, description: d, category: c);
    offers = [
      of('o1', 's1', 'صندوق مشاوي', 15000, 5000, 2, 'باقي 45 د', box: true, pw: '10–11 م', w: 48, d: 'وجبات مشاوي انلغى طلبها أو زادت آخر اليوم. المحتوى ممكن يتغير حسب الموجود، بس قيمته الأصلية ما تقل عن 15,000 دينار.'),
      of('o2', 's1', 'نص فروج', 10000, 4000, 3, 'باقي 45 د', pw: '10–11 م', w: 30),
      of('o3', 's1', 'كبة موصلية', 8000, 3000, 4, 'باقي 45 د', pw: '10–11 م', w: 22),
      of('o4', 's2', 'صندوق معجنات', 9000, 3000, 5, 'باقي ساعة', box: true, pw: '9–10 م', w: 86),
      of('o5', 's2', 'صمون حار ×10', 2500, 1000, 8, 'باقي ساعة', pw: '9–10 م', w: 120),
      of('o6', 's3', 'كنافة', 10000, 4000, 3, 'باقي ساعتين', pw: '11–12 م', w: 40),
      of('o7', 's3', 'صندوق حلويات', 16000, 5000, 2, 'باقي ساعتين', box: true, pw: '11–12 م', w: 35),
      of('p1', 'm1', 'لبن 1 لتر — كرتونة 6', 9000, 4500, 40, 'ينتهي بعد 4 أيام', w: 320, st: Storage.chilled, c: 'ألبان وأجبان'),
      of('p2', 'm1', 'بسكت شوكولاتة ×6', 2500, 1000, 60, 'ينتهي بعد 5 أيام', w: 210, c: 'سناكات وحلويات'),
      of('p3', 'm2', 'صدور دجاج 1 كغم', 12000, 7000, 25, 'ينتهي بعد 9 أيام', w: 95, st: Storage.frozen, c: 'لحوم ومجمدات'),
      of('p4', 'm2', 'مسحوق غسيل 3 كغم', 14000, 8500, 30, 'ينتهي بعد 3 أسابيع', w: 41, c: 'منظفات'),
    ];
  }
}

final app = AppState();

extension Chats on AppState {
  bool get isSupportStaff => can(Perm.support);

  Chat? chatById(String id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// محادثة الدعم مالتي (تنفتح إذا ماكو)
  Chat? myChat({required String kind, String storeId = ''}) {
    final u = me;
    if (u == null) return null;
    for (final c in chats) {
      if (c.kind == kind && c.userPhone == u.phone && c.storeId == storeId) return c;
    }
    final c = Chat(id: 'ch${DateTime.now().millisecondsSinceEpoch}', kind: kind, userPhone: u.phone, userName: u.name, storeId: storeId);
    chats.insert(0, c);
    _changedPublic();
    return c;
  }

  /// أنا بهاي المحادثة من «الفريق» (الدعم أو صاحب المحل)؟
  bool isStaffIn(Chat c) {
    if (c.userPhone == currentPhone) return false;
    if (c.kind == 'support') return isSupportStaff;
    return ownsStore(c.storeId);
  }

  bool canSeeChat(Chat c) => c.userPhone == currentPhone || isStaffIn(c);

  void sendChat(Chat c, String text) {
    final u = me;
    final t = text.trim();
    if (u == null || t.isEmpty || !canSeeChat(c)) return;
    final staff = isStaffIn(c);
    c.messages.add(ChatMsg(from: u.phone, text: t.length > 1000 ? t.substring(0, 1000) : t, staff: staff));
    if (c.messages.length > 300) c.messages.removeAt(0);
    c.open = true;
    c.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (staff) {
      c.staffReadAt = c.updatedAt;
      final who = c.kind == 'support' ? 'دعم ديبو' : (storeById(c.storeId)?.name ?? 'المحل');
      notify(c.userPhone, 'رسالة جديدة من $who: ${t.length > 60 ? '${t.substring(0, 60)}…' : t}');
    } else {
      c.userReadAt = c.updatedAt;
      if (c.userName.isEmpty) c.userName = u.name;
      if (c.kind == 'support') {
        for (final x in users.where((x) => x.role == Role.admin || (x.role == Role.supervisor && x.perms.contains(Perm.support.name)))) {
          notify(x.phone, 'رسالة جديدة للدعم من ${u.name.isEmpty ? u.phone : u.name}');
        }
      } else {
        final owner = storeById(c.storeId)?.ownerPhone;
        if (owner != null && owner.isNotEmpty) notify(owner, 'رسالة جديدة من ${u.name.isEmpty ? 'زبون' : u.name}');
      }
    }
    _changedPublic();
  }

  void markChatRead(Chat c) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (isStaffIn(c)) {
      if (c.unreadFor(staff: true) == 0) return;
      c.staffReadAt = now;
    } else if (c.userPhone == currentPhone) {
      if (c.unreadFor(staff: false) == 0) return;
      c.userReadAt = now;
    } else {
      return;
    }
    _changedPublic();
  }

  void closeChat(Chat c) {
    if (!isStaffIn(c)) return;
    c.open = false;
    c.messages.add(ChatMsg(from: currentPhone ?? '', text: 'انغلقت المحادثة. إذا عندك شي ثاني اكتبلنا بأي وقت.', staff: true));
    c.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _changedPublic();
  }

  List<Chat> get supportChats =>
      chats.where((c) => c.kind == 'support' && c.messages.isNotEmpty).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  List<Chat> shopChats(String storeId) =>
      chats.where((c) => c.kind == 'shop' && c.storeId == storeId && c.messages.isNotEmpty).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// ملخص دين زبون
class DebtSummary {
  final int ordered, paid, remaining, overdue;
  final int nextDue; // أقرب موعد جاي (0 = ماكو)
  final int oldestOverdue; // أقدم موعد فات (0 = ماكو)
  const DebtSummary(this.ordered, this.paid, this.remaining, this.overdue, this.nextDue, this.oldestOverdue);
  int get paidPercent => ordered == 0 ? 0 : (paid * 100 / ordered).round().clamp(0, 100);
}

extension DebtBook on AppState {
  // ---------- المتجر المجاني ----------
  Store? get myShop {
    for (final s in stores) {
      if (s.type == StoreType.shop && s.ownerPhone == currentPhone) return s;
    }
    return null;
  }

  List<Store> get shops => stores.where((s) => s.type == StoreType.shop && !s.suspended && s.listed).toList();

  bool ownsStore(String storeId) => storeById(storeId)?.ownerPhone == currentPhone && currentPhone != null;

  Store? openShop({required String name, required String area, String about = '', String phone = '', String mapLink = '', bool listed = true, String imageId = ''}) {
    final u = me;
    if (u == null || u.suspended || myShop != null) return null;
    final s = Store(
      id: 'shop${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      area: area.trim(),
      type: StoreType.shop,
      ownerPhone: u.phone,
      eta: 'استلام أو توصيل من المحل',
      usuallyPublishes: about.trim(),
      phone: phone.trim(),
      mapLink: mapLink.trim(),
      listed: listed,
      imageId: imageId,
    );
    stores.add(s);
    _logPublic('فتح متجر مجاني: ${s.name} — ${u.phone}');
    _changedPublic();
    return s;
  }

  void updateShop(Store s, {required String name, required String area, required String about, required String phone, required String mapLink, required bool listed}) {
    if (!ownsStore(s.id) || name.trim().length < 2) return;
    s
      ..name = name.trim()
      ..area = area.trim()
      ..usuallyPublishes = about.trim()
      ..phone = phone.trim()
      ..mapLink = mapLink.trim()
      ..listed = listed;
    _changedPublic();
  }

  void setShopPromo(Store s, {required String imageId, required String text}) {
    if (!ownsStore(s.id)) return;
    s.promoImageId = imageId;
    s.promoText = text.trim();
    _changedPublic();
  }

  void setShopImage(Store s, String imageId) {
    if (!ownsStore(s.id)) return;
    s.imageId = imageId;
    _changedPublic();
  }

  /// يلقى زبون بنفس الاسم أو الرقم، أو يسوي جديد
  Debtor? findOrAddDebtor(String storeId, {required String name, String phone = ''}) {
    final n = name.trim(), p = phone.trim();
    for (final d in debtorsOf(storeId)) {
      if ((p.isNotEmpty && d.phone == p) || (p.isEmpty && d.name == n)) return d;
    }
    return addDebtor(storeId, name: n, phone: p);
  }

  /// يلغي كل الحركات المفتوحة لزبون (حذف الكل)
  void voidAllOf(Debtor d) {
    if (!ownsStore(d.storeId)) return;
    for (final e in debts.where((e) => e.debtorId == d.id && !e.voided)) {
      e.voided = true;
    }
    _changedPublic();
  }

  void updateShopProductFull(Offer o, {required String name, required int price, required String category, required String description, required bool available, String? imageId}) {
    if (!ownsStore(o.storeId) || name.trim().isEmpty || price <= 0) return;
    o
      ..title = name.trim()
      ..price = price
      ..originalPrice = o.originalPrice > price ? o.originalPrice : price
      ..category = category.trim()
      ..description = description.trim()
      ..active = available;
    if (imageId != null) o.imageId = imageId;
    _changedPublic();
  }

  /// منتج بالمتجر المجاني (سعر عادي، بدون كمية محددة)
  void addShopProduct(Store s, {required String name, required int price, int? oldPrice, String imageId = '', String description = '', String category = '', bool available = true}) {
    if (!ownsStore(s.id) || s.type != StoreType.shop || s.suspended || name.trim().isEmpty || price <= 0) return;
    offers.insert(
      0,
      Offer(
        id: 'sp${DateTime.now().millisecondsSinceEpoch}',
        storeId: s.id,
        title: name.trim(),
        originalPrice: (oldPrice != null && oldPrice > price) ? oldPrice : price,
        price: price,
        quantityLeft: 9999,
        expiresLabel: '',
        category: category.trim(),
        imageId: imageId,
        description: description.trim(),
        active: available,
      ),
    );
    _changedPublic();
  }

  void updateShopProduct(Offer o, {required String name, required int price, int? oldPrice}) {
    if (!ownsStore(o.storeId) || name.trim().isEmpty || price <= 0) return;
    o.title = name.trim();
    o.price = price;
    o.originalPrice = (oldPrice != null && oldPrice > price) ? oldPrice : price;
    _changedPublic();
  }

  void deleteShopProduct(Offer o) {
    if (!ownsStore(o.storeId) || storeById(o.storeId)?.type != StoreType.shop) return;
    offers.remove(o);
    _changedPublic();
  }

  // ---------- الزبائن والديون ----------
  List<Debtor> debtorsOf(String storeId) => debtors.where((d) => d.storeId == storeId).toList();
  Debtor? debtorById(String id) {
    for (final d in debtors) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<DebtEntry> entriesOf(String debtorId) =>
      debts.where((e) => e.debtorId == debtorId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// التسديد يتوزع على الطلبات من الأقدم للأحدث
  DebtSummary summaryOf(String debtorId) {
    final all = debts.where((e) => e.debtorId == debtorId && !e.voided).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final orders = all.where((e) => !e.payment).toList();
    final ordered = orders.fold(0, (s, e) => s + e.amount);
    final paid = all.where((e) => e.payment).fold(0, (s, e) => s + e.amount);
    var left = paid;
    var overdue = 0, nextDue = 0, oldest = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final o in orders) {
      final cover = left >= o.amount ? o.amount : left;
      left -= cover;
      final unpaid = o.amount - cover;
      if (unpaid <= 0 || o.dueAt <= 0) continue;
      if (o.dueAt < now) {
        overdue += unpaid;
        if (oldest == 0 || o.dueAt < oldest) oldest = o.dueAt;
      } else if (nextDue == 0 || o.dueAt < nextDue) {
        nextDue = o.dueAt;
      }
    }
    final remaining = ordered - paid;
    return DebtSummary(ordered, paid, remaining < 0 ? 0 : remaining, overdue, nextDue, oldest);
  }

  /// مجموع دفتر المحل
  DebtSummary shopSummary(String storeId) {
    var o = 0, p = 0, r = 0, od = 0;
    for (final d in debtorsOf(storeId)) {
      final s = summaryOf(d.id);
      o += s.ordered;
      p += s.paid;
      r += s.remaining;
      od += s.overdue;
    }
    return DebtSummary(o, p, r, od, 0, 0);
  }

  String _newCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    while (true) {
      String part() => List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
      final c = '${part()}-${part()}';
      if (!debtors.any((d) => d.code == c)) return c;
    }
  }

  Debtor? addDebtor(String storeId, {required String name, String phone = ''}) {
    if (!ownsStore(storeId) || name.trim().length < 2) return null;
    final d = Debtor(id: 'dr${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99)}', storeId: storeId, name: name.trim(), phone: phone.trim(), code: _newCode());
    debtors.insert(0, d);
    _changedPublic();
    return d;
  }

  void _tellDebtor(Debtor d, String text) {
    for (final u in users.where((u) => u.debtCodes.contains(d.code))) {
      notify(u.phone, text);
    }
  }

  void addDebtOrder(Debtor d, {required List<DebtItem> items, required String month, int dueAt = 0, String note = ''}) {
    if (!ownsStore(d.storeId)) return;
    final clean = items.where((i) => i.name.trim().isNotEmpty && i.price > 0 && i.qty > 0).toList();
    if (clean.isEmpty) return;
    final amount = clean.fold(0, (s, i) => s + i.total);
    debts.insert(0, DebtEntry(id: 'de${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99)}', debtorId: d.id, storeId: d.storeId, payment: false, items: clean, amount: amount, month: month, dueAt: dueAt, note: note.trim()));
    _tellDebtor(d, '${storeById(d.storeId)?.name ?? 'المحل'}: انضاف عليك ${iqd(amount)}');
    _changedPublic();
  }

  /// يرجّع المبلغ المسجّل فعلاً (ما يزيد على الباقي)
  int addDebtPayment(Debtor d, int amount, {String note = ''}) {
    if (!ownsStore(d.storeId) || amount <= 0) return 0;
    final rem = summaryOf(d.id).remaining;
    final a = amount > rem ? rem : amount;
    if (a <= 0) return 0;
    debts.insert(0, DebtEntry(id: 'dp${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(99)}', debtorId: d.id, storeId: d.storeId, payment: true, amount: a, month: monthKey(DateTime.now()), note: note.trim()));
    _tellDebtor(d, '${storeById(d.storeId)?.name ?? 'المحل'}: انسجّلت دفعة ${iqd(a)}. الباقي ${iqd(rem - a)}');
    _changedPublic();
    return a;
  }

  void voidDebtEntry(DebtEntry e) {
    if (!ownsStore(e.storeId) || e.voided) return;
    e.voided = true;
    _changedPublic();
  }

  void regenerateDebtCode(Debtor d) {
    if (!ownsStore(d.storeId)) return;
    final old = d.code;
    d.code = _newCode();
    for (final u in users) {
      u.debtCodes.remove(old);
    }
    _changedPublic();
  }

  void updateDebtor(Debtor d, {required String name, required String phone}) {
    if (!ownsStore(d.storeId) || name.trim().length < 2) return;
    d.name = name.trim();
    d.phone = phone.trim();
    _changedPublic();
  }

  /// تذكير داخل التطبيق: يوصل للزبون اللي ضاف رمزه. يرجّع عدد الحسابات اللي وصلها
  int remindDebtor(Debtor d) {
    if (!ownsStore(d.storeId)) return 0;
    final s = summaryOf(d.id);
    if (s.remaining <= 0) return 0;
    final store = storeById(d.storeId);
    final due = s.overdue > 0 ? ' — منها ${iqd(s.overdue)} متأخرة' : (s.nextDue > 0 ? ' — موعدها ${DateTime.fromMillisecondsSinceEpoch(s.nextDue).day}/${DateTime.fromMillisecondsSinceEpoch(s.nextDue).month}' : '');
    final linked = users.where((u) => u.debtCodes.contains(d.code)).toList();
    for (final u in linked) {
      notify(u.phone, 'تذكير من ${store?.name ?? 'المحل'}: المتبقي عليك ${iqd(s.remaining)}$due');
    }
    if (linked.isNotEmpty) _changedPublic();
    return linked.length;
  }

  // ---------- جهة الزبون ----------
  Debtor? debtorByCode(String code) {
    final c = code.trim().toUpperCase().replaceAll(' ', '');
    final norm = c.length == 8 ? '${c.substring(0, 4)}-${c.substring(4)}' : c;
    for (final d in debtors) {
      if (d.code == norm && d.active) return d;
    }
    return null;
  }

  /// يربط رمز بحساب الزبون. يرجّع سبب المنع أو null
  String? linkDebtCode(String code) {
    final u = me;
    if (u == null) return 'سجّل دخول أول';
    final d = debtorByCode(code);
    if (d == null) return 'الرمز غلط أو انلغى. اطلب رمز جديد من صاحب المحل.';
    if (u.debtCodes.contains(d.code)) return 'هذا الرمز مضاف من قبل';
    u.debtCodes.add(d.code);
    _changedPublic();
    return null;
  }

  void unlinkDebtCode(String code) {
    me?.debtCodes.remove(code);
    _changedPublic();
  }

  List<Debtor> get myDebtAccounts {
    final codes = me?.debtCodes ?? const <String>[];
    return debtors.where((d) => d.active && codes.contains(d.code)).toList();
  }
}

class OrderError implements Exception {
  final String message;
  OrderError(this.message);
  @override
  String toString() => message;
}

// ======================= الحسابات والتسويات الشهرية =======================
// كل الأرقام أعداد صحيحة بالدينار، وكل رقم ينحسب من الطلبات نفسها بكل مرة (ما نخزن مجاميع ممكن تختلف).
// التسوية تنسجل كمبلغ مدفوع؛ والباقي = المستحق − مجموع المدفوع. فإذا تغيّر شي بعد التسوية يبين كباقي أو زيادة، وما يضيع ولا دينار.

/// حالة حساب (محل/مندوب) لشهر
class Balance {
  final int due; // المستحق (موجب = ديبو تدفع، سالب = ديبو تستلم)
  final List<Settlement> payments;
  const Balance(this.due, this.payments);
  int get paid => payments.fold(0, (s, p) => s + p.amount);
  int get remaining => due - paid;
  bool get settled => remaining == 0 && payments.isNotEmpty;
  bool get untouched => payments.isEmpty;
  String get status {
    if (due == 0 && payments.isEmpty) return 'ماكو مستحق';
    if (remaining == 0) return 'مسدّد بالكامل';
    if (payments.isEmpty) return 'بانتظار التسوية';
    if (due > 0) return remaining > 0 ? 'باقي ${iqd(remaining)}' : 'دفعنا زيادة ${iqd(-remaining)}';
    return remaining < 0 ? 'باقي نستلم ${iqd(-remaining)}' : 'استلمنا زيادة ${iqd(remaining)}';
  }
}

/// كشف محل لشهر
class StoreStatement {
  final Store store;
  final String month;
  final List<Order> orders;
  final List<Order> depoOrders; // وصّلها مندوب ديبو (ديبو حصّلت الفلوس)
  final List<Order> storeOrders; // استلام ذاتي أو مندوب المحل (المحل حصّل الفلوس)
  final Balance balance;
  const StoreStatement(this.store, this.month, this.orders, this.depoOrders, this.storeOrders, this.balance);

  int get sales => orders.fold(0, (s, o) => s + o.itemsTotal);
  int get commission => orders.fold(0, (s, o) => s + o.commission);
  int get depoGoods => depoOrders.fold(0, (s, o) => s + o.itemsTotal); // (أ) بضاعة حصّلتها ديبو
  int get depoCommission => depoOrders.fold(0, (s, o) => s + o.commission);
  int get storeCollected => storeOrders.fold(0, (s, o) => s + o.total); // حصّلها المحل (ويه رسم توصيله إن وجد)
  int get storeCommission => storeOrders.fold(0, (s, o) => s + o.commission); // (ب) عمولة على المحل
  /// الصافي: موجب = ديبو تدفع للمحل، سالب = المحل يدفع لديبو
  int get net => depoGoods - commission;
  int get storeEarnings => sales - commission; // اللي يطلع للمحل فعلياً من البضاعة
}

class CourierStatement {
  final String phone;
  final String month;
  final List<Order> orders;
  final Balance balance;
  const CourierStatement(this.phone, this.month, this.orders, this.balance);
  int get earned => orders.fold(0, (s, o) => s + o.courierPay);
  double get km => orders.fold(0.0, (s, o) => s + o.distanceKm);
  int get collected => orders.fold(0, (s, o) => s + o.total);
}

/// ملخص ديبو لشهر + معادلة التوازن
class MonthReport {
  final String month;
  final List<Order> orders;
  final int sales, commission, deliveryFees, storeDeliveryFees, courierPay, freeDeliveryCost;
  final int payToStores, collectFromStores, payToCouriers; // اللي بعده ما مسوّى
  const MonthReport(this.month, this.orders, this.sales, this.commission, this.deliveryFees, this.storeDeliveryFees, this.courierPay, this.freeDeliveryCost,
      this.payToStores, this.collectFromStores, this.payToCouriers);
  int get profit => commission + deliveryFees - courierPay;
  int get customersPaid => orders.fold(0, (s, o) => s + o.total);
  // حصة المحلات = بضاعة − عمولة + رسوم توصيل مندوبهم
  int get storesShare => sales - commission + storeDeliveryFees;
  /// لازم: اللي دفعه الزبائن = حصة المحلات + أجور المندوبين + ربح ديبو
  int get imbalance => customersPaid - (storesShare + courierPay + profit);
}

extension Finance on AppState {
  bool get canFinance => canAny([Perm.finance]);

  List<Order> deliveredIn(String month) =>
      orders.where((o) => o.status == OrderStatus.delivered && o.settleMonth == month && storeById(o.storeId)?.type != StoreType.shop).toList();

  /// الشهور اللي بيها طلبات أو تسويات + الشهر الحالي (الأحدث أول)
  List<String> get financeMonths {
    final set = <String>{monthKey(DateTime.now())};
    for (final o in orders.where((o) => o.status == OrderStatus.delivered)) {
      set.add(o.settleMonth);
    }
    for (final x in settlements.where((x) => x.kind != 'cash')) {
      set.add(x.month);
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  bool isCurrentMonth(String m) => m == monthKey(DateTime.now());

  List<Settlement> paymentsOf(String kind, String target, String month) =>
      settlements.where((s) => s.kind == kind && s.target == target && s.month == month).toList();

  StoreStatement storeStatement(Store s, String month) {
    final list = deliveredIn(month).where((o) => o.storeId == s.id).toList()..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    final depo = list.where(paidCourier).toList();
    final self = list.where((o) => !paidCourier(o)).toList();
    final st = StoreStatement(s, month, list, depo, self, const Balance(0, []));
    return StoreStatement(s, month, list, depo, self, Balance(st.net, paymentsOf('store', s.id, month)));
  }

  List<StoreStatement> storeStatements(String month) {
    final ids = {for (final o in deliveredIn(month)) o.storeId, for (final x in settlements.where((x) => x.kind == 'store' && x.month == month)) x.target};
    final list = [for (final id in ids) if (storeById(id) != null) storeStatement(storeById(id)!, month)];
    list.sort((a, b) => b.balance.remaining.abs().compareTo(a.balance.remaining.abs()));
    return list;
  }

  CourierStatement courierStatement(String phone, String month) {
    final list = deliveredIn(month).where((o) => o.courierPhone == phone && paidCourier(o)).toList()..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));
    return CourierStatement(phone, month, list, Balance(list.fold(0, (s, o) => s + o.courierPay), paymentsOf('courier', phone, month)));
  }

  List<CourierStatement> courierStatements(String month) {
    final phones = {
      for (final o in deliveredIn(month)) if (paidCourier(o)) o.courierPhone!,
      for (final x in settlements.where((x) => x.kind == 'courier' && x.month == month)) x.target,
    };
    return [for (final p in phones) courierStatement(p, month)]..sort((a, b) => b.earned.compareTo(a.earned));
  }

  MonthReport monthReport(String month) {
    final list = deliveredIn(month);
    final paid = list.where(paidCourier);
    final stores = storeStatements(month);
    final couriers = courierStatements(month);
    return MonthReport(
      month,
      list,
      list.fold(0, (s, o) => s + o.itemsTotal),
      list.fold(0, (s, o) => s + o.commission),
      paid.fold(0, (s, o) => s + o.deliveryFee),
      list.where((o) => !paidCourier(o)).fold(0, (s, o) => s + o.deliveryFee),
      paid.fold(0, (s, o) => s + o.courierPay),
      paid.where((o) => o.deliveryFee == 0).fold(0, (s, o) => s + o.courierPay),
      stores.where((x) => x.balance.remaining > 0).fold(0, (s, x) => s + x.balance.remaining),
      stores.where((x) => x.balance.remaining < 0).fold(0, (s, x) => s - x.balance.remaining),
      couriers.where((x) => x.balance.remaining > 0).fold(0, (s, x) => s + x.balance.remaining),
    );
  }

  /// النقد: كل اللي حصّله المندوب − كل اللي سلّمه (من سجل الاستلام)
  int cashCollectedBy(String phone) =>
      orders.where((o) => o.courierPhone == phone && o.status == OrderStatus.delivered && paidCourier(o)).fold(0, (s, o) => s + o.total);
  int cashHandedBy(String phone) => settlements.where((x) => x.kind == 'cash' && x.target == phone).fold(0, (s, x) => s - x.amount);
  List<Settlement> cashRecordsOf(String phone) => settlements.where((x) => x.kind == 'cash' && x.target == phone).toList();

  /// تعديل مسافة طلب (قبل أي تسوية لأجور ذاك الشهر) — الأجرة تنعاد بنفس تسعيرة يوم التسليم
  String? setOrderDistance(Order o, double km) {
    if (!(canFinance || canAny([Perm.operations]))) return 'ما عندك صلاحية';
    if (o.courierPhone != null && paymentsOf('courier', o.courierPhone!, o.settleMonth).isNotEmpty) return 'انسوّت أجور هذا الشهر، ما تنعدل المسافة';
    final cp = CourierPay.of(o.payRule, settings);
    final old = o.courierPay;
    final oldKm = o.distanceKm;
    o.distanceKm = cp.kmOf(km);
    o.kmSource = 'edited';
    o.kmReviewed = true;
    if (!o.kmFlags.contains('edited:${oldKm.toStringAsFixed(1)}')) o.kmFlags.add('edited:${oldKm.toStringAsFixed(1)}');
    if (o.status == OrderStatus.delivered && paidCourier(o)) {
      if (o.payRule.length != 4) o.payRule = cp.rule;
      o.courierPay = cp.pay(o.distanceKm);
    }
    _log('تعديل مسافة الطلب #${o.id} إلى ${o.distanceKm.toStringAsFixed(1)} كم (الأجرة ${iqd(old)} ← ${iqd(o.courierPay)})');
    _changed();
    return null;
  }

  /// صاحب المحل (أو الشراكات/العمليات) يثبّت موقع المحل بالـ GPS وهو بالمحل
  String? setStoreLocation(Store s, GeoFix f) {
    if (!(ownsStore(s.id) || me?.storeId == s.id || canAny([Perm.partnerships, Perm.operations]))) return 'ما عندك صلاحية';
    if (f.mocked) return 'الموقع مزيّف (تطبيق تغيير موقع). طفّيه وجرّب';
    if (f.accuracy > settings.gpsMaxAccuracy) return 'دقة الـ GPS ضعيفة (${f.accuracy.round()} م). اطلع لباب المحل وجرّب';
    final had = s.hasLocation;
    s
      ..lat = f.lat
      ..lng = f.lng;
    _log('${had ? 'تغيير' : 'تثبيت'} موقع ${s.name} بالـ GPS (دقة ${f.accuracy.round()} م)');
    _changed();
    return null;
  }

  /// المندوب استلم من المحل: نسجل موقعه (يفيد إذا المحل بعده ما مثبّت موقعه)
  void courierPickedUp(Order o, GeoFix? f) {
    if (o.courierPhone != currentPhone || o.status != OrderStatus.ready) return;
    if (f != null) {
      o.pickLat = f.lat;
      o.pickLng = f.lng;
      if (f.mocked && !o.kmFlags.contains('mock')) o.kmFlags.add('mock');
      final s = storeById(o.storeId);
      if (s != null && s.hasLocation && Geo.straightKm(s.lat, s.lng, f.lat, f.lng) > 0.5) o.kmFlags.add('pickfar');
    }
    setStatus(o, OrderStatus.onTheWay);
  }

  /// المندوب سلّم: المسافة تنحسب من الـ GPS (المحل ← مكان التسليم) × معامل الطرق.
  /// [manualKm] بس إذا الـ GPS ما اشتغل — وتنعلّم «تحتاج مراجعة».
  void courierDelivered(Order o, GeoFix? drop, {double? manualKm}) {
    if (o.courierPhone != currentPhone || o.status != OrderStatus.onTheWay) return;
    final s = storeById(o.storeId);
    final flags = <String>{...o.kmFlags};
    double? sLat, sLng, eLat, eLng;
    if (s != null && s.hasLocation) {
      sLat = s.lat;
      sLng = s.lng;
    } else if (o.pickLat != 0) {
      sLat = o.pickLat;
      sLng = o.pickLng;
      flags.add('nostore');
    }
    var source = '';
    if (drop != null) {
      o.dropLat = drop.lat;
      o.dropLng = drop.lng;
      if (drop.mocked) flags.add('mock');
      if (drop.accuracy > settings.gpsMaxAccuracy) flags.add('weak');
      if (o.custLat != 0 && Geo.straightKm(o.custLat, o.custLng, drop.lat, drop.lng) > 1) flags.add('far');
      eLat = drop.lat;
      eLng = drop.lng;
      source = 'gps';
    } else if (o.custLat != 0) {
      eLat = o.custLat;
      eLng = o.custLng;
      source = 'customer';
    }
    if (sLat != null && eLat != null) {
      final straight = Geo.straightKm(sLat, sLng!, eLat, eLng!);
      o
        ..startLat = sLat
        ..startLng = sLng
        ..endLat = eLat
        ..endLng = eLng
        ..straightKm = (straight * 100).round() / 100
        ..roadFactor = settings.roadFactor
        ..distanceKm = straight * settings.roadFactor / 100
        ..kmSource = source;
    } else if (manualKm != null) {
      o
        ..distanceKm = manualKm
        ..kmSource = 'manual';
    } else {
      o.kmSource = 'estimate'; // تقدير المحل
    }
    o.kmFlags = flags.toList();
    setStatus(o, OrderStatus.delivered);
  }

  /// المالية/العمليات تأكد إن المسافة صحيحة
  void approveKm(Order o) {
    if (!(canFinance || canAny([Perm.operations]))) return;
    o.kmReviewed = true;
    _log('مراجعة واعتماد مسافة الطلب #${o.id}: ${o.distanceKm.toStringAsFixed(1)} كم = ${iqd(o.courierPay)}');
    _changed();
  }

  /// شرح مصدر المسافة
  String kmSourceText(Order o) {
    final parts = <String>[];
    switch (o.kmSource) {
      case 'gps':
        parts.add('GPS: من ${o.kmFlags.contains('nostore') ? 'مكان الاستلام' : 'موقع المحل'} إلى مكان التسليم');
      case 'customer':
        parts.add('GPS: من ${o.kmFlags.contains('nostore') ? 'مكان الاستلام' : 'موقع المحل'} إلى موقع الزبون (GPS المندوب ما اشتغل)');
      case 'manual':
        parts.add('كتبها المندوب يدوياً (الـ GPS ما اشتغل)');
      case 'estimate':
        parts.add('تقدير المحل (ماكو GPS)');
      case 'edited':
        parts.add('عدّلتها المالية');
      default:
        parts.add('بدون GPS (طلب قديم)');
    }
    if (o.straightKm > 0) parts.add('خط مستقيم ${o.straightKm.toStringAsFixed(2)} كم × ${(o.roadFactor / 100).toStringAsFixed(2)} معامل الطرق');
    for (final f in o.kmFlags) {
      if (f == 'mock') parts.add('⚠️ موقع مزيّف');
      if (f == 'weak') parts.add('⚠️ دقة GPS ضعيفة');
      if (f == 'far') parts.add('⚠️ التسليم أبعد من كيلو عن موقع الزبون');
      if (f == 'pickfar') parts.add('⚠️ الاستلام أبعد من نص كيلو عن المحل');
      if (f.startsWith('edited:')) parts.add('كانت ${f.substring(7)} كم قبل التعديل');
    }
    if (o.kmReviewed) parts.add('✓ مراجَعة');
    return parts.join(' • ');
  }

  String _who() => me == null ? '' : (me!.name.isEmpty ? me!.phone : me!.name);

  /// تسجيل تسوية. amount بنفس إشارة المستحق (موجب: دفعنا، سالب: استلمنا). يرجع رسالة خطأ أو null.
  String? addSettlement({required String kind, required String target, required String month, required int amount, required int remaining, String note = ''}) {
    if (!canFinance) return 'ما عندك صلاحية المالية';
    if (isCurrentMonth(month)) return 'التسوية بعد ما يخلص الشهر';
    if (amount == 0) return 'المبلغ صفر';
    if (remaining == 0) return 'الحساب مسدّد';
    if (amount.sign != remaining.sign) return 'اتجاه المبلغ غلط';
    if (amount.abs() > remaining.abs()) return 'المبلغ أكثر من الباقي (${iqd(remaining.abs())})';
    if (kind == 'courier') {
      final n = courierStatement(target, month).orders.where((o) => o.kmNeedsReview).length;
      if (n > 0) return 'راجع مسافة $n ${n == 1 ? 'توصيلة' : 'توصيلات'} أول (معلّمة «تحتاج مراجعة»)';
    }
    settlements.insert(0, Settlement(id: '${kind}_${DateTime.now().millisecondsSinceEpoch}', kind: kind, target: target, month: month, amount: amount, at: DateTime.now().millisecondsSinceEpoch, by: _who(), note: note.trim()));
    final left = remaining - amount;
    if (kind == 'store') {
      final st = storeById(target);
      if (st != null) {
        notify(st.ownerPhone,
            '${amount > 0 ? 'استلمت من ديبو ${iqd(amount)}' : 'سدّدت لديبو ${iqd(-amount)}'} عن ${monthKey2(month)}${left == 0 ? ' — الحساب صار مسدّد' : ' — الباقي ${iqd(left.abs())}'}');
      }
      _log('تسوية ${st?.name ?? target} لشهر $month: ${amount > 0 ? 'دفعنا' : 'استلمنا'} ${iqd(amount.abs())} • الباقي ${iqd(left.abs())}');
    } else {
      notify(target, 'استلمت أجورك عن ${monthKey2(month)}: ${iqd(amount)}${left == 0 ? '' : ' — الباقي ${iqd(left)}'}');
      _log('تسوية أجور المندوب $target لشهر $month: ${iqd(amount)} • الباقي ${iqd(left)}');
    }
    _changed();
    return null;
  }

  String monthKey2(String m) {
    final p = m.split('/');
    return p.length == 2 ? 'شهر ${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : m;
  }

  /// المدير بس يلغي تسوية (إذا انسجلت بالغلط). استلام النقد يرجّع الطلبات «بيد المندوب».
  void undoSettlement(Settlement s) {
    if (me?.role != Role.admin) return;
    settlements.removeWhere((x) => x.id == s.id);
    if (s.kind == 'cash') {
      for (final o in orders.where((o) => s.orderIds.contains(o.id))) {
        o.cashSettled = false;
      }
    }
    _log('إلغاء تسوية (${s.kind}) ${s.target} لشهر ${s.month}: ${iqd(s.amount.abs())}');
    _changed();
  }

  /// كشوفات حسابي (للمحل أو المندوب)
  List<StoreStatement> myStoreStatements(Store s) =>
      [for (final m in financeMonths) storeStatement(s, m)].where((x) => x.orders.isNotEmpty || x.balance.payments.isNotEmpty || isCurrentMonth(x.month)).toList();
  List<CourierStatement> myCourierStatements() => currentPhone == null
      ? []
      : [for (final m in financeMonths) courierStatement(currentPhone!, m)].where((x) => x.orders.isNotEmpty || x.balance.payments.isNotEmpty || isCurrentMonth(x.month)).toList();

  /// نص الكشف (للنسخ والإرسال)
  String storeStatementText(StoreStatement st) {
    final b = StringBuffer()
      ..writeln('كشف حساب ${st.store.name} — ${st.month}')
      ..writeln('عدد الطلبات: ${st.orders.length} (مندوب ديبو ${st.depoOrders.length}، استلام/مندوب المحل ${st.storeOrders.length})')
      ..writeln('المبيعات: ${iqd(st.sales)}')
      ..writeln('عمولة ديبو: ${iqd(st.commission)}')
      ..writeln('(أ) بضاعة حصّلها مندوب ديبو: ${iqd(st.depoGoods)}')
      ..writeln('(ب) كل العمولة: ${iqd(st.commission)}')
      ..writeln('الصافي (أ − ب): ${st.net >= 0 ? 'ديبو تدفع للمحل' : 'المحل يدفع لديبو'} ${iqd(st.net.abs())}');
    for (final p in st.balance.payments.reversed) {
      b.writeln('تسوية ${dateTimeLabel(p.at)}: ${p.amount > 0 ? 'دفعنا' : 'استلمنا'} ${iqd(p.amount.abs())}');
    }
    b.writeln('الحالة: ${st.balance.status}');
    b.writeln('— التفاصيل —');
    for (final o in st.orders.reversed) {
      b.writeln('#${o.id} ${dateTimeLabel(o.deliveredAt > 0 ? o.deliveredAt : o.createdAt)} • ${paidCourier(o) ? 'مندوب ديبو' : (o.pickup ? 'استلام ذاتي' : 'مندوب المحل')} • بضاعة ${iqd(o.itemsTotal)} • عمولة ${iqd(o.commission)}');
    }
    return b.toString();
  }

  String courierStatementText(CourierStatement st) {
    final b = StringBuffer()
      ..writeln('كشف أجور ${userByPhone(st.phone)?.name ?? st.phone} — ${st.month}')
      ..writeln('التوصيلات: ${st.orders.length} • المسافة: ${st.km.toStringAsFixed(1)} كم')
      ..writeln('الأجور: ${iqd(st.earned)}');
    for (final p in st.balance.payments.reversed) {
      b.writeln('تسوية ${dateTimeLabel(p.at)}: ${iqd(p.amount)}');
    }
    b.writeln('الحالة: ${st.balance.status}');
    b.writeln('— التفاصيل —');
    for (final o in st.orders.reversed) {
      b.writeln('#${o.id} ${dateTimeLabel(o.deliveredAt)} • ${o.distanceKm.toStringAsFixed(1)} كم • ${iqd(o.courierPay)} • ${kmSourceText(o)}');
    }
    return b.toString();
  }
}

String dateTimeLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}/${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
