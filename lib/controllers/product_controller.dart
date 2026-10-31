import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/product_model.dart';
import 'package:fresh_bites_api/repositories/product_repository.dart';

class ProductController {
  final ProductRepository _repository = ProductRepository();
  static final _idPattern = RegExp(r'^[a-fA-F0-9]{24}$');

  Future<Response> getAll(RequestContext context) async {
    try {
      final products = await _repository.getAll();

      return Response.json(
        body: products.map((product) => product.toJson()).toList(),
      );
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> create(RequestContext context) async {
    final body = await _readObjectBody(context);
    if (body == null) return _badRequest();

    final product = _productFromBody(body);
    if (product == null) return _badRequest();

    try {
      final id = await _repository.create(product);

      return Response.json(
        statusCode: 201,
        body: product.withId(id).toJson(),
      );
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> getById(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();

    try {
      final product = await _repository.getById(id);
      if (product == null) return _notFound();

      return Response.json(body: product.toJson());
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> update(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest();

    final body = await _readObjectBody(context);
    if (body == null) return _badRequest();

    final product = _productFromBody(body, requireAvailability: true);
    if (product == null) return _badRequest();

    try {
      final updated = await _repository.update(id, product);
      if (!updated) return _notFound();

      final saved = await _repository.getById(id);
      if (saved == null) return _notFound();

      return Response.json(body: saved.toJson());
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> delete(String id) async {
    if (!_isValidId(id)) return _badRequest();

    try {
      final deleted = await _repository.delete(id);
      if (!deleted) return _notFound();

      return Response(statusCode: 204);
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Map<String, dynamic>?> _readObjectBody(
    RequestContext context,
  ) async {
    try {
      final body = await context.request.json();
      return body is Map<String, dynamic> ? body : null;
    } on FormatException {
      return null;
    }
  }

  Product? _productFromBody(
    Map<String, dynamic> body, {
    bool requireAvailability = false,
  }) {
    const allowedFields = {
      'name',
      'description',
      'price',
      'categoryId',
      'imageUrl',
      'isAvailable',
    };
    if (body.keys.any((key) => !allowedFields.contains(key))) return null;

    final name = body['name'];
    final description = body['description'];
    final price = body['price'];
    final categoryId = body['categoryId'];
    final imageUrl = body['imageUrl'];
    final isAvailable = body.containsKey('isAvailable')
        ? body['isAvailable']
        : requireAvailability
        ? null
        : true;
    if (name is! String ||
        name.trim().isEmpty ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        categoryId is! String ||
        !_isValidId(categoryId) ||
        (body.containsKey('description') && description is! String) ||
        (body.containsKey('imageUrl') &&
            imageUrl != null &&
            imageUrl is! String) ||
        isAvailable is! bool) {
      return null;
    }

    return Product(
      name: name.trim(),
      description: description as String?,
      price: price.toDouble(),
      categoryId: categoryId,
      imageUrl: imageUrl as String?,
      isAvailable: isAvailable,
    );
  }

  bool _isValidId(String id) => _idPattern.hasMatch(id);

  Response _badRequest() {
    return Response.json(
      statusCode: 400,
      body: {'error': 'Invalid product data or product id'},
    );
  }

  Response _notFound() {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Product not found'},
    );
  }

  Response _internalServerError() {
    return Response.json(
      statusCode: 500,
      body: {'error': 'An unexpected error occurred'},
    );
  }
}
