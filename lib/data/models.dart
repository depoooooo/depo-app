import 'package:flutter/foundation.dart';

/// نوع المحل: مطعم (رواجع) أو تاجر (عروض)
enum StoreType { restaurant, merchant }

/// طريقة الحفظ لمنتجات التجار
enum Storage { normal, chilled, frozen }

class Store {
  final String id;
  final String name;
  final String area; // الحي — يظهر ويه الاسم
  final StoreType type;
  final double rating;
  final int ratingCount;
  final double distanceKm;
  final String eta; // مثلاً 20–40 د
  final int followers;
  final String usuallyPublishes; // «عادةً ينشر الساعة كذا»
  final bool sponsored;

  const Store({
    required this.id,
    required this.name,
    required this.area,
    required this.type,
    required this.rating,
    required this.ratingCount,
    required this.distanceKm,
    required this.eta,
    this.followers = 0,
    this.usuallyPublishes = '',
    this.sponsored = false,
  });

  String get fullName => '$name — $area';
}

class Offer {
  final String id;
  final String storeId;
  final String title;
  final int originalPrice; // دينار
  final int price; // دينار
  final int quantityLeft;
  final bool surpriseBox;
  final String expiresLabel; // «باقي 45 د» أو «ينتهي بعد 4 أيام»
  final String pickupWindow;
  final int orderedThisWeek;
  final Storage storage;
  final String description;

  const Offer({
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
  });

  int get discountPercent =>
      originalPrice == 0 ? 0 : ((1 - price / originalPrice) * 100).round();
}

class CartLine {
  final Offer offer;
  int qty;
  CartLine(this.offer, this.qty);
}

/// السلة — من محل واحد بس (قرار معتمد)
class Cart extends ChangeNotifier {
  String? storeId;
  final List<CartLine> lines = [];

  int get total => lines.fold(0, (s, l) => s + l.offer.price * l.qty);
  int get originalTotal =>
      lines.fold(0, (s, l) => s + l.offer.originalPrice * l.qty);
  int get saved => originalTotal - total;
  int get count => lines.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => lines.isEmpty;

  /// يرجّع false إذا المنتج من محل ثاني والسلة مو فارغة
  bool canAdd(Offer o) => storeId == null || storeId == o.storeId;

  void add(Offer o, {int qty = 1}) {
    if (!canAdd(o)) return;
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

/// سلة واحدة للتطبيق كله (مؤقتاً لحد ما نربط Firebase)
final cart = Cart();

String iqd(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b د.ع';
}
