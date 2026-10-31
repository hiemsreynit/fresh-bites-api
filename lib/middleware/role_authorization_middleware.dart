import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/user_model.dart';

Middleware requireRoleMiddleware(Set<String> allowedRoles) {
  return (handler) {
    return (context) {
      final user = context.read<User>();
      if (!allowedRoles.contains(user.role)) {
        return Response.json(
          statusCode: 403,
          body: {'error': 'Insufficient permissions'},
        );
      }
      return handler(context);
    };
  };
}
