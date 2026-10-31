import 'package:fresh_bites_api/services/password_service.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordService', () {
    test('hashes passwords and verifies only the matching password', () {
      final hash = PasswordService.hash('correct horse battery');

      expect(hash, isNot('correct horse battery'));
      expect(PasswordService.verify('correct horse battery', hash), isTrue);
      expect(PasswordService.verify('incorrect password', hash), isFalse);
    });

    test('rejects passwords outside supported bounds', () {
      expect(PasswordService.isValid('short7'), isFalse);
      expect(PasswordService.isValid('a' * 73), isFalse);
      expect(PasswordService.isSupportedLength('é' * 37), isFalse);
    });
  });
}
