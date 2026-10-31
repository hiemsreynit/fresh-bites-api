import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/middleware/authentication_middleware.dart';
import 'package:fresh_bites_api/middleware/role_authorization_middleware.dart';

Handler middleware(Handler handler) {
  final authenticatedHandler = authenticationMiddleware()(handler);
  final adminHandler = authenticationMiddleware()(
    requireRoleMiddleware({'admin'})(handler),
  );

  return (context) {
    if (context.request.method == HttpMethod.get) {
      return adminHandler(context);
    }
    return authenticatedHandler(context);
  };
}
