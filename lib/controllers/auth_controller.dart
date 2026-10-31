import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/user_repository.dart';
import 'package:fresh_bites_api/services/password_service.dart';

class AuthController {
  final UserRepository _repository = UserRepository();
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Response> register(RequestContext context) async {
    final body = await _readBody(context);
    if (body == null) return _badRequest();

    const allowedFields = {
      'name',
      'email',
      'password',
      'phone',
      'defaultAddress',
    };
    if (body.isEmpty || body.keys.any((key) => !allowedFields.contains(key))) {
      return _badRequest();
    }

    final name = body['name'];
    final email = body['email'];
    final password = body['password'];
    final phone = body['phone'];
    final address = body['defaultAddress'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.trim().length > 100 ||
        email is! String ||
        !_isValidEmail(email) ||
        password is! String ||
        !PasswordService.isValid(password) ||
        phone is! String ||
        phone.trim().isEmpty ||
        phone.trim().length > 32 ||
        (body.containsKey('defaultAddress') &&
            address != null &&
            address is! String) ||
        (address is String && address.length > 500)) {
      return _badRequest();
    }

    try {
      final user = await _repository.create(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        passwordHash: PasswordService.hash(password),
        phone: phone.trim(),
        defaultAddress: (address as String?)?.trim(),
      );
      final expiresAt = DateTime.now().toUtc().add(
        UserRepository.tokenLifetime,
      );
      final token = await _repository.createAccessToken(
        user.id!,
        expiresAt: expiresAt,
      );
      return Response.json(
        statusCode: 201,
        body: _tokenResponse(user, token, expiresAt),
      );
    } on DuplicateUserEmailException {
      return Response.json(
        statusCode: 409,
        body: {'error': 'A user with this email already exists'},
      );
    } catch (error) {
      stderr.writeln('Authentication operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> login(RequestContext context) async {
    final body = await _readBody(context);
    if (body == null ||
        body.keys.any((key) => !{'email', 'password'}.contains(key))) {
      return _badRequest();
    }

    final email = body['email'];
    final password = body['password'];
    if (email is! String ||
        !_isValidEmail(email) ||
        password is! String ||
        password.isEmpty ||
        !PasswordService.isSupportedLength(password)) {
      return _badRequest();
    }

    try {
      final credentials = await _repository.getCredentialsByEmail(
        email.trim().toLowerCase(),
      );
      if (credentials == null ||
          !PasswordService.verify(password, credentials.passwordHash)) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Invalid email or password'},
        );
      }

      final expiresAt = DateTime.now().toUtc().add(
        UserRepository.tokenLifetime,
      );
      final token = await _repository.createAccessToken(
        credentials.user.id!,
        expiresAt: expiresAt,
      );
      return Response.json(
        body: _tokenResponse(credentials.user, token, expiresAt),
      );
    } catch (error) {
      stderr.writeln('Authentication operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Response me(RequestContext context) {
    final user = context.read<User>();
    return Response.json(body: user.toJson());
  }

  Future<Map<String, dynamic>?> _readBody(RequestContext context) async {
    try {
      final body = await context.request.json();
      return body is Map<String, dynamic> ? body : null;
    } on FormatException {
      return null;
    }
  }

  bool _isValidEmail(String email) {
    return email.length <= 254 && _emailPattern.hasMatch(email.trim());
  }

  Map<String, dynamic> _tokenResponse(
    User user,
    String token,
    DateTime expiresAt,
  ) {
    return {
      'accessToken': token,
      'tokenType': 'Bearer',
      'expiresAt': expiresAt.toIso8601String(),
      'user': user.toJson(),
    };
  }

  Response _badRequest() {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid request data'},
    );
  }

  Response _internalServerError() {
    return Response.json(
      statusCode: 500,
      body: {'error': 'An unexpected error occurred'},
    );
  }
}
