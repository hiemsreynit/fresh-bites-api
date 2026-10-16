
import 'package:mongo_dart/mongo_dart.dart';

class MongoDatabase {
  static Db? _db;
  static Future<void>? _connection;

  static Future<void> connect() {
    if (_db != null) return Future.value();
    return _connection ??= _connect();
  }

  static Future<void> _connect() async {
    try {
      final database = await Db.create(
        'mongodb://admin:haha123!@localhost:27017/fresh_bites?authSource=admin',
      );

      await database.open();
      _db = database;

      await _initializeCollections();

      print('MongoDB connected and initialized successfully!');
    } catch (_) {
      _db = null;
      _connection = null;
      rethrow;
    }
  }

  static Map<String, dynamic> _field(
    String type, {
    bool nullable = false,
    List<Object>? allowed,
    num? minimum,
  }) {
    final result = <String, dynamic>{
      'bsonType': nullable ? [type, 'null'] : type,
    };

    if (allowed != null) result['enum'] = allowed;
    if (minimum != null) result['minimum'] = minimum;

    return result;
  }

  static Map<String, dynamic> _schema(
    List<String> required,
    Map<String, dynamic> properties,
  ) {
    return {
      'bsonType': 'object',
      'required': required,
      'properties': {
        '_id': {'bsonType': 'objectId'},
        ...properties,
      },
    };
  }

  static final Map<String, Map<String, dynamic>> _schemas = {
    'users': _schema(
      [
        'name',
        'email',
        'passwordHash',
        'phone',
        'role',
        'createdAt',
        'updatedAt',
      ],
      {
        'name': _field('string'),
        'email': _field('string'),
        'passwordHash': _field('string'),
        'phone': _field('string'),
        'role': _field(
          'string',
          allowed: ['customer', 'admin'],
        ),
        'defaultAddress': _field('string', nullable: true),
        'createdAt': _field('date'),
        'updatedAt': _field('date'),
      },
    ),

    'categories': _schema(
      ['name', 'isActive', 'createdAt', 'updatedAt'],
      {
        'name': _field('string'),
        'description': _field('string'),
        'imageUrl': _field('string', nullable: true),
        'isActive': _field('bool'),
        'createdAt': _field('date'),
        'updatedAt': _field('date'),
      },
    ),

    'products': _schema(
      [
        'name',
        'price',
        'categoryId',
        'isAvailable',
        'createdAt',
        'updatedAt',
      ],
      {
        'name': _field('string'),
        'description': _field('string'),
        'price': _field('decimal', minimum: 0),
        'categoryId': _field('objectId'),
        'imageUrl': _field('string', nullable: true),
        'isAvailable': _field('bool'),
        'createdAt': _field('date'),
        'updatedAt': _field('date'),
      },
    ),

    'orders': _schema(
      [
        'userId',
        'items',
        'deliveryAddress',
        'deliveryPhone',
        'subtotal',
        'deliveryFee',
        'totalAmount',
        'orderStatus',
        'paymentStatus',
        'createdAt',
        'updatedAt',
      ],
      {
        'userId': _field('objectId'),
        'items': {
          'bsonType': 'array',
          'minItems': 1,
          'items': {
            'bsonType': 'object',
            'required': [
              'productId',
              'productName',
              'unitPrice',
              'quantity',
              'subtotal',
            ],
            'properties': {
              'productId': _field('objectId'),
              'productName': _field('string'),
              'unitPrice': _field('decimal', minimum: 0),
              'quantity': _field('int', minimum: 1),
              'subtotal': _field('decimal', minimum: 0),
            },
          },
        },
        'deliveryAddress': _field('string'),
        'deliveryPhone': _field('string'),
        'subtotal': _field('decimal', minimum: 0),
        'deliveryFee': _field('decimal', minimum: 0),
        'totalAmount': _field('decimal', minimum: 0),
        'orderStatus': _field(
          'string',
          allowed: [
            'pending',
            'confirmed',
            'preparing',
            'out_for_delivery',
            'delivered',
            'cancelled',
          ],
        ),
        'paymentStatus': _field(
          'string',
          allowed: [
            'unpaid',
            'pending',
            'paid',
            'failed',
            'refunded',
          ],
        ),
        'createdAt': _field('date'),
        'updatedAt': _field('date'),
      },
    ),

    'payments': _schema(
      [
        'orderId',
        'userId',
        'amount',
        'currency',
        'paymentMethod',
        'paymentStatus',
        'createdAt',
        'updatedAt',
      ],
      {
        'orderId': _field('objectId'),
        'userId': _field('objectId'),
        'amount': _field('decimal', minimum: 0),
        'currency': _field(
          'string',
          allowed: ['USD', 'KHR'],
        ),
        'paymentMethod': _field(
          'string',
          allowed: [
            'cash_on_delivery',
            'card',
            'digital_wallet',
          ],
        ),
        'transactionReference': _field(
          'string',
          nullable: true,
        ),
        'paymentStatus': _field(
          'string',
          allowed: [
            'pending',
            'completed',
            'failed',
            'refunded',
          ],
        ),
        'paidAt': _field('date', nullable: true),
        'createdAt': _field('date'),
        'updatedAt': _field('date'),
      },
    ),
  };

  static Future<void> _initializeCollections() async {
    final existing = (await db.getCollectionNames()).toSet();

    for (final entry in _schemas.entries) {
      final name = entry.key;
      final validator = {
        r'$jsonSchema': entry.value,
      };

      if (existing.contains(name)) {
        await db.runCommand({
          'collMod': name,
          'validator': validator,
          'validationLevel': 'moderate',
          'validationAction': 'error',
        }.cast<String, Object>());
      } else {
        await db.runCommand({
          'create': name,
          'validator': validator,
          'validationLevel': 'strict',
          'validationAction': 'error',
        }.cast<String, Object>());
      }
    }

    await _createIndex('users', 'email_unique', {
      'email': 1,
    }, unique: true);

    await _createIndex('categories', 'category_name_unique', {
      'name': 1,
    }, unique: true);

    await _createIndex('products', 'categoryId_index', {
      'categoryId': 1,
    });

    await _createIndex('orders', 'user_created_index', {
      'userId': 1,
      'createdAt': -1,
    });

    await _createIndex('payments', 'order_created_index', {
      'orderId': 1,
      'createdAt': -1,
    });
  }

  static Future<void> _createIndex(
    String collection,
    String name,
    Map<String, int> keys, {
    bool unique = false,
  }) async {
    await db.runCommand({
      'createIndexes': collection,
      'indexes': [
        {
          'key': keys,
          'name': name,
          if (unique) 'unique': true,
        },
      ],
    }.cast<String, Object>());
  }

  static Db get db {
    if (_db == null) {
      throw StateError('MongoDB is not connected.');
    }

    return _db!;
  }
}
