import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:khqr_generator/khqr_generator.dart';

import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:fresh_bites_api/services/payment_provider.dart';

class PaymentProviderConfigurationException implements Exception {
  final String message;

  const PaymentProviderConfigurationException(this.message);

  @override
  String toString() => message;
}

enum PaymentProviderMode { demo, bakong }

class PaymentProviderSettings {
  final PaymentProviderMode mode;
  final String? bakongEnvironment;
  final String? bakongApiToken;
  final String? bakongMerchantAccountId;
  final String? bakongMerchantName;

  const PaymentProviderSettings({
    required this.mode,
    required this.bakongEnvironment,
    required this.bakongApiToken,
    required this.bakongMerchantAccountId,
    required this.bakongMerchantName,
  });

  factory PaymentProviderSettings.fromEnvironment() {
    final env = DotEnv()..load();
    return PaymentProviderSettings.fromValues(
      provider: env['PAYMENT_PROVIDER'],
      bakongEnvironment: env['BAKONG_ENVIRONMENT'],
      bakongApiToken: env['BAKONG_API_TOKEN'],
      bakongMerchantAccountId: env['BAKONG_MERCHANT_ACCOUNT_ID'],
      bakongMerchantName: env['BAKONG_MERCHANT_NAME'],
    );
  }

  factory PaymentProviderSettings.fromValues({
    String? provider,
    String? bakongEnvironment,
    String? bakongApiToken,
    String? bakongMerchantAccountId,
    String? bakongMerchantName,
  }) {
    final mode = switch ((provider ?? 'demo').trim().toLowerCase()) {
      '' || 'demo' => PaymentProviderMode.demo,
      'bakong' => PaymentProviderMode.bakong,
      _ => throw const PaymentProviderConfigurationException(
        'PAYMENT_PROVIDER must be either demo or bakong.',
      ),
    };

    final settings = PaymentProviderSettings(
      mode: mode,
      bakongEnvironment: _nonEmpty(bakongEnvironment),
      bakongApiToken: _nonEmpty(bakongApiToken),
      bakongMerchantAccountId: _nonEmpty(bakongMerchantAccountId),
      bakongMerchantName: _nonEmpty(bakongMerchantName),
    );

    if (mode == PaymentProviderMode.bakong) {
      if (settings.bakongEnvironment != 'sit') {
        throw const PaymentProviderConfigurationException(
          'BAKONG_ENVIRONMENT must be set to sit; production processing is '
          'not enabled.',
        );
      }
      if (settings.bakongApiToken == null ||
          settings.bakongMerchantAccountId == null ||
          settings.bakongMerchantName == null) {
        throw const PaymentProviderConfigurationException(
          'Bakong mode requires BAKONG_API_TOKEN, '
          'BAKONG_MERCHANT_ACCOUNT_ID, and BAKONG_MERCHANT_NAME.',
        );
      }
    }
    return settings;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class BakongService implements PaymentProvider {
  final PaymentProviderSettings settings;

  const BakongService(this.settings);

  @override
  String get name => 'bakong';

  @override
  bool get isDemo => false;

  @override
  Future<PaymentRequest> createPaymentRequest(PaymentRequestInput input) async {
    final order = input.order;
    final merchantAccountId = settings.bakongMerchantAccountId;
    final merchantName = settings.bakongMerchantName;

    if (merchantAccountId == null || merchantName == null) {
      throw const PaymentProviderConfigurationException(
        'Bakong requires BAKONG_MERCHANT_ACCOUNT_ID and BAKONG_MERCHANT_NAME.',
      );
    }

    final currency = order.currency.toUpperCase() == 'KHR'
        ? KHQRCurrency.khr.code
        : KHQRCurrency.usd.code;

    // 1. Generate dynamic KHQR using Bakong parameters
    final individualInfo = IndividualInfo(
      bakongAccountID: merchantAccountId,
      merchantName: merchantName,
      merchantCity: 'Phnom Penh',
      amount: order.totalAmount,
      currency: currency,
      storeLabel: merchantName,
      terminalLabel: order.id,
      billNumber: order.id,
      purposeOfTransaction: 'Order #${order.id}',
    );

    final response = KHQRGenerator.generateIndividual(individualInfo);
    if (response.status.code != 0 || response.data == null) {
      throw StateError(
        'Failed to generate KHQR: ${response.status.message ?? 'Unknown error'}',
      );
    }

    final qrString = response.data!.qr;
    // 2. MD5 of raw QR is used by Bakong to track dynamic transactions
    final md5Hash = response.data!.md5.isNotEmpty
        ? response.data!.md5.toLowerCase()
        : md5.convert(utf8.encode(qrString)).toString().toLowerCase();

    return PaymentRequest(
      paymentReference: md5Hash,
      qrData: qrString,
    );
  }

  @override
  Future<PaymentVerification> verifyTransaction(Payment payment) async {
    final md5Hash = payment.transactionReference;
    if (md5Hash == null || md5Hash.isEmpty) {
      return const PaymentVerification(
        status: PaymentVerificationStatus.failed,
      );
    }

    final token = settings.bakongApiToken;
    if (token == null || token.isEmpty) {
      throw const PaymentProviderConfigurationException(
        'BAKONG_API_TOKEN is not configured.',
      );
    }

    // Bakong SIT Check Transaction Endpoint
    final url = Uri.parse(
      'https://sit-api-bakong.nbc.org.kh/v1/check_transaction_by_md5',
    );

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'md5': md5Hash}),
    );

    if (response.statusCode == 401) {
      throw const PaymentProviderConfigurationException(
        'Bakong SIT returned 401 Unauthorized. Check BAKONG_API_TOKEN.',
      );
    }

    if (response.statusCode != 200) {
      return const PaymentVerification(
        status: PaymentVerificationStatus.failed,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responseCode = body['responseCode'] ?? body['code'];
    final data = body['data'] as Map<String, dynamic>?;

    // Code 0 with non-null data confirms payment was completed
    if (responseCode == 0 && data != null) {
      return PaymentVerification(
        status: PaymentVerificationStatus.successful,
        transactionId: data['hash'] as String?,
        paymentReference: md5Hash,
        receiverAccountId: data['toAccountId'] as String?,
        currency: data['currency'] as String?,
        amount: data['amount']?.toString(),
      );
    }

    // errorCode 1 or null data means the customer has not paid yet
    final errorCode = body['errorCode'];
    if (errorCode == 1 || data == null) {
      return const PaymentVerification(
        status: PaymentVerificationStatus.pending,
      );
    }

    return const PaymentVerification(
      status: PaymentVerificationStatus.failed,
    );
  }
}