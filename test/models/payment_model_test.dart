import 'package:decimal/decimal.dart';
import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentStatus', () {
    test('parses persisted status values', () {
      expect(PaymentStatus.fromValue('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromValue('completed'), PaymentStatus.completed);
      expect(PaymentStatus.fromValue('unknown'), isNull);
    });

    test('permits only configured transitions', () {
      expect(
        PaymentStatus.pending.canTransitionTo(PaymentStatus.completed),
        isTrue,
      );
      expect(
        PaymentStatus.pending.canTransitionTo(PaymentStatus.failed),
        isTrue,
      );
      expect(
        PaymentStatus.completed.canTransitionTo(PaymentStatus.refunded),
        isTrue,
      );
      expect(
        PaymentStatus.pending.canTransitionTo(PaymentStatus.refunded),
        isFalse,
      );
      expect(
        PaymentStatus.failed.canTransitionTo(PaymentStatus.completed),
        isFalse,
      );
    });
  });

  test('deserializes MongoDB payment amounts and ObjectIds', () {
    final paymentId = ObjectId();
    final orderId = ObjectId();
    final userId = ObjectId();
    final now = DateTime.utc(2026, 11, 1);
    final payment = Payment.fromMap({
      '_id': paymentId,
      'orderId': orderId,
      'userId': userId,
      'amount': Decimal.parse('16.25'),
      'currency': 'USD',
      'paymentMethod': 'cash_on_delivery',
      'transactionReference': null,
      'paymentStatus': 'pending',
      'paidAt': null,
      'createdAt': now,
      'updatedAt': now,
    });

    expect(payment.id, paymentId.oid);
    expect(payment.orderId, orderId.oid);
    expect(payment.userId, userId.oid);
    expect(payment.amount, 16.25);
    expect(payment.toJson()['currency'], 'USD');
    expect(payment.toJson()['paymentMethod'], 'cash_on_delivery');
  });
}
