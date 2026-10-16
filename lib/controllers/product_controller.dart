
import 'package:dart_frog/dart_frog.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';

class ProductController {
  final ProductRepository _repository = ProductRepository();

  Future<Response> getAll(RequestContext context) async {
    try {
      final products = await _repository.getAll();

      return Response.json(
        body: products.map((product) => {
          'id': product.id,
          ...product.toMap(),
        }).toList(),
      );
    } catch (e) {
      return Response.json(
        statusCode: 500,
        body: {'error': 'Failed to retrieve products'},
      );
    }
  }

  Future<Response> create(RequestContext context) async {
    try {
      final body =
          await context.request.json() as Map<String, dynamic>;

      final product = Product(
        name: body['name'] as String,
        price: (body['price'] as num).toDouble(),
      );

      final id = await _repository.create(product);

      return Response.json(
        statusCode: 201,
        body: {
          'id': id,
          ...product.toMap(),
        },
      );
    } catch (e) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'Invalid product data'},
      );
    }
  }
}
