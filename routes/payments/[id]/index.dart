import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/payment_controller.dart';

final _controller = PaymentController();

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.get) {
    return _controller.getById(context, id);
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'GET'},
  );
}
