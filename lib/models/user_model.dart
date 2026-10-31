import 'package:mongo_dart/mongo_dart.dart';

class User {
  final String? id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? defaultAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.defaultAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    final rawId = map['_id'];
    return User(
      id: rawId is ObjectId ? rawId.toHexString() : rawId?.toString(),
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      role: map['role'] as String,
      defaultAddress: map['defaultAddress'] as String?,
      createdAt: map['createdAt'] as DateTime,
      updatedAt: map['updatedAt'] as DateTime,
    );
  }

  Map<String, dynamic> toDocument() => {
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'defaultAddress': defaultAddress,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role,
    'defaultAddress': defaultAddress,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class UserCredentials {
  final User user;
  final String passwordHash;

  const UserCredentials({
    required this.user,
    required this.passwordHash,
  });
}
