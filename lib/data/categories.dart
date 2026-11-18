import 'models.dart';

/// أنواع الأكل لـ «شتشتهي اليوم؟» — تنعرف من اسم العرض واسم المحل
class FoodCat {
  final String name;
  final String emoji;
  final List<String> words;
  const FoodCat(this.name, this.emoji, this.words);
}

const foodCats = [
  FoodCat('صناديق', '🎁', []),
  FoodCat('مشاوي', '🍢', ['مشاوي', 'شواء', 'كباب', 'تكة', 'معلاق']),
  FoodCat('فروج', '🍗', ['فروج', 'دجاج', 'بروستد', 'شاورما']),
  FoodCat('معجنات', '🥐', ['معجنات', 'صمون', 'خبز', 'فطائر', 'فرن', 'لحم بعجين']),
  FoodCat('حلويات', '🍰', ['حلو', 'كنافة', 'كيك', 'بقلاوة', 'زلابية']),
  FoodCat('موصلي', '🥘', ['كبة', 'دولمة', 'قوزي', 'برياني', 'باچة', 'تشريب']),
  FoodCat('بيتزا وبرگر', '🍕', ['بيتزا', 'برگر', 'برجر', 'همبرگر']),
];

bool inCat(FoodCat c, Offer o, Store? s) {
  if (c.name == 'صناديق') return o.surpriseBox;
  final t = '${o.title} ${o.description} ${s?.name ?? ''}';
  return c.words.any(t.contains);
}
