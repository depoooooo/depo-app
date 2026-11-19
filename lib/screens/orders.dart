import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/depo_refresh.dart';
import 'auth.dart';

/// طلباتي
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = app.myOrders;
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي'), automaticallyImplyLeading: false),
      body: DepoRefresh(
        onRefresh: app.refreshFromServer,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (!app.loggedIn) ...[
            const EmptyState(icon: Icons.receipt_long_outlined, text: 'سجّل حتى تشوف طلباتك'),
            FilledButton(onPressed: () => ensureLoggedIn(context), child: const Text('تسجيل الدخول')),
          ] else if (list.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, text: 'بعدك ما طلبت شي')
          else
            for (final o in list) OrderTile(order: o, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)))),
        ],
        ),
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final Widget? trailing;
  const OrderTile({super.key, required this.order, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final s = app.storeById(order.storeId);
    final open = order.isOpen;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Badge2(orderStatusNames[order.status]!, bg: open ? DepoColors.brand : DepoColors.soft),
          const Spacer(),
          Text(timeAgo(order.createdAt), style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
        ]),
        const SizedBox(height: 6),
        Text(s?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(order.lines.map((l) => '${l.title} ×${l.qty}').join('، '), style: const TextStyle(fontSize: 13, color: DepoColors.muted)),
        const SizedBox(height: 4),
        Row(children: [
          Text(iqd(order.total), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Text(order.pickup ? '• استلام ذاتي' : '• توصيل', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
        ]),
        if (trailing != null) ...[const SizedBox(height: 8), trailing!],
      ]),
    );
  }
}

/// تتبع الطلب
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final o = app.orderById(orderId);
        if (o == null) return const Scaffold(body: Center(child: Text('الطلب مو موجود')));
        final s = app.storeById(o.storeId);
        final steps = o.pickup
            ? [OrderStatus.placed, OrderStatus.accepted, OrderStatus.preparing, OrderStatus.ready, OrderStatus.delivered]
            : [OrderStatus.placed, OrderStatus.accepted, OrderStatus.preparing, OrderStatus.ready, OrderStatus.onTheWay, OrderStatus.delivered];
        final idx = steps.indexOf(o.status);
        final failed = o.status == OrderStatus.rejected || o.status == OrderStatus.cancelled;
        return Scaffold(
          appBar: AppBar(title: Text('طلب #${o.id}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (failed)
                    Text('${orderStatusNames[o.status]}${o.rejectReason.isEmpty ? '' : ' — ${o.rejectReason}'}',
                        style: const TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w800))
                  else ...[
                    Text(o.status == OrderStatus.delivered ? 'وصل الطلب، بالعافية!' : (o.pickup ? 'استلام من المحل' : 'الوصول المتوقع خلال 20–40 دقيقة'),
                        style: const TextStyle(color: DepoColors.muted)),
                    const SizedBox(height: 12),
                    Row(children: [
                      for (var i = 0; i < steps.length; i++)
                        Expanded(
                          child: Column(children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: i <= idx ? DepoColors.dark : DepoColors.line,
                              child: i <= idx ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 4),
                            Text(orderStatusNames[steps[i]]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, fontWeight: i <= idx ? FontWeight.w800 : FontWeight.w500, color: i <= idx ? DepoColors.ink : DepoColors.muted)),
                          ]),
                        ),
                    ]),
                  ],
                ]),
              ),
              if (!failed && o.status != OrderStatus.delivered)
                AppCard(
                  child: Column(children: [
                    const Text('رمز الاستلام', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text(o.pickupCode,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8, color: DepoColors.dark)),
                    Text(o.pickup ? 'اعرضه للمحل وقت الاستلام' : 'اعرضه للمندوب وقت التسليم', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                    TextButton.icon(
                      onPressed: () => toast(context, 'دز الرمز ${o.pickupCode} لصديقك حتى يستلم بدالك'),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('خلّي صديقك يستلم'),
                    ),
                  ]),
                ),
              if (o.courierPhone != null && o.status == OrderStatus.onTheWay)
                AppCard(
                  child: Row(children: [
                    const CircleAvatar(backgroundColor: DepoColors.soft, child: Icon(Icons.delivery_dining, color: DepoColors.dark)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('المندوب بالطريق إلك', style: TextStyle(fontWeight: FontWeight.w800))),
                    IconButton.filled(tooltip: 'اتصل بالمندوب', onPressed: () => toast(context, 'الاتصال عبر التطبيق يتفعل ويه Firebase'), icon: const Icon(Icons.phone)),
                  ]),
                ),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final l in o.lines)
                    Row(children: [Expanded(child: Text('${l.title} ×${l.qty}')), Text(iqd(l.price * l.qty))]),
                  Row(children: [const Expanded(child: Text('التوصيل')), Text(o.deliveryFee == 0 ? 'مجاني' : iqd(o.deliveryFee))]),
                  const Divider(),
                  Row(children: [
                    const Expanded(child: Text('المجموع — نقداً عند الاستلام', style: TextStyle(fontWeight: FontWeight.w900))),
                    Text(iqd(o.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  Text('وفّرت ${iqd(o.originalTotal - o.itemsTotal)}', style: const TextStyle(color: DepoColors.success, fontWeight: FontWeight.w700)),
                  if (!o.pickup && o.address.isNotEmpty) Text('العنوان: ${o.address}', style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
                ]),
              ),
              if (o.status == OrderStatus.placed && o.customerPhone == app.currentPhone)
                OutlinedButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('تلغي الطلب؟'),
                        content: const Text('تكدر تلغي بس قبل ما يقبله المحل.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('لا')),
                          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('إلغاء الطلب')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    final cur = app.orderById(o.id);
                    if (cur == null || cur.status != OrderStatus.placed) {
                      if (context.mounted) toast(context, 'المحل قبل الطلب، ما ينلغى هسه. تواصل ويه الدعم.');
                      return;
                    }
                    app.setStatus(cur, OrderStatus.cancelled, reason: 'ألغاه الزبون');
                  },
                  child: const Text('إلغاء الطلب'),
                ),
              if (o.status == OrderStatus.delivered && o.rating == 0 && o.customerPhone == app.currentPhone) ...[
                const SizedBox(height: 8),
                const Text('شلون كان الطلب؟', style: TextStyle(fontWeight: FontWeight.w900)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i نجوم',
                      onPressed: () {
                        app.rateOrder(o, i);
                        toast(context, 'شكراً على تقييمك!');
                      },
                      icon: const Icon(Icons.star_rounded, color: DepoColors.accent, size: 36),
                    ),
                ]),
              ],
              if (o.rating > 0) Center(child: Text('قيّمت الطلب ${'★' * o.rating}', style: const TextStyle(color: DepoColors.accent, fontSize: 18))),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintScreen(order: o))),
                icon: const Icon(Icons.report_outlined),
                label: const Text('عندي مشكلة بالطلب'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ComplaintScreen extends StatefulWidget {
  final Order order;
  const ComplaintScreen({super.key, required this.order});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  static const types = ['ناقص', 'تالف', 'منتهي الصلاحية / مشكلة صحية', 'متأخر', 'أخرى'];
  String type = types.first;
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مشكلة بالطلب #${widget.order.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('نوع المشكلة', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in types) ChoiceChip(label: Text(t), selected: type == t, onSelected: (_) => setState(() => type = t)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: text, maxLines: 4, decoration: const InputDecoration(labelText: 'اشرح المشكلة')),
          const SizedBox(height: 8),
          if (type.contains('صحية'))
            const Text('الشكاوى الصحية تنعالج خلال ساعتين والعرض ينشال فوراً.', style: TextStyle(color: DepoColors.danger, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (text.text.trim().length < 5 && type == 'أخرى') {
                toast(context, 'اشرح المشكلة شوية');
                return;
              }
              app.addComplaint(o: widget.order, type: type, text: text.text.trim());
              toast(context, 'وصلت شكواك، راح نتواصل وياك');
              Navigator.pop(context);
            },
            child: const Text('أرسل'),
          ),
        ],
      ),
    );
  }
}
