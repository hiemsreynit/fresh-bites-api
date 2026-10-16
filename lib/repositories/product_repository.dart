
import 'package:mongo_dart/mongo_dart.dart';
import '../database/mongodb.dart';
import '../models/product_model.dart';

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

  Future<String> create(Product product) async {
    final result = await _collection.insertOne(product.toMap());
    return result.id.toString();
  }

  Future<bool> update(String id, Product product) async {
    final result = await _collection.updateOne(
      where.id(ObjectId.parse(id)),
      modify.set('name', product.name).set('price', product.price),
    );

    return result.nModified > 0;
  }

  Future<bool> delete(String id) async {
    final result = await _collection.deleteOne(
      where.id(ObjectId.parse(id)),
    );

    return result.nRemoved > 0;
  }
}
