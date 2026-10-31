import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/category_controller.dart';

final _controller = CategoryController();

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;

  if (method == HttpMethod.get) {
    return _controller.getAll(context);
  }

  if (method == HttpMethod.post) {
    return _controller.create(context);
  }

  return Response(
    statusCode: 405,
    headers: {'allow': 'GET, POST'},
  );
}
