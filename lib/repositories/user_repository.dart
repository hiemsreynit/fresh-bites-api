import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:fresh_bites_api/database/mongodb.dart';
import 'package:fresh_bites_api/models/user_model.dart';

class DuplicateUserEmailException implements Exception {
  const DuplicateUserEmailException();
}

class UserRepository {
  static const tokenLifetime = Duration(days: 7);
  static final _secureRandom = Random.secure();

  DbCollection get _users => MongoDatabase.db.collection('users');
  DbCollection get _tokens => MongoDatabase.db.collection('auth_tokens');

  Future<List<User>> getAll() async {
    final documents = await _users.find().toList();
    return documents.map(User.fromMap).toList();
  }

  Future<User?> getById(String id) async {
    final document = await _users.findOne(where.id(ObjectId.parse(id)));
    return document == null ? null : User.fromMap(document);
  }

  Future<UserCredentials?> getCredentialsByEmail(String email) async {
    final document = await _users.findOne(where.eq('email', email));
    if (document == null) return null;

    return UserCredentials(
      user: User.fromMap(document),
      passwordHash: document['passwordHash'] as String,
    );
  }

  Future<User> create({
    required String name,
    required String email,
    required String passwordHash,
    required String phone,
    String? defaultAddress,
  }) async {
    final now = DateTime.now();
    final document = {
      'name': name,
      'email': email,
      'passwordHash': passwordHash,
      'phone': phone,
      'role': 'customer',
      'defaultAddress': defaultAddress,
      'createdAt': now,
      'updatedAt': now,
    };

    try {
      final result = await _users.insertOne(document);
      return User.fromMap({...document, '_id': result.id});
    } on MongoDartError catch (error) {
      if (_isDuplicateKeyError(error)) {
        throw const DuplicateUserEmailException();
      }
      rethrow;
    }
  }

  Future<User?> update(String id, Map<String, Object?> changes) async {
    final modifier = modify.set('updatedAt', DateTime.now());
    for (final entry in changes.entries) {
      modifier.set(entry.key, entry.value);
    }

    try {
      final userId = ObjectId.parse(id);
      final result = await _users.updateOne(
        where.id(userId),
        modifier,
      );
      if (result.nMatched == 0) return null;
      if (changes.containsKey('passwordHash')) {
        await _tokens.deleteMany(where.eq('userId', userId));
      }
      return await getById(id);
    } on MongoDartError catch (error) {
      if (_isDuplicateKeyError(error)) {
        throw const DuplicateUserEmailException();
      }
      rethrow;
    }
  }

  Future<bool> delete(String id) async {
    final userId = ObjectId.parse(id);
    await _tokens.deleteMany(where.eq('userId', userId));
    final result = await _users.deleteOne(where.id(userId));
    return result.nRemoved > 0;
  }

  Future<String> createAccessToken(
    String userId, {
    required DateTime expiresAt,
  }) async {
    final bytes = List<int>.generate(
      32,
      (_) => _secureRandom.nextInt(256),
    );
    final token = base64Url.encode(bytes).replaceAll('=', '');
    final now = DateTime.now().toUtc();

    await _tokens.insertOne({
      'tokenHash': _hashToken(token),
      'userId': ObjectId.parse(userId),
      'expiresAt': expiresAt,
      'createdAt': now,
    });
    return token;
  }

  Future<User?> getUserForAccessToken(String token) async {
    final tokenDocument = await _tokens.findOne(
      where.eq('tokenHash', _hashToken(token)),
    );
    if (tokenDocument == null) return null;

    final expiresAt = tokenDocument['expiresAt'] as DateTime;
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      await _tokens.deleteOne(where.id(tokenDocument['_id'] as ObjectId));
      return null;
    }

    final userId = tokenDocument['userId'] as ObjectId;
    return getById(userId.toHexString());
  }

  String _hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  bool _isDuplicateKeyError(MongoDartError error) {
    return error.mongoCode == 11000 ||
        error.errorCode == '11000' ||
        error.errorCodeName == 'DuplicateKey';
  }
}
