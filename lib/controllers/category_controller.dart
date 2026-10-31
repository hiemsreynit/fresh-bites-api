import 'package:dart_frog/dart_frog.dart';

import 'package:fresh_bites_api/models/category_model.dart';
import 'package:fresh_bites_api/repositories/category_repository.dart';

class CategoryController {
  final CategoryRepository _repository = CategoryRepository();

  Future<Response> getAll(RequestContext context) async {
    final rawFilter = context.request.uri.queryParameters['isActive'];
    bool? isActive;

    if (rawFilter != null) {
      if (rawFilter == 'true') {
        isActive = true;
      } else if (rawFilter == 'false') {
        isActive = false;
      } else {
        return _badRequest('isActive must be true or false');
      }
    }

    try {
      final categories = await _repository.getAll(isActive: isActive);
      return Response.json(
        body: categories.map((category) => category.toJson()).toList(),
      );
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> getById(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest('Invalid category id');

    try {
      final category = await _repository.getById(id);
      if (category == null) return _notFound();

      return Response.json(body: category.toJson());
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> create(RequestContext context) async {
    final body = await _readObjectBody(context);
    if (body == null) return _badRequest('Invalid category data');

    final category = _categoryFromCreateBody(body);
    if (category == null) return _badRequest('Invalid category data');

    try {
      final created = await _repository.create(category);
      return Response.json(
        statusCode: 201,
        body: created.toJson(),
      );
    } on DuplicateCategoryNameException {
      return _conflict('A category with this name already exists');
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> update(RequestContext context, String id) async {
    if (!_isValidId(id)) return _badRequest('Invalid category id');

    final body = await _readObjectBody(context);
    if (body == null) return _badRequest('Invalid category data');

    final changes = _changesFromUpdateBody(body);
    if (changes == null) return _badRequest('Invalid category data');

    try {
      final updated = await _repository.update(id, changes);
      if (!updated) return _notFound();

      final category = await _repository.getById(id);
      if (category == null) return _notFound();

      return Response.json(body: category.toJson());
    } on DuplicateCategoryNameException {
      return _conflict('A category with this name already exists');
    } catch (_) {
      return _internalServerError();
    }
  }

  Future<Response> delete(String id) async {
    if (!_isValidId(id)) return _badRequest('Invalid category id');

    try {
      final result = await _repository.deleteIfUnused(id);
      return switch (result) {
        CategoryDeletionResult.deleted => Response(statusCode: 204),
        CategoryDeletionResult.notFound => _notFound(),
        CategoryDeletionResult.referencedByProducts => _conflict(
          'Category is referenced by one or more products',
        ),
      };
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

  Category? _categoryFromCreateBody(Map<String, dynamic> body) {
    const allowedFields = {
      'name',
      'description',
      'imageUrl',
      'isActive',
    };
    if (body.keys.any((key) => !allowedFields.contains(key))) return null;

    final name = body['name'];
    final description = body['description'];
    final imageUrl = body['imageUrl'];
    final isActive = body['isActive'];
    if (name is! String ||
        name.trim().isEmpty ||
        (body.containsKey('description') && description is! String) ||
        (body.containsKey('imageUrl') &&
            imageUrl != null &&
            imageUrl is! String) ||
        (body.containsKey('isActive') && isActive is! bool)) {
      return null;
    }

    final now = DateTime.now();
    return Category(
      name: name.trim(),
      description: description as String?,
      imageUrl: imageUrl as String?,
      isActive: isActive as bool? ?? true,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, Object?>? _changesFromUpdateBody(
    Map<String, dynamic> body,
  ) {
    const allowedFields = {
      'name',
      'description',
      'imageUrl',
      'isActive',
    };
    if (body.isEmpty || body.keys.any((key) => !allowedFields.contains(key))) {
      return null;
    }

    final changes = <String, Object?>{};
    if (body.containsKey('name')) {
      final name = body['name'];
      if (name is! String || name.trim().isEmpty) return null;
      changes['name'] = name.trim();
    }
    if (body.containsKey('description')) {
      final description = body['description'];
      if (description is! String) return null;
      changes['description'] = description;
    }
    if (body.containsKey('imageUrl')) {
      final imageUrl = body['imageUrl'];
      if (imageUrl != null && imageUrl is! String) return null;
      changes['imageUrl'] = imageUrl;
    }
    if (body.containsKey('isActive')) {
      final isActive = body['isActive'];
      if (isActive is! bool) return null;
      changes['isActive'] = isActive;
    }

    return changes;
  }

  bool _isValidId(String id) {
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id);
  }

  Response _badRequest(String message) {
    return Response.json(
      statusCode: 400,
      body: {'error': message},
    );
  }

  Response _notFound() {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Category not found'},
    );
  }

  Response _conflict(String message) {
    return Response.json(
      statusCode: 409,
      body: {'error': message},
    );
  }

  Response _internalServerError() {
    return Response.json(
      statusCode: 500,
      body: {'error': 'An unexpected error occurred'},
    );
  }
}
