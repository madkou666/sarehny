import 'models.dart';

String inboxCsv(List<InboxMessage> messages) {
  final rows = <List<String>>[
    ['رقم الرسالة', 'التاريخ', 'النوع', 'نص الرسالة', 'الإجابة', 'المفضلة'],
    ...messages.map((message) => [
          message.id.toString(),
          message.createdAt.toIso8601String(),
          message.isQuestion ? 'سؤال' : (message.isVoice ? 'رسالة صوتية' : 'رسالة'),
          message.body,
          message.answer ?? '',
          message.isFavorite ? 'نعم' : 'لا',
        ]),
  ];

  String escape(String value) {
    final normalized = value.replaceAll('"', '""');
    return '"$normalized"';
  }

  return '\uFEFF${rows.map((row) => row.map(escape).join(',')).join('\r\n')}\r\n';
}

String inboxCsvFileName(DateTime date) =>
    'sarehny-messages-${date.toIso8601String().substring(0, 10)}.csv';

bool canExportInboxCsv(int messageCount) => messageCount > 0;

bool isValidCsvFileName(String fileName) =>
    RegExp(r'^sarehny-messages-\d{4}-\d{2}-\d{2}\.csv$').hasMatch(fileName);

bool isCsvPayloadWithinLimit(String content) => content.length <= 2 * 1024 * 1024;

bool _containsFormulaPrefix(String value) =>
    value.startsWith('=') || value.startsWith('+') || value.startsWith('-') || value.startsWith('@');

String safeCsvCell(String value) {
  final protected = _containsFormulaPrefix(value) ? "'$value" : value;
  return '"${protected.replaceAll('"', '""')}"';
}

String safeInboxCsv(List<InboxMessage> messages) {
  final rows = <List<String>>[
    ['رقم الرسالة', 'التاريخ', 'النوع', 'نص الرسالة', 'الإجابة', 'المفضلة'],
    ...messages.map((message) => [
          message.id.toString(),
          message.createdAt.toIso8601String(),
          message.isQuestion ? 'سؤال' : (message.isVoice ? 'رسالة صوتية' : 'رسالة'),
          message.body,
          message.answer ?? '',
          message.isFavorite ? 'نعم' : 'لا',
        ]),
  ];

  return '\uFEFF${rows.map((row) => row.map(safeCsvCell).join(',')).join('\r\n')}\r\n';
}

bool canShareCsvPayload(String fileName, String content) =>
    isValidCsvFileName(fileName) && isCsvPayloadWithinLimit(content);

String normalizedCsvText(String content) => content.replaceAll('\r\n', '\n');
