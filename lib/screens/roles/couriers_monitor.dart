import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/debt_ui.dart';
import '../../widgets/waze_map.dart';
import '../address/address_ui.dart';

String _ago(int at) {
  if (at <= 0) return 'ما معروف';
  final m = ((DateTime.now().millisecondsSinceEpoch - at) / 60000).floor();
  if (m < 1) return 'هسه';
  if (m < 60) return 'قبل $m د';
  return 'قبل ${(m / 60).floor()} س';
}

/// مراقبة المندوبين: وين كل مندوب هسه، شنو يسوي، وآخر تحديث
class CouriersMonitorTab extends StatelessWidget {
  const CouriersMonitorTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = app.trackedCouriers;
        final spots = [for (final u in list) (u: u, s: app.courierSpot(u.phone))].where((x) => x.s != null).toList();
        final center = spots.isEmpty ? mosulCenter : LatLng(spots.first.s!.lat, spots.first.s!.lng);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: spots.length > 1 ? 12.5 : 14),
                children: [
                  osmTiles(),
                  MarkerLayer(markers: [
                    for (final x in spots)
                      Marker(
                        point: LatLng(x.s!.lat, x.s!.lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _open(context, x.u),
                          child: Container(
                            decoration: BoxDecoration(color: _color(x.u, x.s!), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                            child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(spacing: 12, children: [
            _Legend(DepoColors.dark, 'بالطريق بطلب'),
            _Legend(DepoColors.success, 'متاح'),
            _Legend(Color(0xFF9AA5AE), 'موقع قديم / غير متاح'),
          ]),
          SectionTitle('المندوبين (${list.length})'),
          if (list.isEmpty) const EmptyState(icon: Icons.delivery_dining, text: 'بعد ما أكو مندوب شغّل «متاح للتوصيل» أو أخذ طلب'),
          for (final u in list) _CourierRow(u: u, onTap: () => _open(context, u)),
          const Note2('الموقع يتحدث كل 30 ثانية للمندوب اللي بالطريق، وكل دقيقة للمتاح — بشرط التطبيق مفتوح عنده والموقع مشغّل.'),
        ]);
      },
    );
  }

  static Color _color(AppUser u, ({double lat, double lng, int at, Order? order}) s) {
    final stale = DateTime.now().millisecondsSinceEpoch - s.at > 10 * 60000;
    if (stale) return const Color(0xFF9AA5AE);
    if (s.order != null) return DepoColors.dark;
    return u.onDuty ? DepoColors.success : const Color(0xFF9AA5AE);
  }

  void _open(BuildContext context, AppUser u) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourierLiveScreen(phone: u.phone)));
}

class _Legend extends StatelessWidget {
  final Color c;
  final String t;
  const _Legend(this.c, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
      ]);
}

class Note2 extends StatelessWidget {
  final String t;
  const Note2(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, style: const TextStyle(fontSize: 11, color: DepoColors.muted, height: 1.5)));
}

class _CourierRow extends StatelessWidget {
  final AppUser u;
  final VoidCallback onTap;
  const _CourierRow({required this.u, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = app.courierSpot(u.phone);
    final o = s?.order;
    final status = o != null ? 'بالطريق • طلب #${o.id} إلى ${o.customerName}' : (u.onDuty ? 'متاح للتوصيل' : 'غير متاح');
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        CircleAvatar(
          backgroundColor: s == null ? DepoColors.soft : CouriersMonitorTab._color(u, s).withValues(alpha: 0.18),
          child: Icon(Icons.delivery_dining, color: s == null ? DepoColors.muted : CouriersMonitorTab._color(u, s)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name.isEmpty ? u.phone : u.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
            Text('آخر موقع: ${_ago(s?.at ?? 0)} • رصيده ${iqd(app.walletBalance(u.phone))}', style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
          ]),
        ),
        const Icon(Icons.chevron_left),
      ]),
    );
  }
}

/// مندوب واحد مباشر: خريطة ويز على موقعه، الطلب اللي بيده، اتصال
class CourierLiveScreen extends StatelessWidget {
  final String phone;
  const CourierLiveScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final u = app.userByPhone(phone);
        final s = app.courierSpot(phone);
        final o = s?.order;
        return Scaffold(
          appBar: AppBar(
            title: Text(u?.name.isNotEmpty == true ? u!.name : phone),
            actions: [IconButton(tooltip: 'اتصال', onPressed: () => callPhone(context, phone), icon: const Icon(Icons.phone))],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (s == null)
              const EmptyState(icon: Icons.location_off_outlined, text: 'ماكو موقع لهذا المندوب بعد')
            else ...[
              ClipRRect(borderRadius: BorderRadius.circular(16), child: WazeMap(lat: s.lat, lng: s.lng, height: 340)),
              const SizedBox(height: 8),
              Text('آخر تحديث: ${_ago(s.at)}', style: const TextStyle(color: DepoColors.muted)),
            ],
            if (o != null) ...[
              const SectionTitle('الطلب اللي بيده'),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${o.id} • ${app.storeById(o.storeId)?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('إلى: ${o.customerName} — ${o.address}', style: const TextStyle(fontSize: 12)),
                  Text('المبلغ: ${iqd(o.total)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  if (o.custLat != 0 && s != null)
                    Text(
                      'باقي تقريباً ${((app.distanceBetween(s.lat, s.lng, o.custLat, o.custLng)) * 10).round() / 10} كم للزبون',
                      style: const TextStyle(fontSize: 12, color: DepoColors.dark, fontWeight: FontWeight.w800),
                    ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}
