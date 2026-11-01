import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/middleware/authentication_middleware.dart';
import 'package:fresh_bites_api/models/user_model.dart';

Handler middleware(Handler handler) {
  return authenticationMiddleware()((context) {
    if (context.request.method == HttpMethod.get &&
        context.read<User>().role != 'admin') {
      return Response.json(
        statusCode: 403,
        body: {'error': 'Insufficient permissions'},
      );
    }
    return handler(context);
  });
}
