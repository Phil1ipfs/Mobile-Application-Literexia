// lib/services/database_service.dart
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

  // Add method to save user data locally for offline authentication
  Future<bool> saveUserDataLocally({
    required String idNumber,
    String? name,
    String? readingLevel,
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

      if (existingUser.isEmpty) {
        // Insert new user
        await _localDb!.insert('users', {
          'idNumber': idNumber,
          'name': name ?? 'User $idNumber',
          'readingLevel': readingLevel ?? '',
        });
        print('[DatabaseService] User $idNumber saved to local DB');
      } else {
        // Update existing user
        await _localDb!.update(
          'users',
          {
            'name': name ?? existingUser.first['name'],
            'readingLevel': readingLevel ?? existingUser.first['readingLevel'],
          },
          where: 'idNumber = ?',
          whereArgs: [idNumber],
        );
        print('[DatabaseService] User $idNumber updated in local DB');
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

  Future<List<String?>> getCollectionNames() async =>
      _db == null ? [] : _db!.getCollectionNames();

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

  // Get lessons for a specific reading level from MongoDB
  Future<List<Map<String, dynamic>>> getLessonsForLevel(String readingLevel) async {
  // Make sure the database is initialized
  if (!_isInitialized) {
    await initialize();
  }

  // Normalize reading level to match database format
  final String targetReadingLevel = readingLevel;
  print('[DatabaseService] Getting lessons for level: $targetReadingLevel');

  try {
    if (isConnected && _db != null) {
      // Get the pre-assessment collection instead of main_assessment
      final preAssessmentDb = await getPreAssessmentDatabase();
      final preAssessmentCollection = preAssessmentDb.collection('pre-assessment');
      
      // Try multiple query approaches to maximize chances of finding matching content
      List<Map<String, dynamic>> assessments = [];
      
      // 1. First try exact match on readingLevel field
      var query = where.eq('difficultyLevels.$targetReadingLevel.targetReadingLevel', targetReadingLevel)
                  .and(where.eq('status', 'active'));
      assessments = await preAssessmentCollection.find(query).toList();
      
      // 2. If no results, try with case-insensitive match
      if (assessments.isEmpty) {
        print('[DatabaseService] No assessments found with exact match, trying broader query');
        // Fixed this line - using take(5) instead of limit(5)
        assessments = await preAssessmentCollection.find(where.eq('status', 'active')).take(5).toList();
      }
      
      if (assessments.isNotEmpty) {
        print('[DatabaseService] Found ${assessments.length} assessments for level $targetReadingLevel');
        
        // Process into lesson format for display
        List<Map<String, dynamic>> lessons = [];
        int index = 1;
        
        for (final assessment in assessments) {
          // Debug exact assessment data
          print('[DatabaseService] Processing assessment: ${assessment['_id']} | Title: ${assessment['title']}');
          
          // Determine if lesson should be available
          bool isAvailable = index == 1; // First lesson always available
          
          lessons.add({
            'index': index,
            'title': 'ARALIN $index: ${assessment['title'] ?? 'Filipino Lesson'}',
            'description': assessment['description'] ?? 'Interactive Filipino reading activities',
            'questionCount': (assessment['questions'] as List<dynamic>?)?.length ?? 5,
            'isAvailable': isAvailable,
            'assessmentId': assessment['_id'].toString(), // Use the ObjectId as string
          });
          
          index++;
        }
        
        // Save processed lessons to local DB for offline access
        await _saveLessonsToLocalDb(lessons, targetReadingLevel);
        
        return lessons;
      }
    }
    
    // If MongoDB query fails or returns empty, throw exception instead of using fallback
    throw Exception('No lessons found for reading level: $targetReadingLevel');
  } catch (e) {
    print('[DatabaseService] Error fetching lessons: $e');
    // Rethrow the error instead of using fallback
    throw Exception('Failed to load lessons: $e');
  }
}

  // Helper method to save fetched lessons to local DB
  Future<void> _saveLessonsToLocalDb(List<Map<String, dynamic>> lessons, String readingLevel) async {
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
  Future<List<Map<String, dynamic>>> _getLessonsFromLocalDb(String readingLevel) async {
    if (_localDb == null) {
      print('[DatabaseService] Local DB not available, throw exception');
      throw Exception('Local database not available');
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
        print('[DatabaseService] Found ${localLessons.length} lessons in local DB');
        return localLessons;
      }
      
      // If no lessons in local DB, throw exception
      throw Exception('No local lessons found for reading level: $readingLevel');
    } catch (e) {
      print('[DatabaseService] Error reading from local DB: $e');
      throw Exception('Failed to get local lessons: $e');
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
      
      // First, try to check the pre-assessment collection for completedByStudents
      final preAssessmentCollection = (await getPreAssessmentDatabase()).collection('pre-assessment');
      
      // Try different approaches to find the assessment
      ObjectId? objectId;
      if (assessmentId is String && assessmentId.length == 24) {
        try {
          objectId = ObjectId.fromHexString(assessmentId);
        } catch (e) {
          print('[DatabaseService] Could not convert to ObjectId: $e');
        }
      }
      
      // Check using ObjectId if available
      if (objectId != null) {
        final query = where.eq('_id', objectId).and(where.eq('completedByStudents', userId));
        final count = await preAssessmentCollection.count(query);
        if (count > 0) {
          print('[DatabaseService] Found completion using ObjectId');
          return true;
        }
      }
      
      // Check using assessmentId string
      final query = where.eq('assessmentId', assessmentId).and(where.eq('completedByStudents', userId));
      final count = await preAssessmentCollection.count(query);
      if (count > 0) {
        print('[DatabaseService] Found completion using assessmentId');
        return true;
      }
      
      // If not found in pre-assessment, check student_responses as a fallback
      final studentResponseCollection = _db!.collection('student_responses');
      final responseQuery = where.eq('studentId', userId).and(where.eq('categoryId', assessmentId));
      final responseCount = await studentResponseCollection.count(responseQuery);
      if (responseCount > 0) {
        print('[DatabaseService] Found completion using student_responses');
        return true;
      }
      
      // If not found in student_responses, check category_results as a fallback
      final categoryResultCollection = _db!.collection('category_results');
      final categoryQuery = where.eq('studentId', userId);
      final categoryResults = await categoryResultCollection.find(categoryQuery).toList();
      
      for (final result in categoryResults) {
        // Check if any category result matches this assessment
        if (result['assessmentId'] == assessmentId || 
            (result['categories'] != null && 
             (result['categories'] as List).any((c) => c['categoryId'] == assessmentId))) {
          print('[DatabaseService] Found completion using category_results');
          return true;
        }
      }
      
      // Finally, check completed_lessons in user document
      final usersCollection = _db!.collection('users');
      
      // Convert userId to the appropriate type
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
      if (userDoc != null) {
        final completedAssessments = userDoc['completedAssessments'];
        if (completedAssessments != null && 
            completedAssessments is List && 
            completedAssessments.contains(assessmentId.toString())) {
          print('[DatabaseService] Found completion in user document');
          return true;
        }
        
        // Also check completedLessons array
        final completedLessons = userDoc['completedLessons'];
        if (completedLessons != null && completedLessons is List) {
          print('[DatabaseService] Checking completedLessons: $completedLessons');
          // If we find any match, consider it completed
          if (completedLessons.any((item) => item.toString() == assessmentId.toString())) {
            print('[DatabaseService] Found completion in completedLessons');
            return true;
          }
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
}