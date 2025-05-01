// lib/services/database_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Db? _db;
  bool _isInitialized = false;
  bool _isWeb = false;
  String? _connectionError;

  // Set this to true to force a real MongoDB connection even on web
  // FOR TESTING ONLY - NOT FOR PRODUCTION
  static bool forceRealConnection = false;

  // Getters for status
  bool get isInitialized => _isInitialized;
  bool get isConnected => _db != null && _isInitialized && !_isWeb;
  String? get connectionError => _connectionError;

  // Initialize database connection
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Check if running on web platform
    if (kIsWeb && !forceRealConnection) {
      print('Running on web platform - using mock database');
      _isWeb = true;
      _isInitialized = true;
      return true;
    }

    try {
      // Get MongoDB connection string from .env file
      final mongoUri = dotenv.env['MONGO_URI'];
      if (mongoUri == null || mongoUri.isEmpty) {
        _connectionError = 'MongoDB URI not found in environment variables';
        print(_connectionError);
        _isInitialized = true;
        _isWeb = true; // Fall back to mock data
        return false;
      }

      print('Attempting to connect to MongoDB with URI: ${maskUri(mongoUri)}');

      // Connect to MongoDB
      _db = await Db.create(mongoUri);
      await _db!.open();

      _isInitialized = true;
      print('Connected to MongoDB successfully');

      // Print available collections for debugging
      final collections = await _db!.getCollectionNames();
      print('Available collections: $collections');

      return true;
    } catch (e) {
      _connectionError = 'Failed to connect to MongoDB: $e';
      print(_connectionError);
      _isInitialized = true;
      _isWeb = true; // Fall back to mock data
      return false;
    }
  }

  // Helper method to mask URI for safe logging
  String maskUri(String uri) {
    try {
      final parts = uri.split('@');
      if (parts.length > 1) {
        final credentials = parts[0].split('://')[1];
        return uri.replaceAll(credentials, '***:***');
      }
      return uri.replaceAll(RegExp(r':[^@:]+@'), ':***@');
    } catch (_) {
      return '[unable to mask uri]';
    }
  }

  // Get collection by name
  DbCollection getCollection(String name) {
    if (_isWeb && !forceRealConnection) {
      // For web, return a dummy collection or mock behavior
      throw Exception(
        'Direct MongoDB connections not supported on web platform. Use an API instead.',
      );
    }

    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized. Call initialize() first.');
    }

    return _db!.collection(name);
  }

  // Test database connection
  Future<bool> testConnection() async {
    if (_isWeb && !forceRealConnection) return false;
    if (!_isInitialized || _db == null) return false;

    try {
      // Try to get the database stats as a simple connection test
      final collections = await _db!.getCollectionNames();
      print('MongoDB connection test: SUCCESS');
      print(
        'Found ${collections.length} collections: ${collections.join(", ")}',
      );

      // Test opening the users collection
      if (collections.contains('users')) {
        final usersCollection = _db!.collection('users');
        final testQuery = await usersCollection.findOne(
          where.eq('idNumber', 123456),
        );
        print('Direct test query result: $testQuery');

        // Try to fetch one user for debugging
        if (testQuery != null && testQuery.isNotEmpty) {
          final sampleUser = await usersCollection.findOne();
          print('Sample user data: $sampleUser');
        }
      } else {
        print('WARNING: users collection not found!');
      }

      return true;
    } catch (e) {
      print('Failed to connect to MongoDB: $e');
      return false;
    }
  }

  // Close the database connection
  Future<void> close() async {
    if (!_isWeb && _isInitialized && _db != null) {
      await _db!.close();
      _isInitialized = false;
      print('Disconnected from MongoDB');
    }
  }

  Future<void> printAllUsers() async {
    if (_isWeb && !forceRealConnection) {
      print('Web mode: Cannot list all users in mock DB');
      return;
    }

    if (!_isInitialized || _db == null) {
      print('Database not initialized');
      return;
    }

    try {
      final usersCollection = _db!.collection('users');
      final users = await usersCollection.find().toList();

      print('===== ALL USERS IN DATABASE =====');
      print('Total users found: ${users.length}');

      for (var user in users) {
        print(
          'User: ${user['idNumber']} (${user['idNumber'].runtimeType}), '
          'name: ${user['name']}, '
          'completedLessons: ${user['completedLessons']}',
        );
      }
      print('=================================');
    } catch (e) {
      print('Error listing all users: $e');
    }
  }

  // Add this to your database_service.dart file

  Future<bool> ensureTestUserExists() async {
    if (_isWeb && !forceRealConnection) {
      print('Web mode: Using mock database');
      return true;
    }

    if (!_isInitialized || _db == null) {
      print('Database not initialized. Call initialize() first.');
      return false;
    }

    try {
      print('Checking for test user in database...');

      // Get users collection
      final usersCollection = _db!.collection('users');

      // Check if users collection exists
      final collections = await _db!.getCollectionNames();
      if (!collections.contains('users')) {
        print('Creating users collection...');
        // Create collection by inserting and removing a dummy document
        await usersCollection.insertOne({'temp': true});
        await usersCollection.deleteOne(where.eq('temp', true));
        print('Users collection created successfully');
      }

      // Check if test user exists
      final testUser = await usersCollection.findOne(
        where.eq('idNumber', 123456),
      );

      if (testUser == null) {
        print('Test user not found. Creating test user...');

        // Insert test user
        final result = await usersCollection.insertOne({
          'idNumber': 123456,
          'name': 'PHILLIP',
          'createdAt': DateTime.now(),
          'lastLogin': DateTime.now(),
          'completedLessons': [1],
        });

        if (result.isSuccess) {
          print('Created test user with ID: 123456');
          return true;
        } else {
          print('Failed to create test user');
          return false;
        }
      } else {
        print('Test user already exists with ID: 123456');
        return true;
      }
    } catch (e) {
      print('Error ensuring test user exists: $e');
      return false;
    }
  }
}
