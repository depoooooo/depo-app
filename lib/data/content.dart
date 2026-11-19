import 'package:flutter/material.dart';

/// الأيقونات المتاحة للأقسام والبنرات (تنحفظ باسمها)
const iconRegistry = <String, IconData>{
  'grill': Icons.outdoor_grill_rounded,
  'chicken': Icons.set_meal_rounded,
  'rice': Icons.rice_bowl_rounded,
  'pizza': Icons.local_pizza_rounded,
  'burger': Icons.lunch_dining_rounded,
  'kebab': Icons.kebab_dining_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'cake': Icons.cake_rounded,
  'fish': Icons.phishing_rounded,
  'cafe': Icons.local_cafe_rounded,
  'oil': Icons.water_drop_rounded,
  'grain': Icons.grain_rounded,
  'noodles': Icons.ramen_dining_rounded,
  'can': Icons.inventory_rounded,
  'spice': Icons.spa_rounded,
  'sauce': Icons.soup_kitchen_rounded,
  'dairy': Icons.icecream_rounded,
  'frozen': Icons.ac_unit_rounded,
  'bread': Icons.breakfast_dining_rounded,
  'snack': Icons.cookie_rounded,
  'drink': Icons.local_drink_rounded,
  'egg': Icons.egg_alt_rounded,
  'clean': Icons.cleaning_services_rounded,
  'care': Icons.face_retouching_natural_rounded,
  'baby': Icons.child_friendly_rounded,
  'fruit': Icons.apple_rounded,
  'veg': Icons.eco_rounded,
  'meat': Icons.kebab_dining_outlined,
  'box': Icons.inventory_2_rounded,
  'gift': Icons.card_giftcard_rounded,
  'fire': Icons.local_fire_department_rounded,
  'store': Icons.storefront_rounded,
  'star': Icons.stars_rounded,
  'hand': Icons.handshake_rounded,
  'offer': Icons.local_offer_rounded,
  'sell': Icons.sell_rounded,
  'bolt': Icons.bolt_rounded,
  'heart': Icons.favorite_rounded,
  'delivery': Icons.delivery_dining_rounded,
  'percent': Icons.percent_rounded,
  'restaurant': Icons.restaurant_rounded,
  'basket': Icons.shopping_basket_rounded,
};

IconData iconOf(String key) => iconRegistry[key] ?? Icons.category_rounded;

/// ألوان جاهزة للاختيار
const colorPresets = <int>[
  0xFF06363C, 0xFF0E7F8A, 0xFF4BCDDB, 0xFF2B5F66, 0xFFF5A524, 0xFFF26B1D,
  0xFFE63946, 0xFFEC4899, 0xFF8B5CF6, 0xFF3B82F6, 0xFF10B981, 0xFF16A34A,
  0xFFB45309, 0xFF6B7280, 0xFFE76F51, 0xFF2A9D8F,
];

String hexOf(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
int? parseHex(String s) {
  final t = s.trim().replaceAll('#', '');
  if (t.length != 6) return null;
  final v = int.tryParse(t, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

/// بنر بالرئيسية
class BannerItem {
  String id;
  String title;
  String text;
  int bg;
  bool darkText;
  String imageId; // صورة خلفية (اختياري)
  String icon;
  String tab; // rawaji / market / all
  String action; // none / login / join / store / category / search
  String target;
  bool guestOnly; // يطلع بس للي ما مسجّل
  int start, end; // 0 = بدون
  bool active;

  BannerItem({
    required this.id,
    this.title = '',
    this.text = '',
    this.bg = 0xFF06363C,
    this.darkText = false,
    this.imageId = '',
    this.icon = 'fire',
    this.tab = 'rawaji',
    this.action = 'none',
    this.target = '',
    this.guestOnly = false,
    this.start = 0,
    this.end = 0,
    this.active = true,
  });

  bool get liveNow {
    final now = DateTime.now().millisecondsSinceEpoch;
    return active && (start == 0 || now >= start) && (end == 0 || now <= end);
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'text': text, 'bg': bg, 'darkText': darkText, 'imageId': imageId, 'icon': icon,
        'tab': tab, 'action': action, 'target': target, 'guestOnly': guestOnly, 'start': start, 'end': end, 'active': active,
      };

  factory BannerItem.fromJson(Map<String, dynamic> j) => BannerItem(
        id: (j['id'] ?? '') as String,
        title: noEmoji((j['title'] ?? '') as String),
        text: noEmoji((j['text'] ?? '') as String),
        bg: (j['bg'] ?? 0xFF06363C) as int,
        darkText: (j['darkText'] ?? false) as bool,
        imageId: (j['imageId'] ?? '') as String,
        icon: (j['icon'] ?? 'fire') as String,
        tab: (j['tab'] ?? 'rawaji') as String,
        action: (j['action'] ?? 'none') as String,
        target: (j['target'] ?? '') as String,
        guestOnly: (j['guestOnly'] ?? false) as bool,
        start: (j['start'] ?? 0) as int,
        end: (j['end'] ?? 0) as int,
        active: (j['active'] ?? true) as bool,
      );

  BannerItem copy() => BannerItem.fromJson(toJson());
}

/// قسم (نوع مطعم أو صنف ماركت)
class CatItem {
  String name;
  String icon;
  int color;
  String imageId;
  List<String> words;
  bool active;

  CatItem({required this.name, this.icon = 'restaurant', this.color = 0xFF0E7F8A, this.imageId = '', List<String>? words, this.active = true})
      : words = words ?? [];

  Map<String, dynamic> toJson() => {'name': name, 'icon': icon, 'color': color, 'imageId': imageId, 'words': words, 'active': active};
  factory CatItem.fromJson(Map<String, dynamic> j) => CatItem(
        name: (j['name'] ?? '') as String,
        icon: (j['icon'] ?? 'restaurant') as String,
        color: (j['color'] ?? 0xFF0E7F8A) as int,
        imageId: (j['imageId'] ?? '') as String,
        words: List<String>.from(j['words'] ?? const []),
        active: (j['active'] ?? true) as bool,
      );
  CatItem copy() => CatItem.fromJson(toJson());
}

/// أجزاء الرئيسية اللي تنطفي وتشتغل
const homeSectionNames = {
  'cats': 'الأقسام (الدوائر)',
  'filters': 'أزرار الفلترة',
  'banners': 'البنرات',
  'myStores': 'محلاتي (المتابَعة)',
  'nearby': 'رواجع قريبة عليك',
  'campaign': 'قسم الحملة',
  'boxes': 'صناديق المفاجأة',
  'stores': 'قائمة المطاعم',
  'marketCheap': 'الماركت: كلشي بـ 1,000',
  'marketGrid': 'الماركت: عروض قوية اليوم',
  'marketStores': 'الماركت: المحلات',
};

/// كل المحتوى اللي ينعدّل من داخل التطبيق
class ContentConfig {
  List<BannerItem> banners;
  List<CatItem> restCats;
  List<CatItem> marketCats;
  List<String> searchPhrases;
  String splash1, splash2;
  Map<String, bool> sections;

  ContentConfig({
    required this.banners,
    required this.restCats,
    required this.marketCats,
    required this.searchPhrases,
    this.splash1 = 'أكل طيب',
    this.splash2 = 'بسعر أطيب',
    Map<String, bool>? sections,
  }) : sections = sections ?? {for (final k in homeSectionNames.keys) k: true};

  bool show(String key) => sections[key] ?? true;

  Map<String, dynamic> toJson() => {
        'banners': banners.map((e) => e.toJson()).toList(),
        'restCats': restCats.map((e) => e.toJson()).toList(),
        'marketCats': marketCats.map((e) => e.toJson()).toList(),
        'searchPhrases': searchPhrases,
        'splash1': splash1,
        'splash2': splash2,
        'sections': sections,
      };

  factory ContentConfig.fromJson(Map<String, dynamic> j) {
    final d = ContentConfig.defaults();
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f, List<T> def) =>
        j[k] is List ? (j[k] as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList() : def;
    return ContentConfig(
      banners: l('banners', BannerItem.fromJson, d.banners),
      restCats: l('restCats', CatItem.fromJson, d.restCats),
      marketCats: l('marketCats', CatItem.fromJson, d.marketCats),
      searchPhrases: j['searchPhrases'] is List ? [for (final x in j['searchPhrases'] as List) noEmoji('$x')] : d.searchPhrases,
      splash1: (j['splash1'] ?? d.splash1) as String,
      splash2: (j['splash2'] ?? d.splash2) as String,
      sections: {...d.sections, ...Map<String, bool>.from((j['sections'] ?? const {}) as Map)},
    );
  }

  ContentConfig copy() => ContentConfig.fromJson(toJson());

  factory ContentConfig.defaults() => ContentConfig(
        banners: [
          BannerItem(id: 'b1', title: '{campaign}', text: 'رواجع المطاعم تبدي من 1,000 دينار', bg: 0xFF06363C, icon: 'fire', tab: 'rawaji'),
          BannerItem(id: 'b2', title: 'استلم بنفسك', text: 'ووفّر {fee} رسم التوصيل', bg: 0xFF0E7F8A, icon: 'store', tab: 'rawaji'),
          BannerItem(id: 'b3', title: 'سجّل واكسب نقاط', text: 'كل 1,000 دينار = نقطة، بدّلها بصناديق مجانية', bg: 0xFFF5A524, darkText: true, icon: 'star', tab: 'rawaji', action: 'login', guestOnly: true),
          BannerItem(id: 'b4', title: 'عندك مطعم أو محل؟', text: 'انضم لديبو — أول شهر مجاني للمطاعم', bg: 0xFF2B5F66, icon: 'hand', tab: 'rawaji', action: 'join'),
          BannerItem(id: 'b5', title: 'عروض الأسبوع', text: 'خصومات قوية على مواد قريبة الانتهاء — باقي 3 أيام', bg: 0xFF06363C, icon: 'offer', tab: 'market'),
          BannerItem(id: 'b6', title: 'كلشي بـ 1,000 دينار', text: 'منتجات مختارة بسعر واحد', bg: 0xFF0E7F8A, icon: 'sell', tab: 'market'),
        ],
        restCats: [
          CatItem(name: 'مشاوي', icon: 'grill', color: 0xFFE76F51, words: ['مشاوي', 'شواء', 'كباب', 'تكة', 'معلاق']),
          CatItem(name: 'فروج وبروستد', icon: 'chicken', color: 0xFFF4A261, words: ['فروج', 'دجاج', 'بروستد']),
          CatItem(name: 'شرقي وموصلي', icon: 'rice', color: 0xFF2A9D8F, words: ['كبة', 'دولمة', 'قوزي', 'برياني', 'باچة', 'تشريب', 'شرقي']),
          CatItem(name: 'بيتزا', icon: 'pizza', color: 0xFFE63946, words: ['بيتزا']),
          CatItem(name: 'برگر', icon: 'burger', color: 0xFFB5651D, words: ['برگر', 'برجر', 'همبرگر']),
          CatItem(name: 'شاورما وسندويشات', icon: 'kebab', color: 0xFF8D6E63, words: ['شاورما', 'سندويش', 'لفة', 'فلافل']),
          CatItem(name: 'معجنات وأفران', icon: 'bakery', color: 0xFFD4A373, words: ['معجنات', 'صمون', 'خبز', 'فطائر', 'فرن', 'لحم بعجين']),
          CatItem(name: 'حلويات', icon: 'cake', color: 0xFFEC4899, words: ['حلو', 'كنافة', 'كيك', 'بقلاوة', 'زلابية']),
          CatItem(name: 'مأكولات بحرية', icon: 'fish', color: 0xFF3B82F6, words: ['سمك', 'مسكوف', 'روبيان']),
          CatItem(name: 'عصائر ومشروبات', icon: 'cafe', color: 0xFF10B981, words: ['عصير', 'قهوة', 'شاي', 'مشروب']),
        ],
        marketCats: [
          CatItem(name: 'زيوت وسمن', icon: 'oil', color: 0xFFF59E0B, words: ['زيت', 'سمن', 'دهن']),
          CatItem(name: 'رز وحبوب', icon: 'grain', color: 0xFFB45309, words: ['رز', 'تمن', 'عدس', 'حمص', 'برغل', 'حبوب']),
          CatItem(name: 'معكرونة ونودلز', icon: 'noodles', color: 0xFFEAB308, words: ['معكرونة', 'نودلز', 'شعرية']),
          CatItem(name: 'معلبات', icon: 'can', color: 0xFF6B7280, words: ['معلب', 'تونة', 'فول', 'معجون']),
          CatItem(name: 'بهارات وتوابل', icon: 'spice', color: 0xFFDC2626, words: ['بهار', 'كمون', 'فلفل', 'كركم']),
          CatItem(name: 'صلصات وتتبيلات', icon: 'sauce', color: 0xFFEF4444, words: ['صلصة', 'كاتشب', 'مايونيز', 'خل']),
          CatItem(name: 'ألبان وأجبان', icon: 'dairy', color: 0xFF60A5FA, words: ['لبن', 'حليب', 'جبن', 'قيمر', 'زبدة', 'روب']),
          CatItem(name: 'لحوم ومجمدات', icon: 'frozen', color: 0xFF0EA5E9, words: ['دجاج', 'لحم', 'مجمد', 'كباب', 'صدور']),
          CatItem(name: 'خبز ومخبوزات', icon: 'bread', color: 0xFFD97706, words: ['خبز', 'صمون', 'كيك', 'كرواسون']),
          CatItem(name: 'سناكات وحلويات', icon: 'snack', color: 0xFFA855F7, words: ['بسكت', 'شيبس', 'شوكولا', 'حلويات', 'سناك']),
          CatItem(name: 'مشروبات', icon: 'drink', color: 0xFF14B8A6, words: ['ماء', 'عصير', 'مشروب', 'بيبسي', 'شاي', 'قهوة']),
          CatItem(name: 'إفطار وحبوب الصباح', icon: 'egg', color: 0xFFF97316, words: ['كورن', 'بيض', 'عسل', 'مربى', 'شوفان']),
          CatItem(name: 'منظفات', icon: 'clean', color: 0xFF22C55E, words: ['غسيل', 'منظف', 'صابون', 'كلور', 'معطر']),
          CatItem(name: 'عناية شخصية', icon: 'care', color: 0xFFDB2777, words: ['شامبو', 'معجون أسنان', 'مزيل', 'كريم']),
          CatItem(name: 'أطفال', icon: 'baby', color: 0xFF8B5CF6, words: ['حفاض', 'حليب أطفال', 'أطفال']),
        ],
        searchPhrases: [
          'شتشتهي اليوم؟ صندوق مشاوي؟',
          'دوّر على رواجع قريبة منك',
          'كبة موصلية بنص سعرها',
          'صمون حار ×10 بألف دينار',
          'كنافة آخر الليل بسعر حلو',
          'صندوق مفاجأة بثلث سعره',
          'لبن وحليب بخصم قوي',
          'أرخص عروض الماركت اليوم',
          'دوّر على مطعمك المفضل',
          'فروج بروستد رواجع',
        ],
      );
}


/// يشيل الإيموجي (السمايلات) — هوية ديبو بالأيقونات مو بالإيموجي
String noEmoji(String s) => s
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]', unicode: true), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();
