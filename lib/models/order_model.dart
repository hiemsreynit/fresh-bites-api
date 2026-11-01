import 'package:decimal/decimal.dart';
// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:mongo_dart/mongo_dart.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  outForDelivery,
  delivered,
  cancelled;

  String get value => switch (this) {
    OrderStatus.pending => 'pending',
    OrderStatus.confirmed => 'confirmed',
    OrderStatus.preparing => 'preparing',
    OrderStatus.outForDelivery => 'out_for_delivery',
    OrderStatus.delivered => 'delivered',
    OrderStatus.cancelled => 'cancelled',
  };

  static OrderStatus? fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }

  bool canTransitionTo(OrderStatus next) {
    return switch (this) {
      OrderStatus.pending =>
        next == OrderStatus.confirmed || next == OrderStatus.cancelled,
      OrderStatus.confirmed =>
        next == OrderStatus.preparing || next == OrderStatus.cancelled,
      OrderStatus.preparing => next == OrderStatus.outForDelivery,
      OrderStatus.outForDelivery => next == OrderStatus.delivered,
      OrderStatus.delivered || OrderStatus.cancelled => false,
    };
  }
}

class OrderItemRequest {
  final String productId;
  final int quantity;

  const OrderItemRequest({
    required this.productId,
    required this.quantity,
  });
}

class OrderItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawProductId = map['productId'];
    return OrderItem(
      productId: rawProductId is ObjectId
          ? rawProductId.oid
          : rawProductId.toString(),
      productName: map['productName'] as String,
      unitPrice: _amountAsDouble(map['unitPrice']),
      quantity: map['quantity'] as int,
      subtotal: _amountAsDouble(map['subtotal']),
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'subtotal': subtotal,
  };
}

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final String deliveryAddress;
  final String deliveryPhone;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final OrderStatus orderStatus;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.deliveryAddress,
    required this.deliveryPhone,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final rawUserId = map['userId'];
    final status = OrderStatus.fromValue(map['orderStatus'] as String?);
    if (rawId is! ObjectId || rawUserId is! ObjectId || status == null) {
      throw const FormatException('Invalid order document.');
    }

    return Order(
      id: rawId.oid,
      userId: rawUserId.oid,
      items: (map['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      deliveryAddress: map['deliveryAddress'] as String,
      deliveryPhone: map['deliveryPhone'] as String,
      subtotal: _amountAsDouble(map['subtotal']),
      deliveryFee: _amountAsDouble(map['deliveryFee']),
      totalAmount: _amountAsDouble(map['totalAmount']),
      orderStatus: status,
      paymentStatus: map['paymentStatus'] as String,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'items': items.map((item) => item.toJson()).toList(),
    'deliveryAddress': deliveryAddress,
    'deliveryPhone': deliveryPhone,
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'totalAmount': totalAmount,
    'orderStatus': orderStatus.value,
    'paymentStatus': paymentStatus,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

double _amountAsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is Decimal) return value.toDouble();
  if (value is BsonDecimal128) {
    final decimal = value.value;
    if (decimal != null) return decimal.toDouble();
  }
  throw const FormatException('Invalid order amount.');
}
