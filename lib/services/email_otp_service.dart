import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/user_repository.dart';

enum OtpVerificationResult {
  verified,
  invalid,
  expired,
  attemptsExceeded,
  alreadyVerified,
  userNotFound,
}

class EmailDeliveryException implements Exception {
  final String message;

  const EmailDeliveryException(this.message);

  @override
  String toString() => message;
}

class EmailOtpService {
  static const otpLifetime = Duration(minutes: 10);
  static const resendCooldown = Duration(minutes: 1);
  static const maxVerificationAttempts = 5;
  static final _secureRandom = Random.secure();
  static final _hostnamePattern = RegExp(
    r'^(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)'
    r'(?:\.(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?))*\.?$',
  );
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final UserRepository _repository = UserRepository();

  Future<void> sendVerificationCode(User user) async {
    final userId = user.id;
    if (userId == null) {
      throw StateError('Cannot verify a user without an id.');
    }

    final config = _EmailConfig.load();
    final otp = _generateOtp();
    final otpHash = _hashOtp(userId, otp, config.otpHashSecret);
    final now = DateTime.now().toUtc();
    final saved = await _repository.saveOtpIfCooldownElapsed(
      userId: userId,
      otpHash: otpHash,
      expiresAt: now.add(otpLifetime),
      sentAt: now,
      resendCooldown: resendCooldown,
    );
    if (!saved) return;

    try {
      final message = Message()
        ..from = Address(config.fromEmail, 'Fresh Bites')
        ..recipients.add(user.email)
        ..subject = 'Verify your Fresh Bites account'
        ..text =
            'Your Fresh Bites verification code is $otp. '
            'It expires in 10 minutes.';
      await send(message, config.smtpServer);
    } catch (error) {
      try {
        await _repository.deleteOtp(userId, otpHash);
      } catch (cleanupError) {
        stderr.writeln(
          'OTP cleanup after mail failure also failed '
          '(${cleanupError.runtimeType}).',
        );
      }
      throw EmailDeliveryException(
        'SMTP delivery failed (${error.runtimeType}).',
      );
    }
  }

  Future<OtpVerificationResult> verify(String email, String otp) async {
    final credentials = await _repository.getCredentialsByEmail(email);
    if (credentials == null) return OtpVerificationResult.userNotFound;
    final user = credentials.user;
    if (user.emailVerified) return OtpVerificationResult.alreadyVerified;

    final userId = user.id!;
    final record = await _repository.getOtp(userId);
    if (record == null) return OtpVerificationResult.expired;

    final now = DateTime.now().toUtc();
    final expiresAt = record['expiresAt'] as DateTime;
    if (!expiresAt.isAfter(now)) return OtpVerificationResult.expired;

    final attempts = record['attempts'] as int;
    if (attempts >= maxVerificationAttempts) {
      return OtpVerificationResult.attemptsExceeded;
    }

    final expectedHash = record['otpHash'] as String;
    final suppliedHash = _hashOtp(userId, otp, _otpHashSecret());
    if (!_constantTimeEquals(expectedHash, suppliedHash)) {
      await _repository.recordOtpAttempt(
        userId,
        expectedHash,
        now,
        maxVerificationAttempts,
      );
      final updated = await _repository.getOtp(userId);
      if ((updated?['attempts'] as int? ?? 0) >= maxVerificationAttempts) {
        return OtpVerificationResult.attemptsExceeded;
      }
      return OtpVerificationResult.invalid;
    }

    if (!await _repository.consumeOtp(
      userId,
      expectedHash,
      now,
      maxVerificationAttempts,
    )) {
      final currentUser = await _repository.getById(userId);
      return currentUser?.emailVerified == true
          ? OtpVerificationResult.alreadyVerified
          : OtpVerificationResult.invalid;
    }
    if (!await _repository.markEmailVerified(userId, user.email)) {
      final currentUser = await _repository.getById(userId);
      return currentUser == null
          ? OtpVerificationResult.userNotFound
          : OtpVerificationResult.alreadyVerified;
    }
    return OtpVerificationResult.verified;
  }

  String _generateOtp() {
    return _secureRandom.nextInt(1000000).toString().padLeft(6, '0');
  }

  String _hashOtp(String userId, String otp, String secret) {
    return Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode('$userId:$otp')).toString();
  }

  bool _constantTimeEquals(String first, String second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }

  String _otpHashSecret() {
    final env = DotEnv()..load();
    final secret = env['OTP_HASH_SECRET']?.trim();
    if (secret == null || utf8.encode(secret).length < 32) {
      throw const EmailDeliveryException(
        'OTP_HASH_SECRET must contain at least 32 bytes.',
      );
    }
    return secret;
  }

  static bool _isValidHost(String value) {
    return InternetAddress.tryParse(value) != null ||
        _hostnamePattern.hasMatch(value);
  }
}

class _EmailConfig {
  final String otpHashSecret;
  final String fromEmail;
  final SmtpServer smtpServer;

  const _EmailConfig({
    required this.otpHashSecret,
    required this.fromEmail,
    required this.smtpServer,
  });

  factory _EmailConfig.load() {
    final env = DotEnv()..load();
    final secret = env['OTP_HASH_SECRET']?.trim();
    final host = env['SMTP_HOST']?.trim();
    final username = env['SMTP_USERNAME']?.trim();
    final password = env['SMTP_PASSWORD'];
    final fromEmail = env['SMTP_FROM_EMAIL']?.trim();
    final port = int.tryParse(env['SMTP_PORT']?.trim() ?? '');

    if (secret == null || utf8.encode(secret).length < 32) {
      throw const EmailDeliveryException(
        'OTP_HASH_SECRET must contain at least 32 bytes.',
      );
    }
    if (host == null || !EmailOtpService._isValidHost(host)) {
      throw const EmailDeliveryException(
        'SMTP_HOST must be a hostname or IP address only, without a scheme or port.',
      );
    }
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty ||
        fromEmail == null ||
        !EmailOtpService._emailPattern.hasMatch(fromEmail) ||
        port == null ||
        port < 1 ||
        port > 65535) {
      throw const EmailDeliveryException(
        'SMTP settings are incomplete or invalid.',
      );
    }

    return _EmailConfig(
      otpHashSecret: secret,
      fromEmail: fromEmail,
      smtpServer: SmtpServer(
        host,
        port: port,
        username: username,
        password: password,
        ssl: port == 465,
      ),
    );
  }
}
