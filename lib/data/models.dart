import 'package:flutter/foundation.dart';

/// الأدوار — أي حساب يبدي زبون، والمشرف يرفعه
enum Role { customer, restaurant, merchant, courier, supervisor, admin }

const roleNames = {
  Role.customer: 'زبون',
  Role.restaurant: 'مطعم',
  Role.merchant: 'تاجر',
  Role.courier: 'مندوب',
  Role.supervisor: 'مشرف',
  Role.admin: 'مدير عام',
};

/// نوع المحل: مطعم (رواجع) أو تاجر (الماركت)
enum StoreType { restaurant, merchant }

/// طريقة الحفظ لمنتجات التجار
enum Storage { normal, chilled, frozen }

enum OrderStatus { placed, accepted, preparing, ready, onTheWay, delivered, rejected, cancelled }

const orderStatusNames = {
  OrderStatus.placed: 'جديد',
  OrderStatus.accepted: 'المحل قبل',
  OrderStatus.preparing: 'يجهّز',
  OrderStatus.ready: 'جاهز',
  OrderStatus.onTheWay: 'بالطريق',
  OrderStatus.delivered: 'مُسلَّم',
  OrderStatus.rejected: 'مرفوض',
  OrderStatus.cancelled: 'ملغي',
};

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

int _now() => DateTime.now().millisecondsSinceEpoch;

class AppUser {
  String phone;
  String name;
  Role role;
  String? storeId;
  int points;
  bool suspended;
  List<String> addresses;
  List<String> follows; // معرفات المحلات المتابَعة
  List<String> notifications;
  int createdAt;
  String pinHash; // رمز سري للحسابات الخاصة (مطعم/تاجر/مندوب/مشرف/مدير)

  AppUser({
    required this.phone,
    this.name = '',
    this.role = Role.customer,
    this.storeId,
    this.points = 0,
    this.suspended = false,
    List<String>? addresses,
    List<String>? follows,
    List<String>? notifications,
    int? createdAt,
    this.pinHash = '',
  })  : addresses = addresses ?? [],
        follows = follows ?? [],
        notifications = notifications ?? [],
        createdAt = createdAt ?? _now();

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'role': role.name,
        'storeId': storeId,
        'points': points,
        'suspended': suspended,
        'addresses': addresses,
        'follows': follows,
        'notifications': notifications,
        'createdAt': createdAt,
        'pinHash': pinHash,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        phone: j['phone'] as String,
        name: (j['name'] ?? '') as String,
        role: _enum(Role.values, j['role'], Role.customer),
        storeId: j['storeId'] as String?,
        points: (j['points'] ?? 0) as int,
        suspended: (j['suspended'] ?? false) as bool,
        addresses: List<String>.from(j['addresses'] ?? const []),
        follows: List<String>.from(j['follows'] ?? const []),
        notifications: List<String>.from(j['notifications'] ?? const []),
        createdAt: j['createdAt'] as int?,
        pinHash: (j['pinHash'] ?? '') as String,
      );
}

class Store {
  String id;
  String name;
  String area; // الحي — يظهر ويه الاسم
  StoreType type;
  String ownerPhone;
  double rating;
  int ratingCount;
  double distanceKm;
  String eta;
  String usuallyPublishes;
  bool sponsored;
  bool suspended;
  int approvedAt; // بداية الشهر المجاني
  String imageId; // صورة/شعار المحل ('' = ماكو)

  Store({
    required this.id,
    required this.name,
    required this.area,
    required this.type,
    this.ownerPhone = '',
    this.rating = 5.0,
    this.ratingCount = 0,
    this.distanceKm = 2.0,
    this.eta = '20–40 د',
    this.usuallyPublishes = '',
    this.sponsored = false,
    this.suspended = false,
    int? approvedAt,
    this.imageId = '',
  }) : approvedAt = approvedAt ?? _now();

  String get fullName => '$name — $area';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'area': area,
        'type': type.name,
        'ownerPhone': ownerPhone,
        'rating': rating,
        'ratingCount': ratingCount,
        'distanceKm': distanceKm,
        'eta': eta,
        'usuallyPublishes': usuallyPublishes,
        'sponsored': sponsored,
        'suspended': suspended,
        'approvedAt': approvedAt,
        'imageId': imageId,
      };

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as String,
        name: j['name'] as String,
        area: (j['area'] ?? '') as String,
        type: _enum(StoreType.values, j['type'], StoreType.restaurant),
        ownerPhone: (j['ownerPhone'] ?? '') as String,
        rating: ((j['rating'] ?? 5) as num).toDouble(),
        ratingCount: (j['ratingCount'] ?? 0) as int,
        distanceKm: ((j['distanceKm'] ?? 2) as num).toDouble(),
        eta: (j['eta'] ?? '20–40 د') as String,
        usuallyPublishes: (j['usuallyPublishes'] ?? '') as String,
        sponsored: (j['sponsored'] ?? false) as bool,
        suspended: (j['suspended'] ?? false) as bool,
        approvedAt: j['approvedAt'] as int?,
        imageId: (j['imageId'] ?? '') as String,
      );
}

class Offer {
  String id;
  String storeId;
  String title;
  int originalPrice;
  int price;
  int quantityLeft;
  bool surpriseBox;
  String expiresLabel;
  String pickupWindow;
  int orderedThisWeek;
  Storage storage;
  String description;
  bool active;
  bool hidden; // مخفي من المشرف
  int createdAt;
  String imageId; // صورة العرض ('' = ماكو)
  int expiresAt; // وقت انتهاء العرض (0 = بدون)

  Offer({
    required this.id,
    required this.storeId,
    required this.title,
    required this.originalPrice,
    required this.price,
    required this.quantityLeft,
    required this.expiresLabel,
    this.surpriseBox = false,
    this.pickupWindow = '',
    this.orderedThisWeek = 0,
    this.storage = Storage.normal,
    this.description = '',
    this.active = true,
    this.hidden = false,
    int? createdAt,
    this.imageId = '',
    this.expiresAt = 0,
  }) : createdAt = createdAt ?? _now();

  int get discountPercent =>
      originalPrice == 0 ? 0 : ((1 - price / originalPrice) * 100).round();
  bool get expired => expiresAt > 0 && _now() >= expiresAt;
  bool get visible => active && !hidden && quantityLeft > 0 && !expired;

  /// نص الانتهاء: يتحسب من الوقت إذا موجود
  String get expiryText {
    if (expiresAt <= 0) return expiresLabel;
    final left = Duration(milliseconds: expiresAt - _now());
    if (left.isNegative) return 'خلص وقته';
    if (left.inMinutes < 60) return 'باقي ${left.inMinutes + 1} د';
    if (left.inHours < 24) return 'باقي ${left.inHours} ساعة';
    return 'باقي ${left.inDays} يوم';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeId': storeId,
        'title': title,
        'originalPrice': originalPrice,
        'price': price,
        'quantityLeft': quantityLeft,
        'surpriseBox': surpriseBox,
        'expiresLabel': expiresLabel,
        'pickupWindow': pickupWindow,
        'orderedThisWeek': orderedThisWeek,
        'storage': storage.name,
        'description': description,
        'active': active,
        'hidden': hidden,
        'createdAt': createdAt,
        'imageId': imageId,
        'expiresAt': expiresAt,
      };

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as String,
        storeId: j['storeId'] as String,
        title: j['title'] as String,
        originalPrice: j['originalPrice'] as int,
        price: j['price'] as int,
        quantityLeft: j['quantityLeft'] as int,
        expiresLabel: (j['expiresLabel'] ?? '') as String,
        surpriseBox: (j['surpriseBox'] ?? false) as bool,
        pickupWindow: (j['pickupWindow'] ?? '') as String,
        orderedThisWeek: (j['orderedThisWeek'] ?? 0) as int,
        storage: _enum(Storage.values, j['storage'], Storage.normal),
        description: (j['description'] ?? '') as String,
        active: (j['active'] ?? true) as bool,
        hidden: (j['hidden'] ?? false) as bool,
        createdAt: j['createdAt'] as int?,
        imageId: (j['imageId'] ?? '') as String,
        expiresAt: (j['expiresAt'] ?? 0) as int,
      );
}

class OrderLine {
  final String offerId;
  final String title;
  final int price;
  final int originalPrice;
  final int qty;
  const OrderLine({required this.offerId, required this.title, required this.price, required this.originalPrice, required this.qty});

  Map<String, dynamic> toJson() =>
      {'offerId': offerId, 'title': title, 'price': price, 'originalPrice': originalPrice, 'qty': qty};
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        offerId: j['offerId'] as String,
        title: j['title'] as String,
        price: j['price'] as int,
        originalPrice: j['originalPrice'] as int,
        qty: j['qty'] as int,
      );
}

class Order {
  String id;
  String customerPhone;
  String customerName;
  String storeId;
  List<OrderLine> lines;
  int deliveryFee;
  bool pickup; // استلام ذاتي
  String address;
  OrderStatus status;
  String? courierPhone;
  String pickupCode;
  int commission;
  int rating; // 0 = ما مقيّم
  String rejectReason;
  int createdAt;
  bool cashSettled; // المندوب سلّم النقد لـ Depo

  Order({
    required this.id,
    required this.customerPhone,
    required this.customerName,
    required this.storeId,
    required this.lines,
    required this.deliveryFee,
    required this.pickup,
    required this.address,
    required this.pickupCode,
    required this.commission,
    this.status = OrderStatus.placed,
    this.courierPhone,
    this.rating = 0,
    this.rejectReason = '',
    int? createdAt,
    this.cashSettled = false,
  }) : createdAt = createdAt ?? _now();

  int get itemsTotal => lines.fold(0, (s, l) => s + l.price * l.qty);
  int get originalTotal => lines.fold(0, (s, l) => s + l.originalPrice * l.qty);
  int get total => itemsTotal + deliveryFee;
  bool get isOpen => status != OrderStatus.delivered && status != OrderStatus.rejected && status != OrderStatus.cancelled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerPhone': customerPhone,
        'customerName': customerName,
        'storeId': storeId,
        'lines': lines.map((l) => l.toJson()).toList(),
        'deliveryFee': deliveryFee,
        'pickup': pickup,
        'address': address,
        'status': status.name,
        'courierPhone': courierPhone,
        'pickupCode': pickupCode,
        'commission': commission,
        'rating': rating,
        'rejectReason': rejectReason,
        'createdAt': createdAt,
        'cashSettled': cashSettled,
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        customerPhone: j['customerPhone'] as String,
        customerName: (j['customerName'] ?? '') as String,
        storeId: j['storeId'] as String,
        lines: (j['lines'] as List).map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        deliveryFee: (j['deliveryFee'] ?? 0) as int,
        pickup: (j['pickup'] ?? false) as bool,
        address: (j['address'] ?? '') as String,
        status: _enum(OrderStatus.values, j['status'], OrderStatus.placed),
        courierPhone: j['courierPhone'] as String?,
        pickupCode: (j['pickupCode'] ?? '') as String,
        commission: (j['commission'] ?? 0) as int,
        rating: (j['rating'] ?? 0) as int,
        rejectReason: (j['rejectReason'] ?? '') as String,
        createdAt: j['createdAt'] as int?,
        cashSettled: (j['cashSettled'] ?? false) as bool,
      );
}

class JoinRequest {
  String id;
  String phone;
  String name;
  Role type; // restaurant / merchant / courier
  String storeName;
  String area;
  String details;
  String status; // pending / approved / rejected
  String note;
  int createdAt;

  JoinRequest({
    required this.id,
    required this.phone,
    required this.name,
    required this.type,
    required this.storeName,
    required this.area,
    this.details = '',
    this.status = 'pending',
    this.note = '',
    int? createdAt,
  }) : createdAt = createdAt ?? _now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'type': type.name,
        'storeName': storeName,
        'area': area,
        'details': details,
        'status': status,
        'note': note,
        'createdAt': createdAt,
      };

  factory JoinRequest.fromJson(Map<String, dynamic> j) => JoinRequest(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: (j['name'] ?? '') as String,
        type: _enum(Role.values, j['type'], Role.restaurant),
        storeName: (j['storeName'] ?? '') as String,
        area: (j['area'] ?? '') as String,
        details: (j['details'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
        note: (j['note'] ?? '') as String,
        createdAt: j['createdAt'] as int?,
      );
}

class Complaint {
  String id;
  String orderId;
  String phone;
  String type;
  String text;
  bool health; // شكوى صحية = أولوية
  String status; // open / closed
  int createdAt;

  Complaint({
    required this.id,
    required this.orderId,
    required this.phone,
    required this.type,
    required this.text,
    this.health = false,
    this.status = 'open',
    int? createdAt,
  }) : createdAt = createdAt ?? _now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'phone': phone,
        'type': type,
        'text': text,
        'health': health,
        'status': status,
        'createdAt': createdAt,
      };
  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] as String,
        orderId: j['orderId'] as String,
        phone: j['phone'] as String,
        type: (j['type'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        health: (j['health'] ?? false) as bool,
        status: (j['status'] ?? 'open') as String,
        createdAt: j['createdAt'] as int?,
      );
}

/// الإعدادات اللي يضبطها المدير
class AppSettings {
  int restaurantCommission; // %
  int minCommission; // د.ع
  int merchantCommission; // %
  int freeDays;
  int deliveryFee;
  int freeDeliveryThreshold;
  int stage1Km;
  int stage2Km;
  int stage2Minutes;
  int stage3Minutes;
  bool firstOrderFree; // توصيل مجاني لأول طلب
  String promoText; // الشريط الصغير فوق الرئيسية ('' = مطفي)
  String campaignName; // اسم الحملة
  int campaignMinDiscount; // أقل خصم حتى يدخل المطعم بالحملة

  AppSettings({
    this.restaurantCommission = 15,
    this.minCommission = 750,
    this.merchantCommission = 15,
    this.freeDays = 30,
    this.deliveryFee = 2000,
    this.freeDeliveryThreshold = 10000,
    this.stage1Km = 3,
    this.stage2Km = 6,
    this.stage2Minutes = 5,
    this.stage3Minutes = 10,
    this.firstOrderFree = true,
    this.promoText = 'توصيل مجاني لأول طلب',
    this.campaignName = 'رخيييييص',
    this.campaignMinDiscount = 60,
  });

  Map<String, dynamic> toJson() => {
        'restaurantCommission': restaurantCommission,
        'minCommission': minCommission,
        'merchantCommission': merchantCommission,
        'freeDays': freeDays,
        'deliveryFee': deliveryFee,
        'freeDeliveryThreshold': freeDeliveryThreshold,
        'stage1Km': stage1Km,
        'stage2Km': stage2Km,
        'stage2Minutes': stage2Minutes,
        'stage3Minutes': stage3Minutes,
        'firstOrderFree': firstOrderFree,
        'promoText': promoText,
        'campaignName': campaignName,
        'campaignMinDiscount': campaignMinDiscount,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final d = AppSettings();
    int g(String k, int def) => (j[k] ?? def) as int;
    return AppSettings(
      restaurantCommission: g('restaurantCommission', d.restaurantCommission),
      minCommission: g('minCommission', d.minCommission),
      merchantCommission: g('merchantCommission', d.merchantCommission),
      freeDays: g('freeDays', d.freeDays),
      deliveryFee: g('deliveryFee', d.deliveryFee),
      freeDeliveryThreshold: g('freeDeliveryThreshold', d.freeDeliveryThreshold),
      stage1Km: g('stage1Km', d.stage1Km),
      stage2Km: g('stage2Km', d.stage2Km),
      stage2Minutes: g('stage2Minutes', d.stage2Minutes),
      stage3Minutes: g('stage3Minutes', d.stage3Minutes),
      firstOrderFree: (j['firstOrderFree'] ?? d.firstOrderFree) as bool,
      promoText: (j['promoText'] ?? d.promoText) as String,
      campaignName: (j['campaignName'] ?? d.campaignName) as String,
      campaignMinDiscount: g('campaignMinDiscount', d.campaignMinDiscount),
    );
  }
}

class CartLine {
  final Offer offer;
  int qty;
  CartLine(this.offer, this.qty);
}

/// السلة — من محل واحد بس (قرار معتمد). ما تنحفظ.
class Cart extends ChangeNotifier {
  String? storeId;
  final List<CartLine> lines = [];

  int get total => lines.fold(0, (s, l) => s + l.offer.price * l.qty);
  int get originalTotal => lines.fold(0, (s, l) => s + l.offer.originalPrice * l.qty);
  int get saved => originalTotal - total;
  int get count => lines.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => lines.isEmpty;

  bool canAdd(Offer o) => storeId == null || storeId == o.storeId;

  void add(Offer o, {int qty = 1}) {
    if (!canAdd(o) || o.quantityLeft <= 0) return;
    storeId = o.storeId;
    final existing = lines.where((l) => l.offer.id == o.id);
    if (existing.isNotEmpty) {
      final line = existing.first;
      line.qty = (line.qty + qty).clamp(1, o.quantityLeft);
    } else {
      lines.add(CartLine(o, qty.clamp(1, o.quantityLeft)));
    }
    notifyListeners();
  }

  void setQty(CartLine line, int qty) {
    if (qty <= 0) {
      lines.remove(line);
      if (lines.isEmpty) storeId = null;
    } else {
      line.qty = qty.clamp(1, line.offer.quantityLeft);
    }
    notifyListeners();
  }

  void clear() {
    lines.clear();
    storeId = null;
    notifyListeners();
  }
}

final cart = Cart();

String iqd(int v) {
  final neg = v < 0;
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b د.ع';
}

String timeAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'هسه';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
  if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
  return 'قبل ${d.inDays} يوم';
}
