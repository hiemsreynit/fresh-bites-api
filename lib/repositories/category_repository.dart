import 'package:mongo_dart/mongo_dart.dart';

import 'package:fresh_bites_api/database/mongodb.dart';
import 'package:fresh_bites_api/models/category_model.dart';

class DuplicateCategoryNameException implements Exception {
  const DuplicateCategoryNameException();
}

enum CategoryDeletionResult {
  deleted,
  notFound,
  referencedByProducts,
}

class CategoryRepository {
  DbCollection get _collection => MongoDatabase.db.collection('categories');
  DbCollection get _products => MongoDatabase.db.collection('products');

  Future<List<Category>> getAll({bool? isActive}) async {
    final selector = isActive == null ? where : where.eq('isActive', isActive);
    final documents = await _collection.find(selector).toList();
    return documents.map(Category.fromMap).toList();
  }

  Future<Category?> getById(String id) async {
    final document = await _collection.findOne(
      where.id(ObjectId.parse(id)),
    );

    return document == null ? null : Category.fromMap(document);
  }

  Future<Category> create(Category category) async {
    try {
      final result = await _collection.insertOne(category.toDocument());
      return category.withId(result.id.toString());
    } on MongoDartError catch (error) {
      if (_isDuplicateKeyError(error)) {
        throw const DuplicateCategoryNameException();
      }
      rethrow;
    }
  }

  Future<bool> update(String id, Map<String, Object?> changes) async {
    final modifier = modify.set('updatedAt', DateTime.now());
    for (final entry in changes.entries) {
      modifier.set(entry.key, entry.value);
    }

    try {
      final result = await _collection.updateOne(
        where.id(ObjectId.parse(id)),
        modifier,
      );
      return result.nMatched > 0;
    } on MongoDartError catch (error) {
      if (_isDuplicateKeyError(error)) {
        throw const DuplicateCategoryNameException();
      }
      rethrow;
    }
  }

  Future<CategoryDeletionResult> deleteIfUnused(String id) async {
    final objectId = ObjectId.parse(id);
    final category = await _collection.findOne(where.id(objectId));
    if (category == null) return CategoryDeletionResult.notFound;

    final referencingProduct = await _products.findOne(
      where.eq('categoryId', objectId),
    );
    if (referencingProduct != null) {
      return CategoryDeletionResult.referencedByProducts;
    }

    final result = await _collection.deleteOne(where.id(objectId));
    return result.nRemoved > 0
        ? CategoryDeletionResult.deleted
        : CategoryDeletionResult.notFound;
  }

  bool _isDuplicateKeyError(MongoDartError error) {
    return error.mongoCode == 11000 ||
        error.errorCode == '11000' ||
        error.errorCodeName == 'DuplicateKey';
  }
}
