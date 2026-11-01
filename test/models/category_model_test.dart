import 'package:fresh_bites_api/models/category_model.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:test/test.dart';

void main() {
  test('Category.fromMap serializes MongoDB ObjectIds as plain hex IDs', () {
    final id = ObjectId();
    final timestamp = DateTime.utc(2026, 11, 1);
    final category = Category.fromMap({
      '_id': id,
      'name': 'Fast Food',
      'isActive': true,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    expect(category.id, id.oid);
    expect(category.toJson()['_id'], id.oid);
  });
}
