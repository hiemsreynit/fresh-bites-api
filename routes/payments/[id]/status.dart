import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/controllers/payment_controller.dart';

final _controller = PaymentController();

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method == HttpMethod.put) {
    return _controller.updateStatus(context, id);
  }
  return Response(
    statusCode: 405,
    headers: {'allow': 'PUT'},
  );
}
