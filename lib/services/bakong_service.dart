import 'package:dotenv/dotenv.dart';
import 'package:fresh_bites_api/models/payment_model.dart';
import 'package:fresh_bites_api/services/payment_provider.dart';

class PaymentProviderConfigurationException implements Exception {
  final String message;

  const PaymentProviderConfigurationException(this.message);

  @override
  String toString() => message;
}

class BakongIntegrationUnavailableException implements Exception {
  const BakongIntegrationUnavailableException();

  @override
  String toString() =>
      'Bakong payments are not enabled: an approved server-compatible '
      'KHQR SDK and verified SIT integration are required.';
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
    throw const BakongIntegrationUnavailableException();
  }

  @override
  Future<PaymentVerification> verifyTransaction(Payment payment) async {
    throw const BakongIntegrationUnavailableException();
  }
}
