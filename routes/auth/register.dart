import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/auth_controller.dart';

final _controller = AuthController();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.post) {
    return _controller.register(context);
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'POST'},
  );
}
