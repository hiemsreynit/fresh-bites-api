import 'package:decimal/decimal.dart';
// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:mongo_dart/mongo_dart.dart';

enum PaymentMethod {
  cashOnDelivery,
  card,
  digitalWallet;

  String get value => switch (this) {
    PaymentMethod.cashOnDelivery => 'cash_on_delivery',
    PaymentMethod.card => 'card',
    PaymentMethod.digitalWallet => 'digital_wallet',
  };

  static PaymentMethod? fromValue(String? value) {
    for (final method in values) {
      if (method.value == value) return method;
    }
    return null;
  }
}

enum PaymentStatus {
  pending,
  completed,
  failed,
  refunded;

  String get value => name;

  static PaymentStatus? fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }

  bool canTransitionTo(PaymentStatus next) {
    return switch (this) {
      PaymentStatus.pending =>
        next == PaymentStatus.completed || next == PaymentStatus.failed,
      PaymentStatus.completed => next == PaymentStatus.refunded,
      PaymentStatus.failed || PaymentStatus.refunded => false,
    };
  }
}

class Payment {
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final String currency;
  final PaymentMethod paymentMethod;
  final String? transactionReference;
  final PaymentStatus paymentStatus;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.transactionReference,
    required this.paymentStatus,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    final id = map['_id'];
    final orderId = map['orderId'];
    final userId = map['userId'];
    final method = PaymentMethod.fromValue(map['paymentMethod'] as String?);
    final status = PaymentStatus.fromValue(map['paymentStatus'] as String?);
    final amount = _decimalAmount(map['amount']);
    if (id is! ObjectId ||
        orderId is! ObjectId ||
        userId is! ObjectId ||
        method == null ||
        status == null ||
        amount == null ||
        map['currency'] is! String) {
      throw const FormatException('Invalid payment document.');
    }

    return Payment(
      id: id.oid,
      orderId: orderId.oid,
      userId: userId.oid,
      amount: amount.toDouble(),
      currency: map['currency'] as String,
      paymentMethod: method,
      transactionReference: map['transactionReference'] as String?,
      paymentStatus: status,
      paidAt: map['paidAt'] as DateTime?,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'userId': userId,
    'amount': amount,
    'currency': currency,
    'paymentMethod': paymentMethod.value,
    'transactionReference': transactionReference,
    'paymentStatus': paymentStatus.value,
    'paidAt': paidAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

Decimal? _decimalAmount(dynamic value) {
  if (value is Decimal) return value;
  if (value is BsonDecimal128) return value.value;
  if (value is num && value.isFinite) return Decimal.tryParse(value.toString());
  return null;
}
