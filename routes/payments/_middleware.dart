import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/middleware/authentication_middleware.dart';

Handler middleware(Handler handler) {
  return authenticationMiddleware()(handler);
}
