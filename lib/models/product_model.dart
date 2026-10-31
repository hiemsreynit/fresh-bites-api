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
    return Product(
      id: map['_id']?.toString(),
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      categoryId: map['categoryId'].toString(),
      imageUrl: map['imageUrl'] as String?,
      isAvailable: map['isAvailable'] as bool,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
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
      'price': price,
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
