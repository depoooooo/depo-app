import 'package:flutter/material.dart';
import '../../data/app_state.dart';
import '../../data/content.dart';
import '../../data/images.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';

/// تبويب «المحتوى»: تعديل التطبيق من داخله حسب الصلاحية
/// (السوشل ميديا والتصميم: كلشي — التسويق: البنرات)
class ContentTab extends StatelessWidget {
  const ContentTab({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String sub, Widget page, {bool enabled = true}) => AppCard(
          onTap: enabled ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)) : null,
          color: enabled ? null : DepoColors.soft,
          child: Row(children: [
            CircleAvatar(backgroundColor: DepoColors.soft, child: Icon(icon, color: DepoColors.dark)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(enabled ? sub : 'ما عندك صلاحية — يحتاج قسم «السوشل ميديا والتصميم»', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              ]),
            ),
            if (enabled) const Icon(Icons.chevron_left),
          ]),
        );
    final c = app.content;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('أي تغيير هنا يوصل لكل الزبائن بنفس اللحظة، بدون تحديث للتطبيق.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      const SizedBox(height: 10),
      item(Icons.view_carousel_outlined, 'البنرات', '${c.banners.where((b) => b.liveNow).length} فعّال من ${c.banners.length}', const BannersEditor(), enabled: app.canEditBanners),
      item(Icons.restaurant_menu, 'أقسام المطاعم', '${c.restCats.where((x) => x.active).length} قسم ظاهر', const CatsEditor(market: false), enabled: app.canEditContent),
      item(Icons.shopping_basket_outlined, 'أصناف الماركت', '${c.marketCats.where((x) => x.active).length} صنف ظاهر', const CatsEditor(market: true), enabled: app.canEditContent),
      item(Icons.search, 'جمل البحث المتحركة', '${c.searchPhrases.length} جملة', const PhrasesEditor(), enabled: app.canEditContent),
      item(Icons.wallpaper, 'شاشة البداية', '«${c.splash1}» / «${c.splash2}»', const SplashEditor(), enabled: app.canEditContent),
      item(Icons.dashboard_customize_outlined, 'أجزاء الرئيسية', 'تشغيل وإطفاء أي جزء', const SectionsEditor(), enabled: app.canEditContent),
    ]);
  }
}

Widget _saveBar(BuildContext context, VoidCallback onSave) => SafeArea(
      child: Padding(padding: const EdgeInsets.all(16), child: FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.check), label: const Text('حفظ ونشر'))),
    );

/// اختيار لون
class ColorPick extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const ColorPick({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final c in colorPresets)
        InkWell(
          onTap: () => onChanged(c),
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(color: value == c ? DepoColors.ink : Colors.white, width: value == c ? 3 : 2),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3)],
            ),
            child: value == c ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
        ),
      ActionChip(
        avatar: const Icon(Icons.colorize, size: 16),
        label: Text(hexOf(value)),
        onPressed: () async {
          final ctl = TextEditingController(text: hexOf(value));
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('لون مخصص (HEX)'),
              content: TextField(controller: ctl, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: '#4BCDDB')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('تم')),
              ],
            ),
          );
          final v = parseHex(ctl.text);
          if (ok == true && v != null) onChanged(v);
        },
      ),
    ]);
  }
}

/// اختيار أيقونة
class IconPick extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const IconPick({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in iconRegistry.entries)
        InkWell(
          onTap: () => onChanged(e.key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value == e.key ? DepoColors.dark : DepoColors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(e.value, size: 22, color: value == e.key ? Colors.white : DepoColors.dark),
          ),
        ),
    ]);
  }
}

/// صورة (رفع/شيل)
class ImagePickField extends StatefulWidget {
  final String imageId;
  final ValueChanged<String> onChanged;
  final String label;
  final String hint; // ملاحظة للمصمم (القياس)
  final double maxSide;
  final ValueChanged<bool>? onBusy; // حتى الشاشة تقفل زر الحفظ لحد ما تخلص الصورة
  const ImagePickField({super.key, required this.imageId, required this.onChanged, this.label = 'صورة (اختياري)', this.hint = '', this.maxSide = 1200, this.onBusy});

  @override
  State<ImagePickField> createState() => _ImagePickFieldState();
}

class _ImagePickFieldState extends State<ImagePickField> {
  bool busy = false;

  Future<void> _pick() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('من المعرض'), onTap: () => Navigator.pop(c, false)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('صوّر هسه'), onTap: () => Navigator.pop(c, true)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (camera == null || !mounted) return;
    setState(() => busy = true);
    widget.onBusy?.call(true);
    String? err;
    try {
      final b = await Images.pick(camera: camera, maxSide: widget.maxSide, quality: 80);
      if (b != null) {
        final id = await Images.put(b, owner: 'content').timeout(const Duration(seconds: 40));
        widget.onChanged(id);
      }
    } catch (e) {
      err = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => busy = false);
    widget.onBusy?.call(false);
    if (err != null) {
      // نافذة (مو شريط تحت) حتى تبين حتى لو الشاشة نافذة منبثقة
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('ما انرفعت الصورة'),
          content: Text(err!.contains('Timeout') ? 'النت ضعيف، جرّب مرة ثانية' : err),
          actions: [FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c), child: const Text('تمام'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: DepoColors.soft, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: busy
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
            : widget.imageId.isEmpty
                ? const Icon(Icons.image_outlined, color: DepoColors.muted)
                : AppImage(imageId: widget.imageId, height: 64, width: 64, fallback: const Icon(Icons.broken_image_outlined)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(busy ? 'جاري ضغط الصورة ورفعها…' : widget.label, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (widget.hint.isNotEmpty) Text(widget.hint, style: const TextStyle(fontSize: 11, color: DepoColors.muted, height: 1.5)),
        ]),
      ),
      TextButton.icon(
        onPressed: busy ? null : _pick,
        icon: const Icon(Icons.upload),
        label: Text(widget.imageId.isEmpty ? 'رفع' : 'تغيير'),
      ),
      if (widget.imageId.isNotEmpty && !busy) IconButton(tooltip: 'شيل الصورة', onPressed: () => widget.onChanged(''), icon: const Icon(Icons.close)),
    ]);
  }
}

// ======================= البنرات =======================
class BannersEditor extends StatefulWidget {
  const BannersEditor({super.key});

  @override
  State<BannersEditor> createState() => _BannersEditorState();
}

class _BannersEditorState extends State<BannersEditor> {
  late List<BannerItem> list = [for (final b in app.content.banners) b.copy()];

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= list.length) return;
    setState(() {
      final x = list.removeAt(i);
      list.insert(j, x);
    });
  }

  Future<void> _edit([BannerItem? b]) async {
    final r = await Navigator.of(context).push<BannerItem>(MaterialPageRoute(builder: (_) => BannerEdit(item: b?.copy() ?? BannerItem(id: 'b${DateTime.now().millisecondsSinceEpoch}'))));
    if (r == null) return;
    if (r.id.startsWith('__deleted__')) {
      setState(() => list.removeWhere((x) => '__deleted__${x.id}' == r.id));
      return;
    }
    setState(() {
      final i = list.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        list[i] = r;
      } else {
        list.add(r);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const tabs = {'rawaji': 'رواجع المطاعم', 'market': 'الماركت', 'all': 'الاثنين'};
    return Scaffold(
      appBar: AppBar(title: const Text('البنرات')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('بنر جديد')),
      bottomNavigationBar: _saveBar(context, () {
        app.saveBanners(list);
        toast(context, 'انحفظت البنرات ووصلت للكل');
        Navigator.pop(context);
      }),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        const Text('رتّبها بالأسهم. البنر المطفي أو اللي خلص تاريخه ما يطلع.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          AppCard(
            onTap: () => _edit(list[i]),
            child: Row(children: [
              Container(
                width: 56,
                height: 40,
                decoration: BoxDecoration(color: Color(list[i].bg), borderRadius: BorderRadius.circular(8)),
                child: Icon(iconOf(list[i].icon), color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${tabs[list[i].tab]}${list[i].end > 0 ? ' • لحد ${dateLabel(list[i].end)}' : ''}${list[i].guestOnly ? ' • للزوار بس' : ''}',
                      style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
                ]),
              ),
              Switch(value: list[i].active, onChanged: (v) => setState(() => list[i].active = v)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: () => _move(i, -1), child: const Icon(Icons.keyboard_arrow_up)),
                InkWell(onTap: () => _move(i, 1), child: const Icon(Icons.keyboard_arrow_down)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class BannerEdit extends StatefulWidget {
  final BannerItem item;
  const BannerEdit({super.key, required this.item});

  @override
  State<BannerEdit> createState() => _BannerEditState();
}

class _BannerEditState extends State<BannerEdit> {
  late final b = widget.item;
  late final title = TextEditingController(text: b.title);
  late final text = TextEditingController(text: b.text);

  @override
  void dispose() {
    title.dispose();
    text.dispose();
    super.dispose();
  }

  Future<int?> _date(int cur) async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: cur > 0 ? DateTime.fromMillisecondsSinceEpoch(cur) : now,
    );
    return p?.millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    const tabs = {'rawaji': 'رواجع المطاعم', 'market': 'الماركت', 'all': 'الاثنين'};
    const actions = {'none': 'بدون', 'store': 'يفتح محل', 'category': 'يفتح قسم', 'search': 'يفتح البحث', 'join': 'انضمام كمحل', 'shop': 'يفتح «محلي» (دفتر الديون)', 'login': 'تسجيل الدخول'};
    final fg = b.darkText ? DepoColors.ink : Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل البنر'),
        actions: [
          IconButton(
            tooltip: 'حذف البنر',
            onPressed: () {
              Navigator.pop(context, BannerItem(id: '__deleted__${b.id}'));
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      bottomNavigationBar: _saveBar(context, () {
        b.title = title.text.trim();
        b.text = text.text.trim();
        if (b.title.isEmpty) return toast(context, 'اكتب عنوان البنر');
        Navigator.pop(context, b);
      }),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // معاينة
        Container(
          height: 112,
          decoration: BoxDecoration(color: Color(b.bg), borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            if (b.imageId.isNotEmpty) Positioned.fill(child: AppImage(imageId: b.imageId, height: 112, fallback: const SizedBox.shrink())),
            if (b.imageId.isEmpty) Positioned(left: -18, bottom: -22, child: Icon(iconOf(b.icon), size: 120, color: Colors.white.withValues(alpha: 0.12))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title.text.isEmpty ? 'العنوان' : title.text, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: fg)),
                Text(text.text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(controller: title, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'العنوان', helperText: '{campaign} = اسم الحملة • {fee} = رسم التوصيل')),
        const SizedBox(height: 10),
        TextField(controller: text, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'النص')),
        const SizedBox(height: 14),
        const Text('اللون', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        ColorPick(value: b.bg, onChanged: (v) => setState(() => b.bg = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: b.darkText, onChanged: (v) => setState(() => b.darkText = v), title: const Text('كتابة غامقة (للألوان الفاتحة)')),
        ImagePickField(imageId: b.imageId, onChanged: (v) => setState(() => b.imageId = v), label: 'صورة خلفية (اختياري)',
            hint: 'القياس: 1200 × 400 بكسل (3:1)\n• الكتابة المهمة بالنص، الأطراف ممكن تنقص شوية\n• إذا الكتابة داخل الصورة، اترك العنوان والنص فارغة\n• إذا تريد نص التطبيق فوقها، خلي الجهة اليمنى هادئة\n• JPG أو PNG'),
        const SizedBox(height: 10),
        const Text('الأيقونة', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        IconPick(value: b.icon, onChanged: (v) => setState(() => b.icon = v)),
        const SizedBox(height: 14),
        const Text('يطلع بـ', style: TextStyle(fontWeight: FontWeight.w900)),
        Wrap(spacing: 8, children: [for (final e in tabs.entries) ChoiceChip(label: Text(e.value), selected: b.tab == e.key, onSelected: (_) => setState(() => b.tab = e.key))]),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: b.guestOnly, onChanged: (v) => setState(() => b.guestOnly = v), title: const Text('يطلع بس للي ما مسجّل')),
        const Text('من ينضغط', style: TextStyle(fontWeight: FontWeight.w900)),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final e in actions.entries)
            ChoiceChip(label: Text(e.value), selected: b.action == e.key, onSelected: (_) => setState(() {
                  b.action = e.key;
                  b.target = '';
                })),
        ]),
        if (b.action == 'store')
          DropdownButtonFormField<String>(
            initialValue: app.storeById(b.target) == null ? null : b.target,
            isExpanded: true,
            hint: const Text('اختار المحل'),
            items: [for (final s in app.stores.where((s) => !s.suspended)) DropdownMenuItem(value: s.id, child: Text(s.fullName))],
            onChanged: (v) => setState(() => b.target = v ?? ''),
          ),
        if (b.action == 'category')
          DropdownButtonFormField<String>(
            initialValue: [...app.content.restCats, ...app.content.marketCats].any((c) => c.name == b.target) ? b.target : null,
            isExpanded: true,
            hint: const Text('اختار القسم'),
            items: [for (final c in [...app.content.restCats, ...app.content.marketCats]) DropdownMenuItem(value: c.name, child: Text(c.name))],
            onChanged: (v) => setState(() => b.target = v ?? ''),
          ),
        const SizedBox(height: 14),
        const Text('مدة العرض (اختياري)', style: TextStyle(fontWeight: FontWeight.w900)),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await _date(b.start);
                if (d != null) setState(() => b.start = d);
              },
              child: Text(b.start == 0 ? 'من: الآن' : 'من: ${dateLabel(b.start)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await _date(b.end);
                if (d != null) setState(() => b.end = d + 86399000);
              },
              child: Text(b.end == 0 ? 'لحد: دائماً' : 'لحد: ${dateLabel(b.end)}'),
            ),
          ),
        ]),
        if (b.start > 0 || b.end > 0)
          TextButton(onPressed: () => setState(() => b.start = b.end = 0), child: const Text('شيل التواريخ')),
      ]),
    );
  }
}

// ======================= الأقسام =======================
class CatsEditor extends StatefulWidget {
  final bool market;
  const CatsEditor({super.key, required this.market});

  @override
  State<CatsEditor> createState() => _CatsEditorState();
}

class _CatsEditorState extends State<CatsEditor> {
  late List<CatItem> list = [for (final c in (widget.market ? app.content.marketCats : app.content.restCats)) c.copy()];

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= list.length) return;
    setState(() => list.insert(j, list.removeAt(i)));
  }

  Future<void> _edit([int? index]) async {
    final c = index == null ? CatItem(name: '') : list[index].copy();
    final old = c.name;
    final name = TextEditingController(text: c.name);
    final words = TextEditingController(text: c.words.join('، '));
    var uploading = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: Color(c.color).withValues(alpha: 0.2), shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: c.imageId.isEmpty
                      ? Icon(iconOf(c.icon), color: Color(c.color), size: 28)
                      : AppImage(imageId: c.imageId, height: 56, width: 56, fallback: Icon(iconOf(c.icon))),
                ),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم القسم'))),
              ]),
              const SizedBox(height: 12),
              ImagePickField(
                  imageId: c.imageId,
                  onChanged: (v) {
                    c.imageId = v; // تنحفظ حتى لو انسدت النافذة
                    if (ctx.mounted) set(() {});
                  },
                  onBusy: (v) {
                    uploading = v;
                    if (ctx.mounted) set(() {});
                  },
                  label: 'صورة القسم (تطلع بالدائرة بدل الأيقونة)',
                  maxSide: 600,
                  hint: 'القياس: 500 × 500 بكسل (مربعة)\n• تنقص دائرة: خلي الأكلة/المنتج بالنص ويه فراغ حواليه\n• خلفية بيضاء أو لون سادة'),
              const SizedBox(height: 10),
              const Text('الأيقونة', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              IconPick(value: c.icon, onChanged: (v) => set(() => c.icon = v)),
              const SizedBox(height: 12),
              const Text('اللون', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ColorPick(value: c.color, onChanged: (v) => set(() => c.color = v)),
              const SizedBox(height: 12),
              TextField(controller: words, decoration: const InputDecoration(labelText: 'كلمات تدل عليه (اختياري)', helperText: 'مفصولة بفاصلة — حتى العروض القديمة تنعرف لهذا القسم')),
              const SizedBox(height: 14),
              FilledButton(onPressed: uploading ? null : () => Navigator.pop(ctx, true), child: Text(uploading ? 'انتظر الصورة…' : 'تم')),
              const SizedBox(height: 6),
              const Text('بعد «تم» لا تنسى «حفظ ونشر» تحت', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: DepoColors.muted)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    c.name = name.text.trim();
    c.words = words.text.split(RegExp('[،,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (c.name.isEmpty) return;
    if (list.any((x) => x.name == c.name && x.name != old)) {
      if (mounted) toast(context, 'أكو قسم بنفس الاسم');
      return;
    }
    setState(() {
      if (index == null) {
        list.add(c);
      } else {
        list[index] = c;
      }
    });
    if (index != null && old != c.name && mounted) {
      toast(context, 'تنبيه: المحلات أو العروض المسجّلة على «$old» تحتاج تعدّل قسمها');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.market ? 'أصناف الماركت' : 'أقسام المطاعم';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('قسم جديد')),
      bottomNavigationBar: _saveBar(context, () {
        app.saveCats(market: widget.market, list: list);
        toast(context, 'انحفظت $title');
        Navigator.pop(context);
      }),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        const Text('الترتيب هنا هو ترتيب الدوائر بالرئيسية. المطفي يختفي بدون ما ينمسح.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          AppCard(
            onTap: () => _edit(i),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Color(list[i].color).withValues(alpha: 0.2), shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: list[i].imageId.isEmpty
                    ? Icon(iconOf(list[i].icon), color: Color(list[i].color))
                    : AppImage(imageId: list[i].imageId, height: 44, width: 44, fallback: Icon(iconOf(list[i].icon))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(list[i].name, style: TextStyle(fontWeight: FontWeight.w900, color: list[i].active ? DepoColors.ink : DepoColors.muted))),
              Switch(value: list[i].active, onChanged: (v) => setState(() => list[i].active = v)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(onTap: () => _move(i, -1), child: const Icon(Icons.keyboard_arrow_up)),
                InkWell(onTap: () => _move(i, 1), child: const Icon(Icons.keyboard_arrow_down)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

// ======================= جمل البحث =======================
class PhrasesEditor extends StatefulWidget {
  const PhrasesEditor({super.key});

  @override
  State<PhrasesEditor> createState() => _PhrasesEditorState();
}

class _PhrasesEditorState extends State<PhrasesEditor> {
  late final ctls = [for (final p in app.content.searchPhrases) TextEditingController(text: p)];

  @override
  void dispose() {
    for (final c in ctls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جمل البحث المتحركة')),
      bottomNavigationBar: _saveBar(context, () {
        app.savePhrases([for (final c in ctls) c.text]);
        toast(context, 'انحفظت الجمل');
        Navigator.pop(context);
      }),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('تنكتب حرف حرف بشريط البحث، وحدة ورا الثانية.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < ctls.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: TextField(controller: ctls[i], maxLength: 40, decoration: InputDecoration(labelText: 'جملة ${i + 1}', counterText: ''))),
              IconButton(onPressed: () => setState(() => ctls.removeAt(i).dispose()), icon: const Icon(Icons.delete_outline)),
            ]),
          ),
        OutlinedButton.icon(onPressed: () => setState(() => ctls.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('جملة جديدة')),
      ]),
    );
  }
}

// ======================= شاشة البداية =======================
class SplashEditor extends StatefulWidget {
  const SplashEditor({super.key});

  @override
  State<SplashEditor> createState() => _SplashEditorState();
}

class _SplashEditorState extends State<SplashEditor> {
  late final a = TextEditingController(text: app.content.splash1);
  late final b = TextEditingController(text: app.content.splash2);

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شاشة البداية')),
      bottomNavigationBar: _saveBar(context, () {
        app.saveSplash(a.text, b.text);
        toast(context, 'انحفظت. تطلع من يفتح التطبيق المرة الجاية');
        Navigator.pop(context);
      }),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(color: DepoColors.brand, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Image.asset('assets/logo/depo-ar-white.png', width: 140),
            const SizedBox(height: 8),
            Text(a.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(b.text, style: const TextStyle(color: DepoColors.ink, fontSize: 19, fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 14),
        TextField(controller: a, maxLength: 30, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'السطر الأول (أبيض)')),
        TextField(controller: b, maxLength: 30, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'السطر الثاني (غامق)')),
        const Text('صور المعالم (المنارة والجامع) تتبدل بنسخة جديدة من التطبيق.', style: TextStyle(fontSize: 12, color: DepoColors.muted)),
      ]),
    );
  }
}

// ======================= أجزاء الرئيسية =======================
class SectionsEditor extends StatefulWidget {
  const SectionsEditor({super.key});

  @override
  State<SectionsEditor> createState() => _SectionsEditorState();
}

class _SectionsEditorState extends State<SectionsEditor> {
  late final m = Map<String, bool>.from(app.content.sections);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أجزاء الرئيسية')),
      bottomNavigationBar: _saveBar(context, () {
        app.saveSections(m);
        toast(context, 'انحفظت');
        Navigator.pop(context);
      }),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in homeSectionNames.entries)
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(value: m[e.key] ?? true, onChanged: (v) => setState(() => m[e.key] = v), title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w800))),
          ),
      ]),
    );
  }
}

/// للاستخدام بمكان ثاني: هل عنده أي صلاحية محتوى
bool canSeeContent() => app.canEditBanners || app.canEditContent;

/// للتوافق ويه models (Perm مستخدمة بالتبويبات)
const contentPerms = [Perm.design, Perm.marketing];
