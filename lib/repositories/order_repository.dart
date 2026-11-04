import 'package:decimal/decimal.dart';
// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:fresh_bites_api/database/mongodb.dart';
import 'package:fresh_bites_api/models/order_model.dart';

class OrderProductNotFoundException implements Exception {
  final String productId;

  const OrderProductNotFoundException(this.productId);
}

class OrderProductUnavailableException implements Exception {
  final String productId;

  const OrderProductUnavailableException(this.productId);
}

class InvalidOrderProductException implements Exception {
  final String productId;

  const InvalidOrderProductException(this.productId);
}

class OrderRepository {
  static final _zero = Decimal.zero;
  static final _deliveryFee = Decimal.zero;

  DbCollection get _orders => MongoDatabase.db.collection('orders');
  DbCollection get _products => MongoDatabase.db.collection('products');

  Future<Order> create({
    required String userId,
    required List<OrderItemRequest> requestedItems,
    required String deliveryAddress,
    required String deliveryPhone,
  }) async {
    final now = DateTime.now().toUtc();
    var subtotal = _zero;
    final snapshots = <Map<String, dynamic>>[];

    for (final requested in requestedItems) {
      final productId = ObjectId.parse(requested.productId);
      final product = await _products.findOne(where.id(productId));
      if (product == null) {
        throw OrderProductNotFoundException(requested.productId);
      }
      if (product['isAvailable'] != true) {
        throw OrderProductUnavailableException(requested.productId);
      }

      final name = product['name'];
      final price = _readPrice(product['price']);
      if (name is! String ||
          name.trim().isEmpty ||
          price == null ||
          price < _zero) {
        throw InvalidOrderProductException(requested.productId);
      }

      final itemSubtotal = price * Decimal.fromInt(requested.quantity);
      subtotal += itemSubtotal;
      snapshots.add({
        'productId': productId,
        'productName': name,
        'unitPrice': price,
        'quantity': requested.quantity,
        'subtotal': itemSubtotal,
      });
    }

    final total = subtotal + _deliveryFee;
    final orderId = ObjectId();
    final document = {
      '_id': orderId,
      'userId': ObjectId.parse(userId),
      'items': snapshots,
      'deliveryAddress': deliveryAddress,
      'deliveryPhone': deliveryPhone,
      'subtotal': subtotal,
      'deliveryFee': _deliveryFee,
      'totalAmount': total,
      'currency': 'USD',
      'orderStatus': OrderStatus.pending.value,
      'paymentStatus': 'unpaid',
      'createdAt': now,
      'updatedAt': now,
    };
    await _orders.insertOne(document);
    final saved = await _orders.findOne(where.id(orderId));
    if (saved == null) throw StateError('Created order could not be reloaded.');
    return Order.fromMap(saved);
  }

  Future<List<Order>> getAll({String? userId}) async {
    final selector = userId == null
        ? where.sortBy('createdAt', descending: true)
        : where
              .eq('userId', ObjectId.parse(userId))
              .sortBy('createdAt', descending: true);
    final documents = await _orders.find(selector).toList();
    return documents.map(Order.fromMap).toList();
  }

  Future<Order?> getById(String id) async {
    final document = await _orders.findOne(where.id(ObjectId.parse(id)));
    return document == null ? null : Order.fromMap(document);
  }

  Future<bool> updateStatus({
    required String id,
    required OrderStatus expectedStatus,
    required OrderStatus newStatus,
    String? expectedPaymentStatus,
  }) async {
    final selector = where
        .id(ObjectId.parse(id))
        .eq('orderStatus', expectedStatus.value);
    if (expectedPaymentStatus != null) {
      selector.eq('paymentStatus', expectedPaymentStatus);
    }
    final result = await _orders.updateOne(
      selector,
      modify
          .set('orderStatus', newStatus.value)
          .set('updatedAt', DateTime.now().toUtc()),
    );
    return result.nMatched > 0;
  }

  Decimal? _readPrice(dynamic value) {
    if (value is Decimal) return value;
    if (value is BsonDecimal128) return value.value;
    if (value is num && value.isFinite) {
      return Decimal.tryParse(value.toString());
    }
    return null;
  }
}
