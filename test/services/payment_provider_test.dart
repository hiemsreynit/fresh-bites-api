import 'package:fresh_bites_api/models/order_model.dart';
import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:fresh_bites_api/services/bakong_service.dart';
import 'package:fresh_bites_api/services/payment_provider.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentProviderSettings', () {
    test('defaults to demo mode', () {
      final settings = PaymentProviderSettings.fromValues();

      expect(settings.mode, PaymentProviderMode.demo);
    });

    test('requires SIT credentials for Bakong mode', () {
      expect(
        () => PaymentProviderSettings.fromValues(provider: 'bakong'),
        throwsA(isA<PaymentProviderConfigurationException>()),
      );
    });

    test('does not allow production Bakong mode', () {
      expect(
        () => PaymentProviderSettings.fromValues(
          provider: 'bakong',
          bakongEnvironment: 'production',
          bakongApiToken: 'sit-token',
          bakongMerchantAccountId: 'merchant@bank',
          bakongMerchantName: 'Fresh Bites',
        ),
        throwsA(isA<PaymentProviderConfigurationException>()),
      );
    });
  });

  group('DemoPaymentProvider', () {
    final provider = DemoPaymentProvider();

    test('creates distinct references without generating a QR', () async {
      final first = await provider.createPaymentRequest(
        PaymentRequestInput(order: _order(), paymentMethod: PaymentMethod.card),
      );
      final second = await provider.createPaymentRequest(
        PaymentRequestInput(order: _order(), paymentMethod: PaymentMethod.card),
      );

      expect(first.paymentReference, startsWith('DEMO-'));
      expect(second.paymentReference, startsWith('DEMO-'));
      expect(first.paymentReference, isNot(second.paymentReference));
      expect(first.qrData, isNull);
    });

    test('verification remains pending in demo mode', () async {
      final result = await provider.verifyTransaction(_payment());

      expect(result.status, PaymentVerificationStatus.pending);
      expect(result.transactionId, isNull);
    });
  });

  test('Bakong service generates a valid KHQR payment request', () async {
    final settings = PaymentProviderSettings.fromValues(
      provider: 'bakong',
      bakongEnvironment: 'sit',
      bakongApiToken: 'sit-token',
      bakongMerchantAccountId: 'merchant@bank',
      bakongMerchantName: 'Fresh Bites',
    );
    final service = BakongService(settings);

    final request = await service.createPaymentRequest(
      PaymentRequestInput(
        order: _order(),
        paymentMethod: PaymentMethod.digitalWallet,
      ),
    );

    expect(request.paymentReference, isNotEmpty);
    expect(request.qrData, isNotNull);
  });
}

Order _order() {
  final now = DateTime.utc(2026, 11, 4);
  return Order(
    id: ObjectId().oid,
    userId: ObjectId().oid,
    items: const [],
    deliveryAddress: 'Test address',
    deliveryPhone: '010000000',
    subtotal: 1,
    deliveryFee: 0,
    totalAmount: 1,
    currency: 'USD',
    orderStatus: OrderStatus.pending,
    paymentStatus: 'unpaid',
    createdAt: now,
    updatedAt: now,
  );
}

Payment _payment() {
  final now = DateTime.utc(2026, 11, 4);
  return Payment(
    id: ObjectId().oid,
    orderId: ObjectId().oid,
    userId: ObjectId().oid,
    amount: 1,
    currency: 'USD',
    paymentMethod: PaymentMethod.digitalWallet,
    paymentProvider: 'demo',
    transactionReference: 'DEMO-reference',
    providerTransactionId: null,
    qrData: null,
    paymentStatus: PaymentStatus.pending,
    paidAt: null,
    createdAt: now,
    updatedAt: now,
  );
}
