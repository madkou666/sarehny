import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_theme.dart';
import 'public_message_screen.dart';

enum NativeSitePage { home, about, blog, article, profile, contact }

class NativeSiteScreen extends StatefulWidget {
  const NativeSiteScreen({
    super.key,
    required this.api,
    required this.page,
    this.username,
    this.articleId,
  });

  final ApiClient api;
  final NativeSitePage page;
  final String? username;
  final int? articleId;

  @override
  State<NativeSiteScreen> createState() => _NativeSiteScreenState();
}

class _NativeSiteScreenState extends State<NativeSiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late Future<Map<String, dynamic>> _content;
  bool _sending = false;
  bool _sent = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _content = _loadContent();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadContent() {
    switch (widget.page) {
      case NativeSitePage.home:
        return widget.api.siteHome();
      case NativeSitePage.about:
        return widget.api.siteAbout();
      case NativeSitePage.blog:
        return widget.api.blogPosts();
      case NativeSitePage.article:
        final id = widget.articleId;
        if (id == null || id < 1) throw const ApiException('معرّف المقال غير صالح.');
        return widget.api.blogPost(id);
      case NativeSitePage.profile:
        final username = widget.username?.trim() ?? '';
        return widget.api.publicProfile(username);
      case NativeSitePage.contact:
        return Future<Map<String, dynamic>>.value(const {});
    }
  }

  String get _title => switch (widget.page) {
        NativeSitePage.home => 'أسرار',
        NativeSitePage.about => 'من نحن',
        NativeSitePage.blog => 'المدونة',
        NativeSitePage.article => 'المقال',
        NativeSitePage.profile => 'الملف العام',
        NativeSitePage.contact => 'اتصل بنا',
      };

  Future<void> _refresh() async {
    setState(() => _content = _loadContent());
    try {
      await _content;
    } catch (_) {}
  }

  Future<void> _sendContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _sent = false;
      _submitError = null;
    });
    try {
      await widget.api.sendContactMessage(
        name: _name.text.trim(),
        email: _email.text.trim(),
        subject: _subject.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
      _formKey.currentState!.reset();
      _name.clear();
      _email.clear();
      _subject.clear();
      _body.clear();
    } on ApiException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openArticle(int id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeSiteScreen(
        api: widget.api,
        page: NativeSitePage.article,
        articleId: id,
      ),
    ));
  }

  void _openSendMessage(String username) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublicMessageScreen(api: widget.api, initialUsername: username),
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text(_title)),
          body: widget.page == NativeSitePage.contact
              ? _contactBody()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _content,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const ListView(
                          physics: AlwaysScrollableScrollPhysics(),
                          children: [SizedBox(height: 200), Center(child: CircularProgressIndicator())],
                        );
                      }
                      if (snapshot.hasError) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(28),
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 12),
                            Text('تعذّر تحميل المحتوى', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(snapshot.error.toString(), textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            Center(child: FilledButton.tonal(onPressed: _refresh, child: const Text('إعادة المحاولة'))),
                          ],
                        );
                      }
                      final data = snapshot.data ?? const <String, dynamic>{};
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: _buildPage(data),
                      );
                    },
                  ),
                ),
        ),
      );

  List<Widget> _buildPage(Map<String, dynamic> data) => switch (widget.page) {
        NativeSitePage.home => _home(data),
        NativeSitePage.about => _about(data),
        NativeSitePage.blog => _blog(data),
        NativeSitePage.article => _article(data),
        NativeSitePage.profile => _profile(data),
        NativeSitePage.contact => const [],
      };

  List<Widget> _home(Map<String, dynamic> data) {
    final posts = (data['posts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((post) => Map<String, dynamic>.from(post))
        .toList();
    final theme = Theme.of(context);
    final palette = theme.extension<SarehnyPalette>()!;
    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [palette.primary, palette.secondary], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['title'] as String? ?? 'مساحة للكلام الذي لم يُقَل', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 10),
          Text(data['lead'] as String? ?? '', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PublicMessageScreen(api: widget.api))),
            icon: const Icon(Icons.send_rounded),
            label: const Text('أرسل رسالة مجهولة'),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Text('مساحة آمنة، وكلام حقيقي', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('أنشئ رابطك الخاص، شاركه مع من تحب، واستقبل كلماتهم الصادقة في صندوق لا يراه سواك.'),
      const SizedBox(height: 18),
      const _FeatureTile(icon: Icons.lock_outline_rounded, title: 'رسائل وأسئلة مجهولة', body: 'استقبل كلمات صادقة وأسئلة من أصحاب رابطك.'),
      const SizedBox(height: 10),
      const _FeatureTile(icon: Icons.favorite_border_rounded, title: 'صندوق منظم', body: 'احفظ الرسائل المفضلة، وأجب عن الأسئلة أو أبلغ عن الإساءة.'),
      const SizedBox(height: 24),
      Text('من المدونة', style: theme.textTheme.titleLarge),
      const SizedBox(height: 10),
      if (posts.isEmpty) const Text('لا توجد مقالات منشورة حاليًا.') else ...posts.map((post) => _postCard(post)),
    ];
  }

  List<Widget> _about(Map<String, dynamic> data) {
    final body = (data['body'] as String? ?? '').trim();
    final paragraphs = body.isEmpty ? <String>[] : body.split(RegExp(r'\n\s*\n')).where((part) => part.trim().isNotEmpty).toList();
    return [
      _PageHero(kicker: 'تعرّف علينا', title: data['title'] as String? ?? 'مساحة تجعل الصراحة أسهل', body: data['intro'] as String? ?? ''),
      const SizedBox(height: 22),
      Text('الفكرة', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      const Text('أحيانًا يصعب علينا قول ما نشعر به مباشرة. هنا يمكنك فتح باب للكلام: أنشئ رابطك، شاركه، واقرأ ما يريد الآخرون قوله لك دون أن تظهر هويتهم.'),
      for (final paragraph in paragraphs) ...[
        const SizedBox(height: 12),
        Text(paragraph.trim(), style: Theme.of(context).textTheme.bodyLarge),
      ],
    ];
  }

  List<Widget> _blog(Map<String, dynamic> data) {
    final posts = (data['posts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((post) => Map<String, dynamic>.from(post))
        .toList();
    return [
      const _PageHero(kicker: 'من أسرار / المدونة', title: 'أفكار تستحق أن تُقال.', body: 'مساحة للحكايات والأفكار حول الصراحة والتواصل.'),
      const SizedBox(height: 22),
      Text('أحدث المقالات', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (posts.isEmpty)
        const _EmptyContent(title: 'القصص قادمة قريبًا', message: 'لا توجد مقالات منشورة حاليًا.')
      else
        ...posts.map((post) => _postCard(post)),
    ];
  }

  List<Widget> _article(Map<String, dynamic> data) {
    final post = Map<String, dynamic>.from(data['post'] as Map? ?? const {});
    final body = (post['body'] as String? ?? '').trim();
    final paragraphs = body.split(RegExp(r'\n\s*\n')).where((part) => part.trim().isNotEmpty).toList();
    return [
      Text(post['title'] as String? ?? '', style: Theme.of(context).textTheme.headlineMedium),
      if ((post['excerpt'] as String? ?? '').isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(post['excerpt'] as String, style: Theme.of(context).textTheme.bodyLarge),
      ],
      const SizedBox(height: 8),
      Text(_dateLabel(post['created_at'] as String?), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
      for (final paragraph in paragraphs) ...[
        Text(paragraph.trim(), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 14),
      ],
      TextButton.icon(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('العودة إلى المدونة')),
    ];
  }

  List<Widget> _profile(Map<String, dynamic> data) {
    final profile = Map<String, dynamic>.from(data['profile'] as Map? ?? const {});
    final answers = (data['answers'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((answer) => Map<String, dynamic>.from(answer))
        .toList();
    final username = profile['username'] as String? ?? widget.username ?? '';
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(
              radius: 36,
              foregroundImage: profile['avatar_url'] is String ? NetworkImage(profile['avatar_url'] as String) : null,
              child: profile['avatar_url'] is String ? null : const Icon(Icons.person_outline_rounded, size: 30),
            ),
            const SizedBox(height: 10),
            Text(profile['display_name'] as String? ?? '', style: Theme.of(context).textTheme.titleLarge),
            Text('@$username', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => _openSendMessage(username), icon: const Icon(Icons.send_rounded), label: const Text('أرسل رسالة مجهولة')),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      Text('إجابات منشورة', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      if (answers.isEmpty)
        const _EmptyContent(title: 'لا توجد إجابات منشورة', message: 'ستظهر هنا الإجابات التي اختار صاحب الحساب نشرها.')
      else
        ...answers.map((answer) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('السؤال', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(answer['question'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
                  const Divider(height: 24),
                  Text('الإجابة', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 6),
                  Text(answer['answer'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
                ]),
              ),
            )),
    ];
  }

  Widget _postCard(Map<String, dynamic> post) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openArticle((post['id'] as num?)?.toInt() ?? 0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_dateLabel(post['created_at'] as String?), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 7),
              Text(post['title'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(post['excerpt'] as String? ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              const Align(alignment: AlignmentDirectional.centerStart, child: Text('اقرأ المقال')),
            ]),
          ),
        ),
      );

  Widget _contactBody() => SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 30), children: [
            Text('خلّينا نسمعك.', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('لديك فكرة أو سؤال أو ملاحظة؟ اكتب لنا وسنقرأ رسالتك.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            TextFormField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الاسم'), validator: (value) => (value?.trim().length ?? 0) < 2 ? 'الاسم يجب أن يكون حرفين على الأقل.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _email, maxLength: 190, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), validator: (value) => value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? 'أدخل بريدًا إلكترونيًا صحيحًا.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _subject, maxLength: 180, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الموضوع'), validator: (value) => (value?.trim().length ?? 0) < 3 ? 'الموضوع يجب أن يكون ٣ أحرف على الأقل.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _body, minLines: 5, maxLines: 9, maxLength: 5000, decoration: const InputDecoration(labelText: 'رسالتك', alignLabelWithHint: true), validator: (value) => (value?.trim().length ?? 0) < 10 ? 'الرسالة يجب أن تكون ١٠ أحرف على الأقل.' : null),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(_submitError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_sent) ...[
              const SizedBox(height: 8),
              Text('وصلت رسالتك بنجاح. شكرًا لتواصلك معنا.', style: TextStyle(color: Theme.of(context).extension<SarehnyPalette>()!.success)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _sending ? null : _sendContact, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_sending ? 'جارٍ الإرسال' : 'أرسل الرسالة')),
          ]),
        ),
      );

  String _dateLabel(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class NativeFeatureUnavailableScreen extends StatelessWidget {
  const NativeFeatureUnavailableScreen({super.key, required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.construction_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('هذه الميزة لم تُربط بعد بواجهة Flutter أصلية', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(detail, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                const Text('لن نفتح الموقع أو WebView لتنفيذها. ستظهر هنا بعد إضافة API آمن واختباره.', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}

class _PageHero extends StatelessWidget {
  const _PageHero({required this.kicker, required this.title, required this.body});
  final String kicker;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(kicker, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ]);
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(body),
          isThreeLine: true,
        ),
      );
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.primary, size: 30),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      );
}
