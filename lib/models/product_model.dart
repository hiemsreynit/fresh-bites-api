// ignore: implementation_imports
import 'package:bson/src/types/bson_decimal_128.dart';
import 'package:decimal/decimal.dart';
import 'package:mongo_dart/mongo_dart.dart';

class Product {
  final String? id;
  final String name;
  final String? description;
  final double price;
  final String categoryId;
  final String? imageUrl;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.description,
    required this.price,
    required this.categoryId,
    this.imageUrl,
    this.isAvailable = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final rawCategoryId = map['categoryId'];
    final createdAt =
        _dateTimeFromValue(map['createdAt']) ?? DateTime.now().toUtc();
    return Product(
      id: rawId is ObjectId ? rawId.oid : rawId?.toString(),
      name: map['name'] as String,
      description: map['description'] as String?,
      price: _priceAsDouble(map['price']),
      categoryId: rawCategoryId is ObjectId
          ? rawCategoryId.oid
          : rawCategoryId.toString(),
      imageUrl: map['imageUrl'] as String?,
      isAvailable: _availabilityFromValue(map['isAvailable']),
      createdAt: createdAt,
      updatedAt: _dateTimeFromValue(map['updatedAt']) ?? createdAt,
    );
  }

  Product withId(String value) {
    return Product(
      id: value,
      name: name,
      description: description,
      price: price,
      categoryId: categoryId,
      imageUrl: imageUrl,
      isAvailable: isAvailable,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'price': Decimal.parse(price.toString()),
      'categoryId': categoryId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

double _priceAsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is Decimal) return value.toDouble();
  if (value is BsonDecimal128) {
    final decimal = value.value;
    if (decimal != null) return decimal.toDouble();
  }
  throw const FormatException('Invalid product price.');
}

bool _availabilityFromValue(dynamic value) {
  if (value == null) return true;
  if (value is bool) return value;
  throw const FormatException('Invalid product availability.');
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  throw const FormatException('Invalid product timestamp.');
}
