import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/models.dart';

void main() {
  group('AppUser', () {
    test('parses the existing PHP account fields without exposing secrets', () {
      final user = AppUser.fromJson({
        'id': 42,
        'username': 'sara_99',
        'display_name': 'سارة',
        'email': 'sara@test.invalid',
        'public_url': '/sara_99',
        'avatar_url': null,
        'is_verified': true,
        'is_admin': true,
        'insights_enabled': false,
      });

      expect(user.id, 42);
      expect(user.username, 'sara_99');
      expect(user.publicUrl, '/sara_99');
      expect(user.isVerified, isTrue);
      expect(user.isAdmin, isTrue);
    });

    test('does not grant admin access when the server omits the role', () {
      final user = AppUser.fromJson({'id': 7, 'username': 'member'});

      expect(user.isAdmin, isFalse);
    });
  });

  group('InboxMessage', () {
    test('parses text messages and voice metadata', () {
      final message = InboxMessage.fromJson({
        'id': 7,
        'body': 'رسالة اختبار',
        'is_favorite': true,
        'is_question': false,
        'answer': null,
        'created_at': '2026-10-10 10:00:00',
        'is_voice': true,
        'audio_seconds': 12,
      });

      expect(message.id, 7);
      expect(message.body, 'رسالة اختبار');
      expect(message.isFavorite, isTrue);
      expect(message.isVoice, isTrue);
      expect(message.audioSeconds, 12);
    });
  });
}
