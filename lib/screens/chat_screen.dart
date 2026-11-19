import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/debt_ui.dart';
import 'auth.dart';

/// يفتح محادثة الدعم مالتي
Future<void> openSupport(BuildContext context) async {
  if (!await ensureLoggedIn(context, reason: 'سجّل حتى تكدر تراسل الدعم') || !context.mounted) return;
  final c = app.myChat(kind: 'support');
  if (c != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.id)));
}

/// يفتح محادثة ويه محل
Future<void> openShopChat(BuildContext context, String storeId) async {
  if (!await ensureLoggedIn(context, reason: 'سجّل حتى تكدر تراسل المحل') || !context.mounted) return;
  if (app.ownsStore(storeId)) return toast(context, 'هذا محلك');
  final c = app.myChat(kind: 'shop', storeId: storeId);
  if (c != null) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.id)));
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send(Chat c) {
    if (input.text.trim().isEmpty) return;
    app.sendChat(c, input.text);
    input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = app.chatById(widget.chatId);
        if (c == null || !app.canSeeChat(c)) {
          return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.chat_bubble_outline, text: 'المحادثة مو موجودة'));
        }
        final staff = app.isStaffIn(c);
        if (_lastCount != c.messages.length) {
          _lastCount = c.messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            app.markChatRead(c);
            if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
          });
        }
        final store = c.storeId.isEmpty ? null : app.storeById(c.storeId);
        final title = staff
            ? (c.userName.isEmpty ? c.userPhone : c.userName)
            : (c.kind == 'support' ? 'دعم ديبو' : (store?.name ?? 'المحل'));
        return Scaffold(
          appBar: AppBar(
            title: Column(children: [
              Text(title),
              Text(
                staff ? c.userPhone : (c.kind == 'support' ? 'نرد عليك هنا بأقرب وقت' : 'محادثة ويه المحل'),
                style: const TextStyle(fontSize: 11, color: DepoColors.muted, fontWeight: FontWeight.w500),
              ),
            ]),
            actions: [
              if (staff && c.open)
                TextButton(onPressed: () => app.closeChat(c), child: const Text('إغلاق')),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: c.messages.isEmpty
                  ? EmptyState(
                      icon: Icons.support_agent,
                      text: c.kind == 'support'
                          ? 'اكتبلنا مشكلتك أو سؤالك: طلب، دفع، حساب، أو أي شي. فريق الدعم يرد عليك هنا.'
                          : 'اسأل المحل عن الأسعار أو حسابك أو أي شي.',
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: c.messages.length,
                      itemBuilder: (context, i) {
                        final m = c.messages[i];
                        final mine = m.staff == staff;
                        return Align(
                          alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: mine ? DepoColors.dark : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: mine ? null : Border.all(color: DepoColors.line),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.text, style: TextStyle(color: mine ? Colors.white : DepoColors.ink, height: 1.5)),
                              const SizedBox(height: 2),
                              Text(_time(m.at), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : DepoColors.muted)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: DepoColors.line))),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(hintText: 'اكتب رسالتك...', counterText: '', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(tooltip: 'إرسال', onPressed: () => _send(c), icon: const Icon(Icons.send_rounded)),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final today = DateTime.now();
    final hm = '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    return d.day == today.day && d.month == today.month ? hm : '${dateLabel(ms)} $hm';
  }
}

/// قائمة المحادثات (للدعم أو لصاحب المحل)
class ChatListView extends StatefulWidget {
  final List<Chat> Function() source;
  const ChatListView({super.key, required this.source});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  bool onlyOpen = true;

  @override
  Widget build(BuildContext context) {
    final all = widget.source();
    final list = onlyOpen ? all.where((c) => c.open).toList() : all;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        ChoiceChip(label: Text('المفتوحة (${all.where((c) => c.open).length})'), selected: onlyOpen, onSelected: (_) => setState(() => onlyOpen = true)),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('الكل'), selected: !onlyOpen, onSelected: (_) => setState(() => onlyOpen = false)),
      ]),
      const SizedBox(height: 10),
      if (list.isEmpty) const EmptyState(icon: Icons.forum_outlined, text: 'ماكو محادثات'),
      for (final c in list)
        AppCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: c.id))),
          child: Row(children: [
            CircleAvatar(backgroundColor: DepoColors.soft, child: Text((c.userName.isEmpty ? '؟' : c.userName).characters.first, style: const TextStyle(fontWeight: FontWeight.w900, color: DepoColors.dark))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.userName.isEmpty ? c.userPhone : c.userName, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(c.messages.isEmpty ? '' : c.messages.last.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: DepoColors.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(timeAgo(c.updatedAt), style: const TextStyle(fontSize: 11, color: DepoColors.muted)),
              if (c.unreadFor(staff: true) > 0) Badge2('${c.unreadFor(staff: true)}', bg: DepoColors.danger, fg: Colors.white)
              else if (!c.open) const Badge2('مغلقة', bg: DepoColors.soft, fg: DepoColors.muted),
            ]),
          ]),
        ),
    ]);
  }
}
