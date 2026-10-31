import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/auth_controller.dart';

final _controller = AuthController();

Response onRequest(RequestContext context) {
  if (context.request.method == HttpMethod.get) {
    return _controller.me(context);
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'GET'},
  );
}
