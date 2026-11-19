import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/geo_ui.dart';
import '../auth.dart';

/// مركز الموصل (إذا ماكو موقع)
const mosulCenter = LatLng(36.3450, 43.1450);

/// طبقة الخريطة (OpenStreetMap — بدون مفتاح)
Widget osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.depo.app',
      maxZoom: 19,
    );

/// الدبوس بنص الخريطة
class CenterPin extends StatelessWidget {
  final bool lifted;
  const CenterPin({super.key, this.lifted = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 150),
            offset: lifted ? const Offset(0, -0.25) : Offset.zero,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DepoColors.dark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: const Icon(Icons.circle, size: 10, color: Colors.white),
              ),
              Container(width: 3, height: 12, color: DepoColors.dark),
            ]),
          ),
        ),
      ),
    );
  }
}

// ======================= «وين تحب يوصل طلبك؟» =======================
Future<void> showAddressSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => const _AddressSheet(),
  );
}

class _AddressSheet extends StatelessWidget {
  const _AddressSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final name = app.me?.name ?? '';
        final list = app.places;
        final current = app.usingCurrentLocation;
        final sel = app.selectedPlace;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.isEmpty ? 'أهلاً وسهلاً،' : 'أهلاً وسهلاً $name،', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const Text('وين تحب يوصل طلبك؟', style: TextStyle(color: DepoColors.muted)),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  _PlaceRow(
                    selected: current,
                    title: 'الموقع الحالي',
                    subtitle: 'تصفّح المطاعم القريبة من مكانك هسه',
                    icon: Icons.my_location,
                    onTap: () async {
                      final r = await locateWithProgress(context);
                      if (!context.mounted) return;
                      if (r.fix == null) return toast(context, r.error);
                      await app.selectPlace('current', fix: r.fix);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  for (final a in list) ...[
                    const Divider(height: 1),
                    _PlaceRow(
                      selected: !current && sel?.id == a.id,
                      title: a.name.isEmpty ? 'عنوان' : a.name,
                      subtitle: a.short,
                      icon: a.hasMap ? Icons.location_on_outlined : Icons.location_off_outlined,
                      onTap: () async {
                        await app.selectPlace(a.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      onEdit: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddressFormScreen(address: a.copy()))),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  if (!await ensureLoggedIn(context, reason: 'سجّل حتى تحفظ عناوينك') || !context.mounted) return;
                  await addAddressFlow(context);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة عنوان'),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final bool selected;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  const _PlaceRow({required this.selected, required this.title, required this.subtitle, required this.icon, required this.onTap, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? DepoColors.dark : DepoColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
            ]),
          ),
          if (onEdit != null) IconButton(tooltip: 'تعديل', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20, color: DepoColors.muted)),
        ]),
      ),
    );
  }
}

/// إضافة عنوان: الخريطة ← معلومات العنوان. يرجّع العنوان المحفوظ
Future<Address?> addAddressFlow(BuildContext context) async {
  final start = app.currentFix != null ? LatLng(app.currentFix!.lat, app.currentFix!.lng) : null;
  final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(builder: (_) => MapPickScreen(initial: start, locateOnOpen: start == null)));
  if (p == null || !context.mounted) return null;
  final a = Address(id: '', phone: app.currentPhone ?? '', lat: p.latitude, lng: p.longitude);
  return Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => AddressFormScreen(address: a)));
}

// ======================= «اختيار الموقع» =======================
class MapPickScreen extends StatefulWidget {
  final LatLng? initial;
  final bool locateOnOpen;
  const MapPickScreen({super.key, this.initial, this.locateOnOpen = false});

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final ctl = MapController();
  bool moving = false;
  late LatLng center = widget.initial ?? mosulCenter;

  @override
  void initState() {
    super.initState();
    if (widget.locateOnOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _locate(silent: true));
  }

  Future<void> _locate({bool silent = false}) async {
    final r = await locateWithProgress(context);
    if (!mounted) return;
    if (r.fix == null) {
      if (!silent) toast(context, r.error);
      return;
    }
    app.currentFix = r.fix;
    center = LatLng(r.fix!.lat, r.fix!.lng);
    ctl.move(center, 17);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اختيار الموقع'),
          Text('حرّك الخريطة لحد ما الدبوس يصير على باب بيتك', style: TextStyle(fontSize: 12, color: DepoColors.muted, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: ctl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initial == null ? 13 : 17,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (camera, hasGesture) {
              center = camera.center;
              if (hasGesture && !moving) setState(() => moving = true);
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) {
                if (moving) setState(() => moving = false);
              }
            },
          ),
          children: [
            osmTiles(),
            const Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(padding: EdgeInsets.all(4), child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black54))),
            ),
          ],
        ),
        CenterPin(lifted: moving),
        Positioned(
          right: 16,
          bottom: 16,
          child: Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _locate,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('موقعي', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(width: 6),
                  Icon(Icons.gps_fixed, size: 20),
                ]),
              ),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: () => Navigator.pop(context, center), child: const Text('تأكيد الموقع')),
        ),
      ),
    );
  }
}

// ======================= «معلومات العنوان» =======================
class AddressFormScreen extends StatefulWidget {
  final Address address;
  const AddressFormScreen({super.key, required this.address});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  late final Address a = widget.address;
  late final name = TextEditingController(text: a.name);
  late final details = TextEditingController(text: a.details);
  late final phone = TextEditingController(text: a.phone.startsWith('0') ? a.phone.substring(1) : a.phone);
  late final street = TextEditingController(text: a.street);
  late final building = TextEditingController(text: a.building);
  late final floor = TextEditingController(text: a.floor);
  late final apt = TextEditingController(text: a.apt);
  late final landmark = TextEditingController(text: a.landmark);
  int mapVersion = 0;

  @override
  void dispose() {
    for (final c in [name, details, phone, street, building, floor, apt, landmark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _editMap() async {
    final p = await Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => MapPickScreen(initial: a.hasMap ? LatLng(a.lat, a.lng) : null, locateOnOpen: !a.hasMap),
    ));
    if (p == null) return;
    setState(() {
      a.lat = p.latitude;
      a.lng = p.longitude;
      mapVersion++;
    });
  }

  void _save() {
    var ph = phone.text.trim().replaceAll(' ', '');
    if (ph.startsWith('+964')) ph = ph.substring(4);
    if (ph.isNotEmpty && !ph.startsWith('0')) ph = '0$ph';
    a
      ..name = name.text.trim()
      ..details = details.text.trim()
      ..phone = ph
      ..street = street.text.trim()
      ..building = building.text.trim()
      ..floor = floor.text.trim()
      ..apt = apt.text.trim()
      ..landmark = landmark.text.trim();
    if (!a.hasMap) return toast(context, 'حدد موقعك على الخريطة («تعديل» فوق)');
    if (ph.length != 11) return toast(context, 'رقم الاتصال لازم يكون 11 رقم (07xxxxxxxxx)');
    final err = app.savePlace(a);
    if (err != null) return toast(context, err);
    Navigator.pop(context, a);
  }

  Widget _field(TextEditingController c, String label, {bool req = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(
            label: Text.rich(TextSpan(children: [
              TextSpan(text: label),
              if (req) const TextSpan(text: ' *', style: TextStyle(color: DepoColors.danger)),
            ])),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final center = a.hasMap ? LatLng(a.lat, a.lng) : mosulCenter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات العنوان'),
        actions: [
          if (app.places.any((x) => x.id == a.id))
            IconButton(
              tooltip: 'حذف العنوان',
              onPressed: () {
                app.deletePlace(a.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 130,
            child: Stack(children: [
              FlutterMap(
                key: ValueKey(mapVersion),
                options: MapOptions(initialCenter: center, initialZoom: a.hasMap ? 16.5 : 12, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [osmTiles()],
              ),
              if (a.hasMap) const CenterPin(),
              Positioned.fill(child: Material(color: Colors.transparent, child: InkWell(onTap: _editMap))),
              Positioned(
                left: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _editMap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(a.hasMap ? 'تعديل' : 'حدد على الخريطة', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_location_alt_outlined, size: 16),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _field(name, 'اسم العنوان، مثل: البيت، الشغل، أخرى…', req: true),
        _field(details, 'تفاصيل العنوان (الحي والمنطقة)', req: true),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(phone, 'رقم الاتصال', req: true, type: TextInputType.phone)),
          const SizedBox(width: 8),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: DepoColors.line), borderRadius: BorderRadius.circular(14)),
            child: const Text('+964', textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
        Row(children: [
          Expanded(child: _field(street, 'اسم الشارع')),
          const SizedBox(width: 8),
          Expanded(child: _field(building, 'رقم البناية/البيت')),
        ]),
        Row(children: [
          Expanded(child: _field(floor, 'رقم الطابق')),
          const SizedBox(width: 8),
          Expanded(child: _field(apt, 'رقم الشقة')),
        ]),
        _field(landmark, 'أقرب نقطة دالة'),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: FilledButton(onPressed: _save, child: const Text('تأكيد العنوان'))),
      ),
    );
  }
}
