import 'package:mongo_dart/mongo_dart.dart';

import 'package:fresh_bites_api/database/mongodb.dart';
import 'package:fresh_bites_api/models/product_model.dart';

class ProductRepository {
  DbCollection get _collection => MongoDatabase.db.collection('products');

  Future<List<Product>> getAll() async {
    final documents = await _collection.find().toList();
    return documents.map(Product.fromMap).toList();
  }

  Future<Product?> getById(String id) async {
    final document = await _collection.findOne(
      where.id(ObjectId.parse(id)),
    );

    return document == null ? null : Product.fromMap(document);
  }

  Future<Product> create(Product product) async {
    final document = product.toMap()
      ..['categoryId'] = ObjectId.parse(product.categoryId);
    final result = await _collection.insertOne(document);
    if (!result.isSuccess) {
      final writeError = result.writeError;
      throw StateError(
        'MongoDB rejected product insert'
        '${writeError?.code == null ? '' : ' (${writeError!.code})'}'
        '${writeError?.errmsg == null ? '' : ': ${writeError!.errmsg}'}',
      );
    }

    final id = result.id;
    if (id is! ObjectId) {
      throw StateError('MongoDB did not return a product ObjectId.');
    }
    final savedProduct = await getById(id.oid);
    if (savedProduct == null) {
      throw StateError('Created product could not be reloaded.');
    }
    return savedProduct;
  }

  Future<bool> update(String id, Product product) async {
    final modifier = modify
        .set('name', product.name)
        .set('price', product.toMap()['price'])
        .set('categoryId', ObjectId.parse(product.categoryId))
        .set('isAvailable', product.isAvailable)
        .set('updatedAt', DateTime.now());
    if (product.description == null) {
      modifier.unset('description');
    } else {
      modifier.set('description', product.description);
    }
    if (product.imageUrl == null) {
      modifier.unset('imageUrl');
    } else {
      modifier.set('imageUrl', product.imageUrl);
    }

    final result = await _collection.updateOne(
      where.id(ObjectId.parse(id)),
      modifier,
    );
    if (!result.isSuccess) {
      final writeError = result.writeError;
      throw StateError(
        'MongoDB rejected product update'
        '${writeError?.code == null ? '' : ' (${writeError!.code})'}'
        '${writeError?.errmsg == null ? '' : ': ${writeError!.errmsg}'}',
      );
    }

    return result.nMatched > 0;
  }

  Future<bool> delete(String id) async {
    final result = await _collection.deleteOne(
      where.id(ObjectId.parse(id)),
    );

    return result.nRemoved > 0;
  }
}
