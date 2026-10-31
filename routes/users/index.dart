import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/user_controller.dart';

final _controller = UserController();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _controller.getAll();
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'GET'},
  );
}
