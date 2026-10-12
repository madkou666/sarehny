import 'dart:async';

import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/message_card.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  final List<InboxMessage> _messages = [];
  Map<String, dynamic> _stats = {};
  String _filter = 'all';
  String _query = '';
  String _sort = 'newest';
  Timer? _searchDebounce;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestVersion = 0;
  String? _cursorCreatedAt;
  int? _cursorId;
  String? _error;
  static const _filters = <(String, String)>[( 'all', 'الكل'), ('questions', 'الأسئلة'), ('pending', 'بانتظار الإجابة'), ('published', 'منشورة'), ('favorites', 'المفضلة')];

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() { super.initState(); _scroll.addListener(_maybeLoadMore); _load(); }
  @override
  void dispose() { _searchDebounce?.cancel(); _searchController.dispose(); _scroll.dispose(); super.dispose(); }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == _query) return;
      _query = query;
      _load(refresh: true);
    });
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 240 && !_loading && !_loadingMore && _hasMore) _loadMore();
  }

  Future<void> _load({bool refresh = false}) async {
    final requestVersion = ++_requestVersion;
    final requestedFilter = _filter;
    final requestedQuery = _query;
    final requestedSort = _sort;
    if (refresh) {
      _messages.clear();
      _page = 1;
      _hasMore = false;
      _cursorCreatedAt = null;
      _cursorId = null;
    }
    setState(() { _loading = _messages.isEmpty; _loadingMore = false; _error = null; });
    try {
      final result = await widget.api.inbox(filter: requestedFilter, sort: requestedSort, query: requestedQuery, page: 1);
      final items = (result['messages'] as List<dynamic>? ?? []).map((value) => InboxMessage.fromJson(Map<String, dynamic>.from(value as Map))).toList();
      if (!mounted || requestVersion != _requestVersion || requestedFilter != _filter || requestedQuery != _query || requestedSort != _sort) return;
      setState(() {
        _messages..clear()..addAll(items);
        _stats = Map<String, dynamic>.from(result['stats'] as Map? ?? {});
        final pagination = result['pagination'] as Map?;
        _hasMore = pagination?['has_more'] == true;
        final cursor = pagination?['next_cursor'] as Map?;
        _cursorCreatedAt = cursor?['created_at'] as String?;
        _cursorId = (cursor?['id'] as num?)?.toInt();
        _page = 1;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted && requestVersion == _requestVersion && requestedFilter == _filter && requestedQuery == _query && requestedSort == _sort) {
        setState(() { _error = error is ApiException ? error.message : 'تعذّر قراءة الرسائل من الخادم.'; _loading = false; });
      }
    }
  }

  Future<void> _loadMore() async {
    final requestVersion = _requestVersion;
    final requestedFilter = _filter;
    final requestedQuery = _query;
    final requestedSort = _sort;
    final requestedPage = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.api.inbox(
        filter: requestedFilter,
        sort: requestedSort,
        query: requestedQuery,
        page: requestedPage,
        beforeCreatedAt: _cursorCreatedAt,
        beforeId: _cursorId,
      );
      final items = (result['messages'] as List<dynamic>? ?? []).map((value) => InboxMessage.fromJson(Map<String, dynamic>.from(value as Map))).toList();
      if (!mounted || requestVersion != _requestVersion || requestedFilter != _filter || requestedQuery != _query || requestedSort != _sort) return;
      setState(() {
        final existingIds = _messages.map((message) => message.id).toSet();
        _messages.addAll(items.where((message) => existingIds.add(message.id)));
        final pagination = result['pagination'] as Map?;
        _page = (pagination?['page'] as num?)?.toInt() ?? requestedPage;
        _hasMore = pagination?['has_more'] == true;
        final cursor = pagination?['next_cursor'] as Map?;
        _cursorCreatedAt = cursor?['created_at'] as String?;
        _cursorId = (cursor?['id'] as num?)?.toInt();
      });
    } on Object catch (error) {
      if (mounted && requestVersion == _requestVersion && requestedFilter == _filter && requestedQuery == _query && requestedSort == _sort) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is ApiException ? error.message : 'تعذّر تحميل الرسائل الأقدم.')));
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) setState(() => _loadingMore = false);
    }
  }

  Future<void> _action(InboxMessage message, String action, Map<String, String> fields) async {
    try {
      await widget.api.messageAction(message.id, action, fields: fields);
      if (!mounted) return;
      final label = switch (action) { 'delete' => 'حُذفت الرسالة', 'report' => 'تم إرسال البلاغ', 'favorite' => 'تم تحديث المفضلة', 'unpublish' => 'تم إخفاء الإجابة المنشورة', _ => 'تم حفظ الإجابة' };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
      await _load(refresh: true);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  int _count(String key) => (_stats[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final palette = theme.extension<SarehnyPalette>()!;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('صندوق الرسائل'), actions: [
        IconButton(tooltip: 'تحديث الرسائل', onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(onRefresh: () => _load(refresh: true), child: CustomScrollView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.primary, palette.secondary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مساحتك الخاصة', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.75), fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(
                        'رسائل بصراحة،\nوبلا أسماء.',
                        style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, height: 1.35, fontSize: 21),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.onPrimary.withValues(alpha: 0.75)),
                          const SizedBox(width: 6),
                          Text('صندوق خاص وآمن', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.75), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, .16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_unread_outlined, color: theme.colorScheme.onPrimary, size: 27),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _StatTile(label: 'كل الرسائل', value: _count('total'), icon: Icons.inbox_outlined)), const SizedBox(width: 9), Expanded(child: _StatTile(label: 'اليوم', value: _count('today'), icon: Icons.bolt_rounded)), const SizedBox(width: 9), Expanded(child: _StatTile(label: 'أسئلة معلّقة', value: _count('pending'), icon: Icons.help_outline_rounded))]),
          const SizedBox(height: 20),
          Text('رسائلك الأخيرة', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث في نص الرسالة أو الإجابة',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'مسح البحث',
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _sort,
            decoration: const InputDecoration(labelText: 'ترتيب الرسائل'),
            items: const [
              DropdownMenuItem(value: 'newest', child: Text('الأحدث أولًا')),
              DropdownMenuItem(value: 'oldest', child: Text('الأقدم أولًا')),
            ],
            onChanged: (value) {
              if (value == null || value == _sort) return;
              setState(() => _sort = value);
              _load(refresh: true);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _filters.length, separatorBuilder: (_, index) => const SizedBox(width: 8), itemBuilder: (context, index) {
            final (value, label) = _filters[index];
            final selected = _filter == value;
            return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) { setState(() => _filter = value); _load(refresh: true); }, showCheckmark: false, selectedColor: palette.primarySoft, labelStyle: TextStyle(color: selected ? palette.primary : palette.muted, fontWeight: FontWeight.w700));
          })),
        ]))),
        if (_loading) const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
        else if (_error != null) SliverFillRemaining(hasScrollBody: false, child: _EmptyState(icon: Icons.cloud_off_outlined, title: 'تعذّر تحميل الرسائل', message: _error!, actionLabel: 'أعد المحاولة', onAction: () => _load(refresh: true)))
        else if (_messages.isEmpty) SliverFillRemaining(hasScrollBody: false, child: _EmptyState(
          icon: Icons.mark_email_read_outlined,
          title: _query.isNotEmpty ? 'لا توجد نتائج مطابقة' : 'صندوقك هادئ الآن',
          message: _query.isNotEmpty ? 'جرّب عبارة بحث أخرى أو امسح البحث لعرض رسائلك.' : 'عندما تصلك ��سالة مجهولة، ستظهر هنا. شارك رابطك الشخصي ليبدأ أصدقاؤك بالكتابة.',
        ))
        else SliverPadding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 28), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
          if (index == _messages.length) return _loadingMore ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())) : const SizedBox(height: 16);
          final message = _messages[index];
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: MessageCard(key: ValueKey(message.id), api: widget.api, message: message, onAction: (action, fields) => _action(message, action, fields)));
        }, childCount: _messages.length + (_hasMore || _loadingMore ? 1 : 0))))
      ])),
    ));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) { final theme = Theme.of(context); final palette = theme.extension<SarehnyPalette>()!; return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13), decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: palette.line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 17, color: palette.primary), const SizedBox(height: 8), Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10))])); }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) { final theme = Theme.of(context); final palette = theme.extension<SarehnyPalette>()!; return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(28), children: [const SizedBox(height: 36), Icon(icon, size: 48, color: palette.primary), const SizedBox(height: 14), Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)), if (actionLabel != null && onAction != null) ...[const SizedBox(height: 18), Center(child: FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)))] ]); }
}
