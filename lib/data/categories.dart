import 'package:flutter/material.dart';
import 'app_state.dart';
import 'content.dart';
import 'models.dart';

/// قسم جاهز للعرض (من المحتوى اللي ينعدّل بالتطبيق)
class Cat {
  final String name;
  final IconData icon;
  final Color color;
  final String imageId;
  final List<String> words;
  const Cat(this.name, this.icon, this.color, [this.words = const [], this.imageId = '']);
  factory Cat.of(CatItem c) => Cat(c.name, iconOf(c.icon), Color(c.color), c.words, c.imageId);
}

/// أقسام المطاعم الفعّالة
List<Cat> get restaurantCats => [for (final c in app.content.restCats) if (c.active) Cat.of(c)];

/// أصناف الماركت الفعّالة
List<Cat> get marketCats => [for (final c in app.content.marketCats) if (c.active) Cat.of(c)];

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
