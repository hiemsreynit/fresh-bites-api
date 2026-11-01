import 'package:fresh_bites_api/services/password_service.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordService', () {
    test('hashes passwords and verifies only the matching password', () {
      const password = 'correct horse battery staple';
      final hash = PasswordService.hash(password);

      expect(hash, isNot(password));
      expect(PasswordService.verify(password, hash), isTrue);
      expect(PasswordService.verify('incorrect password', hash), isFalse);
    });

    test('rejects passwords outside supported bounds', () {
      expect(PasswordService.isValid('short'), isFalse);
      expect(PasswordService.isSupportedLength('x' * 73), isFalse);
      expect(PasswordService.isSupportedLength('x' * 72), isTrue);
    });
  });
}
