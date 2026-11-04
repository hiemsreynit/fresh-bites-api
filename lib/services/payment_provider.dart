import 'dart:math';

import 'package:fresh_bites_api/models/order_model.dart';
import 'package:fresh_bites_api/models/payment_model.dart';

enum PaymentVerificationStatus { pending, failed, successful }

class PaymentRequestInput {
  final Order order;
  final PaymentMethod paymentMethod;

  const PaymentRequestInput({
    required this.order,
    required this.paymentMethod,
  });
}

class PaymentRequest {
  final String paymentReference;
  final String? qrData;

  const PaymentRequest({
    required this.paymentReference,
    required this.qrData,
  });
}

class PaymentVerification {
  final PaymentVerificationStatus status;
  final String? transactionId;
  final String? paymentReference;
  final String? receiverAccountId;
  final String? currency;
  final String? amount;

  const PaymentVerification({
    required this.status,
    this.transactionId,
    this.paymentReference,
    this.receiverAccountId,
    this.currency,
    this.amount,
  });
}

abstract interface class PaymentProvider {
  String get name;

  bool get isDemo;

  Future<PaymentRequest> createPaymentRequest(PaymentRequestInput input);

  Future<PaymentVerification> verifyTransaction(Payment payment);
}

class DemoPaymentProvider implements PaymentProvider {
  static final _secureRandom = Random.secure();

  @override
  String get name => 'demo';

  @override
  bool get isDemo => true;

  @override
  Future<PaymentRequest> createPaymentRequest(PaymentRequestInput input) async {
    return PaymentRequest(
      paymentReference: _newReference('DEMO'),
      qrData: null,
    );
  }

  @override
  Future<PaymentVerification> verifyTransaction(Payment payment) async {
    return const PaymentVerification(
      status: PaymentVerificationStatus.pending,
    );
  }

  static String _newReference(String prefix) {
    final suffix = List.generate(
      32,
      (_) => _secureRandom.nextInt(16).toRadixString(16),
    ).join();
    return '$prefix-$suffix';
  }
}

String newCashOnDeliveryReference() {
  final random = Random.secure();
  final suffix = List.generate(
    32,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return 'COD-$suffix';
}
