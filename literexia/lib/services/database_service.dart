import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Db? _db;
  Database? _localDb;
  bool _isInitialized = false;
  bool _isWeb = false;
  String? _connectionError;

  static bool forceRealConnection = false;

  bool get isInitialized => _isInitialized;
  bool get isConnected => _db != null && _isInitialized && !_isWeb;
  String? get connectionError => _connectionError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Initialize local database first
    await _initLocalDatabase();

    if (kIsWeb && !forceRealConnection) {
      _isWeb = true;
      _isInitialized = true;
      print('[DatabaseService] Web platform ➜ mock mode');
      return true;
    }

    try {
      final uri = dotenv.env['MONGO_URI'];
      if (uri == null || uri.isEmpty) {
        _connectionError = 'MONGO_URI not found in .env';
        _isInitialized = true;
        _isWeb = true;
        return false;
      }

      print('[DatabaseService] Connecting ➜ ${_maskUri(uri)}');
      _db = await Db.create(uri);
      await _db!.open();

      // Try to sync any pending offline data
      await _syncOfflineData();

      _isInitialized = true;
      print(
        '[DatabaseService] Connected. Collections: ${await _db!.getCollectionNames()}',
      );
      return true;
    } catch (e) {
      _connectionError = 'Mongo connection failed: $e';
      _isInitialized = true;
      _isWeb = true;
      print('[DatabaseService] $_connectionError - Using offline mode');
      return true; // Still return true since we have local DB
    }
  }

  Future<void> _initLocalDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/literexia_local.db';
      _localDb = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Create tables for users and assessments
          await db.execute(
            'CREATE TABLE users(id INTEGER PRIMARY KEY, idNumber TEXT, name TEXT, readingLevel TEXT)',
          );
          await db.execute(
            'CREATE TABLE assessments(id INTEGER PRIMARY KEY, userId TEXT, assessmentId INTEGER, score INTEGER, readingLevel TEXT, pending INTEGER)',
          );
          // Create lessons table for offline lesson data
          await db.execute(
            'CREATE TABLE lessons(id INTEGER PRIMARY KEY, lessonIndex INTEGER, title TEXT, description TEXT, questionCount INTEGER, readingLevel TEXT)',
          );
        },
      );
      print('[DatabaseService] Local database initialized');
    } catch (e) {
      print('[DatabaseService] Error initializing local database: $e');
    }
  }

  // Add method to save assessment results locally
  Future<bool> saveAssessmentResultsLocally({
    required Object userId,
    required dynamic assessmentId,
    required int score,
    required String readingLevel,
  }) async {
    try {
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return false;
      }

      // Check if user exists
      final existingUser = await _localDb!.query(
        'users',
        where: 'idNumber = ?',
        whereArgs: [userId],
      );

      // Insert user if not exists
      if (existingUser.isEmpty) {
        await _localDb!.insert('users', {
          'idNumber': userId,
          'name': 'User $userId',
          'readingLevel': readingLevel,
        });
      } else {
        // Update existing user
        await _localDb!.update(
          'users',
          {'readingLevel': readingLevel},
          where: 'idNumber = ?',
          whereArgs: [userId],
        );
      }

      // Save assessment result
      await _localDb!.insert('assessments', {
        'userId': userId,
        'assessmentId': assessmentId is int ? assessmentId : 1,
        'score': score,
        'readingLevel': readingLevel,
        'pending': 1, // Mark as pending sync
      });

      print('[DatabaseService] Assessment results saved locally');
      return true;
    } catch (e) {
      print('[DatabaseService] Error saving locally: $e');
      return false;
    }
  }

  Future<void> _syncOfflineData() async {
    // Implementation to sync pending local data with MongoDB when connection is available
    if (_localDb == null || _db == null) return;

    try {
      // Get all pending assessments
      final pendingAssessments = await _localDb!.query(
        'assessments',
        where: 'pending = ?',
        whereArgs: [1],
      );

      if (pendingAssessments.isEmpty) return;

      print(
        '[DatabaseService] Syncing ${pendingAssessments.length} pending assessments',
      );

      for (final assessment in pendingAssessments) {
        try {
          // Get the user ID and reading level
          final userId = assessment['userId'] as String;
          final readingLevel = assessment['readingLevel'] as String;

          // Try with numeric ID first
          int? numericId;
          try {
            numericId = int.parse(userId);
          } catch (e) {
            // If not numeric, use as is
          }

          final query =
              numericId != null
                  ? where.eq('idNumber', numericId)
                  : where.eq('idNumber', userId);

          // Update in MongoDB
          final result = await _db!
              .collection('users')
              .updateOne(
                query,
                modify
                    .set('readingLevel', readingLevel)
                    .set(
                      'lastAssessmentDate',
                      DateTime.now().toIso8601String(),
                    ),
              );

          if (result.isSuccess) {
            // Mark as synced in local DB
            await _localDb!.update(
              'assessments',
              {'pending': 0},
              where: 'id = ?',
              whereArgs: [assessment['id']],
            );

            print('[DatabaseService] Synced assessment for user $userId');
          }
        } catch (e) {
          print('[DatabaseService] Error syncing assessment: $e');
        }
      }
    } catch (e) {
      print('[DatabaseService] Error during sync: $e');
    }
  }

  DbCollection getCollection(String name) {
    if (_isWeb && !forceRealConnection) {
      throw Exception('Direct MongoDB connections not supported on web.');
    }
    if (!_isInitialized || _db == null) {
      throw Exception('Database not initialized.');
    }
    return _db!.collection(name);
  }

  Future<List<String?>> getCollectionNames() async =>
      _db == null ? [] : _db!.getCollectionNames();

  Future<void> close() async {
    if (!_isWeb && _isInitialized && _db != null) {
      await _db!.close();
    }

    if (_localDb != null) {
      await _localDb!.close();
    }

    _isInitialized = false;
    print('[DatabaseService] Disconnected');
  }

  String _maskUri(String uri) {
    try {
      final parts = uri.split('@');
      if (parts.length > 1) {
        final creds = parts[0].split('://')[1];
        return uri.replaceFirst(creds, '***:***');
      }
      return uri.replaceAll(RegExp(r':[^@:]+@'), ':***@');
    } catch (_) {
      return '[unable to mask uri]';
    }
  }

  // NEW METHOD: Get lessons for a specific reading level from MongoDB or local DB
  Future<List<Map<String, dynamic>>> getLessonsForLevel(
    String readingLevel,
  ) async {
    // Make sure the database is initialized
    if (!_isInitialized) {
      await initialize();
    }

    // Normalize reading level to lowercase for consistent queries
    final normalizedLevel = readingLevel.toLowerCase();
    print('[DatabaseService] Getting lessons for level: $normalizedLevel');

    try {
      if (isConnected && _db != null) {
        // Try to fetch from MongoDB first
        final lessonsCollection = _db!.collection('lessons');

        // Find lessons that match the reading level or are available for all levels
        final cursor =
            await lessonsCollection.find({
              '\$or': [
                {'readingLevel': normalizedLevel},
                {'readingLevel': 'all'},
              ],
              'isActive': true, // Only get active lessons
            }).toList();

        if (cursor.isNotEmpty) {
          print('[DatabaseService] Found ${cursor.length} lessons in MongoDB');

          // Save to local DB for offline access
          await _saveLessonsToLocalDb(cursor, normalizedLevel);

          // Convert MongoDB documents to Map
          return cursor.map((doc) => doc as Map<String, dynamic>).toList();
        }
      }

      // If MongoDB fetch fails or returns empty, try local DB
      return await _getLessonsFromLocalDb(normalizedLevel);
    } catch (e) {
      print('[DatabaseService] Error fetching lessons: $e');

      // Fallback to local DB in case of error
      return await _getLessonsFromLocalDb(normalizedLevel);
    }
  }

  // Helper method to save fetched lessons to local DB
  Future<void> _saveLessonsToLocalDb(
    List<Map<String, dynamic>> lessons,
    String readingLevel,
  ) async {
    if (_localDb == null) return;

    try {
      // Begin transaction
      await _localDb!.transaction((txn) async {
        // Remove existing lessons for this level to avoid duplicates
        await txn.delete(
          'lessons',
          where: 'readingLevel = ?',
          whereArgs: [readingLevel],
        );

        // Insert new lessons
        for (final lesson in lessons) {
          await txn.insert('lessons', {
            'lessonIndex': lesson['lessonIndex'] ?? lesson['index'] ?? 0,
            'title': lesson['title'] ?? 'Untitled Lesson',
            'description': lesson['description'] ?? 'No description available',
            'questionCount': lesson['questionCount'] ?? 5,
            'readingLevel': readingLevel,
          });
        }
      });

      print('[DatabaseService] Saved ${lessons.length} lessons to local DB');
    } catch (e) {
      print('[DatabaseService] Error saving lessons to local DB: $e');
    }
  }

  // Helper method to get lessons from local DB
  Future<List<Map<String, dynamic>>> _getLessonsFromLocalDb(
    String readingLevel,
  ) async {
    if (_localDb == null) {
      print(
        '[DatabaseService] Local DB not available, returning fallback data',
      );
      return _getFallbackLessons(readingLevel);
    }

    try {
      // Query local DB for lessons
      final localLessons = await _localDb!.query(
        'lessons',
        where: 'readingLevel = ?',
        whereArgs: [readingLevel],
        orderBy: 'lessonIndex ASC',
      );

      if (localLessons.isNotEmpty) {
        print(
          '[DatabaseService] Found ${localLessons.length} lessons in local DB',
        );
        return localLessons;
      }

      // If no lessons in local DB, return fallback data
      return _getFallbackLessons(readingLevel);
    } catch (e) {
      print('[DatabaseService] Error reading from local DB: $e');
      return _getFallbackLessons(readingLevel);
    }
  }

  // Fallback data if no lessons found in MongoDB or local DB
  List<Map<String, dynamic>> _getFallbackLessons(String readingLevel) {
    print('[DatabaseService] Using fallback lesson data for $readingLevel');

    // Base lesson that is always available
    final List<Map<String, dynamic>> lessons = [
      {
        'lessonIndex': 1,
        'title': 'ARALIN 1: Panimulang Pagbasa',
        'description':
            'Learn the basics of Filipino reading with interactive exercises',
        'questionCount': 5,
        'isAvailable': true,
      },
    ];

    // Add level-specific lessons
    switch (readingLevel.toLowerCase()) {
      case 'emergent':
        lessons.addAll([
          {
            'lessonIndex': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'lessonIndex': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
        ]);
        break;

      case 'early':
        lessons.addAll([
          {
            'lessonIndex': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'lessonIndex': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
          {
            'lessonIndex': 4,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'description': 'Learn animal sounds in Filipino language',
            'questionCount': 6,
            'isAvailable': true,
          },
        ]);
        break;

      case 'fluent':
        lessons.addAll([
          {
            'lessonIndex': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'lessonIndex': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
          {
            'lessonIndex': 4,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'description': 'Learn animal sounds in Filipino language',
            'questionCount': 6,
            'isAvailable': true,
          },
          {
            'lessonIndex': 5,
            'title': 'ARALIN 5: Mga Salitang may Katunog',
            'description': 'Learn words that rhyme in Filipino',
            'questionCount': 7,
            'isAvailable': true,
          },
        ]);
        break;
    }

    return lessons;
  }
}
