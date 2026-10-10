import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';

class MessageCard extends StatelessWidget {
  const MessageCard({super.key, required this.message, required this.onAction});
  final InboxMessage message;
  final Future<void> Function(String action, Map<String, String> fields) onAction;

  String _dateLabel(DateTime date) {
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return 'الآن';
    if (age.inHours < 1) return 'منذ ${age.inMinutes} دقيقة';
    if (age.inDays < 1) return 'منذ ${age.inHours} ساعة';
    if (age.inDays == 1) return 'أمس';
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _answer(BuildContext context) async {
    final controller = TextEditingController(text: message.answer ?? '');
    final answer = await showDialog<String>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('إجابة السؤال'), content: TextField(controller: controller, minLines: 3, maxLines: 6, maxLength: 2000, decoration: const InputDecoration(hintText: 'اكتب إجابتك هنا...')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ الإجابة'))])));
    controller.dispose();
    if (answer != null && answer.length >= 2) await onAction('answer', {'answer': answer});
  }

  Future<void> _select(BuildContext context, String action) async {
    if (action == 'answer') return _answer(context);
    if (action == 'delete') {
      final confirm = await showDialog<bool>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('حذف الرسالة؟'), content: const Text('سيتم حذفها من صندوقك نهائيًا.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))])));
      if (confirm != true) return;
    }
    if (action == 'report') return onAction('report', {'reason': 'other', 'details': ''});
    await onAction(action, const {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: SarehnyColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(message.isQuestion ? Icons.help_outline_rounded : Icons.lock_outline_rounded, color: SarehnyColors.primary, size: 19)),
        const SizedBox(width: 10),
        Text(message.isQuestion ? 'سؤال مجهول' : 'رسالة مجهولة', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)),
        const Spacer(), Text(_dateLabel(message.createdAt), style: theme.textTheme.bodySmall),
      ]),
      const SizedBox(height: 15),
      if (message.isVoice) Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: SarehnyColors.canvas, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.graphic_eq_rounded, color: SarehnyColors.primary), const SizedBox(width: 8), Expanded(child: Text('رسالة صوتية${message.audioSeconds == null ? '' : ' · ${message.audioSeconds} ثانية'}', style: theme.textTheme.bodyMedium))])),
      if (!message.isVoice || message.body != '🎙️ رسالة صوتية') Text(message.body, style: theme.textTheme.bodyLarge),
      if (message.answer != null && message.answer!.isNotEmpty) ...[const SizedBox(height: 14), Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFF4F1FB), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('إجابتك المنشورة', style: theme.textTheme.labelMedium?.copyWith(color: SarehnyColors.primary, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(message.answer!, style: theme.textTheme.bodyMedium)]))],
      const SizedBox(height: 12),
      Row(children: [
        IconButton(tooltip: message.isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة', onPressed: () => _select(context, 'favorite'), icon: Icon(message.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, color: message.isFavorite ? const Color(0xFFCC9B38) : SarehnyColors.muted)),
        if (message.isQuestion) TextButton.icon(onPressed: () => _select(context, 'answer'), icon: const Icon(Icons.reply_rounded, size: 18), label: Text(message.answer == null ? 'أجب' : 'تعديل الإجابة')),
        const Spacer(),
        PopupMenuButton<String>(tooltip: 'إجراءات الرسالة', onSelected: (action) => _select(context, action), itemBuilder: (context) => [const PopupMenuItem(value: 'report', child: Text('إبلاغ')), const PopupMenuItem(value: 'delete', child: Text('حذف الرسالة'))], icon: const Icon(Icons.more_horiz_rounded, color: SarehnyColors.muted)),
      ]),
    ])));
  }
}
