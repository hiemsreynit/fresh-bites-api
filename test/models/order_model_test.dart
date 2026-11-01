import 'package:decimal/decimal.dart';
import 'package:fresh_bites_api/models/order_model.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

void main() {
  group('OrderStatus', () {
    test('parses persisted status values', () {
      expect(OrderStatus.fromValue('pending'), OrderStatus.pending);
      expect(
        OrderStatus.fromValue('out_for_delivery'),
        OrderStatus.outForDelivery,
      );
      expect(OrderStatus.fromValue('unknown'), isNull);
    });

    test('permits only configured forward transitions', () {
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.confirmed),
        isTrue,
      );
      expect(
        OrderStatus.confirmed.canTransitionTo(OrderStatus.preparing),
        isTrue,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.outForDelivery),
        isTrue,
      );
      expect(
        OrderStatus.outForDelivery.canTransitionTo(OrderStatus.delivered),
        isTrue,
      );
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.preparing),
        isFalse,
      );
      expect(
        OrderStatus.delivered.canTransitionTo(OrderStatus.cancelled),
        isFalse,
      );
      expect(
        OrderStatus.cancelled.canTransitionTo(OrderStatus.pending),
        isFalse,
      );
    });
  });

  test('deserializes MongoDB Decimal values in order totals and snapshots', () {
    final orderId = ObjectId();
    final userId = ObjectId();
    final productId = ObjectId();
    final now = DateTime.utc(2026, 11, 1);
    final order = Order.fromMap({
      '_id': orderId,
      'userId': userId,
      'items': [
        {
          'productId': productId,
          'productName': 'Chicken Burger',
          'unitPrice': Decimal.parse('8'),
          'quantity': 2,
          'subtotal': Decimal.parse('16'),
        },
      ],
      'deliveryAddress': 'Dankao, Phnom Penh',
      'deliveryPhone': '010123456',
      'subtotal': Decimal.parse('16'),
      'deliveryFee': Decimal.zero,
      'totalAmount': Decimal.parse('16'),
      'orderStatus': 'pending',
      'paymentStatus': 'unpaid',
      'createdAt': now,
      'updatedAt': now,
    });

    expect(order.items.single.unitPrice, 8);
    expect(order.items.single.subtotal, 16);
    expect(order.totalAmount, 16);
  });
}
