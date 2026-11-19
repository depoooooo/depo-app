import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'categories_screen.dart';
import '../data/categories.dart';

/// طلب الانضمام كمطعم أو تاجر أو مندوب — المشرف يراجعه ويوافق
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  Role type = Role.restaurant;
  final storeName = TextEditingController();
  final kind = TextEditingController();
  String cuisine = '';
  final area = TextEditingController();
  final vehicle = TextEditingController();
  final docs = <String, String>{}; // اسم الورقة -> رقم الصورة
  String? uploading;

  @override
  void dispose() {
    storeName.dispose();
    kind.dispose();
    area.dispose();
    vehicle.dispose();
    super.dispose();
  }

  List<String> get requiredDocs => type == Role.courier
      ? ['صورة الهوية', 'صورة شخصية', 'إجازة السوق']
      : ['الإجازة الصحية', 'السجل التجاري', 'صور المحل'];

  Future<void> _submit() async {
    if (!await ensureLoggedIn(context, reason: 'سجّل أول حتى نربط الطلب برقمك')) return;
    if (!mounted) return;
    final block = app.joinBlocker();
    if (block != null) {
      toast(context, block);
      return;
    }
    if (type != Role.courier && (storeName.text.trim().isEmpty || area.text.trim().isEmpty)) {
      toast(context, 'اكتب اسم المحل والحي');
      return;
    }
    if (type == Role.restaurant && cuisine.isEmpty) {
      toast(context, 'اختار نوع المطعم');
      return;
    }
    if (docs.length < requiredDocs.length) {
      toast(context, 'ارفع كل الأوراق المطلوبة');
      return;
    }
    app.submitJoin(
      type: type,
      storeName: type == Role.courier ? '' : storeName.text.trim(),
      area: type == Role.courier ? '' : area.text.trim(),
      details: type == Role.courier ? 'المركبة: ${vehicle.text.trim()}' : 'النوع: ${type == Role.restaurant ? cuisine : kind.text.trim()}',
      docs: docs,
      cuisine: type == Role.restaurant ? cuisine : '',
    );
    toast(context, 'وصل طلبك! المشرف يراجعه ويرتب زيارة تفتيش خلال 72 ساعة');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(Role r, IconData icon) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AppCard(
              onTap: () => setState(() {
                type = r;
                docs.clear();
              }),
              color: type == r ? DepoColors.soft : Colors.white,
              borderColor: type == r ? DepoColors.dark : DepoColors.line,
              child: Column(children: [Icon(icon, color: DepoColors.dark, size: 30), Text(roleNames[r]!, style: const TextStyle(fontWeight: FontWeight.w800))]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('انضم إلى Depo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [tile(Role.restaurant, Icons.restaurant), tile(Role.merchant, Icons.storefront), tile(Role.courier, Icons.delivery_dining)]),
          const SizedBox(height: 8),
          if (type != Role.courier) ...[
            TextField(controller: storeName, decoration: InputDecoration(labelText: type == Role.restaurant ? 'اسم المطعم' : 'اسم المتجر')),
            const SizedBox(height: 10),
            if (type == Role.restaurant) ...[
              const Text('نوع المطعم', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              CatPicker(cats: restaurantCats, value: cuisine, onChanged: (v) => setState(() => cuisine = v)),
            ] else
              TextField(controller: kind, decoration: const InputDecoration(labelText: 'نوع المتجر (سوق، جملة، موزع...)')),
            const SizedBox(height: 10),
            TextField(controller: area, decoration: const InputDecoration(labelText: 'الحي', hintText: 'مثلاً: الزهور، النور، المجموعة الثقافية')),
          ] else
            TextField(controller: vehicle, decoration: const InputDecoration(labelText: 'نوع المركبة ورقمها')),
          const SizedBox(height: 14),
          const Text('الأوراق والصور', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in requiredDocs)
              FilterChip(
                avatar: uploading == d
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(docs.containsKey(d) ? Icons.check_circle : Icons.add_a_photo_outlined, size: 18),
                label: Text(d),
                selected: docs.containsKey(d),
                onSelected: uploading != null
                    ? null
                    : (v) async {
                        if (!v) {
                          setState(() => docs.remove(d));
                          return;
                        }
                        if (!await ensureLoggedIn(context, reason: 'سجّل أول حتى نرفع أوراقك') || !context.mounted) return;
                        setState(() => uploading = d);
                        final id = await pickAndUpload(context, owner: 'join:${app.currentPhone}');
                        if (!mounted) return;
                        setState(() {
                          uploading = null;
                          if (id != null) docs[d] = id;
                        });
                      },
              ),
          ]),
          const SizedBox(height: 4),
          const Text('اضغط على كل ورقة وصوّرها أو اختارها من المعرض', style: TextStyle(fontSize: 11, color: DepoColors.muted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: const Text('أرسل الطلب')),
          const SizedBox(height: 8),
          const Text('المشرف يراجع طلبك ويرتب زيارة تفتيش خلال 72 ساعة', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        ],
      ),
    );
  }
}
