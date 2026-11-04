import 'dart:io';

import 'package:decimal/decimal.dart';
// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:fresh_bites_api/database/mongodb.dart';
import 'package:fresh_bites_api/models/order_model.dart';
import 'package:fresh_bites_api/models/payment_model.dart';

class PaymentOrderNotFoundException implements Exception {}

class PaymentConflictException implements Exception {}

class InvalidPaymentOrderException implements Exception {}

class PaymentRepository {
  DbCollection get _payments => MongoDatabase.db.collection('payments');
  DbCollection get _orders => MongoDatabase.db.collection('orders');

  Future<Order> getPayableOrder({
    required String orderId,
    required String userId,
  }) async {
    final order = await _orders.findOne(
      where.id(ObjectId.parse(orderId)),
    );
    if (order == null || order['userId'] is! ObjectId) {
      throw PaymentOrderNotFoundException();
    }
    if ((order['userId'] as ObjectId).oid != userId) {
      throw PaymentOrderNotFoundException();
    }
    _validatePayableOrder(order);
    return Order.fromMap(order);
  }

  Future<Payment> create({
    required String orderId,
    required String userId,
    required PaymentMethod paymentMethod,
    required String paymentProvider,
    required String transactionReference,
    String? qrData,
  }) async {
    final orderObjectId = ObjectId.parse(orderId);
    final order = await _orders.findOne(where.id(orderObjectId));
    if (order == null || order['userId'] is! ObjectId) {
      throw PaymentOrderNotFoundException();
    }
    if ((order['userId'] as ObjectId).oid != userId) {
      throw PaymentOrderNotFoundException();
    }
    _validatePayableOrder(order);
    final amount = _decimalAmount(order['totalAmount']);
    final currency = order['currency'];
    final existing = await _payments.findOne(
      where.eq('orderId', orderObjectId),
    );
    if (existing != null) throw PaymentConflictException();

    final now = DateTime.now().toUtc();
    final currentOrderStatus = order['orderStatus'];
    if (currentOrderStatus is! String ||
        amount == null ||
        amount < Decimal.zero ||
        currency is! String) {
      throw InvalidPaymentOrderException();
    }

    final orderPaymentStatus = paymentMethod == PaymentMethod.cashOnDelivery
        ? 'unpaid'
        : 'pending';
    final didUpdateOrder = paymentMethod == PaymentMethod.cashOnDelivery
        ? true
        : (await _orders.updateOne(
                where
                    .id(orderObjectId)
                    .eq('orderStatus', currentOrderStatus)
                    .eq('paymentStatus', 'unpaid'),
                modify
                    .set('paymentStatus', orderPaymentStatus)
                    .set('updatedAt', now),
              )).nMatched >
              0;
    if (!didUpdateOrder) throw PaymentConflictException();

    final document = {
      '_id': ObjectId(),
      'orderId': orderObjectId,
      'userId': ObjectId.parse(userId),
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod.value,
      'paymentProvider': paymentProvider,
      'transactionReference': transactionReference,
      'providerTransactionId': null,
      'qrData': qrData,
      'paymentStatus': PaymentStatus.pending.value,
      'paidAt': null,
      'createdAt': now,
      'updatedAt': now,
    };

    try {
      final result = await _payments.insertOne(document);
      if (!result.isSuccess) {
        final writeError = result.writeError;
        if (writeError?.code == 11000) throw PaymentConflictException();
        throw StateError(
          'MongoDB rejected payment insert'
          '${writeError?.code == null ? '' : ' (${writeError!.code})'}'
          '${writeError?.errmsg == null ? '' : ': ${writeError!.errmsg}'}',
        );
      }

      final paymentId = result.id;
      if (paymentId is! ObjectId) {
        throw StateError('MongoDB did not return a payment ObjectId.');
      }
      final saved = await _payments.findOne(where.id(paymentId));
      if (saved == null) {
        throw StateError('Created payment could not be reloaded.');
      }
      return Payment.fromMap(saved);
    } catch (error) {
      if (paymentMethod != PaymentMethod.cashOnDelivery) {
        final rollback = await _orders.updateOne(
          where.id(orderObjectId).eq('paymentStatus', orderPaymentStatus),
          modify.set('paymentStatus', 'unpaid').set('updatedAt', now),
        );
        if (rollback.nMatched == 0) {
          stderr.writeln('Payment creation order-status rollback failed.');
          throw StateError('Payment creation rollback failed.');
        }
      }
      rethrow;
    }
  }

  Future<List<Payment>> getAll({String? userId}) async {
    final selector = userId == null
        ? where.sortBy('createdAt', descending: true)
        : where
              .eq('userId', ObjectId.parse(userId))
              .sortBy('createdAt', descending: true);
    final documents = await _payments.find(selector).toList();
    return documents.map(Payment.fromMap).toList();
  }

  Future<Payment?> getById(String id) async {
    final document = await _payments.findOne(where.id(ObjectId.parse(id)));
    return document == null ? null : Payment.fromMap(document);
  }

  Future<bool> updateStatus({
    required Payment payment,
    required PaymentStatus newStatus,
  }) async {
    if (newStatus == PaymentStatus.completed) {
      throw PaymentConflictException();
    }
    final orderId = ObjectId.parse(payment.orderId);
    final order = await _orders.findOne(where.id(orderId));
    if (order == null) throw PaymentConflictException();

    final oldOrderPaymentStatus = _orderPaymentStatus(payment);
    if (order['paymentStatus'] != oldOrderPaymentStatus) {
      throw PaymentConflictException();
    }
    final newOrderPaymentStatus = _orderPaymentStatus(
      payment,
      statusOverride: newStatus,
    );
    final now = DateTime.now().toUtc();
    final orderUpdate = await _orders.updateOne(
      where.id(orderId).eq('paymentStatus', oldOrderPaymentStatus),
      modify.set('paymentStatus', newOrderPaymentStatus).set('updatedAt', now),
    );
    if (orderUpdate.nMatched == 0) throw PaymentConflictException();

    final modifier = modify
        .set('paymentStatus', newStatus.value)
        .set('updatedAt', now);
    try {
      final paymentUpdate = await _payments.updateOne(
        where
            .id(ObjectId.parse(payment.id))
            .eq('paymentStatus', payment.paymentStatus.value),
        modifier,
      );
      if (paymentUpdate.nMatched > 0) return true;
    } catch (_) {
      await _rollbackOrderPaymentStatus(
        orderId,
        newOrderPaymentStatus,
        oldOrderPaymentStatus,
        now,
      );
      rethrow;
    }

    await _rollbackOrderPaymentStatus(
      orderId,
      newOrderPaymentStatus,
      oldOrderPaymentStatus,
      now,
    );
    return false;
  }

  Future<bool> completeVerifiedPayment({
    required String paymentId,
    required String providerTransactionId,
  }) async {
    if (providerTransactionId.trim().isEmpty) {
      throw PaymentConflictException();
    }

    final paymentObjectId = ObjectId.parse(paymentId);
    final paymentDocument = await _payments.findOne(where.id(paymentObjectId));
    if (paymentDocument == null) throw PaymentConflictException();
    final payment = Payment.fromMap(paymentDocument);
    if (payment.paymentStatus != PaymentStatus.pending ||
        payment.paymentProvider != 'bakong' ||
        payment.paymentMethod == PaymentMethod.cashOnDelivery) {
      throw PaymentConflictException();
    }

    final orderId = ObjectId.parse(payment.orderId);
    final order = await _orders.findOne(where.id(orderId));
    if (order == null ||
        !['pending', 'confirmed'].contains(order['orderStatus']) ||
        order['paymentStatus'] != 'pending') {
      throw PaymentConflictException();
    }

    final now = DateTime.now().toUtc();
    final orderUpdate = await _orders.updateOne(
      where
          .id(orderId)
          .eq('orderStatus', order['orderStatus'])
          .eq('paymentStatus', 'pending'),
      modify.set('paymentStatus', 'paid').set('updatedAt', now),
    );
    if (orderUpdate.nMatched == 0) throw PaymentConflictException();

    try {
      final paymentUpdate = await _payments.updateOne(
        where
            .id(paymentObjectId)
            .eq('paymentStatus', PaymentStatus.pending.value)
            .eq('paymentProvider', 'bakong')
            .eq('providerTransactionId', null),
        modify
            .set('paymentStatus', PaymentStatus.completed.value)
            .set('providerTransactionId', providerTransactionId)
            .set('paidAt', now)
            .set('updatedAt', now),
      );
      if (paymentUpdate.nMatched > 0) return true;
    } catch (error) {
      await _rollbackOrderPaymentStatus(orderId, 'paid', 'pending', now);
      if (_isDuplicateKeyError(error)) throw PaymentConflictException();
      rethrow;
    }

    await _rollbackOrderPaymentStatus(orderId, 'paid', 'pending', now);
    return false;
  }

  void _validatePayableOrder(Map<String, dynamic> order) {
    if (!['pending', 'confirmed'].contains(order['orderStatus']) ||
        order['paymentStatus'] != 'unpaid') {
      throw PaymentConflictException();
    }
    final amount = _decimalAmount(order['totalAmount']);
    final currency = order['currency'];
    if (amount == null ||
        amount < Decimal.zero ||
        currency is! String ||
        !['USD', 'KHR'].contains(currency)) {
      throw InvalidPaymentOrderException();
    }
  }

  bool _isDuplicateKeyError(Object error) {
    return error.toString().contains('E11000') ||
        error.toString().contains('11000');
  }

  Future<void> _rollbackOrderPaymentStatus(
    ObjectId orderId,
    String expected,
    String restore,
    DateTime now,
  ) async {
    final rollback = await _orders.updateOne(
      where.id(orderId).eq('paymentStatus', expected),
      modify.set('paymentStatus', restore).set('updatedAt', now),
    );
    if (rollback.nMatched == 0) {
      stderr.writeln('Payment status update order-status rollback failed.');
      throw StateError('Payment status update rollback failed.');
    }
  }

  String _orderPaymentStatus(
    Payment payment, {
    PaymentStatus? statusOverride,
  }) {
    final status = statusOverride ?? payment.paymentStatus;
    return switch (status) {
      PaymentStatus.pending =>
        payment.paymentMethod == PaymentMethod.cashOnDelivery
            ? 'unpaid'
            : 'pending',
      PaymentStatus.completed => 'paid',
      PaymentStatus.failed => 'failed',
      PaymentStatus.refunded => 'refunded',
    };
  }
}

Decimal? _decimalAmount(dynamic value) {
  if (value is Decimal) return value;
  if (value is BsonDecimal128) return value.value;
  if (value is num && value.isFinite) return Decimal.tryParse(value.toString());
  return null;
}
