import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/user_controller.dart';

final _controller = UserController();

Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method == HttpMethod.get) return _controller.getById(id);
  if (method == HttpMethod.put) return _controller.update(context, id);
  if (method == HttpMethod.delete) return _controller.delete(context, id);

  return Response(
    statusCode: 405,
    headers: {'allow': 'GET, PUT, DELETE'},
  );
}
