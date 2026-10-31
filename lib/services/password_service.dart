import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';

class PasswordService {
  static const minimumLength = 8;
  static const maximumBytes = 72;

  static bool isValid(String password) {
    return password.length >= minimumLength && isSupportedLength(password);
  }

  static bool isSupportedLength(String password) {
    return utf8.encode(password).length <= maximumBytes;
  }

  static String hash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
  }

  static bool verify(String password, String passwordHash) {
    try {
      return BCrypt.checkpw(password, passwordHash);
    } on ArgumentError {
      return false;
    }
  }
}
