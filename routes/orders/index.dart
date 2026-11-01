import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/order_controller.dart';

final _controller = OrderController();

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.get) {
    return _controller.getAll(context);
  }
  if (context.request.method == HttpMethod.post) {
    return _controller.create(context);
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'GET, POST'},
  );
}
