
class Product {
  final String? id;
  final String name;
  final double price;

  Product({
    this.id,
    required this.name,
    required this.price,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['_id']?.toString(),
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }
}
