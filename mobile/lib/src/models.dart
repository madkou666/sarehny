class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.publicUrl,
    this.avatarUrl,
    this.isVerified = false,
    this.isAdmin = false,
    this.insightsEnabled = false,
  });

  final int id;
  final String username;
  final String displayName;
  final String email;
  final String publicUrl;
  final String? avatarUrl;
  final bool isVerified;
  final bool isAdmin;
  final bool insightsEnabled;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int? ?? 0,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        isAdmin: json['is_admin'] as bool? ?? false,
        insightsEnabled: json['insights_enabled'] as bool? ?? false,
      );
}

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.body,
    required this.isFavorite,
    required this.isQuestion,
    required this.createdAt,
    this.answer,
    this.isVoice = false,
    this.audioSeconds,
  });

  final int id;
  final String body;
  final bool isFavorite;
  final bool isQuestion;
  final DateTime createdAt;
  final String? answer;
  final bool isVoice;
  final int? audioSeconds;

  factory InboxMessage.fromJson(Map<String, dynamic> json) => InboxMessage(
        id: json['id'] as int? ?? 0,
        body: json['body'] as String? ?? '',
        isFavorite: json['is_favorite'] as bool? ?? false,
        isQuestion: json['is_question'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        answer: json['answer'] as String?,
        isVoice: json['is_voice'] as bool? ?? false,
        audioSeconds: json['audio_seconds'] as int?,
      );
}
