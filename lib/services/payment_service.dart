import 'package:decimal/decimal.dart';

import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:fresh_bites_api/repositories/payment_repository.dart';
import 'package:fresh_bites_api/services/bakong_service.dart';
import 'package:fresh_bites_api/services/payment_provider.dart';

class PaymentVerificationConflictException implements Exception {}

class PaymentCreation {
  final Payment payment;
  final String? qrData;

  const PaymentCreation({
    required this.payment,
    required this.qrData,
  });

  Map<String, dynamic> toJson() {
    final provider = payment.paymentProvider;
    return {
      ...payment.toJson(),
      'provider': provider,
      'isDemo': provider == 'demo',
      'qrData': qrData,
      if (provider == 'demo')
        'message':
            'Demo simulation only. No KHQR was generated and no payment was '
            'processed.',
    };
  }
}

class PaymentService {
  final PaymentRepository _repository;
  final PaymentProvider? _injectedProvider;
  final PaymentProviderSettings? _injectedSettings;
  PaymentProvider? _resolvedProvider;
  PaymentProviderSettings? _resolvedSettings;

  PaymentService({
    PaymentRepository? repository,
    PaymentProvider? provider,
    PaymentProviderSettings? settings,
  }) : _repository = repository ?? PaymentRepository(),
       _injectedProvider = provider,
       _injectedSettings = settings;

  Future<PaymentCreation> createPayment({
    required String orderId,
    required String userId,
    required PaymentMethod paymentMethod,
  }) async {
    final order = await _repository.getPayableOrder(
      orderId: orderId,
      userId: userId,
    );

    late final String paymentProvider;
    late final String paymentReference;
    String? qrData;
    if (paymentMethod == PaymentMethod.cashOnDelivery) {
      paymentProvider = 'cash_on_delivery';
      paymentReference = newCashOnDeliveryReference();
    } else {
      final provider = _provider();
      if (provider.name == 'bakong' &&
          paymentMethod != PaymentMethod.digitalWallet) {
        throw const PaymentProviderConfigurationException(
          'Bakong currently supports only the digital_wallet payment method.',
        );
      }
      final request = await provider.createPaymentRequest(
        PaymentRequestInput(order: order, paymentMethod: paymentMethod),
      );
      paymentProvider = provider.name;
      paymentReference = request.paymentReference;
      qrData = request.qrData;
    }

    final payment = await _repository.create(
      orderId: order.id,
      userId: userId,
      paymentMethod: paymentMethod,
      paymentProvider: paymentProvider,
      transactionReference: paymentReference,
      qrData: qrData,
    );
    return PaymentCreation(payment: payment, qrData: qrData);
  }

  Future<PaymentVerification?> verifyPayment(String paymentId) async {
    final payment = await _repository.getById(paymentId);
    if (payment == null) return null;
    if (payment.paymentStatus != PaymentStatus.pending) {
      throw PaymentVerificationConflictException();
    }

    final provider = _providerForPayment(payment);
    final verification = await provider.verifyTransaction(payment);
    switch (verification.status) {
      case PaymentVerificationStatus.pending:
        return verification;
      case PaymentVerificationStatus.failed:
        if (!await _repository.updateStatus(
          payment: payment,
          newStatus: PaymentStatus.failed,
        )) {
          throw PaymentVerificationConflictException();
        }
        return verification;
      case PaymentVerificationStatus.successful:
        final settings = _settings();
        if (!_matchesExpectedTransaction(payment, verification, settings)) {
          throw PaymentVerificationConflictException();
        }
        if (!await _repository.completeVerifiedPayment(
          paymentId: payment.id,
          providerTransactionId: verification.transactionId!,
        )) {
          throw PaymentVerificationConflictException();
        }
        return verification;
    }
  }

  Map<String, dynamic> paymentToJson(Payment payment) {
    return {
      ...payment.toJson(),
      'provider': payment.paymentProvider,
      'isDemo': payment.paymentProvider == 'demo',
    };
  }

  PaymentProvider _provider() {
    return _resolvedProvider ??=
        _injectedProvider ??
        switch (_settings().mode) {
          PaymentProviderMode.demo => DemoPaymentProvider(),
          PaymentProviderMode.bakong => BakongService(_settings()),
        };
  }

  PaymentProvider _providerForPayment(Payment payment) {
    if (payment.paymentProvider == 'demo') return DemoPaymentProvider();
    if (payment.paymentProvider == 'bakong') {
      final settings = _settings();
      if (settings.mode != PaymentProviderMode.bakong) {
        throw const PaymentProviderConfigurationException(
          'Set PAYMENT_PROVIDER=bakong and configure SIT credentials before '
          'verifying a Bakong payment.',
        );
      }
      return _injectedProvider ?? BakongService(settings);
    }
    throw PaymentVerificationConflictException();
  }

  PaymentProviderSettings _settings() {
    return _resolvedSettings ??=
        _injectedSettings ?? PaymentProviderSettings.fromEnvironment();
  }

  bool _matchesExpectedTransaction(
    Payment payment,
    PaymentVerification verification,
    PaymentProviderSettings settings,
  ) {
    final expectedAmount = Decimal.tryParse(payment.amount.toString());
    final verifiedAmount = Decimal.tryParse(verification.amount ?? '');
    return verification.transactionId != null &&
        verification.transactionId!.isNotEmpty &&
        verification.paymentReference == payment.transactionReference &&
        verification.receiverAccountId == settings.bakongMerchantAccountId &&
        verification.currency == payment.currency &&
        expectedAmount != null &&
        verifiedAmount == expectedAmount;
  }
}
