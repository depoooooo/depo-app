import 'models.dart';

/// بيانات تجريبية للعرض بس — تنشال لما نربط Firebase
const stores = <Store>[
  Store(
    id: 's1',
    name: 'مطعم الشواء',
    area: 'الزهور',
    type: StoreType.restaurant,
    rating: 4.7,
    ratingCount: 312,
    distanceKm: 1.2,
    eta: '20–40 د',
    followers: 1240,
    usuallyPublishes: 'عادةً ينشر رواجع الساعة 10 بالليل',
    sponsored: true,
  ),
  Store(
    id: 's2',
    name: 'فرن المعجنات',
    area: 'المجموعة الثقافية',
    type: StoreType.restaurant,
    rating: 4.8,
    ratingCount: 540,
    distanceKm: 2.0,
    eta: '25–40 د',
    followers: 860,
    usuallyPublishes: 'عادةً ينشر رواجع الساعة 9 بالليل',
  ),
  Store(
    id: 's3',
    name: 'محل الحلويات',
    area: 'النور',
    type: StoreType.restaurant,
    rating: 4.6,
    ratingCount: 198,
    distanceKm: 3.0,
    eta: '30–40 د',
    followers: 410,
    usuallyPublishes: 'عادةً ينشر رواجع الساعة 11 بالليل',
  ),
  Store(
    id: 'm1',
    name: 'سوق النور',
    area: 'النور',
    type: StoreType.merchant,
    rating: 4.5,
    ratingCount: 120,
    distanceKm: 2.4,
    eta: 'اليوم',
  ),
  Store(
    id: 'm2',
    name: 'هايبر الساحل',
    area: 'الساحل الأيسر',
    type: StoreType.merchant,
    rating: 4.4,
    ratingCount: 88,
    distanceKm: 4.0,
    eta: 'اليوم',
  ),
];

const offers = <Offer>[
  Offer(id: 'o1', storeId: 's1', title: 'صندوق مشاوي', originalPrice: 15000, price: 5000, quantityLeft: 2, surpriseBox: true, expiresLabel: 'باقي 45 د', pickupWindow: '10–11 م', orderedThisWeek: 48, description: 'وجبات مشاوي انلغى طلبها أو زادت آخر اليوم. المحتوى ممكن يتغير حسب الموجود، بس قيمته الأصلية ما تقل عن 15,000 دينار.'),
  Offer(id: 'o2', storeId: 's1', title: 'نص فروج', originalPrice: 10000, price: 4000, quantityLeft: 3, expiresLabel: 'باقي 45 د', pickupWindow: '10–11 م', orderedThisWeek: 30),
  Offer(id: 'o3', storeId: 's1', title: 'كبة موصلية', originalPrice: 8000, price: 3000, quantityLeft: 4, expiresLabel: 'باقي 45 د', pickupWindow: '10–11 م', orderedThisWeek: 22),
  Offer(id: 'o4', storeId: 's2', title: 'صندوق معجنات', originalPrice: 9000, price: 3000, quantityLeft: 5, surpriseBox: true, expiresLabel: 'باقي ساعة', pickupWindow: '9–10 م', orderedThisWeek: 86),
  Offer(id: 'o5', storeId: 's2', title: 'صمون حار ×10', originalPrice: 2500, price: 1000, quantityLeft: 8, expiresLabel: 'باقي ساعة', pickupWindow: '9–10 م', orderedThisWeek: 120),
  Offer(id: 'o6', storeId: 's3', title: 'كنافة', originalPrice: 10000, price: 4000, quantityLeft: 3, expiresLabel: 'باقي ساعتين', pickupWindow: '11–12 م', orderedThisWeek: 40),
  Offer(id: 'o7', storeId: 's3', title: 'صندوق حلويات', originalPrice: 16000, price: 5000, quantityLeft: 2, surpriseBox: true, expiresLabel: 'باقي ساعتين', pickupWindow: '11–12 م', orderedThisWeek: 35),
  Offer(id: 'p1', storeId: 'm1', title: 'لبن 1 لتر — كرتونة 6', originalPrice: 9000, price: 4500, quantityLeft: 40, expiresLabel: 'ينتهي بعد 4 أيام', orderedThisWeek: 320, storage: Storage.chilled),
  Offer(id: 'p2', storeId: 'm1', title: 'بسكت شوكولاتة ×6', originalPrice: 2500, price: 1000, quantityLeft: 60, expiresLabel: 'ينتهي بعد 5 أيام', orderedThisWeek: 210),
  Offer(id: 'p3', storeId: 'm2', title: 'صدور دجاج 1 كغم', originalPrice: 12000, price: 7000, quantityLeft: 25, expiresLabel: 'ينتهي بعد 9 أيام', orderedThisWeek: 95, storage: Storage.frozen),
  Offer(id: 'p4', storeId: 'm2', title: 'مسحوق غسيل 3 كغم', originalPrice: 14000, price: 8500, quantityLeft: 30, expiresLabel: 'ينتهي بعد 3 أسابيع', orderedThisWeek: 41),
];

Store storeById(String id) => stores.firstWhere((s) => s.id == id);
List<Offer> offersOf(String storeId) =>
    offers.where((o) => o.storeId == storeId).toList();
