import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_SupportMessage> _messages = [];
  Timer? _pollTimer;
  int _lastMessageId = 0;
  bool _loading = true;
  bool _sending = false;
  bool _polling = false;
  bool _needsLogin = false;
  String _status = 'none';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_poll());
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => unawaited(_poll()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final data = await widget.api.supportPoll(after: _lastMessageId);
      if (!mounted) return;
      _mergeMessages(data['messages']);
      setState(() {
        _status = data['status'] as String? ?? 'none';
        _needsLogin = data['need_name'] == true;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } finally {
      _polling = false;
    }
  }

  void _mergeMessages(Object? value) {
    if (value is! List) return;
    final existingIds = _messages.map((message) => message.id).toSet();
    for (final item in value.whereType<Map>()) {
      final message = _SupportMessage.fromJson(Map<String, dynamic>.from(item));
      if (message.id > 0 && existingIds.add(message.id)) {
        _messages.add(message);
        if (message.id > _lastMessageId) _lastMessageId = message.id;
      }
    }
    _messages.sort((left, right) => left.id.compareTo(right.id));
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || body.length > 2000 || _sending || _needsLogin) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final data = await widget.api.supportSend(body, after: _lastMessageId);
      if (!mounted) return;
      _mergeMessages(data['messages']);
      setState(() {
        _status = data['status'] as String? ?? 'open';
        _error = null;
      });
      _controller.clear();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('الدعم الفني'),
            actions: [
              IconButton(
                tooltip: 'تحديث المحادثة',
                onPressed: _poll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _ConversationStatus(status: _status, needsLogin: _needsLogin),
                if (_error != null)
                  MaterialBanner(
                    content: Text(_error!),
                    leading: const Icon(Icons.info_outline_rounded),
                    actions: [
                      TextButton(onPressed: _poll, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                Expanded(child: _conversation()),
                _composer(),
              ],
            ),
          ),
        ),
      );

  Widget _conversation() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: const [
          SizedBox(height: 40),
          Icon(Icons.support_agent_rounded, size: 48),
          SizedBox(height: 14),
          Text('مرحبًا بك في الدعم الفني', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('اكتب استفسارك، وسنواصل المحادثة هنا باستخدام محادثة حسابك على الموقع.', textAlign: TextAlign.center),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _poll,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
      ),
    );
  }

  Widget _composer() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                readOnly: _needsLogin,
                decoration: InputDecoration(
                  hintText: _needsLogin ? 'سجّل الدخول مجددًا لمراسلة الدعم' : 'اكتب رسالتك للدعم',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                tooltip: 'إرسال الرسالة',
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      );
}

class _ConversationStatus extends StatelessWidget {
  const _ConversationStatus({required this.status, required this.needsLogin});

  final String status;
  final bool needsLogin;

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';
    final color = needsLogin
        ? Theme.of(context).colorScheme.error
        : isClosed
            ? Theme.of(context).colorScheme.outline
            : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(needsLogin ? Icons.lock_outline_rounded : isClosed ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              needsLogin
                  ? 'انتهت جلسة الدخول؛ ارجع لتسجيل الدخول قبل بدء محادثة دعم.'
                  : status == 'none'
                      ? 'محادثة خاصة مع فريق الدعم'
                      : isClosed
                          ? 'المحادثة مغلقة — يمكنك إرسال رسالة لإعادة فتحها'
                          : 'المحادثة مفتوحة',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final fromSupport = message.sender == 'admin';
    final colors = Theme.of(context).colorScheme;
    final background = fromSupport ? colors.surfaceContainerHighest : colors.primaryContainer;
    final foreground = fromSupport ? colors.onSurface : colors.onPrimaryContainer;
    return Align(
      alignment: fromSupport ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fromSupport ? 'فريق الدعم' : 'أنت', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.75))),
            const SizedBox(height: 4),
            Text(message.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground)),
            const SizedBox(height: 5),
            Text(message.createdAt, textDirection: TextDirection.ltr, textAlign: TextAlign.end, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.65))),
          ],
        ),
      ),
    );
  }
}

class _SupportMessage {
  const _SupportMessage({required this.id, required this.sender, required this.body, required this.createdAt});

  final int id;
  final String sender;
  final String body;
  final String createdAt;

  factory _SupportMessage.fromJson(Map<String, dynamic> json) => _SupportMessage(
        id: (json['id'] as num?)?.toInt() ?? int.tryParse('${json['id']}') ?? 0,
        sender: json['sender'] as String? ?? 'user',
        body: json['body'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}
