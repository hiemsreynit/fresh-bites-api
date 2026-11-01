// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:decimal/decimal.dart';
import 'package:fresh_bites_api/models/product_model.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Product.fromMap', () {
    test('converts MongoDB ObjectIds and Decimal128 prices', () {
      final productId = ObjectId();
      final categoryId = ObjectId();
      final timestamp = DateTime.utc(2026, 11, 1);
      final product = Product.fromMap({
        '_id': productId,
        'name': 'Fresh Juice',
        'price': BsonDecimal128(Decimal.parse('3.50')),
        'categoryId': categoryId,
        'isAvailable': true,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });

      expect(product.id, productId.oid);
      expect(product.categoryId, categoryId.oid);
      expect(product.price, 3.5);
    });

    test('accepts numeric product prices', () {
      final timestamp = DateTime.utc(2026, 11, 1);
      final product = Product.fromMap({
        '_id': ObjectId(),
        'name': 'Fresh Juice',
        'price': 3.5,
        'categoryId': ObjectId(),
        'isAvailable': true,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });

      expect(product.price, 3.5);
    });

    test('serializes stored prices as exact Decimal values', () {
      final product = Product(
        name: 'Fresh Juice',
        price: 3.5,
        categoryId: ObjectId().oid,
      );

      expect(product.toMap()['price'], Decimal.parse('3.5'));
    });

    test('defaults availability for legacy records where it is missing', () {
      final product = Product.fromMap({
        '_id': ObjectId(),
        'name': 'Legacy Juice',
        'price': 3.5,
        'categoryId': ObjectId(),
      });

      expect(product.isAvailable, isTrue);
      expect(product.updatedAt, product.createdAt);
      expect(product.createdAt, isA<DateTime>());
    });

    test('preserves explicit unavailability', () {
      final timestamp = DateTime.utc(2026, 11, 1);
      final product = Product.fromMap({
        '_id': ObjectId(),
        'name': 'Unavailable Juice',
        'price': 3.5,
        'categoryId': ObjectId(),
        'isAvailable': false,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });

      expect(product.isAvailable, isFalse);
    });
  });
}
