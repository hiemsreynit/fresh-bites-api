import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/user_repository.dart';

Middleware authenticationMiddleware() {
  return (handler) {
    return (context) async {
      final token = _bearerToken(context.request.headers['authorization']);
      if (token == null) return _unauthorized();

      try {
        final user = await UserRepository().getUserForAccessToken(token);
        if (user == null) return _unauthorized();
        return await handler(context.provide<User>(() => user));
      } catch (error) {
        stderr.writeln(
          'Authentication lookup failed: ${error.runtimeType}',
        );
        return Response.json(
          statusCode: 500,
          body: {'error': 'An unexpected error occurred'},
        );
      }
    };
  };
}

String? _bearerToken(String? authorization) {
  if (authorization == null) return null;
  final parts = authorization.trim().split(RegExp(r'\s+'));
  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return null;
  }
  return parts[1];
}

Response _unauthorized() {
  return Response.json(
    statusCode: 401,
    headers: {'www-authenticate': 'Bearer'},
    body: {'error': 'Authentication required'},
  );
}
