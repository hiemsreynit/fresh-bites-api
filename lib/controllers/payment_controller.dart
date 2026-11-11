import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/payment_repository.dart';
import 'package:fresh_bites_api/services/bakong_service.dart';
import 'package:fresh_bites_api/services/payment_service.dart';

class PaymentController {
  final PaymentRepository _repository = PaymentRepository();
  final PaymentService _service = PaymentService();
  static final _idPattern = RegExp(r'^[a-fA-F0-9]{24}$');

  Future<Response> create(RequestContext context) async {
    final user = context.read<User>();
    if (user.role != 'customer') return _forbidden();
    final userId = user.id;
    if (userId == null || !_isValidId(userId)) return _internalServerError();

    final body = await _readBody(context);
    if (body == null) return _badRequest();
    final request = _createRequestFromBody(body);
    if (request == null) return _badRequest();

    try {
      final payment = await _service.createPayment(
        orderId: request.orderId,
        userId: userId,
        paymentMethod: request.paymentMethod,
      );
      return Response.json(statusCode: 201, body: payment.toJson());
    } on PaymentOrderNotFoundException {
      return _notFound();
    } on PaymentConflictException {
      return _conflict();
    } on PaymentProviderConfigurationException catch (error) {
      stderr.writeln('Payment provider configuration error: ${error.message}');
      return _serviceUnavailable(error.message);
    } on BakongIntegrationUnavailableException catch (error) {
      stderr.writeln('Bakong integration unavailable.');
      return _serviceUnavailable(error.toString());
    } on InvalidPaymentOrderException {
      stderr.writeln('Payment order data is invalid.');
      return _internalServerError();
    } catch (error) {
      stderr.writeln('Payment creation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> getAll(RequestContext context) async {
    final user = context.read<User>();
    if (user.role != 'admin' && user.id == null) {
      return _internalServerError();
    }
    try {
      final payments = await _repository.getAll(
        userId: user.role == 'admin' ? null : user.id,
      );
      return Response.json(
        body: payments.map(_service.paymentToJson).toList(),
      );
    } catch (error) {
      stderr.writeln('Payment listing failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> getById(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final user = context.read<User>();
    try {
      final payment = await _repository.getById(id);
      if (payment == null || !_canAccess(user, payment)) return _notFound();
      return Response.json(body: _service.paymentToJson(payment));
    } catch (error) {
      stderr.writeln('Payment lookup failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

    Future<Response> verify(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final user = context.read<User>();

    try {
      final payment = await _repository.getById(id);
      if (payment == null || !_canAccess(user, payment)) return _notFound();

      final verification = await _service.verifyPayment(id);
      if (verification == null) return _notFound();

      final updatedPayment = await _repository.getById(id);

      return Response.json(
        body: {
          'status': verification.status.name,
          'transactionId': verification.transactionId,
          if (updatedPayment != null)
            'payment': _service.paymentToJson(updatedPayment),
        },
      );
    } on PaymentVerificationConflictException {
      return _conflict();
    } on PaymentProviderConfigurationException catch (error) {
      stderr.writeln('Payment provider configuration error: ${error.message}');
      return _serviceUnavailable(error.message);
    } catch (error) {
      stderr.writeln('Payment verification failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> updateStatus(
    RequestContext context,
    String id,
  ) async {
    if (!_isValidId(id)) return _badRequest();
    if (context.read<User>().role != 'admin') return _forbidden();

    final body = await _readBody(context);
    if (body == null ||
        body.length != 1 ||
        body.keys.single != 'paymentStatus' ||
        body['paymentStatus'] is! String) {
      return _badRequest();
    }
    final rawStatus = body['paymentStatus'];
    if (rawStatus is! String) return _badRequest();
    final nextStatus = PaymentStatus.fromValue(rawStatus);
    if (nextStatus == null) return _badRequest();
    if (nextStatus == PaymentStatus.completed) return _conflict();

    try {
      final current = await _repository.getById(id);
      if (current == null) return _notFound();
      if (!current.paymentStatus.canTransitionTo(nextStatus)) {
        return _conflict();
      }
      final updated = await _repository.updateStatus(
        payment: current,
        newStatus: nextStatus,
      );
      if (!updated) return _conflict();
      final saved = await _repository.getById(id);
      return saved == null
          ? _notFound()
          : Response.json(body: _service.paymentToJson(saved));
    } on PaymentConflictException {
      return _conflict();
    } catch (error) {
      stderr.writeln('Payment status update failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Map<String, dynamic>?> _readBody(RequestContext context) async {
    try {
      final body = await context.request.json();
      return body is Map<String, dynamic> ? body : null;
    } on FormatException {
      return null;
    }
  }

  _CreatePaymentRequest? _createRequestFromBody(
    Map<String, dynamic> body,
  ) {
    if (body.length != 2 ||
        body.keys.toSet().difference({'orderId', 'paymentMethod'}).isNotEmpty) {
      return null;
    }
    final orderId = body['orderId'];
    final rawPaymentMethod = body['paymentMethod'];
    if (orderId is! String ||
        !_isValidId(orderId) ||
        rawPaymentMethod is! String) {
      return null;
    }
    final paymentMethod = PaymentMethod.fromValue(rawPaymentMethod);
    if (paymentMethod == null) return null;
    return _CreatePaymentRequest(
      orderId: orderId.toLowerCase(),
      paymentMethod: paymentMethod,
    );
  }

  bool _isValidId(String id) => _idPattern.hasMatch(id);

  bool _canAccess(User user, Payment payment) {
    return user.role == 'admin' || user.id == payment.userId;
  }

  Response _badRequest() => Response.json(
    statusCode: 400,
    body: {'error': 'Invalid payment data or payment id'},
  );

  Response _notFound() =>
      Response.json(statusCode: 404, body: {'error': 'Payment not found'});

  Response _forbidden() => Response.json(
    statusCode: 403,
    body: {'error': 'Insufficient permissions'},
  );

  Response _conflict() => Response.json(
    statusCode: 409,
    body: {
      'error': 'Payment is already created or status change is not allowed',
    },
  );

  Response _serviceUnavailable(String message) => Response.json(
    statusCode: 503,
    body: {'error': message},
  );

  Response _internalServerError() => Response.json(
    statusCode: 500,
    body: {'error': 'An unexpected error occurred'},
  );
}

class _CreatePaymentRequest {
  final String orderId;
  final PaymentMethod paymentMethod;

  const _CreatePaymentRequest({
    required this.orderId,
    required this.paymentMethod,
  });
}
