// lib/services/database_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Db? _db;
  Db? _preAssessmentDb;  // Separate connection for Pre_Assessment database
  Database? _localDb;
  bool _isInitialized = false;
  bool _isWeb = false;
  String? _connectionError;

  static bool forceRealConnection = false;

  bool get isInitialized => _isInitialized;
  bool get isConnected => _db != null && _isInitialized && !_isWeb;
  String? get connectionError => _connectionError;

  // Get the Pre_Assessment database directly
  Future<Db> getPreAssessmentDatabase() async {
    if (_preAssessmentDb != null) {
      if (_preAssessmentDb!.state != State.OPEN) {
        await _preAssessmentDb!.open();
      }
      return _preAssessmentDb!;
    }
    
    // Create a new connection to Pre_Assessment database
    final uri = dotenv.env['MONGO_URI'];
    if (uri == null || uri.isEmpty) {
      throw Exception('MONGO_URI not found in .env');
    }

    final uriWithDb = uri.replaceFirstMapped(
      RegExp(r'mongodb(\+srv)?:\/\/([^/]+)\/([^?]*)'),
      (m) => 'mongodb${m[1] ?? ''}://${m[2]}/Pre_Assessment',
    );
    
    print('[DatabaseService] Connecting directly to Pre_Assessment database ➜ ${_maskUri(uriWithDb)}');
    _preAssessmentDb = await Db.create(uriWithDb);
    await _preAssessmentDb!.open();
    
    // Log the available collections
    final collections = await _preAssessmentDb!.getCollectionNames();
    print('[DatabaseService] Connected to Pre_Assessment database. Collections: $collections');
    
    return _preAssessmentDb!;
  }

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

      print('[DatabaseService] Connecting to default database ➜ ${_maskUri(uri)}');
      _db = await Db.create(uri);
      await _db!.open();
      
      // Also initialize the Pre_Assessment database connection
      await getPreAssessmentDatabase();

      // Try to sync any pending offline data
      await _syncOfflineData();

      _isInitialized = true;
      print('[DatabaseService] Connected to default database: ${_db!.databaseName}');
      print('[DatabaseService] Collections: ${await _db!.getCollectionNames()}');
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
            'CREATE TABLE users(id INTEGER PRIMARY KEY, idNumber TEXT, name TEXT, readingLevel TEXT, preAssessmentCompleted INTEGER DEFAULT 0)',
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

  // Add method to save user data locally for offline authentication
  Future<bool> saveUserDataLocally({
    required String idNumber,
    String? name,
    String? readingLevel,
    bool? preAssessmentCompleted,
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
        whereArgs: [idNumber],
      );

      // Prepare data to save
      final Map<String, dynamic> userData = {
        'idNumber': idNumber,
        'name': name ?? 'User $idNumber',
        'readingLevel': readingLevel ?? '',
      };
      
      // Add preAssessmentCompleted if provided (store as integer 0/1)
      if (preAssessmentCompleted != null) {
        userData['preAssessmentCompleted'] = preAssessmentCompleted ? 1 : 0;
      }

      if (existingUser.isEmpty) {
        // Insert new user
        await _localDb!.insert('users', userData);
        print('[DatabaseService] User $idNumber saved to local DB with preAssessmentCompleted=${preAssessmentCompleted ?? "null"}');
      } else {
        // Update existing user but don't overwrite fields if null
        final updatedData = Map<String, dynamic>.from(userData);
        
        // Remove null values to avoid overwriting existing data
        updatedData.removeWhere((key, value) => value == null);
        
        // Update user
        await _localDb!.update(
          'users',
          updatedData,
          where: 'idNumber = ?',
          whereArgs: [idNumber],
        );
        print('[DatabaseService] User $idNumber updated in local DB with preAssessmentCompleted=${preAssessmentCompleted ?? "unchanged"}');
      }

      return true;
    } catch (e) {
      print('[DatabaseService] Error saving user locally: $e');
      return false;
    }
  }

  // Add method to get user from local database
  Future<Map<String, dynamic>?> getUserFromLocalDb(String idNumber) async {
    try {
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return null;
      }

      final users = await _localDb!.query(
        'users',
        where: 'idNumber = ?',
        whereArgs: [idNumber],
      );

      if (users.isNotEmpty) {
        print('[DatabaseService] Found user in local DB: $idNumber');
        return users.first;
      }

      print('[DatabaseService] User not found in local DB: $idNumber');
      return null;
    } catch (e) {
      print('[DatabaseService] Error getting user from local DB: $e');
      return null;
    }
  }

  // Check if user exists in local database
  Future<bool> userExistsLocally(String idNumber) async {
    try {
      if (_localDb == null) return false;
      
      final result = await _localDb!.query(
        'users',
        where: 'idNumber = ?',
        whereArgs: [idNumber],
        limit: 1,
      );
      
      return result.isNotEmpty;
    } catch (e) {
      print('[DatabaseService] Error checking local user: $e');
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
    
    // Print debug information about the requested collection
    print('[DatabaseService] Getting collection: $name');
    
    // For pre-assessment, we need to use the explicit Pre_Assessment database connection
    if (name == 'pre-assessment') {
      if (_preAssessmentDb != null) {
        print('[DatabaseService] Using Pre_Assessment database for pre-assessment collection');
        return _preAssessmentDb!.collection(name);
      } else {
        print('[DatabaseService] WARNING: Pre_Assessment database not initialized, using default database');
      }
    }
    
    return _db!.collection(name);
  }

  Future<List<String?>> getCollectionNames() async {
    if (_db == null) return [];
    final collections = await _db!.getCollectionNames();
    return (collections as List).map((e) => e?.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getAllLocalUsers() async {
    try {
      if (_localDb == null) return [];
      return await _localDb!.query('users');
    } catch (e) {
      print('[DatabaseService] Error getting all local users: $e');
      return [];
    }
  }

  Future<void> close() async {
    if (!_isWeb && _isInitialized) {
      if (_db != null) {
        await _db!.close();
      }
      if (_preAssessmentDb != null) {
        await _preAssessmentDb!.close();
      }
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

  // Get lessons for a specific reading level from MongoDB - STRICT FILTERING
  Future<List<Map<String, dynamic>>> getLessonsForLevel(
    String readingLevel, {
    String? userIdNumber,
    List<int>? completedLessons,
  }) async {
    // Make sure the database is initialized
    if (!_isInitialized) {
      await initialize();
    }

    // Normalize and validate reading level
    final String targetReadingLevel = _normalizeReadingLevel(readingLevel);
    print('[DatabaseService] Getting lessons for EXACT level: $targetReadingLevel');

    try {
      if (isConnected && _db != null) {
        // Use the main_assessment collection for lesson content
        final mainAssessmentCollection = _db!.collection('main_assessment');
        
        print('[DatabaseService] Querying main_assessment for EXACT readingLevel: $targetReadingLevel');

        // STRICT QUERY - Only get assessments that EXACTLY match the reading level
        var query = where
          .eq('readingLevel', targetReadingLevel)
          .and(where.eq('isActive', true));
        
        var assessments = await mainAssessmentCollection.find(query).toList();

        print('[DatabaseService] Found ${assessments.length} assessments for EXACT level $targetReadingLevel');

        // If no exact matches found, DO NOT fallback to other levels
        // This ensures users only see content appropriate for their level
        if (assessments.isEmpty) {
          print('[DatabaseService] No assessments found for reading level $targetReadingLevel');
          print('[DatabaseService] Will NOT fallback to other levels for content integrity');
          
          // Return empty list - no lessons available for this level
          // The UI should handle this gracefully by showing "no lessons" message
          return [];
        }

        // Debug: Log what we found
        for (final assessment in assessments) {
          print('[DatabaseService] Assessment found: Category=${assessment['category']}, Level=${assessment['readingLevel']}, Questions=${(assessment['questions'] as List?)?.length ?? 0}');
        }

        // Use provided user data for completion tracking
        final safeUserIdNumber = userIdNumber ?? '';
        final safeCompletedLessons = completedLessons ?? [];

        print('[DatabaseService] User $safeUserIdNumber has completed lessons: $safeCompletedLessons');

        // Process lessons in order, maintaining level consistency
        List<Map<String, dynamic>> lessons = [];
        int index = 1;
        
        for (final assessment in assessments) {
          // Verify this assessment is still for the correct reading level
          final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
          if (assessmentLevel != targetReadingLevel) {
            print('[DatabaseService] Skipping assessment with mismatched level: $assessmentLevel vs $targetReadingLevel');
            continue;
          }

          // Check if this specific assessment has been completed
          final String assessmentIdString = assessment['_id'].toString();
          final bool isCompleted = safeUserIdNumber.isNotEmpty 
              ? await hasStudentCompletedAssessment(safeUserIdNumber, assessmentIdString)
              : false;
          
          // Lesson availability logic
          bool isAvailable = index == 1; // First lesson always available
          
          if (index > 1 && assessments.length > 1 && safeUserIdNumber.isNotEmpty) {
            // Check if previous lesson is completed
            final previousAssessmentId = assessments[index - 2]['_id'].toString();
            isAvailable = await hasStudentCompletedAssessment(safeUserIdNumber, previousAssessmentId);
          }
          
          // Extract category from assessment
          final category = assessment['category'] ?? 'Filipino Lesson';
          final questionCount = (assessment['questions'] as List<dynamic>?)?.length ?? 5;
          
          // Create lesson with reading level verification
          lessons.add({
            'index': index,
            'title': 'ARALIN $index: $category',
            'description': _getDescriptionForLevel(targetReadingLevel, category),
            'questionCount': questionCount,
            'isAvailable': isAvailable,
            'isCompleted': isCompleted,
            'assessmentId': assessmentIdString,
            'readingLevel': targetReadingLevel, // Ensure consistency
            'category': category,
          });
          
          print('[DatabaseService] Created lesson $index: $category (Available: $isAvailable, Completed: $isCompleted)');
          index++;
        }

        // Save processed lessons to local DB for offline access
        if (lessons.isNotEmpty) {
          await _saveLessonsToLocalDb(lessons, targetReadingLevel);
        }
        
        print('[DatabaseService] Returning ${lessons.length} lessons for reading level $targetReadingLevel');
        return lessons;
      }
      
      // If MongoDB not available, try local DB (should also respect reading level)
      return await _getLessonsFromLocalDb(targetReadingLevel);
      
    } catch (e) {
      print('[DatabaseService] Error fetching lessons for level $targetReadingLevel: $e');
      
      // Try local DB as fallback, but still maintain level filtering
      try {
        return await _getLessonsFromLocalDb(targetReadingLevel);
      } catch (localError) {
        print('[DatabaseService] Local DB also failed: $localError');
        // Return empty list to maintain level integrity
        return [];
      }
    }
  }

  // Helper method to normalize reading level format
  String _normalizeReadingLevel(String readingLevel) {
    // Ensure consistent capitalization and formatting
    switch (readingLevel.toLowerCase().trim()) {
      case 'low emerging':
      case 'lowEmerging':
      case 'low_emerging':
        return 'Low Emerging';
      case 'high emerging':
      case 'highEmerging':
      case 'high_emerging':
        return 'High Emerging';
      case 'developing':
        return 'Developing';
      case 'transitioning':
        return 'Transitioning';
      case 'at grade level':
      case 'atGradeLevel':
      case 'at_grade_level':
        return 'At Grade Level';
      case 'emergent':
        return 'Low Emerging'; // Map old format to new
      case 'early':
        return 'High Emerging'; // Map old format to new
      case 'fluent':
        return 'At Grade Level'; // Map old format to new
      default:
        return readingLevel; // Return as-is if not recognized
    }
  }

  // Helper method to get appropriate description based on reading level
  String _getDescriptionForLevel(String readingLevel, String category) {
    final levelDescriptions = {
      'Low Emerging': 'Fundamental $category skills for beginning readers',
      'High Emerging': 'Building $category foundation with basic skills',
      'Developing': 'Strengthening $category abilities for growing readers',
      'Transitioning': 'Advanced $category practice for developing readers',
      'At Grade Level': 'Grade-appropriate $category mastery activities',
    };
    
    return levelDescriptions[readingLevel] ?? 
           'Interactive $category activities for ${readingLevel.toLowerCase()} readers';
  }

  // Updated helper method to save lessons to local DB with level filtering
  Future<void> _saveLessonsToLocalDb(List<Map<String, dynamic>> lessons, String readingLevel) async {
    if (_localDb == null || lessons.isEmpty) return;
    
    try {
      // Begin transaction
      await _localDb!.transaction((txn) async {
        // Remove existing lessons for this SPECIFIC level only
        await txn.delete(
          'lessons',
          where: 'readingLevel = ?',
          whereArgs: [readingLevel],
        );
        
        // Insert new lessons with level verification
        for (final lesson in lessons) {
          // Ensure we're only saving lessons for the correct level
          final lessonLevel = lesson['readingLevel'] ?? readingLevel;
          if (lessonLevel == readingLevel) {
            await txn.insert('lessons', {
              'lessonIndex': lesson['index'] ?? 0,
              'title': lesson['title'] ?? 'Untitled Lesson',
              'description': lesson['description'] ?? 'No description available',
              'questionCount': lesson['questionCount'] ?? 5,
              'readingLevel': readingLevel, // Explicitly set the level
              'category': lesson['category'] ?? 'Unknown',
              'assessmentId': lesson['assessmentId'] ?? '',
            });
          }
        }
      });
      
      print('[DatabaseService] Saved ${lessons.length} lessons for level $readingLevel to local DB');
    } catch (e) {
      print('[DatabaseService] Error saving lessons to local DB: $e');
    }
  }

  // Helper method to get lessons from local DB
  Future<List<Map<String, dynamic>>> _getLessonsFromLocalDb(String readingLevel) async {
    if (_localDb == null) {
      print('[DatabaseService] Local DB not available');
      return [];
    }
    
    try {
      // Query local DB for lessons with EXACT reading level match
      final localLessons = await _localDb!.query(
        'lessons',
        where: 'readingLevel = ?',
        whereArgs: [readingLevel],
        orderBy: 'lessonIndex ASC',
      );
      
      if (localLessons.isNotEmpty) {
        print('[DatabaseService] Found ${localLessons.length} lessons in local DB for level $readingLevel');
        
        // Convert to expected format and ensure level consistency
        return localLessons.map((lesson) => {
          'index': lesson['lessonIndex'] ?? 0,
          'title': lesson['title'] ?? 'Untitled Lesson',
          'description': lesson['description'] ?? 'No description available',
          'questionCount': lesson['questionCount'] ?? 5,
          'isAvailable': true, // Local lessons default to available
          'isCompleted': false, // Will be updated by caller
          'assessmentId': lesson['assessmentId'] ?? 'local_${lesson['lessonIndex']}',
          'readingLevel': readingLevel, // Ensure consistency
          'category': lesson['category'] ?? 'Filipino Lesson',
        }).toList();
      }
      
      print('[DatabaseService] No local lessons found for reading level: $readingLevel');
      return [];
      
    } catch (e) {
      print('[DatabaseService] Error reading from local DB: $e');
      return [];
    }
  }

  // Updated markLessonAsCompleted method for the DatabaseService
  Future<void> markLessonAsCompleted(String userIdNumber, int lessonIndex) async {
    try {
      // Check if database is initialized
      if (!isInitialized) {
        await initialize();
      }
      
      print('Marking lesson $lessonIndex as completed for user $userIdNumber');
      
      // If we have MongoDB connection
      if (isConnected && _db != null) {
        final usersCollection = getCollection('users');
        
        // Convert userIdNumber to int if possible
        dynamic userId;
        try {
          userId = int.parse(userIdNumber);
        } catch (e) {
          userId = userIdNumber;
        }
        
        // Query to find the user
        final query = where.eq('idNumber', userId);
        
        // First check if the lesson is already completed
        final user = await usersCollection.findOne(query);
        
        if (user != null) {
          List<dynamic> completedLessons = user['completedLessons'] ?? [];
          
          // Check if lesson is already marked as completed
          if (!completedLessons.contains(lessonIndex) && 
              !completedLessons.contains(lessonIndex.toString())) {
            
            // Update the completedLessons array
            await usersCollection.updateOne(
              query,
              modify.addToSet('completedLessons', lessonIndex),
            );
            
            print('Marked lesson $lessonIndex as completed for user $userIdNumber in MongoDB');
          } else {
            print('Lesson $lessonIndex already completed for user $userIdNumber');
          }
        } else {
          print('User $userIdNumber not found in MongoDB');
        }
      }
      
      // Always update local database too
      if (_localDb != null) {
        // Check if lessons table exists
        try {
          await _localDb!.rawQuery('SELECT name FROM sqlite_master WHERE type="table" AND name="completed_lessons"');
        } catch (e) {
          // Create table if it doesn't exist
          await _localDb!.execute(
            'CREATE TABLE IF NOT EXISTS completed_lessons(id INTEGER PRIMARY KEY, userId TEXT, lessonId INTEGER, completionDate TEXT)',
          );
        }
        
        // Check if this lesson is already marked as completed
        final existingRecord = await _localDb!.query(
          'completed_lessons',
          where: 'userId = ? AND lessonId = ?',
          whereArgs: [userIdNumber, lessonIndex],
        );
        
        if (existingRecord.isEmpty) {
          // Insert new completion record
          await _localDb!.insert('completed_lessons', {
            'userId': userIdNumber,
            'lessonId': lessonIndex,
            'completionDate': DateTime.now().toIso8601String(),
          });
          
          print('Marked lesson $lessonIndex as completed for user $userIdNumber in local DB');
        } else {
          print('Lesson $lessonIndex already completed for user $userIdNumber in local DB');
        }
      }
    } catch (e) {
      print('Error marking lesson as completed: $e');
    }
  }

  // Improved database debugging method
  Future<void> debugDatabaseState() async {
    print('\n=============== DATABASE DEBUG ===============');
    
    if (!isInitialized) {
      print('Database service not initialized');
      return;
    }
    
    if (!isConnected) {
      print('Not connected to MongoDB - using offline mode');
      return;
    }
    
    try {
      // Check default database
      if (_db != null) {
        print('Default database name: ${_db!.databaseName}');
        final collections = await _db!.getCollectionNames();
        print('Collections in default database:');
        for (final coll in collections) {
          print('  - $coll');
        }
      } else {
        print('Default database connection not available');
      }
      
      // Check Pre_Assessment database
      if (_preAssessmentDb != null) {
        if (_preAssessmentDb!.state != State.OPEN) {
          print('Pre_Assessment database connection exists but is not open');
        } else {
          print('\nPre_Assessment database connection:');
          final paCollections = await _preAssessmentDb!.getCollectionNames();
          print('Collections in Pre_Assessment database:');
          for (final coll in paCollections) {
            print('  - $coll');
            
            // If it's the pre-assessment collection, check if documents exist
            if (coll == 'pre-assessment') {
              final count = await _preAssessmentDb!.collection(coll!!).count();
              print('    Document count: $count');
              
              if (count > 0) {
                // Get a sample document
                final sample = await _preAssessmentDb!.collection(coll!!).findOne();
                if (sample != null) {
                  print('    Sample assessmentId: ${sample['assessmentId']}');
                  print('    Sample title: ${sample['title']}');
                  
                  // Check if it has questions
                  if (sample.containsKey('questions')) {
                    print('    Questions count: ${(sample['questions'] as List?)?.length ?? 0}');
                  } else {
                    print('    No questions field found in document');
                  }
                }
              }
            }
          }
        }
      } else {
        print('Pre_Assessment database connection not available');
      }
      
      // Also try to directly check for the pre-assessment collection
      print('\nLooking for pre-assessment collection in all available databases:');
      
      if (_db != null) {
        try {
          final count = await _db!.collection('pre-assessment').count();
          print('  In default database (${_db!.databaseName}): $count documents');
        } catch (e) {
          print('  In default database: Error - $e');
        }
      }
      
      // Attempt to insert a test document to the pre-assessment collection
      try {
        print('\nAttempting test insertion into pre-assessment collection...');
        final preAssessmentDb = await getPreAssessmentDatabase();
        final result = await preAssessmentDb.collection('pre-assessment').count(where.eq('assessmentId', 'FL-G1-001'));
        print('  Documents with assessmentId=FL-G1-001: $result');
        
        // First try to find the document from paste.txt
        final checkDoc = await preAssessmentDb.collection('pre-assessment').findOne(where.eq('assessmentId', 'FL-G1-001'));
        if (checkDoc != null) {
          print('  Found test document from paste.txt');
        } else {
          // If document doesn't exist, insert it
          print('  Document from paste.txt not found - you may need to insert it manually');
          // NOTE: Uncomment this to insert the test document if needed
          /*
          final insertResult = await preAssessmentDb.collection('pre-assessment').insertOne({
            'assessmentId': 'FL-G1-001',
            'title': 'Filipino Reading Pre-Assessment - Grade 1',
            'description': 'Test assessment document',
            'questions': [
              {
                'questionId': 'Q1',
                'questionNumber': 1,
                'questionTypeId': 'alphabet_knowledge',
                'questionText': 'Test question',
                'options': [
                  {'optionId': '1', 'optionText': 'Option 1', 'isCorrect': true},
                  {'optionId': '2', 'optionText': 'Option 2', 'isCorrect': false}
                ]
              }
            ],
            'status': 'active'
          });
          print('  Inserted test document: ${insertResult.isSuccess}');
          */
        }
      } catch (e) {
        print('  Error testing pre-assessment collection: $e');
      }
      
      print('=============================================\n');
    } catch (e) {
      print('Error during database debug: $e');
    }
  }

  Future<void> saveStudentResponse(Map<String, dynamic> response) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot save student response - not connected to DB');
      return;
    }
    
    try {
      // Make sure we're saving to the right collection
      final studentResponseCollection = _db!.collection('student_responses');
      
      // Add timestamps if they don't exist
      if (!response.containsKey('createdAt')) {
        response['createdAt'] = DateTime.now().toIso8601String();
      }
      if (!response.containsKey('updatedAt')) {
        response['updatedAt'] = DateTime.now().toIso8601String();
      }
      
      final result = await studentResponseCollection.insertOne(response);
      print('[DatabaseService] Saved student response: ${result.id}');
    } catch (e) {
      print('[DatabaseService] Error saving student response: $e');
      // You might want to log this error or handle it in some way
      rethrow;
    }
  }

  Future<String> saveCategoryResult(Map<String, dynamic> result) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot save category result - not connected to DB');
      return '';
    }
    
    try {
      // Make sure we're saving to the right collection
      final categoryResultCollection = _db!.collection('category_results');
      
      // Add timestamps if they don't exist
      if (!result.containsKey('createdAt')) {
        result['createdAt'] = DateTime.now().toIso8601String();
      }
      if (!result.containsKey('updatedAt')) {
        result['updatedAt'] = DateTime.now().toIso8601String();
      }
      
      final insertResult = await categoryResultCollection.insertOne(result);
      
      if (insertResult.id != null) {
        print('[DatabaseService] Saved category result with ID: ${insertResult.id}');
        return insertResult.id.toString();
      } else {
        print('[DatabaseService] Category result saved but no ID returned');
        return '';
      }
    } catch (e) {
      print('[DatabaseService] Error saving category result: $e');
      return '';
    }
  }

  Future<void> updateStudentResponsesCategoryId(String userId, String categoryResultId) async {
    if (!isConnected || _db == null || categoryResultId.isEmpty) {
      print('[DatabaseService] Cannot update student responses - not connected to DB or invalid categoryResultId');
      return;
    }
    
    try {
      final studentResponseCollection = _db!.collection('student_responses');
      
      // Try to convert the categoryResultId to ObjectId if it's in the right format
      ObjectId? categoryResultObjectId;
      try {
        if (categoryResultId.length == 24) {
          categoryResultObjectId = ObjectId.fromHexString(categoryResultId);
        }
      } catch (e) {
        print('[DatabaseService] Could not convert categoryResultId to ObjectId: $e');
        // Continue with the string version
      }
      
      // Update all responses for this user that have an empty categoryResultId
      final updateResult = await studentResponseCollection.updateMany(
        where.eq('studentId', userId).and(where.eq('categoryResultId', '')),
        modify.set('categoryResultId', categoryResultObjectId ?? categoryResultId)
              .set('updatedAt', DateTime.now().toIso8601String()),
      );
      
      print('[DatabaseService] Updated ${updateResult.isSuccess ? "successfully" : "with errors"} student responses with category result ID');
    } catch (e) {
      print('[DatabaseService] Error updating student responses: $e');
    }
  }

  Future<void> markAssessmentAsCompleted(String userId, dynamic assessmentId) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot mark assessment as completed - not connected to DB');
      return;
    }
    
    try {
      // 1. Get collections
      final usersCollection = _db!.collection('users');
      final preAssessmentCollection = (await getPreAssessmentDatabase()).collection('pre-assessment');
      
      // 2. Convert userId to the appropriate type (numeric if possible)
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      // 3. Try to convert assessmentId to ObjectId if it looks like one
      dynamic assessmentIdValue = assessmentId;
      ObjectId? assessmentObjectId;
      
      if (assessmentId is String && assessmentId.length == 24) {
        try {
          assessmentObjectId = ObjectId.fromHexString(assessmentId);
          assessmentIdValue = assessmentObjectId;
        } catch (e) {
          print('[DatabaseService] Could not convert assessmentId to ObjectId: $e');
          // Keep as string if it's not a valid ObjectId
        }
      }
      
      // 4. Update user document to mark assessment as completed
      final userUpdateResult = await usersCollection.updateOne(
        where.eq('idNumber', userIdValue),
        modify
          .set('lastAssessmentDate', DateTime.now().toIso8601String())
          .set('preAssessmentCompleted', true)
          .addToSet('completedAssessments', assessmentId.toString()),
      );
      
      print('[DatabaseService] Updated user completion status: ${userUpdateResult.isSuccess}');
      
      // 5. Update the pre-assessment document to track which students have completed it
      // First, check if assessmentObjectId is valid, otherwise try to find by other means
      var query;
      if (assessmentObjectId != null) {
        query = where.eq('_id', assessmentObjectId);
      } else if (assessmentId is String) {
        // Try to find by string assessmentId field if it exists
        query = where.eq('assessmentId', assessmentId);
      } else {
        // Last resort - try direct value
        query = where.eq('_id', assessmentId);
      }
      
      // Perform the update to add this user to completedByStudents array
      final assessmentUpdateResult = await preAssessmentCollection.updateOne(
        query,
        modify
          .addToSet('completedByStudents', userId)
          .set('lastCompletedAt', DateTime.now().toIso8601String()),
      );
      
      if (assessmentUpdateResult.isSuccess) {
        print('[DatabaseService] Updated pre-assessment document to track student completion');
      } else {
        print('[DatabaseService] Failed to update pre-assessment document: ${assessmentUpdateResult.writeError?.errmsg ?? "Unknown error"}');
        
        // Try an alternative approach if the first one failed
        if (assessmentObjectId == null && assessmentId is String) {
          // If we have a string but it's not a valid ObjectId, try a more flexible query
          final result = await preAssessmentCollection.updateOne(
            where.match('assessmentId', assessmentId),
            modify
              .addToSet('completedByStudents', userId)
              .set('lastCompletedAt', DateTime.now().toIso8601String()),
          );
          
          print('[DatabaseService] Alternative update approach result: ${result.isSuccess}');
        }
      }
    } catch (e) {
      print('[DatabaseService] Error marking assessment as completed: $e');
    }
  }

  Future<bool> hasStudentCompletedAssessment(String userId, dynamic assessmentId) async {
  if (!isConnected || _db == null) {
    print('[DatabaseService] Cannot check completion status - not connected to DB');
    return false;
  }
  
  try {
    print('[DatabaseService] Checking if user $userId has completed assessment $assessmentId');
    
    // Check in category_results collection (managed by web per guide)
    final categoryResultCollection = _db!.collection('category_results');
    
    // Convert userId to the appropriate type
    dynamic userIdValue;
    try {
      userIdValue = int.parse(userId);
    } catch (e) {
      userIdValue = userId;
    }
    
    // Query category_results for completed assessments
    final query = where.eq('studentId', userIdValue);
    final categoryResults = await categoryResultCollection.find(query).toList();
    
    for (final result in categoryResults) {
      // Check if this category result matches this assessment
      if (result['assessmentId'] == assessmentId || 
          result['assessmentId'] == assessmentId.toString()) {
        print('[DatabaseService] Found completion in category_results');
        return true;
      }
    }
    
    // Also check student_responses collection (mobile managed per guide)
    final studentResponseCollection = _db!.collection('student_responses');
    final responseQuery = where.eq('studentId', userIdValue).and(where.eq('categoryId', assessmentId));
    final responseCount = await studentResponseCollection.count(responseQuery);
    if (responseCount > 0) {
      print('[DatabaseService] Found completion using student_responses');
      return true;
    }
    
    // Check completed assessments in user document
    final usersCollection = _db!.collection('users');
    final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
    if (userDoc != null) {
      final completedAssessments = userDoc['completedAssessments'];
      if (completedAssessments != null && 
          completedAssessments is List && 
          completedAssessments.contains(assessmentId.toString())) {
        print('[DatabaseService] Found completion in user document');
        return true;
      }
    }
    
    print('[DatabaseService] No completion record found for user $userId and assessment $assessmentId');
    return false;
  } catch (e) {
    print('[DatabaseService] Error checking assessment completion: $e');
    return false;
  }
  }

  Future<List<String>> getCompletedAssessmentIds(String userId) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot get completed assessments - not connected to DB');
      return [];
    }
    
    try {
      // Get the pre-assessment collection
      final preAssessmentCollection = (await getPreAssessmentDatabase()).collection('pre-assessment');
      
      // Find all assessments where this student is in the completedByStudents array
      final query = where.eq('completedByStudents', userId);
      final completedAssessments = await preAssessmentCollection.find(query).toList();
      
      // Extract the assessment IDs
      final completedIds = completedAssessments.map((doc) {
        // Return the _id as string or assessmentId if available
        return doc['assessmentId']?.toString() ?? doc['_id'].toString();
      }).toList();
      
      print('[DatabaseService] Found ${completedIds.length} completed assessments for user $userId');
      return completedIds.cast<String>();
    } catch (e) {
      print('[DatabaseService] Error getting completed assessments: $e');
      return [];
    }
  }

  /// Save pre-assessment results specifically to Pre_Assessment.user_responses collection
  Future<bool> savePreAssessmentResult({
    required String userId,
    required dynamic assessmentId,
    required int score,
    required String readingLevel, 
    required double readingPercentage,
    required Map<String, String> answers,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (!isInitialized) {
        await initialize();
      }
      
      // First update local database for offline access
      await saveAssessmentResultsLocally(
        userId: userId,
        assessmentId: assessmentId,
        score: score,
        readingLevel: readingLevel,
      );
      
      // If not connected to MongoDB, return success from local save
      if (!isConnected || _db == null) {
        print('[DatabaseService] Not connected to MongoDB, saved pre-assessment locally');
        return true;
      }
      
      // Get a direct connection to Pre_Assessment database
      final preAssessmentDb = await getPreAssessmentDatabase();
      
      // IMPORTANT: Note the plural "user_responses" (not singular "user_response")
      final userResponsesCollection = preAssessmentDb.collection('user_responses');
      
      // Create the complete pre-assessment result document - matching the structure in your collection
      final resultDocument = {
        'userId': userId,
        'assessmentId': assessmentId,
        'score': score,
        'readingLevel': readingLevel,
        'readingPercentage': readingPercentage,
        'answers': answers,
        'completedAt': DateTime.now().toIso8601String(),
        'totalQuestions': additionalData?['totalQuestions'] ?? answers.length,
      };
      
      // Add part1Score if available
      if (additionalData?['part1Score'] != null) {
        resultDocument['part1Score'] = additionalData!['part1Score'];
      }
      
      // Add categoryScores if available
      if (additionalData?['categoryScores'] != null) {
        resultDocument['categoryScores'] = additionalData!['categoryScores'];
      } else {
        // Generate basic category scores
        resultDocument['categoryScores'] = {
          'alphabet_knowledge': {'total': 5, 'correct': 0, 'score': 0},
          'phonological_awareness': {'total': 5, 'correct': 0, 'score': 0},
          'decoding': {'total': 5, 'correct': 0, 'score': 0},
          'word_recognition': {'total': 5, 'correct': 0, 'score': 0},
          'reading_comprehension': {'total': 5, 'correct': 0, 'score': 0},
        };
      }
      
      // Add difficultyBreakdown if available
      if (additionalData?['difficultyBreakdown'] != null) {
        resultDocument['difficultyBreakdown'] = additionalData!['difficultyBreakdown'];
      }
      
      // Add reading comprehension metrics
      resultDocument['correctInReadingComp'] = additionalData?['correctInReadingComp'] ?? 0;
      resultDocument['readingCompQuestions'] = additionalData?['readingCompQuestions'] ?? 5;
      resultDocument['timeTaken'] = additionalData?['timeTaken'] ?? 0;
      resultDocument['allCategoriesPassed'] = score >= (resultDocument['totalQuestions'] * 0.75);
      
      // Save to Pre_Assessment.user_responses collection
      final result = await userResponsesCollection.insertOne(resultDocument);
      
      if (result.isSuccess) {
        print('[DatabaseService] Successfully saved pre-assessment result to Pre_Assessment.user_responses');
        
        // Also save summary record matching your second document type
        final summaryResult = await userResponsesCollection.insertOne({
          'userId': userId,
          'readingLevel': readingLevel,
          'readingPercentage': readingPercentage,
          'preAssessmentCompleted': true,
          'completedAt': DateTime.now().toIso8601String(),
        });
        
        if (summaryResult.isSuccess) {
          print('[DatabaseService] Saved pre-assessment summary to Pre_Assessment.user_responses');
        }
        
        // Also update user profile in main database
        await updateUserPreAssessmentStatus(userId, true, readingLevel, readingPercentage);
        
        return true;
      } else {
        print('[DatabaseService] Failed to save pre-assessment result to Pre_Assessment.user_responses');
        return false;
      }
    } catch (e) {
      print('[DatabaseService] Error saving pre-assessment result: $e');
      return false;
    }
  }

  /// Enhanced method to update user profile with reading percentage
  Future<bool> updateUserPreAssessmentStatus(
    String userId, 
    bool completed, 
    String readingLevel,
    [double readingPercentage = 0.0]
  ) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot update pre-assessment status - not connected to DB');
      return await saveUserDataLocally(
        idNumber: userId,
        readingLevel: readingLevel,
        preAssessmentCompleted: completed,
      );
    }
    
    try {
      print('[DatabaseService] Updating user pre-assessment status in main database');
      
      // Get users collection
      final usersCollection = getCollection('users');
      
      // Convert userId to appropriate type if needed
      dynamic userIdValue = userId;
      
      // Update user document with all relevant fields
      final result = await usersCollection.updateOne(
        where.eq('idNumber', userIdValue),
        modify
          .set('preAssessmentCompleted', completed)
          .set('readingLevel', readingLevel)
          .set('readingPercentage', readingPercentage)
          .set('lastAssessmentDate', DateTime.now().toIso8601String())
          .set('updatedAt', DateTime.now().toIso8601String()),
      );
      
      // Also save locally for redundancy
      await saveUserDataLocally(
        idNumber: userId,
        readingLevel: readingLevel,
        preAssessmentCompleted: completed,
      );
      
      print('[DatabaseService] Pre-assessment status update result: ${result.isSuccess}');
      return result.isSuccess;
    } catch (e) {
      print('[DatabaseService] Error updating pre-assessment status: $e');
      
      // Fallback to local storage
      return await saveUserDataLocally(
        idNumber: userId,
        readingLevel: readingLevel,
        preAssessmentCompleted: completed,
      );
    }
  }
}