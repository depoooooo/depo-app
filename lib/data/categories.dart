import 'package:flutter/material.dart';
import 'models.dart';

/// قسم (نوع مطعم أو صنف ماركت)
class Cat {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> words; // كلمات للتخمين إذا ما محدد
  const Cat(this.name, this.icon, this.color, [this.words = const []]);
}

/// أقسام المطاعم (نوع المطبخ)
const restaurantCats = [
  Cat('مشاوي', Icons.outdoor_grill_rounded, Color(0xFFE76F51), ['مشاوي', 'شواء', 'كباب', 'تكة', 'معلاق']),
  Cat('فروج وبروستد', Icons.set_meal_rounded, Color(0xFFF4A261), ['فروج', 'دجاج', 'بروستد']),
  Cat('شرقي وموصلي', Icons.rice_bowl_rounded, Color(0xFF2A9D8F), ['كبة', 'دولمة', 'قوزي', 'برياني', 'باچة', 'تشريب', 'شرقي']),
  Cat('بيتزا', Icons.local_pizza_rounded, Color(0xFFE63946), ['بيتزا']),
  Cat('برگر', Icons.lunch_dining_rounded, Color(0xFFB5651D), ['برگر', 'برجر', 'همبرگر']),
  Cat('شاورما وسندويشات', Icons.kebab_dining_rounded, Color(0xFF8D6E63), ['شاورما', 'سندويش', 'لفة', 'فلافل']),
  Cat('معجنات وأفران', Icons.bakery_dining_rounded, Color(0xFFD4A373), ['معجنات', 'صمون', 'خبز', 'فطائر', 'فرن', 'لحم بعجين']),
  Cat('حلويات', Icons.cake_rounded, Color(0xFFEC4899), ['حلو', 'كنافة', 'كيك', 'بقلاوة', 'زلابية']),
  Cat('مأكولات بحرية', Icons.phishing_rounded, Color(0xFF3B82F6), ['سمك', 'مسكوف', 'روبيان']),
  Cat('عصائر ومشروبات', Icons.local_cafe_rounded, Color(0xFF10B981), ['عصير', 'قهوة', 'شاي', 'مشروب']),
];

/// أصناف الماركت
const marketCats = [
  Cat('زيوت وسمن', Icons.water_drop_rounded, Color(0xFFF59E0B), ['زيت', 'سمن', 'دهن']),
  Cat('رز وحبوب', Icons.grain_rounded, Color(0xFFB45309), ['رز', 'تمن', 'عدس', 'حمص', 'برغل', 'حبوب']),
  Cat('معكرونة ونودلز', Icons.ramen_dining_rounded, Color(0xFFEAB308), ['معكرونة', 'نودلز', 'شعرية']),
  Cat('معلبات', Icons.inventory_rounded, Color(0xFF6B7280), ['معلب', 'تونة', 'فول', 'معجون']),
  Cat('بهارات وتوابل', Icons.spa_rounded, Color(0xFFDC2626), ['بهار', 'كمون', 'فلفل', 'كركم']),
  Cat('صلصات وتتبيلات', Icons.soup_kitchen_rounded, Color(0xFFEF4444), ['صلصة', 'كاتشب', 'مايونيز', 'خل']),
  Cat('ألبان وأجبان', Icons.icecream_rounded, Color(0xFF60A5FA), ['لبن', 'حليب', 'جبن', 'قيمر', 'زبدة', 'روب']),
  Cat('لحوم ومجمدات', Icons.ac_unit_rounded, Color(0xFF0EA5E9), ['دجاج', 'لحم', 'مجمد', 'كباب', 'صدور']),
  Cat('خبز ومخبوزات', Icons.breakfast_dining_rounded, Color(0xFFD97706), ['خبز', 'صمون', 'كيك', 'كرواسون']),
  Cat('سناكات وحلويات', Icons.cookie_rounded, Color(0xFFA855F7), ['بسكت', 'شيبس', 'شوكولا', 'حلويات', 'سناك']),
  Cat('مشروبات', Icons.local_drink_rounded, Color(0xFF14B8A6), ['ماء', 'عصير', 'مشروب', 'بيبسي', 'شاي', 'قهوة']),
  Cat('إفطار وحبوب الصباح', Icons.egg_alt_rounded, Color(0xFFF97316), ['كورن', 'بيض', 'عسل', 'مربى', 'شوفان']),
  Cat('منظفات', Icons.cleaning_services_rounded, Color(0xFF22C55E), ['غسيل', 'منظف', 'صابون', 'كلور', 'معطر']),
  Cat('عناية شخصية', Icons.face_retouching_natural_rounded, Color(0xFFDB2777), ['شامبو', 'معجون أسنان', 'مزيل', 'كريم']),
  Cat('أطفال', Icons.child_friendly_rounded, Color(0xFF8B5CF6), ['حفاض', 'حليب أطفال', 'أطفال']),
];

Cat? catByName(List<Cat> list, String name) {
  for (final c in list) {
    if (c.name == name) return c;
  }
  return null;
}

Cat? _guess(List<Cat> list, String text) {
  for (final c in list) {
    if (c.words.any(text.contains)) return c;
  }
  return null;
}

/// نوع المطعم: المحدد، وإلا نخمّن من الاسم
String cuisineOf(Store s) {
  if (s.cuisine.isNotEmpty) return s.cuisine;
  return _guess(restaurantCats, s.name)?.name ?? '';
}

/// صنف المنتج: المحدد، وإلا نخمّن من الاسم
String categoryOf(Offer o) {
  if (o.category.isNotEmpty) return o.category;
  return _guess(marketCats, '${o.title} ${o.description}')?.name ?? '';
}
