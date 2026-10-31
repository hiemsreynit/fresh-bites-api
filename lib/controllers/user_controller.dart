import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/user_repository.dart';
import 'package:fresh_bites_api/services/password_service.dart';

class UserController {
  final UserRepository _repository = UserRepository();
  static final _idPattern = RegExp(r'^[a-fA-F0-9]{24}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Response> getAll() async {
    try {
      final users = await _repository.getAll();
      return Response.json(body: users.map((user) => user.toJson()).toList());
    } catch (error) {
      stderr.writeln('User operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> getById(String id) async {
    if (!_isValidId(id)) return _badRequest();
    try {
      final user = await _repository.getById(id);
      if (user == null) return _notFound();
      return Response.json(body: user.toJson());
    } catch (error) {
      stderr.writeln('User operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> update(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final currentUser = context.read<User>();
    if (!_isAdmin(currentUser) && !_sameId(currentUser.id, id)) {
      return _forbidden();
    }

    final body = await _readBody(context);
    if (body == null || body.isEmpty) return _badRequest();
    final changes = _changesFromBody(body);
    if (changes == null) return _badRequest();

    try {
      final updated = await _repository.update(id, changes);
      if (updated == null) return _notFound();
      return Response.json(body: updated.toJson());
    } on DuplicateUserEmailException {
      return Response.json(
        statusCode: 409,
        body: {'error': 'A user with this email already exists'},
      );
    } catch (error) {
      stderr.writeln('User operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> delete(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final currentUser = context.read<User>();
    if (!_isAdmin(currentUser) && !_sameId(currentUser.id, id)) {
      return _forbidden();
    }

    try {
      if (!await _repository.delete(id)) return _notFound();
      return Response(statusCode: 204);
    } catch (error) {
      stderr.writeln('User operation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Map<String, dynamic>?> _readBody(RequestContext context) async {
    try {
      final body = await context.request.json();
      return body is Map<String, dynamic> ? body : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?>? _changesFromBody(Map<String, dynamic> body) {
    const allowedFields = {
      'name',
      'email',
      'phone',
      'defaultAddress',
      'password',
    };
    if (body.keys.any((key) => !allowedFields.contains(key))) return null;

    final changes = <String, Object?>{};
    if (body.containsKey('name')) {
      final name = body['name'];
      if (name is! String || name.trim().isEmpty || name.trim().length > 100) {
        return null;
      }
      changes['name'] = name.trim();
    }
    if (body.containsKey('email')) {
      final email = body['email'];
      if (email is! String ||
          email.length > 254 ||
          !_emailPattern.hasMatch(email.trim())) {
        return null;
      }
      changes['email'] = email.trim().toLowerCase();
    }
    if (body.containsKey('phone')) {
      final phone = body['phone'];
      if (phone is! String ||
          phone.trim().isEmpty ||
          phone.trim().length > 32) {
        return null;
      }
      changes['phone'] = phone.trim();
    }
    if (body.containsKey('defaultAddress')) {
      final address = body['defaultAddress'];
      if (address != null && address is! String) return null;
      if (address is String && address.length > 500) return null;
      changes['defaultAddress'] = address is String ? address.trim() : null;
    }
    if (body.containsKey('password')) {
      final password = body['password'];
      if (password is! String || !PasswordService.isValid(password)) {
        return null;
      }
      changes['passwordHash'] = PasswordService.hash(password);
    }
    return changes;
  }

  bool _isValidId(String id) => _idPattern.hasMatch(id);

  bool _isAdmin(User user) => user.role == 'admin';

  bool _sameId(String? first, String second) =>
      first?.toLowerCase() == second.toLowerCase();

  Response _badRequest() {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid user data or user id'},
    );
  }

  Response _notFound() {
    return Response.json(
      statusCode: 404,
      body: {'error': 'User not found'},
    );
  }

  Response _forbidden() {
    return Response.json(
      statusCode: 403,
      body: {'error': 'Insufficient permissions'},
    );
  }

  Response _internalServerError() {
    return Response.json(
      statusCode: 500,
      body: {'error': 'An unexpected error occurred'},
    );
  }
}
