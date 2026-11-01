import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/order_model.dart';
import 'package:fresh_bites_api/models/user_model.dart';
import 'package:fresh_bites_api/repositories/order_repository.dart';

class OrderController {
  final OrderRepository _repository = OrderRepository();
  static final _idPattern = RegExp(r'^[a-fA-F0-9]{24}$');

  Future<Response> create(RequestContext context) async {
    final user = context.read<User>();
    if (user.role != 'customer') return _forbidden();
    final userId = user.id;
    if (userId == null) return _internalServerError();

    final body = await _readBody(context);
    if (body == null) return _badRequest();
    final request = _orderRequestFromBody(body);
    if (request == null) return _badRequest();

    try {
      final order = await _repository.create(
        userId: userId,
        requestedItems: request.items,
        deliveryAddress: request.deliveryAddress,
        deliveryPhone: request.deliveryPhone,
      );
      return Response.json(statusCode: 201, body: order.toJson());
    } on OrderProductNotFoundException {
      return Response.json(
        statusCode: 404,
        body: {'error': 'One or more products were not found'},
      );
    } on OrderProductUnavailableException {
      return Response.json(
        statusCode: 409,
        body: {'error': 'One or more products are unavailable'},
      );
    } on InvalidOrderProductException catch (error) {
      stderr.writeln(
        'Order product data is invalid (${error.runtimeType}).',
      );
      return _internalServerError();
    } catch (error) {
      stderr.writeln('Order creation failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> getAll(RequestContext context) async {
    final user = context.read<User>();
    final userId = user.id;
    if (user.role != 'admin' && userId == null) {
      return _internalServerError();
    }
    try {
      final orders = await _repository.getAll(
        userId: user.role == 'admin' ? null : userId,
      );
      return Response.json(
        body: orders.map((order) => order.toJson()).toList(),
      );
    } catch (error) {
      stderr.writeln('Order listing failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> getById(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final user = context.read<User>();

    try {
      final order = await _repository.getById(id);
      if (order == null || !_canAccess(user, order)) return _notFound();
      return Response.json(body: order.toJson());
    } catch (error) {
      stderr.writeln('Order lookup failed (${error.runtimeType}).');
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
        body.keys.single != 'orderStatus' ||
        body['orderStatus'] is! String) {
      return _badRequest();
    }

    final nextStatus = OrderStatus.fromValue(body['orderStatus'] as String);
    if (nextStatus == null) return _badRequest();

    try {
      final current = await _repository.getById(id);
      if (current == null) return _notFound();
      if (!current.orderStatus.canTransitionTo(nextStatus)) {
        return _invalidTransition();
      }

      final updated = await _repository.updateStatus(
        id: id,
        expectedStatus: current.orderStatus,
        newStatus: nextStatus,
      );
      if (!updated) return _invalidTransition();
      final saved = await _repository.getById(id);
      return saved == null ? _notFound() : Response.json(body: saved.toJson());
    } catch (error) {
      stderr.writeln('Order status update failed (${error.runtimeType}).');
      return _internalServerError();
    }
  }

  Future<Response> cancel(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();
    final user = context.read<User>();
    final isAdmin = user.role == 'admin';

    try {
      final current = await _repository.getById(id);
      if (current == null || !_canAccess(user, current)) return _notFound();
      if (!isAdmin && current.orderStatus != OrderStatus.pending) {
        return _invalidTransition();
      }
      if (!current.orderStatus.canTransitionTo(OrderStatus.cancelled)) {
        return _invalidTransition();
      }

      final updated = await _repository.updateStatus(
        id: id,
        expectedStatus: current.orderStatus,
        newStatus: OrderStatus.cancelled,
      );
      if (!updated) return _invalidTransition();
      final saved = await _repository.getById(id);
      return saved == null ? _notFound() : Response.json(body: saved.toJson());
    } catch (error) {
      stderr.writeln('Order cancellation failed (${error.runtimeType}).');
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

  _CreateOrderRequest? _orderRequestFromBody(Map<String, dynamic> body) {
    const allowedFields = {'items', 'deliveryAddress', 'deliveryPhone'};
    if (body.isEmpty || body.keys.any((key) => !allowedFields.contains(key))) {
      return null;
    }

    final rawItems = body['items'];
    final address = body['deliveryAddress'];
    final phone = body['deliveryPhone'];
    if (rawItems is! List ||
        rawItems.isEmpty ||
        rawItems.length > 50 ||
        address is! String ||
        address.trim().isEmpty ||
        address.trim().length > 500 ||
        phone is! String ||
        phone.trim().isEmpty ||
        phone.trim().length > 32) {
      return null;
    }

    final items = <OrderItemRequest>[];
    final productIds = <String>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic> ||
          rawItem.length != 2 ||
          rawItem.keys.toSet().difference({
            'productId',
            'quantity',
          }).isNotEmpty) {
        return null;
      }
      final productId = rawItem['productId'];
      final quantity = rawItem['quantity'];
      if (productId is! String ||
          !_isValidId(productId) ||
          quantity is! int ||
          quantity < 1 ||
          quantity > 99) {
        return null;
      }

      final normalizedId = productId.toLowerCase();
      if (!productIds.add(normalizedId)) return null;
      items.add(
        OrderItemRequest(productId: normalizedId, quantity: quantity),
      );
    }

    return _CreateOrderRequest(
      items: items,
      deliveryAddress: address.trim(),
      deliveryPhone: phone.trim(),
    );
  }

  bool _isValidId(String id) => _idPattern.hasMatch(id);

  bool _canAccess(User user, Order order) {
    return user.role == 'admin' || user.id == order.userId;
  }

  Response _badRequest() {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid order data or order id'},
    );
  }

  Response _notFound() {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Order not found'},
    );
  }

  Response _forbidden() {
    return Response.json(
      statusCode: 403,
      body: {'error': 'Insufficient permissions'},
    );
  }

  Response _invalidTransition() {
    return Response.json(
      statusCode: 409,
      body: {'error': 'Order status transition is not permitted'},
    );
  }

  Response _internalServerError() {
    return Response.json(
      statusCode: 500,
      body: {'error': 'An unexpected error occurred'},
    );
  }
}

class _CreateOrderRequest {
  const _CreateOrderRequest({
    required this.items,
    required this.deliveryAddress,
    required this.deliveryPhone,
  });

  final List<OrderItemRequest> items;
  final String deliveryAddress;
  final String deliveryPhone;
}
