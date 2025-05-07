// lib/repositories/user_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

// Mock database for web (in-memory)
class _WebMockDb {
  static final _WebMockDb _instance = _WebMockDb._internal();
  factory _WebMockDb() => _instance;
  _WebMockDb._internal() {
    // Initialize with sample data
    _collections['users'] = [
      {
        '_id': 'mockid1',
        'idNumber':
            123456, // Stored as int to match MongoDB ------------- wala pala to
        'name': 'PHILLIP',
        'createdAt': DateTime.now().toString(),
        'lastLogin': DateTime.now().toString(),
        'completedLessons': [1],
      },
    ];
  }

  final Map<String, List<Map<String, dynamic>>> _collections = {};

  // Get all documents in a collection
  List<Map<String, dynamic>> getCollection(String name) {
    return _collections[name] ?? [];
  }

  // Find a document by field value
  Map<String, dynamic>? findOne(
    String collection,
    String field,
    dynamic value,
  ) {
    final collectionData = _collections[collection] ?? [];
    try {
      return collectionData.firstWhere((doc) => doc[field] == value);
    } catch (_) {
      return null;
    }
  }

  // Insert a document
  bool insertOne(String collection, Map<String, dynamic> document) {
    if (!_collections.containsKey(collection)) {
      _collections[collection] = [];
    }

    // Add an ID if none exists
    if (!document.containsKey('_id')) {
      document['_id'] = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    }

    _collections[collection]!.add(document);
    return true;
  }

  // Update a document
  bool updateOne(
    String collection,
    String field,
    dynamic value,
    Map<String, dynamic> updates,
  ) {
    if (!_collections.containsKey(collection)) return false;

    final index = _collections[collection]!.indexWhere(
      (doc) => doc[field] == value,
    );

    if (index < 0) return false;

    // Handle special update operations
    updates.forEach((key, updateValue) {
      // Handle $set operation (most common)
      if (key == r'$set') {
        (updateValue as Map<String, dynamic>).forEach((fieldName, fieldValue) {
          _collections[collection]![index][fieldName] = fieldValue;
        });
      }
      // Handle $addToSet operation
      else if (key == r'$addToSet') {
        (updateValue as Map<String, dynamic>).forEach((fieldName, fieldValue) {
          if (!_collections[collection]![index].containsKey(fieldName)) {
            _collections[collection]![index][fieldName] = [];
          }

          final list = _collections[collection]![index][fieldName] as List;
          if (!list.contains(fieldValue)) {
            list.add(fieldValue);
          }
        });
      }
      // Simple field update (direct assignment)
      else {
        _collections[collection]![index][key] = updateValue;
      }
    });

    return true;
  }
}

class UserRepository {
  final DatabaseService _databaseService = DatabaseService();
  final String _collectionName = 'users';
  final _webDb = _WebMockDb(); // Web mock database

  // Convert string ID to integer for querying
  int? _parseIdNumber(String idNumber) {
    try {
      return int.parse(idNumber);
    } catch (e) {
      print('Error parsing ID to integer: $e');
      return null;
    }
  }

  // Get user by ID number
  Future<User?> getUserByIdNumber(String idNumber) async {
  print('[UserRepository] Getting user with ID: $idNumber');

  try {
    final collection = _databaseService.getCollection(_collectionName);

    // First try with integer
    int? numericId = _parseIdNumber(idNumber);
    Map<String, dynamic>? result;
    
    if (numericId != null) {
      print('[UserRepository] Trying numeric query: $numericId');
      result = await collection.findOne(where.eq('idNumber', numericId));
      if (result != null) {
        print('[UserRepository] Found with numeric query');
        try {
          return User.fromMap(result);
        } catch (e) {
          print('[UserRepository] Error parsing user data: $e');
          // Continue to try string query if this fails
        }
      }
    }

    // Then try with string if numeric query failed
    if (result == null) {
      print('[UserRepository] Trying string query: $idNumber');
      result = await collection.findOne(where.eq('idNumber', idNumber));
      if (result != null) {
        print('[UserRepository] Found with string query');
        try {
          return User.fromMap(result);
        } catch (e) {
          print('[UserRepository] Error parsing user data: $e');
          return null;
        }
      }
    }

    print('[UserRepository] User not found with either query type');
    return null;
  } catch (e) {
    print('[UserRepository] Error in getUserByIdNumber: $e');
    return null;
  }
}

  Future<bool> userExists(String idNumber) async {
    print('[UserRepository] Checking if user exists with ID: $idNumber');

    if (kIsWeb) {
      // Web implementation
      await Future.delayed(const Duration(milliseconds: 200));

      // Try with integer first
      int? numericId = _parseIdNumber(idNumber);
      bool result = false;

      if (numericId != null) {
        result = _webDb.findOne(_collectionName, 'idNumber', numericId) != null;
      }

      // If not found, try with string
      if (!result) {
        result = _webDb.findOne(_collectionName, 'idNumber', idNumber) != null;
      }

      print('[UserRepository] Web mode - user exists: $result');
      return result;
    }

    try {
      print('[UserRepository] Calling getUserByIdNumber to check existence');
      final user = await getUserByIdNumber(idNumber);
      final exists = user != null;
      print('[UserRepository] User exists: $exists');
      return exists;
    } catch (e) {
      print('[UserRepository] Error checking if user exists: $e');
      return false;
    }
  }

  // Update user's last login
  Future<bool> updateLastLogin(String idNumber) async {
    print('[UserRepository] Updating last login for ID: $idNumber');

    if (kIsWeb) {
      // Web implementation
      await Future.delayed(const Duration(milliseconds: 200));

      // Try with integer first
      int? numericId = _parseIdNumber(idNumber);
      bool result = false;

      if (numericId != null) {
        result = _webDb.updateOne(_collectionName, 'idNumber', numericId, {
          r'$set': {'lastLogin': DateTime.now().toString()},
        });
      }

      // If not successful, try with string
      if (!result) {
        result = _webDb.updateOne(_collectionName, 'idNumber', idNumber, {
          r'$set': {'lastLogin': DateTime.now().toString()},
        });
      }

      print('[UserRepository] Web mode - updated login: $result');
      return result;
    }

    try {
      final collection = _databaseService.getCollection(_collectionName);

      // Convert to integer for MongoDB query
      int? numericId = _parseIdNumber(idNumber);
      if (numericId == null) {
        print('[UserRepository] Invalid numeric ID for update: $idNumber');
        return false;
      }

      final result = await collection.updateOne(
        where.eq('idNumber', numericId),
        ModifierBuilder().set('lastLogin', DateTime.now()),
      );
      print('[UserRepository] Update last login result: ${result.isSuccess}');
      return result.isSuccess;
    } catch (e) {
      print('[UserRepository] Error updating last login: $e');
      return false;
    }
  }

  // Update completed lessons
  Future<bool> updateCompletedLesson(String idNumber, int lessonNumber) async {
    print(
      '[UserRepository] Updating completed lesson for ID: $idNumber, lesson: $lessonNumber',
    );

    if (kIsWeb) {
      // Web implementation
      await Future.delayed(const Duration(milliseconds: 200));

      // Try with integer first
      int? numericId = _parseIdNumber(idNumber);
      bool result = false;

      if (numericId != null) {
        result = _webDb.updateOne(_collectionName, 'idNumber', numericId, {
          r'$addToSet': {'completedLessons': lessonNumber},
        });
      }

      // If not successful, try with string
      if (!result) {
        result = _webDb.updateOne(_collectionName, 'idNumber', idNumber, {
          r'$addToSet': {'completedLessons': lessonNumber},
        });
      }

      print('[UserRepository] Web mode - updated lessons: $result');
      return result;
    }

    try {
      final collection = _databaseService.getCollection(_collectionName);

      // Convert to integer for MongoDB query
      int? numericId = _parseIdNumber(idNumber);
      if (numericId == null) {
        print('[UserRepository] Invalid numeric ID for update: $idNumber');
        return false;
      }

      final result = await collection.updateOne(
        where.eq('idNumber', numericId),
        ModifierBuilder().addToSet('completedLessons', lessonNumber),
      );
      print(
        '[UserRepository] Update completed lesson result: ${result.isSuccess}',
      );
      return result.isSuccess;
    } catch (e) {
      print('[UserRepository] Error updating completed lesson: $e');
      return false;
    }
  }

  // Verify user login by ID number

  Future<bool> verifyLogin(String idNumber) async {
    print('[UserRepository] Verifying login for ID: $idNumber');

    try {
      // First, get all users to see what's in the database
      final collection = _databaseService.getCollection(_collectionName);
      final allUsers = await collection.find().toList();
      print('[UserRepository] Current users in database (${allUsers.length}):');
      for (var user in allUsers) {
        print(
          '[UserRepository] User: ID=${user['idNumber']} (${user['idNumber'].runtimeType}), Name=${user['name']}',
        );
      }

      // Try to get user with the given ID
      print('[UserRepository] Calling getUserByIdNumber with ID: $idNumber');
      final user = await getUserByIdNumber(idNumber);
      print(
        '[UserRepository] getUserByIdNumber result: ${user != null ? user.name : 'null'}',
      );

      if (user != null) {
        print('[UserRepository] User found, updating last login');
        await updateLastLogin(idNumber);
        return true;
      }

      print('[UserRepository] User not found with ID: $idNumber');
      return false;
    } catch (e) {
      print('[UserRepository] Error verifying login: $e');
      return false;
    }
  }

  // Check if a user exists by ID number
  Future<bool> _userExists(String idNumber) async {
    final user = await getUserByIdNumber(idNumber);
    return user != null;
  }

  // Add this method to your UserRepository class

  // Create a new user
  Future<bool> createUser({
    required String idNumber,
    required String name,
    List<int>? completedLessons,
  }) async {
    print('[UserRepository] Creating new user with ID: $idNumber, Name: $name');

    if (kIsWeb) {
      // Web implementation
      await Future.delayed(const Duration(milliseconds: 300));

      // Convert ID to integer if possible
      int? numericId = _parseIdNumber(idNumber);

      // Create user object
      final userData = {
        'idNumber': numericId ?? idNumber, // Use integer if possible
        'name': name,
        'createdAt': DateTime.now().toString(),
        'lastLogin': DateTime.now().toString(),
        'completedLessons': completedLessons ?? [],
      };

      // Insert into mock DB
      final result = _webDb.insertOne(_collectionName, userData);
      final exists = await _userExists(idNumber);
      return result;
    }

    try {
      // First check if user already exists
      final exists = await userExists(idNumber);
      if (exists) {
        print('[UserRepository] User with ID $idNumber already exists');
        return false;
      }

      final collection = _databaseService.getCollection(_collectionName);

      // Convert ID to integer if possible
      int? numericId = _parseIdNumber(idNumber);
      if (numericId == null) {
        print('[UserRepository] Invalid numeric ID for creation: $idNumber');
        return false;
      }

      // Create user document
      final user = {
        'idNumber': numericId, // Store as integer in MongoDB
        'name': name,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
        'completedLessons': completedLessons ?? [],
      };

      // Insert document
      final result = await collection.insertOne(user);
      print('[UserRepository] User creation result: ${result.isSuccess}');

      if (result.isSuccess) {
        print('[UserRepository] Created user with ID: $idNumber');
      }

      return result.isSuccess;
    } catch (e) {
      print('[UserRepository] Error creating user: $e');
      // In UserRepository.verifyLogin method
      // Ensure numericId is defined before using it in the print statement
      int? numericId = _parseIdNumber(idNumber);
      if (numericId != null) {
        print(
          '[UserRepository] Query where condition: ${where.eq('idNumber', numericId).toString()}',
        );
      } else {
        print('[UserRepository] Invalid numeric ID for query condition.');
      }
      return false;
    }
  }
}
