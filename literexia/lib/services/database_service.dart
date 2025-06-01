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
  DbCollection? get lessonsCollection => _db?.collection('lessons');
  DbCollection? get mainAssessmentCollection =>
      _db?.collection('main_assessment');

  DbCollection getDbCollection(String name) {
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
        print(
            '[DatabaseService] Using Pre_Assessment database for pre-assessment collection');
        return _preAssessmentDb!.collection(name);
      } else {
        print(
            '[DatabaseService] WARNING: Pre_Assessment database not initialized, using default database');
      }
    } else if (name == 'main_assessment') {
      // Ensure we're using the correct collection for main_assessment
      print('[DatabaseService] Accessing main_assessment collection');
    }

    return _db!.collection(name);
  }

  String? _currentUserId;
  // Add this getter to fix the issue
  String? get currentUserId => _currentUserId;

  Db? _db;
  Db? _preAssessmentDb; // Separate connection for Pre_Assessment database
  Database? _localDb;
  bool _isInitialized = false;
  bool _isWeb = false;
  String? _connectionError;

  static bool forceRealConnection = false;

  bool get isInitialized => _isInitialized;
  bool get isConnected => _db != null && _isInitialized && !_isWeb;
  String? get connectionError => _connectionError;

  // Set current user ID
  void setCurrentUserId(String userId) {
    _currentUserId =
        userId; // userId should be the idNumber field from your JSON (e.g., "202511111")
    print('[DatabaseService] Current user ID set: $userId');
  }

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

    print('[DatabaseService] Connecting to Pre_Assessment database');
    _preAssessmentDb = await Db.create(uriWithDb);
    await _preAssessmentDb!.open();

    // Log the available collections
    final collections = await _preAssessmentDb!.getCollectionNames();
    print(
        '[DatabaseService] Connected to Pre_Assessment database. Collections: $collections');

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

      print('[DatabaseService] Connecting to main database');
      _db = await Db.create(uri);
      await _db!.open();

      // Also initialize the Pre_Assessment database connection
      await getPreAssessmentDatabase();

      // Try to sync any pending offline data
      await _syncOfflineData();

      _isInitialized = true;
      print(
          '[DatabaseService] Connected to main database: ${_db!.databaseName}');
      print(
          '[DatabaseService] Collections: ${await _db!.getCollectionNames()}');
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
          // Create completed_lessons table
          await db.execute(
            'CREATE TABLE IF NOT EXISTS completed_lessons(id INTEGER PRIMARY KEY, userId TEXT, lessonId INTEGER, completionDate TEXT)',
          );
          // Create category_results table for offline tracking
          await db.execute(
            'CREATE TABLE category_results(id INTEGER PRIMARY KEY, userId TEXT, categoryResultsId TEXT, readingLevel TEXT, overallScore INTEGER, completedCategories INTEGER, totalCategories INTEGER, allCategoriesPassed INTEGER, allCategoriesCompleted INTEGER, data TEXT)',
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
        print(
            '[DatabaseService] User $idNumber saved to local DB with preAssessmentCompleted=${preAssessmentCompleted ?? "null"}');
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
        print(
            '[DatabaseService] User $idNumber updated in local DB with preAssessmentCompleted=${preAssessmentCompleted ?? "unchanged"}');
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

          final query = numericId != null
              ? where.eq('idNumber', numericId)
              : where.eq('idNumber', userId);

          // Update in MongoDB
          final result = await _db!.collection('users').updateOne(
                query,
                modify.set('readingLevel', readingLevel).set(
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
        print(
            '[DatabaseService] Using Pre_Assessment database for pre-assessment collection');
        return _preAssessmentDb!.collection(name);
      } else {
        print(
            '[DatabaseService] WARNING: Pre_Assessment database not initialized, using default database');
      }
    } else if (name == 'main_assessment') {
      // Ensure we're using the correct collection for main_assessment
      print('[DatabaseService] Accessing main_assessment collection');
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

  // Save student response to the student_responses collection
  Future<void> saveStudentResponse(Map<String, dynamic> response) async {
    if (!isConnected || _db == null) {
      print(
          '[DatabaseService] Cannot save student response - not connected to DB');
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

  // Update student responses with category result ID
  Future<void> updateStudentResponsesCategoryId(
      String userId, String categoryResultId) async {
    if (!isConnected || _db == null || categoryResultId.isEmpty) {
      print(
          '[DatabaseService] Cannot update student responses - not connected to DB or invalid categoryResultId');
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
        print(
            '[DatabaseService] Could not convert categoryResultId to ObjectId: $e');
        // Continue with the string version
      }

      // Update all responses for this user that have an empty categoryResultId
      final updateResult = await studentResponseCollection.updateMany(
        where.eq('studentId', userId).and(where.eq('categoryResultId', '')),
        modify
            .set('categoryResultId', categoryResultObjectId ?? categoryResultId)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      print(
          '[DatabaseService] Updated ${updateResult.isSuccess ? "successfully" : "with errors"} student responses with category result ID');
    } catch (e) {
      print('[DatabaseService] Error updating student responses: $e');
    }
  }

  /// Get available categories for a reading level (Phase 1 - Category Determination)
  Future<List<String>> getAvailableCategoriesForLevel(
      String readingLevel) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for category query');
        return [];
      }

      final collection = _db!.collection('main_assessment');

      // Query for distinct categories at this reading level
      final availableCategories = await collection.distinct(
          'category',
          where
              .eq('readingLevel', readingLevel)
              .and(where.eq('isActive', true))
              .and(where.eq('status', 'active')));

      final categories = (availableCategories as List)
          .where((cat) => cat != null)
          .map((cat) => cat.toString())
          .toList();

      print(
          '[DatabaseService] Found ${categories.length} categories for $readingLevel: $categories');
      return categories;
    } catch (e) {
      print('[DatabaseService] Error getting available categories: $e');
      return [];
    }
  }

  /// Create category_results document for main assessment
  Future<String> createCategoryResults({
    required String studentId,
    required String readingLevel,
    required List<String> availableCategories,
  }) async {
    try {
      if (!isConnected || _db == null) {
        print(
            '[DatabaseService] Database not connected for category_results creation');
        return '';
      }

      final collection = _db!.collection('category_results');

      // Convert studentId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(studentId);
      } catch (e) {
        studentIdValue = studentId;
      }

      // Create category_results document
      final categoryResultsDoc = {
        'studentId': studentIdValue,
        'assessmentType': 'main-assessment',
        'assessmentDate': DateTime.now().toIso8601String(),
        'categories': availableCategories
            .map((category) => {
                  'categoryName': category,
                  'totalQuestions': null,
                  'correctAnswers': 0,
                  'score': 0,
                  'isPassed': false,
                  'passingThreshold': 75,
                  'isCompleted': false,
                  'assessmentDate': null,
                  'timeTaken': 0,
                  'lastQuestionAnswered': null,
                  'answers': <String, dynamic>{},
                })
            .toList(),
        'overallScore': 0,
        'completedCategories': 0,
        'totalCategories': availableCategories.length,
        'allCategoriesPassed': false,
        'allCategoriesCompleted': false,
        'readingLevel': readingLevel,
        'readingLevelUpdated': false,
        'timeTaken': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await collection.insertOne(categoryResultsDoc);

      if (result.isSuccess && result.id != null) {
        print(
            '[DatabaseService] Created category_results document: ${result.id}');
        return result.id.toString();
      } else {
        print('[DatabaseService] Failed to create category_results document');
        return '';
      }
    } catch (e) {
      print('[DatabaseService] Error creating category_results: $e');
      return '';
    }
  }

  /// Get questions for a category (Phase 2 - Question Presentation)
  Future<List<Map<String, dynamic>>> getQuestionsForCategory({
    required String readingLevel,
    required String category,
  }) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for questions query');
        return [];
      }

      final collection = _db!.collection('main_assessment');

      // Improve logging for debugging
      print(
          '[DatabaseService] Querying for questions with readingLevel: "$readingLevel", category: "$category"');

      // Find the assessment document for this category and reading level
      // IMPORTANT: Be explicit with the query conditions and add proper error handling
      final query = where
          .eq('readingLevel', readingLevel)
          .and(where.eq('category', category))
          .and(where.eq('isActive', true));

      final doc = await collection.findOne(query);

      if (doc == null) {
        print(
            '[DatabaseService] No assessment found for $category at $readingLevel');

        // Debug: List all available assessments to see what's in the database
        final allAssessments = await collection.find({}).toList();
        print('[DatabaseService] Available assessments:');
        for (var assessment in allAssessments) {
          print(
              '  - Level: ${assessment['readingLevel']}, Category: ${assessment['category']}');
        }

        return [];
      }

      print(
          '[DatabaseService] Found assessment: ${doc['_id']} for $category/$readingLevel');

      // Extract questions with better error handling
      final questions = <Map<String, dynamic>>[];
      if (doc['questions'] != null && doc['questions'] is List) {
        final questionsList = doc['questions'] as List;

        print('[DatabaseService] Processing ${questionsList.length} questions');

        for (final q in questionsList) {
          if (q is Map<String, dynamic>) {
            // Make a deep copy to avoid reference issues
            final questionCopy = Map<String, dynamic>.from(q);

            // Ensure all required fields are present
            if (!questionCopy.containsKey('questionId')) {
              questionCopy['questionId'] = 'q_${questions.length + 1}';
            }

            // Add to questions list
            questions.add(questionCopy);
          } else {
            print('[DatabaseService] Invalid question format: $q');
          }
        }
      } else {
        print('[DatabaseService] No questions array found or invalid format');
      }

      print(
          '[DatabaseService] Loaded ${questions.length} questions for $category');
      return questions;
    } catch (e) {
      print('[DatabaseService] Error getting questions for category: $e');
      // Provide more context in the error message
      print(
          '[DatabaseService] Parameters: readingLevel=$readingLevel, category=$category');
      return [];
    }
  }

  /// Update category totalQuestions (Phase 2 - Question Presentation Setup)
  Future<bool> updateCategoryTotalQuestions({
    required String categoryResultsId,
    required String categoryName,
    required int totalQuestions,
  }) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for category update');
        return false;
      }

      final collection = _db!.collection('category_results');
      final objectId = ObjectId.fromHexString(categoryResultsId);

      // Find the document and update the correct category in the array
      final doc = await collection.findOne(where.eq('_id', objectId));
      if (doc == null) {
        print('[DatabaseService] Category results document not found');
        return false;
      }

      final categories = doc['categories'] as List;
      final categoryIndex =
          categories.indexWhere((cat) => cat['categoryName'] == categoryName);
      if (categoryIndex == -1) {
        print('[DatabaseService] Category $categoryName not found in results');
        return false;
      }

      // Update the fields in the category object
      categories[categoryIndex]['totalQuestions'] = totalQuestions;
      categories[categoryIndex]['assessmentDate'] =
          DateTime.now().toIso8601String();

      final result = await collection.updateOne(
        where.eq('_id', objectId),
        modify
            .set('categories', categories)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      print(
          '[DatabaseService] Updated totalQuestions for $categoryName: $totalQuestions');
      return result.isSuccess;
    } catch (e) {
      print('[DatabaseService] Error updating category total questions: $e');
      return false;
    }
  }

  /// Record answer in category_results (Phase 2 - Answer Recording)
  Future<bool> recordAnswerInCategoryResults({
    required String categoryResultsId,
    required String categoryName,
    required String questionId,
    required String selectedOption,
    required bool isCorrect,
    required double responseTime,
  }) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for answer recording');
        return false;
      }

      final collection = _db!.collection('category_results');
      final objectId = ObjectId.fromHexString(categoryResultsId);

      // Create answer object following the guide's structure
      final answer = {
        'selectedOption': selectedOption,
        'isCorrect': isCorrect,
        'responseTime': responseTime,
        'answeredAt': DateTime.now().toIso8601String(),
      };

      // Fetch the document to update the answers map in Dart
      final doc = await collection.findOne(
        where
            .eq('_id', objectId)
            .and(where.eq('categories.categoryName', categoryName)),
      );

      if (doc == null) {
        print('[DatabaseService] Category results document not found');
        return false;
      }

      final categories =
          List<Map<String, dynamic>>.from(doc['categories'] as List);
      final categoryIndex =
          categories.indexWhere((cat) => cat['categoryName'] == categoryName);
      if (categoryIndex == -1) {
        print('[DatabaseService] Category $categoryName not found in results');
        return false;
      }

      final category = Map<String, dynamic>.from(categories[categoryIndex]);
      final answers = Map<String, dynamic>.from(category['answers'] ?? {});
      answers[questionId] = answer;
      category['answers'] = answers;
      category['lastQuestionAnswered'] = questionId;
      categories[categoryIndex] = category;

      final result = await collection.updateOne(
        where.eq('_id', objectId),
        modify
            .set('categories', categories)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      if (result.isSuccess) {
        print(
            '[DatabaseService] Recorded answer for $questionId in $categoryName');

        // Update category metrics after each answer
        await updateCategoryMetrics(categoryResultsId, categoryName);
        return true;
      } else {
        print('[DatabaseService] Failed to record answer');
        return false;
      }
    } catch (e) {
      print('[DatabaseService] Error recording answer: $e');
      return false;
    }
  }

  /// Update category metrics (Phase 3 - Category Metrics Calculation)
  Future<bool> updateCategoryMetrics(
      String categoryResultsId, String categoryName) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for metrics update');
        return false;
      }

      final collection = _db!.collection('category_results');
      final objectId = ObjectId.fromHexString(categoryResultsId);

      // Get current document to calculate metrics
      final doc = await collection.findOne(where.eq('_id', objectId));
      if (doc == null) {
        print('[DatabaseService] Category results document not found');
        return false;
      }

      final categories = doc['categories'] as List;
      final categoryIndex =
          categories.indexWhere((cat) => cat['categoryName'] == categoryName);
      if (categoryIndex == -1) {
        print('[DatabaseService] Category $categoryName not found in results');
        return false;
      }

      final category = categories[categoryIndex];
      final answers = category['answers'] as Map<String, dynamic>? ?? {};
      final totalQuestions = category['totalQuestions'] as int? ?? 0;

      // Count correct answers
      int correctCount = 0;
      answers.forEach((questionId, answer) {
        if (answer is Map && answer['isCorrect'] == true) {
          correctCount++;
        }
      });

      // Calculate metrics following the guide
      final answeredCount = answers.length;
      final score = answeredCount > 0
          ? ((correctCount / answeredCount) * 100).round()
          : 0;
      final isCompleted = totalQuestions > 0 && answeredCount == totalQuestions;
      final isPassed = score >= 75;

      // Update the fields in the category object
      category['correctAnswers'] = correctCount;
      category['score'] = score;
      category['isPassed'] = isPassed;
      category['isCompleted'] = isCompleted;

      categories[categoryIndex] = category;

      // Update category metrics by setting the entire categories array
      final updateResult = await collection.updateOne(
        where.eq('_id', objectId),
        modify
            .set('categories', categories)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      print(
          '[DatabaseService] Updated metrics for $categoryName: $score% (${isPassed ? "PASSED" : "FAILED"})');

      // If category is completed, update overall metrics
      if (isCompleted) {
        await updateOverallMetrics(categoryResultsId);
      }

      return updateResult.isSuccess;
    } catch (e) {
      print('[DatabaseService] Error updating category metrics: $e');
      return false;
    }
  }

  /// Update overall assessment metrics (Phase 3 - Overall Metrics Updates)
  Future<bool> updateOverallMetrics(String categoryResultsId) async {
    try {
      if (!isConnected || _db == null) {
        print(
            '[DatabaseService] Database not connected for overall metrics update');
        return false;
      }

      final collection = _db!.collection('category_results');
      final objectId = ObjectId.fromHexString(categoryResultsId);

      final doc = await collection.findOne(where.eq('_id', objectId));
      if (doc == null) {
        print('[DatabaseService] Category results document not found');
        return false;
      }

      final categories = doc['categories'] as List;
      final completedCategories =
          categories.where((cat) => cat['isCompleted'] == true).toList();
      final completedCount = completedCategories.length;
      final totalCategories = categories.length;

      // Calculate overall score (average of completed categories)
      int totalScore = 0;
      for (final category in completedCategories) {
        totalScore += (category['score'] as int? ?? 0);
      }
      final overallScore =
          completedCount > 0 ? (totalScore / completedCount).round() : 0;

      // Check completion status
      final allCategoriesCompleted = completedCount == totalCategories;
      final allCategoriesPassed =
          completedCategories.every((cat) => cat['isPassed'] == true);

      final result = await collection.updateOne(
        where.eq('_id', objectId),
        modify
            .set('overallScore', overallScore)
            .set('completedCategories', completedCount)
            .set('allCategoriesCompleted', allCategoriesCompleted)
            .set('allCategoriesPassed', allCategoriesPassed)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      print(
          '[DatabaseService] Updated overall metrics: $overallScore% (${allCategoriesPassed ? "ALL PASSED" : "PENDING"})');

      // Check for reading level advancement if all categories passed
      if (allCategoriesPassed && allCategoriesCompleted) {
        final readingLevelUpdated =
            doc['readingLevelUpdated'] as bool? ?? false;
        if (!readingLevelUpdated) {
          final studentId = doc['studentId'].toString();
          final currentLevel = doc['readingLevel'] as String;
          await advanceUserReadingLevel(
              categoryResultsId, studentId, currentLevel);
        }
      }

      return result.isSuccess;
    } catch (e) {
      print('[DatabaseService] Error updating overall metrics: $e');
      return false;
    }
  }

  /// Advance user reading level (Phase 4 - Reading Level Advancement)
  Future<bool> advanceUserReadingLevel(
      String categoryResultsId, String studentId, String currentLevel) async {
    try {
      if (!isConnected || _db == null) {
        print(
            '[DatabaseService] Database not connected for reading level advancement');
        return false;
      }

      // Define reading level sequence following the guide
      const readingLevels = [
        "Low Emerging",
        "High Emerging",
        "Developing",
        "Transitioning",
        "At Grade Level"
      ];

      final currentIndex = readingLevels.indexOf(currentLevel);
      if (currentIndex < 0 || currentIndex >= readingLevels.length - 1) {
        print(
            '[DatabaseService] Cannot advance from $currentLevel - already at highest level or invalid level');
        return false;
      }

      final nextLevel = readingLevels[currentIndex + 1];

      // Update category_results
      final categoryCollection = _db!.collection('category_results');
      final objectId = ObjectId.fromHexString(categoryResultsId);

      final categoryResult = await categoryCollection.updateOne(
        where.eq('_id', objectId),
        modify
            .set('readingLevel', nextLevel)
            .set('readingLevelUpdated', true)
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      // Update users collection (critical for system consistency)
      final usersCollection = _db!.collection('users');
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(studentId);
      } catch (e) {
        studentIdValue = studentId;
      }

      final userResult = await usersCollection.updateOne(
        where.eq('idNumber', studentIdValue),
        modify
            .set('readingLevel', nextLevel)
            .set('lastAssessmentDate', DateTime.now().toIso8601String())
            .set('updatedAt', DateTime.now().toIso8601String()),
      );

      if (categoryResult.isSuccess && userResult.isSuccess) {
        print(
            '[DatabaseService] Successfully advanced reading level: $currentLevel -> $nextLevel');
        return true;
      } else {
        print(
            '[DatabaseService] Failed to advance reading level - Category: ${categoryResult.isSuccess}, User: ${userResult.isSuccess}');
        return false;
      }
    } catch (e) {
      print('[DatabaseService] Error advancing reading level: $e');
      return false;
    }
  }

  /// Get category results for a student
  Future<Map<String, dynamic>?> getCategoryResultsForStudent(
      String studentId) async {
    try {
      if (!isConnected || _db == null) {
        print(
            '[DatabaseService] Database not connected for category results query');
        return null;
      }

      final collection = _db!.collection('category_results');

      // Convert studentId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(studentId);
      } catch (e) {
        studentIdValue = studentId;
      }

      // Get the most recent category_results for this student
      final doc = await collection.findOne(where
          .eq('studentId', studentIdValue)
          .sortBy('createdAt', descending: true));

      if (doc != null) {
        print(
            '[DatabaseService] Found category results for student $studentId');
      } else {
        print(
            '[DatabaseService] No category results found for student $studentId');
      }

      return doc;
    } catch (e) {
      print('[DatabaseService] Error getting category results: $e');
      return null;
    }
  }

  /// Find incomplete category for student (for resuming assessments)
  Future<String?> findIncompleteCategory(String studentId) async {
    try {
      final categoryResults = await getCategoryResultsForStudent(studentId);
      if (categoryResults == null) return null;

      final categories = categoryResults['categories'] as List?;
      if (categories == null) return null;

      // Find first incomplete category
      for (final category in categories) {
        if (category['isCompleted'] != true) {
          return category['categoryName'] as String?;
        }
      }

      return null; // All categories completed
    } catch (e) {
      print('[DatabaseService] Error finding incomplete category: $e');
      return null;
    }
  }

  /// Reset student's assessment progress (for testing purposes)
  Future<bool> resetStudentProgress(String studentId) async {
    try {
      if (!isConnected || _db == null) {
        print('[DatabaseService] Database not connected for progress reset');
        return false;
      }

      final collection = _db!.collection('category_results');

      // Convert studentId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(studentId);
      } catch (e) {
        studentIdValue = studentId;
      }

      // Delete all category_results for this student
      final result =
          await collection.deleteMany(where.eq('studentId', studentIdValue));

      print(
          '[DatabaseService] Reset progress for student $studentId - deleted ${result.nRemoved} documents');
      return result.isSuccess;
    } catch (e) {
      print('[DatabaseService] Error resetting student progress: $e');
      return false;
    }
  }

  // Helper method to save category_results data locally
  Future<bool> saveCategoryResultsLocally(String userId,
      String categoryResultsId, Map<String, dynamic> data) async {
    try {
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return false;
      }

      // Convert to format for local storage
      final localData = {
        'userId': userId,
        'categoryResultsId': categoryResultsId,
        'readingLevel': data['readingLevel'],
        'overallScore': data['overallScore'] ?? 0,
        'completedCategories': data['completedCategories'] ?? 0,
        'totalCategories': data['totalCategories'] ?? 0,
        'allCategoriesPassed': data['allCategoriesPassed'] == true ? 1 : 0,
        'allCategoriesCompleted':
            data['allCategoriesCompleted'] == true ? 1 : 0,
        'data': data.toString(), // Simple stringification for backup
      };

      // Check if already exists
      final existing = await _localDb!.query(
        'category_results',
        where: 'categoryResultsId = ?',
        whereArgs: [categoryResultsId],
      );

      if (existing.isEmpty) {
        // Insert new record
        await _localDb!.insert('category_results', localData);
      } else {
        // Update existing record
        await _localDb!.update(
          'category_results',
          localData,
          where: 'categoryResultsId = ?',
          whereArgs: [categoryResultsId],
        );
      }

      print(
          '[DatabaseService] Saved category_results locally: $categoryResultsId');
      return true;
    } catch (e) {
      print('[DatabaseService] Error saving category_results locally: $e');
      return false;
    }
  }

  // Helper method to get category_results from local storage
  Future<Map<String, dynamic>?> getCategoryResultsFromLocalDb(
      String userId) async {
    try {
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return null;
      }

      final results = await _localDb!.query(
        'category_results',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'rowid DESC', // Get most recent
        limit: 1,
      );

      if (results.isNotEmpty) {
        print(
            '[DatabaseService] Found local category_results for user $userId');
        return results.first;
      }

      return null;
    } catch (e) {
      print('[DatabaseService] Error getting local category_results: $e');
      return null;
    }
  }

  /// Checks if a student has completed a specific category
  Future<bool> hasStudentCompletedCategory(
      String userId, String category) async {
    // Implement your logic here to check if the student has completed the category.
    // This is a stub implementation; replace with actual database query.
    // For example, query the student_responses or category_results collection.
    try {
      // Example: Check in category_results if the category is marked as completed
      final categoryResults = await getCategoryResultsForStudent(userId);
      if (categoryResults != null && categoryResults['categories'] is List) {
        final categories = categoryResults['categories'] as List;
        final found = categories.firstWhere(
          (cat) =>
              cat['categoryName'] == category && cat['isCompleted'] == true,
          orElse: () => null,
        );
        return found != null;
      }
      return false;
    } catch (e) {
      print('[DatabaseService] Error in hasStudentCompletedCategory: $e');
      return false;
    }
  }

  // Marks a lesson as completed for a user in the database
  Future<void> markLessonAsCompleted(String userId, int lessonIndex) async {
    // Example implementation for MongoDB
    if (!isInitialized) {
      await initialize();
    }
    if (!isConnected) {
      throw Exception('Database not connected');
    }
    final usersCollection = getDbCollection('users');
    if (usersCollection == null) {
      throw Exception('Users collection is not initialized.');
    }
    // Update the user's completedLessons array
    await usersCollection.updateOne(
      {'idNumber': userId},
      {
        r'$addToSet': {'completedLessons': lessonIndex}
      },
    );
  }

  /// Checks if a student has completed a specific assessment.
  Future<bool> hasStudentCompletedAssessment(
      String userId, String assessmentId) async {
    // Replace with your actual logic for checking completion in your database.
    // Example for MongoDB:
    if (!isInitialized) {
      await initialize();
    }
    if (!isConnected) {
      throw Exception('Database not connected');
    }
    final assessmentsCollection = getDbCollection('assessments');
    final result = await assessmentsCollection.findOne({
      'userId': userId,
      'assessmentId': assessmentId,
      'completed': true,
    });
    return result != null;
  }

  /// Test method to verify database connection and data
  Future<void> testDatabaseConnection() async {
    try {
      print('[DatabaseService] ========== DATABASE CONNECTION TEST ==========');
      // Test 1: Check initialization
      print('[DatabaseService] Test 1: Checking initialization...');
      if (!_isInitialized) {
        print('[DatabaseService] Database not initialized, initializing...');
        await initialize();
      }
      print('[DatabaseService] Initialized: [32m[1m[4m$_isInitialized[0m');
      print('[DatabaseService] Connected: $isConnected');
      print('[DatabaseService] Is Web: $_isWeb');
      print('[DatabaseService] DB exists: [32m[1m[4m${_db != null}[0m');
      if (_db == null) {
        print('[DatabaseService] ERROR: Database instance is null');
        return;
      }
      // Test 2: Check collections
      print('[DatabaseService] Test 2: Checking collections...');
      final collections = await _db!.getCollectionNames();
      print('[DatabaseService] Available collections: $collections');
      if (!collections.contains('main_assessment')) {
        print('[DatabaseService] ERROR: main_assessment collection not found');
        return;
      }
      // Test 3: Check main_assessment data
      print('[DatabaseService] Test 3: Checking main_assessment data...');
      final collection = _db!.collection('main_assessment');
      final totalCount = await collection.count();
      print('[DatabaseService] Total documents in main_assessment: $totalCount');
      // Test 4: Check specific reading levels
      print('[DatabaseService] Test 4: Checking reading levels...');
      final readingLevels = ['Low Emerging', 'High Emerging', 'Developing', 'Transitioning', 'At Grade Level'];
      for (final level in readingLevels) {
        final count = await collection.count({'readingLevel': level});
        print('[DatabaseService] Documents for "$level": $count');
        if (count > 0) {
          final docs = await collection.find({'readingLevel': level}).toList();
          final categories = docs.map((doc) => doc['category']).toSet();
          print('[DatabaseService] Categories for "$level": $categories');
        }
      }
      // Test 5: Test the problematic method
      print('[DatabaseService] Test 5: Testing getAvailableCategoriesForLevel...');
      final testLevel = 'At Grade Level';
      final categories = await getAvailableCategoriesForLevel(testLevel);
      print('[DatabaseService] Categories for "$testLevel": $categories');
      print('[DatabaseService] ========== DATABASE CONNECTION TEST COMPLETE ==========');
    } catch (e) {
      print('[DatabaseService] ========== DATABASE CONNECTION TEST FAILED ==========');
      print('[DatabaseService] Error: $e');
      print('[DatabaseService] Stack trace: [31m${StackTrace.current}[0m');
      print('[DatabaseService] ===============================================');
    }
  }
}
