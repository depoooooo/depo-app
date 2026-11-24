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

/// أقسام الشركة — كل مشرف ينطي أقسام وتنفتحله صلاحياتها بس (الإدارة = المدير العام)
enum Perm { operations, support, quality, partnerships, sales, marketing, finance, tech, design }

const permNames = {
  Perm.operations: 'العمليات',
  Perm.support: 'الدعم',
  Perm.quality: 'الجودة وسلامة الأكل',
  Perm.partnerships: 'الشراكات',
  Perm.sales: 'المبيعات',
  Perm.marketing: 'التسويق',
  Perm.finance: 'المالية',
  Perm.tech: 'التقنية',
  Perm.design: 'السوشل ميديا والتصميم',
};

const permDesc = {
  Perm.operations: 'متابعة الطلبات وإلغاؤها، تنسيق المندوبين وطلبات انضمامهم، تسوية نقدهم',
  Perm.support: 'دعم الزبائن والمطاعم والتجار والمندوبين: الشكاوى، متابعة الطلبات، إيقاف حساب مسيء',
  Perm.quality: 'تفتيش المحلات قبل وبعد الانضمام، سحب العروض، إيقاف المحلات، الشكاوى الصحية',
  Perm.partnerships: 'طلبات انضمام المطاعم والتجار: قبول ورفض، ومتابعة المحلات',
  Perm.sales: 'أداء المحلات ومبيعاتها، الإعلانات الممولة (الظهور المميز)',
  Perm.marketing: 'البنرات، التوصيل المجاني لأول طلب، الحملات (مثل خصم فوق الخصم)',
  Perm.finance: 'التقارير والعمولات، استلام النقد من المندوبين',
  Perm.tech: 'الحسابات والأدوار (زبون/مندوب)، إيقاف الحسابات، سجل العمليات',
  Perm.design: 'تصميم التطبيق ومحتواه: البنرات، الأقسام وصورها، جمل البحث، شاشة البداية، أجزاء الرئيسية',
};

/// نوع المحل: مطعم (رواجع) أو تاجر (الماركت)
/// shop = سوق/محل بمتجر مجاني (أسعار عادية + دفتر ديون) — ما يطلع بالرئيسية
enum StoreType { restaurant, merchant, shop }

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
  List<String> perms; // أقسام المشرف
  List<String> debtCodes; // رموز الديون اللي ضافها الزبون
  List<Address> places; // العناوين المفصّلة ويه موقعها على الخريطة
  double locLat, locLng; // آخر موقع (للمندوب المتاح — للمراقبة)
  int locAt;
  bool onDuty; // المندوب مفعّل «متاح للتوصيل»
  // ---- الولاء ----
  Map<String, int> stamps; // أختام كل محل
  Map<String, int> stampAt; // آخر ختم لكل محل (للانتهاء)
  List<Coupon> coupons; // قسائم الخصم (من كروت الخدش)
  int scratchPending; // كروت خدش ما انخدشت بعد

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
    List<String>? perms,
    List<String>? debtCodes,
    List<Address>? places,
    this.locLat = 0,
    this.locLng = 0,
    this.locAt = 0,
    this.onDuty = false,
    Map<String, int>? stamps,
    Map<String, int>? stampAt,
    List<Coupon>? coupons,
    this.scratchPending = 0,
  })  : stamps = stamps ?? {},
        stampAt = stampAt ?? {},
        coupons = coupons ?? [],
        places = places ?? [],
        perms = perms ?? [],
        debtCodes = debtCodes ?? [],
        addresses = addresses ?? [],
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
        'perms': perms,
        'debtCodes': debtCodes,
        'places': places.map((e) => e.toJson()).toList(),
        'locLat': locLat,
        'locLng': locLng,
        'locAt': locAt,
        'onDuty': onDuty,
        'stamps': stamps,
        'stampAt': stampAt,
        'coupons': coupons.map((e) => e.toJson()).toList(),
        'scratchPending': scratchPending,
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
        perms: List<String>.from(j['perms'] ?? const []),
        debtCodes: List<String>.from(j['debtCodes'] ?? const []),
        locLat: _d(j['locLat']),
        locLng: _d(j['locLng']),
        locAt: (j['locAt'] ?? 0) as int,
        onDuty: (j['onDuty'] ?? false) as bool,
        stamps: {for (final e in ((j['stamps'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
        stampAt: {for (final e in ((j['stampAt'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
        coupons: [for (final e in (j['coupons'] as List?) ?? const []) Coupon.fromJson(Map<String, dynamic>.from(e as Map))],
        scratchPending: (j['scratchPending'] ?? 0) as int,
        places: (j['places'] as List?) != null
            ? [for (final e in j['places'] as List) Address.fromJson(Map<String, dynamic>.from(e as Map))]
            // العناوين القديمة (نص بس) تتحول عناوين بدون خريطة
            : [for (final (k, a) in List<String>.from(j['addresses'] ?? const []).indexed) Address(id: 'old$k', name: 'عنوان', details: a)],
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
  String cuisine; // نوع المطعم (مشاوي، بيتزا...) — للأقسام
  String phone; // هاتف المحل (المتجر المجاني)
  String mapLink; // رابط الموقع على الخريطة
  bool listed; // يظهر بالأسواق للجميع
  String promoImageId; // بنر العرض الخاص بصفحة المحل
  String promoText;
  double lat, lng; // موقع المحل (0 = ما محدد)

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
    this.cuisine = '',
    this.phone = '',
    this.mapLink = '',
    this.listed = true,
    this.promoImageId = '',
    this.promoText = '',
    this.lat = 0,
    this.lng = 0,
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
        'cuisine': cuisine,
        'phone': phone,
        'mapLink': mapLink,
        'listed': listed,
        'promoImageId': promoImageId,
        'promoText': promoText,
        'lat': lat,
        'lng': lng,
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
        cuisine: (j['cuisine'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        mapLink: (j['mapLink'] ?? '') as String,
        listed: (j['listed'] ?? true) as bool,
        promoImageId: (j['promoImageId'] ?? '') as String,
        promoText: (j['promoText'] ?? '') as String,
        lat: ((j['lat'] ?? 0) as num).toDouble(),
        lng: ((j['lng'] ?? 0) as num).toDouble(),
      );
  bool get hasLocation => lat != 0 && lng != 0;
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
  String category; // صنف المنتج بالماركت (زيوت، سناكات...)

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
    this.category = '',
  }) : createdAt = createdAt ?? _now();

  int get discountPercent =>
      originalPrice == 0 ? 0 : ((1 - price / originalPrice) * 100).round();

  /// نسبة الزيادة على سعر المحل (يحددها المدير، ولا تظهر للمحل). AppState يربطها بالإعدادات
  static int Function(Offer o) markupPct = (_) => 0;
  static int _withMarkup(int p, int m) => m <= 0 || p <= 0 ? p : ((p * (100 + m) / 100) / 250).ceil() * 250;

  /// السعر اللي يشوفه ويدفعه الزبون
  int get shownPrice => _withMarkup(price, markupPct(this));
  /// السعر الأصلي (قبل الخصم) للزبون — بنفس النسبة حتى تبقى نسبة الخصم نفسها
  int get shownOriginal => originalPrice <= price ? shownPrice : _withMarkup(originalPrice, markupPct(this));
  bool get expired => expiresAt > 0 && _now() >= expiresAt;
  bool get unlimited => quantityLeft >= 9000; // منتجات المتجر المجاني (بدون كمية محددة)
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
        'category': category,
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
        category: (j['category'] ?? '') as String,
      );
}

class OrderLine {
  final String offerId;
  final String title;
  final int price; // سعر الزبون (ويه الزيادة)
  final int originalPrice;
  final int qty;
  final int basePrice; // سعر المحل (اللي كتبه هو) — 0 بالطلبات القديمة = نفس سعر الزبون
  const OrderLine({required this.offerId, required this.title, required this.price, required this.originalPrice, required this.qty, this.basePrice = 0});

  int get storePrice => basePrice > 0 ? basePrice : price;

  Map<String, dynamic> toJson() =>
      {'offerId': offerId, 'title': title, 'price': price, 'originalPrice': originalPrice, 'qty': qty, 'basePrice': basePrice};
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        offerId: j['offerId'] as String,
        title: j['title'] as String,
        price: j['price'] as int,
        originalPrice: j['originalPrice'] as int,
        qty: j['qty'] as int,
        basePrice: (j['basePrice'] ?? 0) as int,
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
  double distanceKm; // مسافة التوصيل (لأجرة المندوب)
  int courierPay; // أجرة المندوب (تنحسب عند التسليم)
  int deliveredAt; // وقت التسليم (للتسوية الشهرية)
  String commissionRule; // كيف انحسبت العمولة (15% / الحد الأدنى / الشهر المجاني)
  List<int> payRule; // تسعيرة المندوب وقت التسليم: [ثابت، لكل كم، حد أدنى، أقصى كم]
  // ---- المسافة بالـ GPS ----
  double custLat, custLng; // موقع الزبون اللي أرسله وقت الطلب
  double pickLat, pickLng; // موقع المندوب لما استلم من المحل
  double dropLat, dropLng; // موقع المندوب لما سلّم للزبون
  double startLat, startLng; // نقطة البداية اللي انحسبت منها المسافة
  double endLat, endLng; // نقطة النهاية
  double straightKm; // خط مستقيم
  int roadFactor; // معامل الطرق % وقت التسليم
  String kmSource; // gps / customer / manual / estimate / edited
  List<String> kmFlags; // mock / weak / far / nostore ...
  bool kmReviewed; // المالية راجعت المسافة
  int courierRating; // تقييم الزبون للمندوب (0 = ما مقيّم)
  double courierLat, courierLng; // آخر موقع للمندوب وهو بالطريق (للتتبّع)
  int courierLocAt;
  int peakBonus; // مكافأة وقت الذروة (ضمن أجرة المندوب)
  bool walletMode; // المندوب دافع رصيد مقدّماً: مبلغ الطلب ينخصم من رصيده عند التسليم
  int loyaltyDiscount; // هدية بطاقة الولاء (ديبو تتحملها)
  int couponDiscount; // قسيمة كرت الخدش (ديبو تتحملها)
  String couponId;

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
    this.distanceKm = 0,
    this.courierPay = 0,
    this.deliveredAt = 0,
    this.commissionRule = '',
    List<int>? payRule,
    this.custLat = 0,
    this.custLng = 0,
    this.pickLat = 0,
    this.pickLng = 0,
    this.dropLat = 0,
    this.dropLng = 0,
    this.startLat = 0,
    this.startLng = 0,
    this.endLat = 0,
    this.endLng = 0,
    this.straightKm = 0,
    this.roadFactor = 0,
    this.kmSource = '',
    List<String>? kmFlags,
    this.kmReviewed = false,
    this.courierRating = 0,
    this.courierLat = 0,
    this.courierLng = 0,
    this.courierLocAt = 0,
    this.peakBonus = 0,
    this.walletMode = false,
    this.loyaltyDiscount = 0,
    this.couponDiscount = 0,
    this.couponId = '',
  })  : payRule = payRule ?? const [],
        kmFlags = kmFlags ?? [],
        createdAt = createdAt ?? _now();

  /// شهر التسوية (حسب وقت التسليم)
  String get settleMonth => monthKey(DateTime.fromMillisecondsSinceEpoch(deliveredAt > 0 ? deliveredAt : createdAt));

  int get itemsTotal => lines.fold(0, (s, l) => s + l.price * l.qty); // اللي يدفعه الزبون
  int get itemsBase => lines.fold(0, (s, l) => s + l.storePrice * l.qty); // حق المحل (سعره هو)
  int get markup => itemsTotal - itemsBase; // زيادة ديبو
  int get originalTotal => lines.fold(0, (s, l) => s + l.originalPrice * l.qty);
  int get discounts => loyaltyDiscount + couponDiscount; // هدايا ديبو
  int get total => itemsTotal + deliveryFee - discounts; // اللي يدفعه الزبون
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
        'distanceKm': distanceKm,
        'courierPay': courierPay,
        'deliveredAt': deliveredAt,
        'commissionRule': commissionRule,
        'payRule': payRule,
        'custLat': custLat,
        'custLng': custLng,
        'pickLat': pickLat,
        'pickLng': pickLng,
        'dropLat': dropLat,
        'dropLng': dropLng,
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        'straightKm': straightKm,
        'roadFactor': roadFactor,
        'kmSource': kmSource,
        'kmFlags': kmFlags,
        'kmReviewed': kmReviewed,
        'courierRating': courierRating,
        'courierLat': courierLat,
        'courierLng': courierLng,
        'courierLocAt': courierLocAt,
        'peakBonus': peakBonus,
        'walletMode': walletMode,
        'loyaltyDiscount': loyaltyDiscount,
        'couponDiscount': couponDiscount,
        'couponId': couponId,
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
        distanceKm: ((j['distanceKm'] ?? 0) as num).toDouble(),
        courierPay: (j['courierPay'] ?? 0) as int,
        deliveredAt: (j['deliveredAt'] ?? 0) as int,
        commissionRule: (j['commissionRule'] ?? '') as String,
        payRule: [for (final x in (j['payRule'] as List? ?? const [])) (x as num).toInt()],
        custLat: _d(j['custLat']),
        custLng: _d(j['custLng']),
        pickLat: _d(j['pickLat']),
        pickLng: _d(j['pickLng']),
        dropLat: _d(j['dropLat']),
        dropLng: _d(j['dropLng']),
        startLat: _d(j['startLat']),
        startLng: _d(j['startLng']),
        endLat: _d(j['endLat']),
        endLng: _d(j['endLng']),
        straightKm: _d(j['straightKm']),
        roadFactor: (j['roadFactor'] ?? 0) as int,
        kmSource: (j['kmSource'] ?? '') as String,
        kmFlags: List<String>.from(j['kmFlags'] ?? const []),
        kmReviewed: (j['kmReviewed'] ?? false) as bool,
        courierRating: (j['courierRating'] ?? 0) as int,
        courierLat: _d(j['courierLat']),
        courierLng: _d(j['courierLng']),
        courierLocAt: (j['courierLocAt'] ?? 0) as int,
        peakBonus: (j['peakBonus'] ?? 0) as int,
        walletMode: (j['walletMode'] ?? false) as bool,
        loyaltyDiscount: (j['loyaltyDiscount'] ?? 0) as int,
        couponDiscount: (j['couponDiscount'] ?? 0) as int,
        couponId: (j['couponId'] ?? '') as String,
      );

  /// المسافة تحتاج مراجعة قبل تسوية أجور المندوب
  bool get kmNeedsReview => !kmReviewed && (kmSource == 'manual' || kmSource == 'estimate' || kmFlags.contains('mock') || kmFlags.contains('weak'));
}

/// تسوية شهرية مسجّلة (محل أو مندوب)
class Settlement {
  final String id;
  final String kind; // store / courier
  final String target; // storeId أو رقم المندوب
  final String month; // YYYY/MM
  final int amount; // موجب = ديبو دفعت، سالب = ديبو استلمت
  final int at;
  final String by;
  final String note;
  final List<String> orderIds; // للنقد: الطلبات اللي انستلم نقدها
  const Settlement({required this.id, required this.kind, required this.target, required this.month, required this.amount, required this.at, required this.by, this.note = '', this.orderIds = const []});

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'target': target, 'month': month, 'amount': amount, 'at': at, 'by': by, 'note': note, 'orderIds': orderIds};
  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        id: j['id'] as String,
        kind: j['kind'] as String,
        target: j['target'] as String,
        month: j['month'] as String,
        amount: (j['amount'] ?? 0) as int,
        at: (j['at'] ?? 0) as int,
        by: (j['by'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        orderIds: List<String>.from(j['orderIds'] ?? const []),
      );
}

/// حساب أجرة المندوب بالتفصيل (نفس الحساب بكل مكان حتى ما يصير فرق ولا دينار)
class CourierPay {
  final int base, perKm, minPay, maxKm, maxPay; // maxPay = 0 يعني بدون سقف (طلبات قديمة)
  const CourierPay(this.base, this.perKm, this.minPay, this.maxKm, [this.maxPay = 0]);
  factory CourierPay.of(List<int> r, AppSettings s) => r.length >= 5
      ? CourierPay(r[0], r[1], r[2], r[3], r[4])
      : r.length == 4
          ? CourierPay(r[0], r[1], r[2], r[3])
          : CourierPay(s.courierBasePay, s.courierPerKm, s.courierMinPay, s.courierMaxKm, s.courierMaxPay);
  List<int> get rule => [base, perKm, minPay, maxKm, maxPay];

  /// المسافة تنحسب لأقرب 0.1 كم وما تعبر الحد الأقصى
  double kmOf(double km) => (km.clamp(0, maxKm.toDouble()) * 10).round() / 10;
  int raw(double km) => base + (perKm * kmOf(km)).round();
  int rounded(double km) => (raw(km) / 250).round() * 250;
  int pay(double km) {
    final p = rounded(km) < minPay ? minPay : rounded(km);
    return maxPay > 0 && p > maxPay ? maxPay : p;
  }

  /// شرح الحساب بالأرقام
  String explain(double km) {
    final k = kmOf(km);
    final r = raw(km);
    final b = StringBuffer('${iqd(base)} + ${iqd(perKm)} × ${k.toStringAsFixed(1)} كم = ${iqd(r)}');
    if (rounded(km) != r) b.write(' ← تقريب لأقرب 250 = ${iqd(rounded(km))}');
    if (rounded(km) < minPay) b.write(' ← أقل من الحد الأدنى، فتصير ${iqd(minPay)}');
    if (maxPay > 0 && rounded(km) > maxPay) b.write(' ← أعلى من السقف، فتصير ${iqd(maxPay)}');
    if (km > maxKm) b.write(' (المسافة انحسبت $maxKm كم = الحد الأقصى)');
    return b.toString();
  }
}

double _d(Object? v) => ((v ?? 0) as num).toDouble();

/// عنوان توصيل مفصّل
class Address {
  String id;
  String name; // البيت، الشغل...
  String details; // تفاصيل العنوان (الحي والمنطقة)
  String phone;
  String street, building, floor, apt, landmark;
  double lat, lng; // 0 = بدون خريطة (عنوان قديم)

  Address({
    required this.id,
    this.name = '',
    this.details = '',
    this.phone = '',
    this.street = '',
    this.building = '',
    this.floor = '',
    this.apt = '',
    this.landmark = '',
    this.lat = 0,
    this.lng = 0,
  });

  bool get hasMap => lat != 0 && lng != 0;

  /// نص العنوان كامل (ينكتب بالطلب للمندوب والمحل)
  String get full {
    final b = <String>[
      if (details.isNotEmpty) details,
      if (street.isNotEmpty) 'شارع $street',
      if (building.isNotEmpty) 'بناية $building',
      if (floor.isNotEmpty) 'طابق $floor',
      if (apt.isNotEmpty) 'شقة $apt',
      if (landmark.isNotEmpty) 'قرب $landmark',
    ];
    return '${name.isEmpty ? '' : '$name: '}${b.join('، ')}${phone.isEmpty ? '' : ' • هاتف $phone'}';
  }

  String get short => [details, if (landmark.isNotEmpty) 'قرب $landmark'].where((e) => e.isNotEmpty).join(' — ');

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'details': details, 'phone': phone, 'street': street, 'building': building,
        'floor': floor, 'apt': apt, 'landmark': landmark, 'lat': lat, 'lng': lng,
      };
  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        details: (j['details'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        street: (j['street'] ?? '') as String,
        building: (j['building'] ?? '') as String,
        floor: (j['floor'] ?? '') as String,
        apt: (j['apt'] ?? '') as String,
        landmark: (j['landmark'] ?? '') as String,
        lat: _d(j['lat']),
        lng: _d(j['lng']),
      );
  Address copy() => Address.fromJson(toJson());
}

/// قسيمة خصم (من كرت الخدش)
class Coupon {
  final String id;
  final int amount;
  final int minOrder;
  final int expiresAt;
  const Coupon({required this.id, required this.amount, required this.minOrder, required this.expiresAt});
  bool get valid => DateTime.now().millisecondsSinceEpoch < expiresAt;
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'minOrder': minOrder, 'expiresAt': expiresAt};
  factory Coupon.fromJson(Map<String, dynamic> j) =>
      Coupon(id: (j['id'] ?? '') as String, amount: (j['amount'] ?? 0) as int, minOrder: (j['minOrder'] ?? 0) as int, expiresAt: (j['expiresAt'] ?? 0) as int);
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
  Map<String, String> docs; // اسم الورقة -> رقم الصورة
  String cuisine; // نوع المطعم المختار

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
    Map<String, String>? docs,
    this.cuisine = '',
  })  : createdAt = createdAt ?? _now(),
        docs = docs ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'docs': docs,
        'cuisine': cuisine,
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
        docs: Map<String, String>.from((j['docs'] ?? const {}) as Map),
        cuisine: (j['cuisine'] ?? '') as String,
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
  int courierBasePay; // أجرة المندوب: مبلغ ثابت لكل طلب
  int courierPerKm; // + لكل كيلومتر
  int courierMinPay; // الحد الأدنى للأجرة
  int courierMaxKm; // أقصى مسافة تنحسب (حماية من الأخطاء)
  int courierCashCap; // سقف النقد بيد المندوب
  int roadFactor; // معامل الطرق %: الطريق الفعلي أطول من الخط المستقيم
  int gpsMaxAccuracy; // أسوأ دقة GPS مقبولة (متر)
  int peakBonus; // مكافأة المندوب بوقت الذروة (د.ع لكل توصيلة)
  String peakHours; // ساعات الذروة، مثل: 12-15,19-23
  int courierMaxPay; // أعلى أجرة للتوصيلة
  int walletMinTopup; // أقل مبلغ لشحن رصيد المندوب
  int walletLowAlert; // تنبيه المندوب إذا رصيده نزل تحت هذا
  String paymentMethods; // طرق شحن الرصيد، مفصولة بفاصلة
  int restaurantMarkup; // نسبة زيادة على أسعار المطاعم (مخفية)
  int merchantMarkup; // نسبة زيادة على أسعار التجار (مخفية)
  bool allowPickup; // «استلام بنفسي»
  bool allowStoreDelivery; // التوصيل بمندوب المحل
  // ---- الولاء (ديبو تتحمل الهدايا) ----
  bool loyaltyOn;
  int stampsNeeded; // كم طلب من نفس المحل حتى الهدية
  int stampReward; // نسبة خصم الهدية %
  int stampRewardCap; // أعلى خصم للهدية
  int stampExpiryDays; // الأختام تنتهي إذا ما طلب خلال
  bool scratchOn; // كرت خدش بعد كل طلب
  String scratchPrizes; // جوائز الخدش: مبلغ:وزن
  int scratchMinOrder; // أقل طلب حتى تنفع القسيمة
  int couponDays; // صلاحية القسيمة

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
    this.campaignName = 'خصم فوق الخصم',
    this.campaignMinDiscount = 60,
    this.courierBasePay = 750,
    this.courierPerKm = 350,
    this.courierMinPay = 1500,
    this.courierMaxKm = 30,
    this.courierCashCap = 100000,
    this.roadFactor = 130,
    this.gpsMaxAccuracy = 150,
    this.peakBonus = 500,
    this.peakHours = '12-15,19-23',
    this.courierMaxPay = 6000,
    this.walletMinTopup = 100000,
    this.walletLowAlert = 20000,
    this.paymentMethods = 'زين كاش,FIB,كي كارد,كاش بالمكتب',
    this.restaurantMarkup = 0,
    this.merchantMarkup = 0,
    this.allowPickup = false,
    this.allowStoreDelivery = false,
    this.loyaltyOn = true,
    this.stampsNeeded = 5,
    this.stampReward = 20,
    this.stampRewardCap = 5000,
    this.stampExpiryDays = 30,
    this.scratchOn = true,
    this.scratchPrizes = '250:45,500:30,1000:17,2000:6,5000:2',
    this.scratchMinOrder = 5000,
    this.couponDays = 7,
  });

  /// هل الساعة [h] ضمن الذروة؟
  bool isPeak(DateTime t) {
    for (final part in peakHours.split(',')) {
      final p = part.trim().split('-');
      if (p.length != 2) continue;
      final a = int.tryParse(p[0].trim()), b = int.tryParse(p[1].trim());
      if (a == null || b == null) continue;
      final h = t.hour;
      if (a <= b ? (h >= a && h < b) : (h >= a || h < b)) return true;
    }
    return false;
  }

  /// أجرة المندوب حسب المسافة: ثابت + لكل كم، وما تنزل عن الحد الأدنى (مقرّبة لـ 250)
  int courierPayFor(double km) => CourierPay(courierBasePay, courierPerKm, courierMinPay, courierMaxKm, courierMaxPay).pay(km);

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
        'courierBasePay': courierBasePay,
        'courierPerKm': courierPerKm,
        'courierMinPay': courierMinPay,
        'courierMaxKm': courierMaxKm,
        'courierCashCap': courierCashCap,
        'roadFactor': roadFactor,
        'gpsMaxAccuracy': gpsMaxAccuracy,
        'peakBonus': peakBonus,
        'peakHours': peakHours,
        'courierMaxPay': courierMaxPay,
        'walletMinTopup': walletMinTopup,
        'walletLowAlert': walletLowAlert,
        'paymentMethods': paymentMethods,
        'restaurantMarkup': restaurantMarkup,
        'merchantMarkup': merchantMarkup,
        'allowPickup': allowPickup,
        'allowStoreDelivery': allowStoreDelivery,
        'loyaltyOn': loyaltyOn,
        'stampsNeeded': stampsNeeded,
        'stampReward': stampReward,
        'stampRewardCap': stampRewardCap,
        'stampExpiryDays': stampExpiryDays,
        'scratchOn': scratchOn,
        'scratchPrizes': scratchPrizes,
        'scratchMinOrder': scratchMinOrder,
        'couponDays': couponDays,
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
      campaignName: ((j['campaignName'] ?? d.campaignName) as String) == 'رخيييييص' ? d.campaignName : (j['campaignName'] ?? d.campaignName) as String,
      campaignMinDiscount: g('campaignMinDiscount', d.campaignMinDiscount),
      // التسعيرة الجديدة (1,500 إلى 6,000): إذا الإعدادات المحفوظة قبلها، ناخذ الافتراضي الجديد
      courierBasePay: j.containsKey('courierMaxPay') ? g('courierBasePay', d.courierBasePay) : d.courierBasePay,
      courierPerKm: j.containsKey('courierMaxPay') ? g('courierPerKm', d.courierPerKm) : d.courierPerKm,
      courierMinPay: j.containsKey('courierMaxPay') ? g('courierMinPay', d.courierMinPay) : d.courierMinPay,
      courierMaxKm: g('courierMaxKm', d.courierMaxKm),
      courierCashCap: g('courierCashCap', d.courierCashCap),
      roadFactor: g('roadFactor', d.roadFactor),
      gpsMaxAccuracy: g('gpsMaxAccuracy', d.gpsMaxAccuracy),
      peakBonus: g('peakBonus', d.peakBonus),
      peakHours: (j['peakHours'] ?? d.peakHours) as String,
      courierMaxPay: g('courierMaxPay', d.courierMaxPay),
      walletMinTopup: g('walletMinTopup', d.walletMinTopup),
      walletLowAlert: g('walletLowAlert', d.walletLowAlert),
      paymentMethods: (j['paymentMethods'] ?? d.paymentMethods) as String,
      restaurantMarkup: g('restaurantMarkup', d.restaurantMarkup),
      merchantMarkup: g('merchantMarkup', d.merchantMarkup),
      allowPickup: (j['allowPickup'] ?? d.allowPickup) as bool,
      allowStoreDelivery: (j['allowStoreDelivery'] ?? d.allowStoreDelivery) as bool,
      loyaltyOn: (j['loyaltyOn'] ?? d.loyaltyOn) as bool,
      stampsNeeded: g('stampsNeeded', d.stampsNeeded),
      stampReward: g('stampReward', d.stampReward),
      stampRewardCap: g('stampRewardCap', d.stampRewardCap),
      stampExpiryDays: g('stampExpiryDays', d.stampExpiryDays),
      scratchOn: (j['scratchOn'] ?? d.scratchOn) as bool,
      scratchPrizes: (j['scratchPrizes'] ?? d.scratchPrizes) as String,
      scratchMinOrder: g('scratchMinOrder', d.scratchMinOrder),
      couponDays: g('couponDays', d.couponDays),
    );
  }
}

class CartLine {
  Offer offer;
  int qty;
  CartLine(this.offer, this.qty);
}

/// السلة — من محل واحد بس (قرار معتمد). ما تنحفظ.
class Cart extends ChangeNotifier {
  String? storeId;
  final List<CartLine> lines = [];

  int get total => lines.fold(0, (s, l) => s + l.offer.shownPrice * l.qty);
  int get originalTotal => lines.fold(0, (s, l) => s + l.offer.shownOriginal * l.qty);
  int get saved => originalTotal - total;
  int get count => lines.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => lines.isEmpty;

  /// يحدّث العروض بالسلة لآخر نسخة (السعر). يرجّع أسماء اللي تغيّر سعرها
  List<String> refresh(Offer? Function(String id) find) {
    final changed = <String>[];
    for (final l in lines) {
      final f = find(l.offer.id);
      if (f == null || identical(f, l.offer)) continue;
      if (f.shownPrice != l.offer.shownPrice) changed.add(f.title);
      l.offer = f;
    }
    if (changed.isNotEmpty) notifyListeners();
    return changed;
  }

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


// ======================= دفتر الديون =======================

/// زبون بدفتر ديون محل
class Debtor {
  String id;
  String storeId;
  String name;
  String phone;
  String code; // XXXX-XXXX — الزبون يكتبه حتى يشوف ديونه
  bool active;
  int createdAt;

  Debtor({required this.id, required this.storeId, required this.name, this.phone = '', required this.code, this.active = true, int? createdAt})
      : createdAt = createdAt ?? _now();

  Map<String, dynamic> toJson() =>
      {'id': id, 'storeId': storeId, 'name': name, 'phone': phone, 'code': code, 'active': active, 'createdAt': createdAt};

  factory Debtor.fromJson(Map<String, dynamic> j) => Debtor(
        id: j['id'] as String,
        storeId: j['storeId'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        active: (j['active'] ?? true) as bool,
        createdAt: j['createdAt'] as int?,
      );
}

class DebtItem {
  String name;
  int price;
  int qty;
  DebtItem({required this.name, required this.price, this.qty = 1});
  int get total => price * qty;
  Map<String, dynamic> toJson() => {'name': name, 'price': price, 'qty': qty};
  factory DebtItem.fromJson(Map<String, dynamic> j) =>
      DebtItem(name: (j['name'] ?? '') as String, price: (j['price'] ?? 0) as int, qty: (j['qty'] ?? 1) as int);
}

/// حركة بالدفتر: طلب (دين) أو دفعة (تسديد). ما تنمسح — تنلغى بس.
class DebtEntry {
  String id;
  String debtorId;
  String storeId;
  bool payment; // false = طلب، true = دفعة
  List<DebtItem> items; // للطلب
  int amount; // مبلغ الطلب (مجموع الأصناف) أو الدفعة
  String month; // شهر الدين YYYY/MM — كل شهر بلون
  int dueAt; // موعد التسديد (0 = بدون)
  String note;
  bool voided; // ملغية (تبقى ظاهرة بشطب)
  int createdAt;

  DebtEntry({
    required this.id,
    required this.debtorId,
    required this.storeId,
    required this.payment,
    List<DebtItem>? items,
    required this.amount,
    required this.month,
    this.dueAt = 0,
    this.note = '',
    this.voided = false,
    int? createdAt,
  })  : items = items ?? [],
        createdAt = createdAt ?? _now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'debtorId': debtorId,
        'storeId': storeId,
        'payment': payment,
        'items': items.map((e) => e.toJson()).toList(),
        'amount': amount,
        'month': month,
        'dueAt': dueAt,
        'note': note,
        'voided': voided,
        'createdAt': createdAt,
      };

  factory DebtEntry.fromJson(Map<String, dynamic> j) => DebtEntry(
        id: j['id'] as String,
        debtorId: j['debtorId'] as String,
        storeId: j['storeId'] as String,
        payment: (j['payment'] ?? false) as bool,
        items: (j['items'] as List? ?? const []).map((e) => DebtItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        amount: (j['amount'] ?? 0) as int,
        month: (j['month'] ?? '') as String,
        dueAt: (j['dueAt'] ?? 0) as int,
        note: (j['note'] ?? '') as String,
        voided: (j['voided'] ?? false) as bool,
        createdAt: j['createdAt'] as int?,
      );
}

String monthKey(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}';

// ======================= المحادثات داخل التطبيق =======================
class ChatMsg {
  final String from; // رقم المرسل
  final String text;
  final bool staff; // من فريق الدعم أو صاحب المحل
  final int at;
  ChatMsg({required this.from, required this.text, required this.staff, int? at}) : at = at ?? _now();
  Map<String, dynamic> toJson() => {'from': from, 'text': text, 'staff': staff, 'at': at};
  factory ChatMsg.fromJson(Map<String, dynamic> j) =>
      ChatMsg(from: (j['from'] ?? '') as String, text: (j['text'] ?? '') as String, staff: (j['staff'] ?? false) as bool, at: j['at'] as int?);
}

/// محادثة: دعم ديبو (support) أو ويه محل (shop)
class Chat {
  String id;
  String kind; // support / shop
  String userPhone;
  String userName;
  String storeId; // للمحل بس
  List<ChatMsg> messages;
  bool open;
  int updatedAt;
  int userReadAt;
  int staffReadAt;

  Chat({
    required this.id,
    required this.kind,
    required this.userPhone,
    this.userName = '',
    this.storeId = '',
    List<ChatMsg>? messages,
    this.open = true,
    int? updatedAt,
    this.userReadAt = 0,
    this.staffReadAt = 0,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? _now();

  int unreadFor({required bool staff}) {
    final read = staff ? staffReadAt : userReadAt;
    return messages.where((m) => m.staff != staff && m.at > read).length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'userPhone': userPhone,
        'userName': userName,
        'storeId': storeId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'open': open,
        'updatedAt': updatedAt,
        'userReadAt': userReadAt,
        'staffReadAt': staffReadAt,
      };

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'support') as String,
        userPhone: (j['userPhone'] ?? '') as String,
        userName: (j['userName'] ?? '') as String,
        storeId: (j['storeId'] ?? '') as String,
        messages: (j['messages'] as List? ?? const []).map((e) => ChatMsg.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        open: (j['open'] ?? true) as bool,
        updatedAt: j['updatedAt'] as int?,
        userReadAt: (j['userReadAt'] ?? 0) as int,
        staffReadAt: (j['staffReadAt'] ?? 0) as int,
      );
}
