class Category {
  final String? id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['_id']?.toString(),
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] as bool,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
    );
  }

  Category withId(String value) {
    return Category(
      id: value,
      name: name,
      description: description,
      imageUrl: imageUrl,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toDocument() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (description != null) 'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
