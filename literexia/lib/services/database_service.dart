// lib/services/database_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import '../utils/reading_level_utils.dart';

// Category validation and testing helper class
class CategoryValidationHelper {
  static const List<String> VALID_CATEGORIES = [
    'Alphabet Knowledge',
    'Phonological Awareness',
    'Decoding',
    'Word Recognition',
    'Reading Comprehension'
  ];

  /// Test category mapping for different question types
  static void testCategoryMapping() {
    print('=== TESTING CATEGORY MAPPING ===');
    
    // Test cases for question IDs
    final testCases = [
      {'questionId': 'AK_1', 'expectedCategory': 'Alphabet Knowledge'},
      {'questionId': 'PA_2', 'expectedCategory': 'Phonological Awareness'},
      {'questionId': 'DC_3', 'expectedCategory': 'Decoding'},
      {'questionId': 'WR_4', 'expectedCategory': 'Word Recognition'},
      {'questionId': 'RC_5', 'expectedCategory': 'Reading Comprehension'},
      {'questionId': 'PRE_AK_001', 'expectedCategory': 'Alphabet Knowledge'},
      {'questionId': 'main_q_1', 'expectedCategory': 'Should use current assessment category'},
    ];
    
    for (final testCase in testCases) {
      final questionId = testCase['questionId'] as String;
      final expected = testCase['expectedCategory'] as String;
      
      print('Question ID: $questionId');
      print('Expected Category: $expected');
      print('---');
    }
  }
  
  /// Validate assessment data before saving
  static bool validateAssessmentData(Map<String, dynamic> assessmentData) {
    print('=== VALIDATING ASSESSMENT DATA ===');
    
    bool isValid = true;
    final errors = <String>[];
    
    // Check required fields
    if (!assessmentData.containsKey('studentId') || assessmentData['studentId'] == null) {
      errors.add('Missing required field: studentId');
      isValid = false;
    }
    
    if (!assessmentData.containsKey('categories') || assessmentData['categories'] == null) {
      errors.add('Missing required field: categories');
      isValid = false;
    } else {
      // Validate categories structure
      final categories = assessmentData['categories'] as List?;
      if (categories == null || categories.isEmpty) {
        errors.add('Categories array is empty');
        isValid = false;
      } else {
        for (int i = 0; i < categories.length; i++) {
          final category = categories[i];
          if (category is! Map) {
            errors.add('Category at index $i is not a Map');
            isValid = false;
            continue;
          }
          
          final categoryMap = category as Map<String, dynamic>;
          
          // Check required category fields
          if (!categoryMap.containsKey('categoryName') || categoryMap['categoryName'] == null) {
            errors.add('Category at index $i missing categoryName');
            isValid = false;
          } else {
            final categoryName = categoryMap['categoryName'].toString();
            if (!VALID_CATEGORIES.contains(categoryName)) {
              errors.add('Invalid category name at index $i: $categoryName');
              isValid = false;
            }
          }
          
          if (!categoryMap.containsKey('score') || categoryMap['score'] == null) {
            errors.add('Category at index $i missing score');
            isValid = false;
          }
          
          if (!categoryMap.containsKey('totalQuestions') || categoryMap['totalQuestions'] == null) {
            errors.add('Category at index $i missing totalQuestions');
            isValid = false;
          }
          
          if (!categoryMap.containsKey('correctAnswers') || categoryMap['correctAnswers'] == null) {
            errors.add('Category at index $i missing correctAnswers');
            isValid = false;
          }
        }
      }
    }
    
    // Print validation results
    if (isValid) {
      print('✅ Assessment data is valid');
    } else {
      print('❌ Assessment data validation failed:');
      for (final error in errors) {
        print('  - $error');
      }
    }
    
    return isValid;
  }
  
  /// Generate test assessment data with correct categories
  static Map<String, dynamic> generateTestAssessmentData({
    required String studentId,
    required String assessmentType,
    bool isPreAssessment = false,
  }) {
    print('=== GENERATING TEST ASSESSMENT DATA ===');
    
    // Generate realistic category scores
    final categories = VALID_CATEGORIES.map((categoryName) {
      final totalQuestions = isPreAssessment ? 1 : 5; // Pre-assessment has 1 question per category
      final correctAnswers = (totalQuestions * 0.8).round(); // 80% correct rate
      final score = ((correctAnswers / totalQuestions) * 100).round();
      
      return {
        'categoryName': categoryName,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'score': score,
        'isPassed': score >= 75,
        'passingThreshold': 75,
      };
    }).toList();
    
    final overallScore = categories.fold<int>(0, (sum, cat) => sum + (cat['score'] as int)) ~/ categories.length;
    
    final testData = {
      'studentId': studentId,
      'assessmentType': assessmentType,
      'assessmentDate': DateTime.now().toIso8601String(),
      'categories': categories,
      'overallScore': overallScore,
      'allCategoriesPassed': categories.every((cat) => cat['isPassed'] == true),
      'readingLevel': _determineReadingLevel(overallScore),
      'readingLevelUpdated': true,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'isPreAssessment': isPreAssessment,
    };
    
    // Add primary category for main assessments
    if (!isPreAssessment) {
      testData['primaryCategory'] = VALID_CATEGORIES.first; // Use first category as primary
    }
    
    print('Generated test data for $assessmentType assessment');
    print('Overall score: $overallScore%');
    print('Categories: ${categories.length}');
    
    return testData;
  }
  
  static String _determineReadingLevel(int overallScore) {
    if (overallScore >= 80) return 'At Grade Level';
    if (overallScore >= 65) return 'Transitioning';
    if (overallScore >= 50) return 'Developing';
    if (overallScore >= 25) return 'High Emerging';
    return 'Low Emerging';
  }
  
  /// Debug method to print question-category mappings
  static void debugQuestionCategoryMapping(List<dynamic> questions, String currentCategory) {
    print('=== DEBUGGING QUESTION-CATEGORY MAPPING ===');
    print('Current Assessment Category: $currentCategory');
    print('Total Questions: ${questions.length}');
    print('---');
    
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      print('Question ${i + 1}:');
      print('  ID: ${question['questionId']}');
      print('  Type ID: ${question['questionTypeId']}');
      print('  Expected Category: $currentCategory');
      print('  ---');
    }
  }
}

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
    bool syncCompletionData = false,
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

      // If requested, sync lesson completion data from MongoDB
      if (syncCompletionData && isConnected && _db != null) {
        try {
          await _syncUserCompletionDataFromMongoDB(idNumber);
          print('[DatabaseService] Synced lesson completion data from MongoDB for user $idNumber');
        } catch (e) {
          print('[DatabaseService] Error syncing completion data: $e');
        }
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

  // Clear all local user data to prevent data bleeding between accounts
  Future<void> clearLocalUserData() async {
    try {
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return;
      }

      // Clear all user-related data
      await _localDb!.delete('users');
      await _localDb!.delete('assessments');
      await _localDb!.delete('assessment_results');
      await _localDb!.delete('lesson_progress');
      await _localDb!.delete('assessment_progress');
      await _localDb!.delete('completed_lessons');
      
      print('[DatabaseService] All local user data cleared successfully');
    } catch (e) {
      print('[DatabaseService] Error clearing local user data: $e');
      // Don't rethrow - this is a cleanup operation and should not block logout
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
    
    // Validate connection is active before proceeding
    if (!isConnected) {
      print('[DatabaseService] WARNING: Connection is not active, operations may fail');
      // Don't attempt to fix connection here - let the calling method handle reconnection
    }
    
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

  /// Ensure MongoDB connection is active and reconnect if necessary
  Future<bool> ensureConnection() async {
    try {
      // Check if we have a valid connection
      if (_db == null || !_db!.isConnected) {
        print('[DatabaseService] Connection lost, attempting to reconnect...');
        return await _reconnectAsync();
      }
      return true;
    } catch (e) {
      print('[DatabaseService] Error checking connection: $e');
      // If we can't check connection state, try to reconnect
      return await _reconnectAsync();
    }
  }
  
  /// Async reconnection method
  Future<bool> _reconnectAsync() async {
    try {
      // Close existing connection if any
      if (_db != null) {
        try {
          await _db!.close();
        } catch (e) {
          print('[DatabaseService] Error closing old connection: $e');
        }
      }
      
      // Re-initialize and connect
      final mongoUri = dotenv.env['MONGO_URI'];
      if (mongoUri != null) {
        _db = Db(mongoUri);
        await _db!.open();
        print('[DatabaseService] Successfully reconnected to MongoDB');
        return true;
      } else {
        print('[DatabaseService] Error: MongoDB URI not found in environment variables');
        return false;
      }
    } catch (e) {
      print('[DatabaseService] Error during async reconnection: $e');
      return false;
    }
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

  
// Enhanced getLessonsForLevel method with strict reading level filtering
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
  final String targetReadingLevel = ReadingLevelUtils.normalizeReadingLevel(readingLevel);
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
      if (assessments.isEmpty) {
        print('[DatabaseService] No assessments found for reading level $targetReadingLevel');
        print('[DatabaseService] Will NOT fallback to other levels for content integrity');
        
        // Return empty list - no lessons available for this level
        return [];
      }

      // Debug: Log what we found
      for (final assessment in assessments) {
        print('[DatabaseService] Assessment found: Category=${assessment['category']}, Level=${assessment['readingLevel']}, Questions=${(assessment['questions'] as List?)?.length ?? 0}');
      }

      // Verify that ALL found assessments match the target reading level exactly
      assessments = assessments.where((assessment) {
        final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
        final normalizedAssessmentLevel = _normalizeReadingLevel(assessmentLevel);
        final isMatch = normalizedAssessmentLevel == targetReadingLevel;
        
        if (!isMatch) {
          print('[DatabaseService] WARNING: Found assessment with mismatched level: $assessmentLevel vs $targetReadingLevel');
        }
        
        return isMatch;
      }).toList();

      // Sort assessments by category to ensure consistent order
      assessments.sort((a, b) {
        final categoryA = a['category']?.toString() ?? '';
        final categoryB = b['category']?.toString() ?? '';
        return categoryA.compareTo(categoryB);
      });

      // Use provided user data for completion tracking
      final safeUserIdNumber = userIdNumber ?? '';
      final safeCompletedLessons = completedLessons ?? [];

      print('[DatabaseService] User $safeUserIdNumber has completed lessons: $safeCompletedLessons');

      // Process lessons in order, maintaining level consistency
      List<Map<String, dynamic>> lessons = [];
      int index = 1;
      
      for (final assessment in assessments) {
        // Double-check this assessment is for the correct reading level
        final assessmentLevel = assessment['readingLevel']?.toString() ?? '';
        final normalizedAssessmentLevel = _normalizeReadingLevel(assessmentLevel);
        if (normalizedAssessmentLevel != targetReadingLevel) {
          print('[DatabaseService] Skipping assessment with mismatched level: $assessmentLevel vs $targetReadingLevel');
          continue;
        }

        // Check if this specific assessment has been completed
        final String assessmentIdString = assessment['_id'].toString();
        final bool isCompleted = safeUserIdNumber.isNotEmpty 
            ? await hasStudentCompletedAssessment(safeUserIdNumber, assessmentIdString)
            : false;
        
        // Lesson availability logic - Fixed to prevent missing lessons
        bool isAvailable = index == 1; // First lesson always available
        
        if (index > 1 && assessments.length > 1 && safeUserIdNumber.isNotEmpty) {
          // Check if previous lesson is completed OR if this lesson was explicitly made available
          final previousAssessmentId = assessments[index - 2]['_id'].toString();
          final previousCompleted = await hasStudentCompletedAssessment(safeUserIdNumber, previousAssessmentId);
          
          // Also check if this specific lesson was made available through completion tracking
          final currentAssessmentId = assessment['_id'].toString();
          final isExplicitlyAvailable = await _isLessonExplicitlyAvailable(safeUserIdNumber, index);
          
          isAvailable = previousCompleted || isExplicitlyAvailable;
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
        
        print('[DatabaseService] Created lesson $index: $category (Available: $isAvailable, Completed: $isCompleted, Level: $targetReadingLevel)');
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

  // Helper method to normalize reading level format with better logging
String _normalizeReadingLevel(String readingLevel) {
  final inputLevel = readingLevel.trim();
  print('[DatabaseService] Normalizing reading level: "$inputLevel"');
  
  // Convert to lowercase for case-insensitive matching
  final lowercaseLevel = inputLevel.toLowerCase();
  
  String normalizedLevel;
  
  // Normalize using pattern matching
  if (lowercaseLevel.contains('low') && lowercaseLevel.contains('emerg')) {
    normalizedLevel = 'Low Emerging';
  } else if (lowercaseLevel.contains('high') && lowercaseLevel.contains('emerg')) {
    normalizedLevel = 'High Emerging';
  } else if (lowercaseLevel.contains('develop')) {
    normalizedLevel = 'Developing';
  } else if (lowercaseLevel.contains('transit')) {
    normalizedLevel = 'Transitioning';
  } else if (lowercaseLevel.contains('grade') || lowercaseLevel.contains('fluent')) {
    normalizedLevel = 'At Grade Level';
  } else if (lowercaseLevel == 'emergent') {
    normalizedLevel = 'Low Emerging'; // Map old format to new
  } else if (lowercaseLevel == 'early') {
    normalizedLevel = 'High Emerging'; // Map old format to new
  } else if (lowercaseLevel == 'fluent') {
    normalizedLevel = 'At Grade Level'; // Map old format to new
  } else {
    // If no match, keep as is but ensure proper capitalization
    normalizedLevel = inputLevel;
    print('[DatabaseService] WARNING: Unrecognized reading level format: "$inputLevel"');
  }
  
  if (normalizedLevel != inputLevel) {
    print('[DatabaseService] Normalized reading level: "$inputLevel" → "$normalizedLevel"');
  } else {
    print('[DatabaseService] Reading level is already normalized: "$normalizedLevel"');
  }
  
  return normalizedLevel;
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

  // Updated helper method to save lessons to local DB with category preservation
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
      
      // Insert new lessons with level verification - FIXED to only use existing columns
      for (final lesson in lessons) {
        // Ensure we're only saving lessons for the correct level
        final lessonLevel = lesson['readingLevel'] ?? readingLevel;
        if (lessonLevel == readingLevel) {
          // FIXED: Only insert columns that exist in the table
          await txn.insert('lessons', {
            'lessonIndex': lesson['index'] ?? 0,
            'title': lesson['title'] ?? 'Untitled Lesson',
            'description': lesson['description'] ?? 'No description available',
            'questionCount': lesson['questionCount'] ?? 5,
            'readingLevel': readingLevel, // Explicitly set the level
            // Remove category and assessmentId for now to avoid SQLite error
          });
        }
      }
    });
    
    print('[DatabaseService] Saved ${lessons.length} lessons for level $readingLevel to local DB (without category column)');
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
      
      // Convert to expected format and ensure level and category consistency
      return localLessons.map((lesson) => {
        'index': lesson['lessonIndex'] ?? 0,
        'title': lesson['title'] ?? 'Untitled Lesson',
        'description': lesson['description'] ?? 'No description available',
        'questionCount': lesson['questionCount'] ?? 5,
        'isAvailable': true, // Local lessons default to available
        'isCompleted': false, // Will be updated by caller
        'assessmentId': lesson['assessmentId'] ?? 'local_${lesson['lessonIndex']}',
        'readingLevel': readingLevel, // Ensure consistency
        'category': lesson['category'] ?? 'Filipino Lesson', // IMPORTANT: Preserve category
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
    // CRITICAL FIX: Ensure studentId is integer
    if (response['studentId'] != null) {
      final currentStudentId = response['studentId'];
      
      if (currentStudentId is String) {
        try {
          final intStudentId = int.parse(currentStudentId);
          response['studentId'] = intStudentId;
          print('[DatabaseService] Converted studentId to integer: $intStudentId');
        } catch (e) {
          print('[DatabaseService] WARNING: Could not convert studentId to integer: $e');
        }
      }
    }
    
    final questionId = response['questionId']?.toString() ?? '';
    final category = response['category']?.toString() ?? '';
    final studentId = response['studentId'];
    
    print('[DatabaseService] Saving student response:');
    print('[DatabaseService]   - Student ID: $studentId (${studentId.runtimeType})');
    print('[DatabaseService]   - Question ID: $questionId');
    print('[DatabaseService]   - Category: $category');
    
    final studentResponseCollection = _db!.collection('student_responses');
    
    // Add timestamps if they don't exist
    if (!response.containsKey('createdAt')) {
      response['createdAt'] = DateTime.now().toIso8601String();
    }
    if (!response.containsKey('updatedAt')) {
      response['updatedAt'] = DateTime.now().toIso8601String();
    }
    
    final result = await studentResponseCollection.insertOne(response);
    
    if (result.isSuccess) {
      print('[DatabaseService] Successfully saved student response with integer studentId');
    } else {
      print('[DatabaseService] Failed to save student response: ${result.writeError?.errmsg}');
    }
  } catch (e) {
    print('[DatabaseService] Error saving student response: $e');
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
    // Ensure we have a valid connection before proceeding
    if (!await ensureConnection()) {
      print('[DatabaseService] Cannot establish MongoDB connection for pre-assessment status update');
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

  // Replace markLessonAsCompletedAndUpdateNext in database_service.dart
Future<void> markLessonAsCompletedAndUpdateNext(String userId, int lessonIndex) async {
  try {
    if (!isInitialized) {
      await initialize();
    }

    // Ensure we have a valid connection before proceeding
    if (!await ensureConnection()) {
      print('[DatabaseService] Cannot establish MongoDB connection for lesson completion update');
      return;
    }

    print('[DatabaseService] Marking lesson $lessonIndex as completed and updating next lesson for user $userId');
    
    // First, mark the current lesson as completed
    await markLessonAsCompleted(userId, lessonIndex);
    
    // Then, immediately make the next lesson available - this is critical
    final nextLessonIndex = lessonIndex + 1;
    
    // We need to make sure this method is working correctly
    // Let's force update the availability in both collections
    
    // First, try the 'lessons' collection
    try {
      final lessonsCollection = _db!.collection('lessons');
      
      // Check if the next lesson exists
      final query = where.eq('studentId', userId).and(where.eq('lessonIndex', nextLessonIndex));
      final nextLessonData = await lessonsCollection.findOne(query);
      
      if (nextLessonData != null) {
        // Update existing lesson
        final updateResult = await lessonsCollection.update(
          query,
          {
            r'$set': {'isAvailable': true},
          },
        );
        // Check if update was successful using the MongoDB result format
        print('[DatabaseService] Updated next lesson $nextLessonIndex availability in lessons collection: ${updateResult['ok'] == 1 ? 'Success' : 'Failed'}');
      } else {
        // Create new lesson entry with availability set to true
        final insertResult = await lessonsCollection.insert({
          'studentId': userId,
          'lessonIndex': nextLessonIndex,
          'isAvailable': true,
          'isCompleted': false,
          'timestamp': DateTime.now().toIso8601String(),
        });
        print('[DatabaseService] Created new available lesson entry for lesson $nextLessonIndex: ${insertResult != null ? 'Success' : 'Failed'}');
      }
    } catch (e) {
      print('[DatabaseService] Error updating lessons collection: $e');
    }
    
    // Also try the main_assessment collection as fallback
    try {
      final mainAssessmentCollection = _db!.collection('main_assessment');
      
      // Get the user's reading level
      final usersCollection = _db!.collection('users');
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
      final readingLevel = userDoc?['readingLevel'] ?? 'Undefined';
      
      // Update the next lesson's availability based on reading level
      final assessmentQuery = where.eq('index', nextLessonIndex).or(where.eq('lessonIndex', nextLessonIndex));
      
      if (readingLevel != 'Undefined') {
        assessmentQuery.and(where.eq('readingLevel', readingLevel));
      }
      
      final updateResult = await mainAssessmentCollection.update(
        assessmentQuery,
        {
          r'$set': {'isAvailable': true},
        },
      );
      
      print('[DatabaseService] Updated main_assessment collection: ${updateResult['ok'] == 1 ? 'Success' : 'Failed'}');
    } catch (e) {
      print('[DatabaseService] Error updating main_assessment collection: $e');
    }
    
    // Finally, also update the user's availableLessons array if it exists
    try {
      final usersCollection = _db!.collection('users');
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      // Add the next lesson to the user's availableLessons array
      final updateResult = await usersCollection.update(
        where.eq('idNumber', userIdValue),
        modify.addToSet('availableLessons', nextLessonIndex),
      );
      
      // For modify operations, we check the writeResult
      print('[DatabaseService] Updated user\'s availableLessons array: ${updateResult['ok'] == 1 ? 'Success' : 'Failed'}');
    } catch (e) {
      print('[DatabaseService] Error updating user\'s availableLessons array: $e');
    }
    
    print('[DatabaseService] Successfully marked lesson $lessonIndex as completed and made lesson $nextLessonIndex available');
  } catch (e) {
    print('[DatabaseService] Error in markLessonAsCompletedAndUpdateNext: $e');
    throw e;
  }
}

// Helper method to check if a lesson was explicitly made available
Future<bool> _isLessonExplicitlyAvailable(String userId, int lessonIndex) async {
  try {
    // Ensure we have a valid connection before proceeding
    if (!await ensureConnection()) {
      print('[DatabaseService] Cannot check lesson availability - no MongoDB connection');
      return false;
    }
    
    // Check the lessons collection for explicit availability
    final lessonsCollection = _db!.collection('lessons');
    final query = where.eq('studentId', userId).and(where.eq('lessonIndex', lessonIndex));
    final lessonData = await lessonsCollection.findOne(query);
    
    if (lessonData != null && lessonData['isAvailable'] == true) {
      return true;
    }
    
    // Also check the user's availableLessons array
    final usersCollection = _db!.collection('users');
    dynamic userIdValue;
    try {
      userIdValue = int.parse(userId);
    } catch (e) {
      userIdValue = userId;
    }
    
    final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
    if (userDoc != null) {
      final availableLessons = userDoc['availableLessons'] as List<dynamic>?;
      if (availableLessons != null && availableLessons.contains(lessonIndex)) {
        return true;
      }
    }
    
    return false;
  } catch (e) {
    print('[DatabaseService] Error checking explicit lesson availability: $e');
    return false;
  }
}

// Method to sync user's lesson completion data from MongoDB after login
Future<void> _syncUserCompletionDataFromMongoDB(String userId) async {
  if (!isConnected || _db == null) {
    print('[DatabaseService] Cannot sync completion data - not connected to MongoDB');
    return;
  }

  try {
    print('[DatabaseService] Syncing completion data from MongoDB for user $userId');
    
    // Convert userId to appropriate type
    dynamic userIdValue;
    try {
      userIdValue = int.parse(userId);
    } catch (e) {
      userIdValue = userId;
    }

    // Method 1: Check category_results collection for completed assessments
    final categoryResultCollection = _db!.collection('category_results');
    final categoryQuery = where.eq('studentId', userIdValue);
    final categoryResults = await categoryResultCollection.find(categoryQuery).toList();
    
    print('[DatabaseService] Found ${categoryResults.length} completed assessments in category_results');
    
    // Method 2: Check user document for completed assessments and available lessons
    final usersCollection = _db!.collection('users');
    final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
    
    if (userDoc != null) {
      // Sync completed assessments
      final completedAssessments = userDoc['completedAssessments'] as List<dynamic>?;
      if (completedAssessments != null && completedAssessments.isNotEmpty) {
        print('[DatabaseService] Found ${completedAssessments.length} completed assessments in user document');
      }
      
      // Sync available lessons
      final availableLessons = userDoc['availableLessons'] as List<dynamic>?;
      if (availableLessons != null && availableLessons.isNotEmpty) {
        print('[DatabaseService] Found available lessons: $availableLessons');
        
        // Create local lesson availability records
        final lessonsCollection = _db!.collection('lessons');
        for (final lessonIndex in availableLessons) {
          if (lessonIndex is int) {
            // Check if lesson record already exists locally
            final existingLesson = await lessonsCollection.findOne(
              where.eq('studentId', userId).and(where.eq('lessonIndex', lessonIndex))
            );
            
            if (existingLesson == null) {
              // Create lesson availability record
              await lessonsCollection.insert({
                'studentId': userId,
                'lessonIndex': lessonIndex,
                'isAvailable': true,
                'isCompleted': false,
                'timestamp': DateTime.now().toIso8601String(),
                'syncedFromMongoDB': true,
              });
              print('[DatabaseService] Created availability record for lesson $lessonIndex');
            }
          }
        }
      }
      
      // Sync completed lessons by checking category results and mapping to lessons
      final categoryToLessonMap = {
        'Alphabet Knowledge': 1,
        'Phonological Awareness': 2,
        'Decoding': 3,
        'Word Recognition': 4,
        'Reading Comprehension': 5,
      };
      
      // Mark lessons as completed based on category results
      for (final result in categoryResults) {
        final category = result['category']?.toString();
        if (category != null && categoryToLessonMap.containsKey(category)) {
          final lessonIndex = categoryToLessonMap[category]!;
          
          // Update or create lesson completion record
          final lessonsCollection = _db!.collection('lessons');
          final lessonQuery = where.eq('studentId', userId).and(where.eq('lessonIndex', lessonIndex));
          final existingLesson = await lessonsCollection.findOne(lessonQuery);
          
          if (existingLesson != null) {
            // Update existing record
            await lessonsCollection.update(
              lessonQuery,
              {r'$set': {'isCompleted': true, 'completedAt': DateTime.now().toIso8601String()}},
            );
          } else {
            // Create new completion record
            await lessonsCollection.insert({
              'studentId': userId,
              'lessonIndex': lessonIndex,
              'isAvailable': true,
              'isCompleted': true,
              'completedAt': DateTime.now().toIso8601String(),
              'syncedFromMongoDB': true,
            });
          }
          
          print('[DatabaseService] Marked lesson $lessonIndex as completed (from category: $category)');
        }
      }
    }
    
    // ADDED: Sync assessment progress from MongoDB
    await _syncAssessmentProgressFromMongoDB(userId);
    
    print('[DatabaseService] Successfully synced completion data for user $userId');
    
  } catch (e) {
    print('[DatabaseService] Error syncing completion data from MongoDB: $e');
    throw e;
  }
}

/// Sync assessment progress from MongoDB to local database
Future<void> _syncAssessmentProgressFromMongoDB(String userId) async {
  if (!isConnected || _db == null) {
    print('[DatabaseService] Cannot sync assessment progress - not connected to MongoDB');
    return;
  }
  
  try {
    print('[DatabaseService] Syncing assessment progress from MongoDB for user $userId');
    
    // Get assessment progress from MongoDB
    final progressCollection = _db!.collection('assessment_progress');
    final progressQuery = where.eq('userId', userId);
    final progressRecords = await progressCollection.find(progressQuery).toList();
    
    print('[DatabaseService] Found ${progressRecords.length} assessment progress records in MongoDB');
    
    if (progressRecords.isNotEmpty && _localDb != null) {
      // Ensure local table exists
      await _localDb!.execute(
        'CREATE TABLE IF NOT EXISTS assessment_progress(id INTEGER PRIMARY KEY, userId TEXT, assessmentId TEXT, currentQuestion INTEGER, totalQuestions INTEGER, progressPercentage INTEGER, updatedAt TEXT, isCompleted INTEGER)',
      );
      
      // Sync each progress record to local database
      for (final progress in progressRecords) {
        final assessmentId = progress['assessmentId'];
        final currentQuestion = progress['currentQuestion'] ?? 0;
        final totalQuestions = progress['totalQuestions'] ?? 0;
        final progressPercentage = progress['progressPercentage'] ?? 0;
        final updatedAt = progress['updatedAt'] ?? DateTime.now().toIso8601String();
        final isCompleted = progress['isCompleted'] ?? false;
        
        // Insert or replace the progress record in local database
        await _localDb!.insert(
          'assessment_progress',
          {
            'userId': userId,
            'assessmentId': assessmentId,
            'currentQuestion': currentQuestion,
            'totalQuestions': totalQuestions,
            'progressPercentage': progressPercentage,
            'updatedAt': updatedAt,
            'isCompleted': isCompleted ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        print('[DatabaseService] Synced assessment progress: $assessmentId - $currentQuestion/$totalQuestions ($progressPercentage%)');
      }
    }
    
  } catch (e) {
    print('[DatabaseService] Error syncing assessment progress from MongoDB: $e');
    // Don't throw - this is a nice-to-have sync operation
  }
}

  Future<bool> isLessonCompletedLocally(String userId, int lessonIndex) async {
    // Replace with your actual local DB logic.
    // Example: Query a local table 'completed_lessons' for this user and lesson.
    try {
      // Assume you have a reference to your local database as `db`
      // and a table 'completed_lessons' with columns 'userId' and 'lessonIndex'
      if (_localDb == null) {
        print('[DatabaseService] Local database not initialized');
        return false;
      }
      final results = await _localDb!.query(
        'completed_lessons',
        where: 'userId = ? AND lessonId = ?',
        whereArgs: [userId, lessonIndex],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      print('[DatabaseService] Error in isLessonCompletedLocally: $e');
      return false;
    }
  }

  // Add this method to the DatabaseService class in lib/services/database_service.dart

Future<bool> updateLessonAvailability(String userId, int lessonIndex, bool isAvailable) async {
  try {
    // Check if database is initialized
    if (!isInitialized) {
      await initialize();
    }
    
    print('[DatabaseService] Updating lesson $lessonIndex availability to $isAvailable for user $userId');
    
    // If we have MongoDB connection
    if (isConnected && _db != null) {
      // Try to update the lesson in the lessons collection first
      try {
        final lessonsCollection = _db!.collection('lessons');
        
        // Convert userIdNumber to int if possible
        dynamic userIdValue;
        try {
          userIdValue = int.parse(userId);
        } catch (e) {
          userIdValue = userId;
        }
        
        // Check if the lesson exists for this user
        final query = where.eq('studentId', userId).and(where.eq('lessonIndex', lessonIndex));
        final existingLesson = await lessonsCollection.findOne(query);
        
        if (existingLesson != null) {
          // Update existing lesson availability
          await lessonsCollection.updateOne(
            query,
            modify.set('isAvailable', isAvailable).set('updatedAt', DateTime.now().toIso8601String()),
          );
          
          print('[DatabaseService] Updated lesson $lessonIndex availability in lessons collection');
        } else {
          // Create new lesson entry with availability
          await lessonsCollection.insertOne({
            'studentId': userId,
            'lessonIndex': lessonIndex,
            'isAvailable': isAvailable,
            'isCompleted': false,
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          print('[DatabaseService] Created new lesson entry with availability $isAvailable');
        }
      } catch (e) {
        print('[DatabaseService] Error updating lessons collection: $e');
      }
      
      // Also update the user's availableLessons array
      try {
        final usersCollection = _db!.collection('users');
        
        // Convert userIdNumber to int if possible
        dynamic userIdValue;
        try {
          userIdValue = int.parse(userId);
        } catch (e) {
          userIdValue = userId;
        }
        
        if (isAvailable) {
          // Add to availableLessons if not already there
          await usersCollection.updateOne(
            where.eq('idNumber', userIdValue),
            modify.addToSet('availableLessons', lessonIndex),
          );
        } else {
          // Remove from availableLessons if it's there
          await usersCollection.updateOne(
            where.eq('idNumber', userIdValue),
            modify.pull('availableLessons', lessonIndex),
          );
        }
        
        print('[DatabaseService] Updated user\'s availableLessons array');
      } catch (e) {
        print('[DatabaseService] Error updating user\'s availableLessons array: $e');
      }
    }
    
    // Always update local database too
    if (_localDb != null) {
      try {
        // Ensure the lessons table exists
        await _localDb!.execute(
          'CREATE TABLE IF NOT EXISTS lessons(id INTEGER PRIMARY KEY, studentId TEXT, lessonIndex INTEGER, isAvailable INTEGER, isCompleted INTEGER, updatedAt TEXT)',
        );
        
        // Check if this lesson already exists in local DB
        final existingRecord = await _localDb!.query(
          'lessons',
          where: 'studentId = ? AND lessonIndex = ?',
          whereArgs: [userId, lessonIndex],
        );
        
        if (existingRecord.isEmpty) {
          // Insert new lesson record
          await _localDb!.insert('lessons', {
            'studentId': userId,
            'lessonIndex': lessonIndex,
            'isAvailable': isAvailable ? 1 : 0,
            'isCompleted': 0,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } else {
          // Update existing lesson
          await _localDb!.update(
            'lessons',
            {
              'isAvailable': isAvailable ? 1 : 0,
              'updatedAt': DateTime.now().toIso8601String(),
            },
            where: 'studentId = ? AND lessonIndex = ?',
            whereArgs: [userId, lessonIndex],
          );
        }
        
        print('[DatabaseService] Updated lesson $lessonIndex availability in local DB');
      } catch (e) {
        print('[DatabaseService] Error updating local DB: $e');
      }
    }
    
    return true;
  } catch (e) {
    print('[DatabaseService] Error in updateLessonAvailability: $e');
    return false;
  }
}

 // In database_service.dart - Update saveAssessmentResult method
Future<bool> saveAssessmentResult(Map<String, dynamic> assessmentData) async {
  try {
    if (!isInitialized) {
      await initialize();
    }
    
    // CRITICAL FIX: Ensure studentId is integer
    if (assessmentData['studentId'] != null) {
      final currentStudentId = assessmentData['studentId'];
      
      if (currentStudentId is String) {
        try {
          final intStudentId = int.parse(currentStudentId);
          assessmentData['studentId'] = intStudentId;
          print('[DatabaseService] Converted string studentId "$currentStudentId" to integer $intStudentId');
        } catch (e) {
          print('[DatabaseService] WARNING: Could not convert studentId to integer: $e');
          // Keep as string if conversion fails
        }
      } else if (currentStudentId is int) {
        print('[DatabaseService] studentId is already integer: $currentStudentId');
      } else {
        print('[DatabaseService] WARNING: studentId has unexpected type: ${currentStudentId.runtimeType}');
      }
    }
    
    // Validate assessment data
    if (!CategoryValidationHelper.validateAssessmentData(assessmentData)) {
      print('[DatabaseService] Assessment data validation failed');
      return false;
    }
    
    final studentId = assessmentData['studentId'];
    final isPreAssessment = assessmentData['isPreAssessment'] ?? false;
    
    print('[DatabaseService] Saving ${isPreAssessment ? "PRE" : "MAIN"} assessment for studentId: $studentId (${studentId.runtimeType})');
    
    if (isConnected && _db != null) {
      final resultsCollection = _db!.collection('category_results');
      
      // Add timestamps and metadata
      if (!assessmentData.containsKey('createdAt')) {
        assessmentData['createdAt'] = DateTime.now().toIso8601String();
      }
      if (!assessmentData.containsKey('updatedAt')) {
        assessmentData['updatedAt'] = DateTime.now().toIso8601String();
      }
      
      assessmentData['savedFromMobile'] = true;
      assessmentData['appVersion'] = '1.0.0';
      
      print('[DatabaseService] Final studentId before save: ${assessmentData['studentId']} (${assessmentData['studentId'].runtimeType})');
      
      final result = await resultsCollection.insertOne(assessmentData);
      
      if (result.isSuccess) {
        print('[DatabaseService] Successfully saved assessment result with integer studentId');
        print('[DatabaseService] Document ID: ${result.id}');
        return true;
      } else {
        print('[DatabaseService] Failed to save: ${result.writeError?.errmsg}');
        return false;
      }
    } else {
      return await _saveAssessmentResultLocally(assessmentData);
    }
  } catch (e) {
    print('[DatabaseService] Error saving assessment result: $e');
    return false;
  }
}

// Helper method to save assessment result locally
Future<bool> _saveAssessmentResultLocally(Map<String, dynamic> assessmentData) async {
  try {
    if (_localDb == null) {
      print('[DatabaseService] Local database not initialized');
      return false;
    }
    
    // Create assessment_results table if it doesn't exist
    await _localDb!.execute(
      'CREATE TABLE IF NOT EXISTS assessment_results(id INTEGER PRIMARY KEY, studentId TEXT, assessmentType TEXT, assessmentDate TEXT, readingLevel TEXT, score INTEGER, pending INTEGER DEFAULT 1)',
    );
    
    // Extract key data for the local database
    final studentId = assessmentData['studentId'] ?? '';
    final assessmentType = assessmentData['assessmentType'] ?? '';
    final assessmentDate = assessmentData['assessmentDate'] ?? DateTime.now().toIso8601String();
    final readingLevel = assessmentData['readingLevel'] ?? '';
    final score = assessmentData['overallScore'] ?? 0;
    
    // Insert into local database
    await _localDb!.insert('assessment_results', {
      'studentId': studentId.toString(),
      'assessmentType': assessmentType,
      'assessmentDate': assessmentDate,
      'readingLevel': readingLevel,
      'score': score,
      'pending': 1, // Mark as pending for future sync
    });
    
    // For pre-assessments, also update the user record
    if (assessmentData['isPreAssessment'] == true) {
      await saveUserDataLocally(
        idNumber: studentId.toString(),
        readingLevel: readingLevel,
        preAssessmentCompleted: true,
      );
    }
    
    print('[DatabaseService] Assessment result saved locally');
    return true;
  } catch (e) {
    print('[DatabaseService] Error saving assessment result locally: $e');
    return false;
  }
}

/// Make a lesson available for a user (used for unlocking Aralin 2, etc.)
Future<void> makeLessonAvailable(String userId, int lessonIndex) async {
  try {
    if (!isInitialized) {
      await initialize();
    }

    if (!isConnected) {
      print('[DatabaseService] Not connected to database, cannot update lesson availability');
      return;
    }

    print('[DatabaseService] Directly making lesson $lessonIndex available for user $userId');
    
    // Get the lessons collection
    final lessonsCollection = _db!.collection('lessons');
    
    // Query for this specific lesson
    final query = where.eq('studentId', userId).and(where.eq('lessonIndex', lessonIndex));
    
    // First check if the lesson exists
    final lessonDoc = await lessonsCollection.findOne(query);
    
    if (lessonDoc != null) {
      // Update existing lesson
      await lessonsCollection.update(
        query,
        {
          r'$set': {'isAvailable': true},
        },
      );
      print('[DatabaseService] Updated existing lesson $lessonIndex to be available');
    } else {
      // Create new lesson document
      await lessonsCollection.insert({
        'studentId': userId,
        'lessonIndex': lessonIndex,
        'isAvailable': true,
        'isCompleted': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('[DatabaseService] Created new available lesson $lessonIndex');
    }
    
    // Also update the user document
    try {
      final usersCollection = _db!.collection('users');
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }
      
      // Add to availableLessons array
      await usersCollection.update(
        where.eq('idNumber', userIdValue),
        modify.addToSet('availableLessons', lessonIndex),
      );
      print('[DatabaseService] Added lesson $lessonIndex to user\'s availableLessons array');
    } catch (e) {
      print('[DatabaseService] Error updating user document: $e');
    }
  } catch (e) {
    print('[DatabaseService] Error making lesson available: $e');
  }
}

// ADDED: Method to validate and fix category mismatches
Future<void> validateAndFixCategoryMismatches(String userId) async {
  if (!isConnected || _db == null) {
    print('[DatabaseService] Cannot validate categories - not connected to DB');
    return;
  }
  
  try {
    print('[DatabaseService] Validating category assignments for user: $userId');
    
    // Get all student responses for this user
    final studentResponseCollection = _db!.collection('student_responses');
    
    // Convert userId to appropriate type
    dynamic userIdValue;
    try {
      userIdValue = int.parse(userId);
    } catch (e) {
      userIdValue = userId;
    }
    
    final responses = await studentResponseCollection.find(
      where.eq('studentId', userIdValue)
    ).toList();
    
    if (responses.isEmpty) {
      print('[DatabaseService] No responses found for user $userId');
      return;
    }
    
    print('[DatabaseService] Found ${responses.length} responses to validate');
    
    int fixedResponses = 0;
    
    for (final response in responses) {
      final questionId = response['questionId']?.toString() ?? '';
      final currentCategory = response['category']?.toString() ?? '';
      
      if (questionId.isNotEmpty) {
        // Determine what the category should be based on question ID
        String correctCategory = _determineCategoryFromQuestionId(questionId);
        
        if (correctCategory != currentCategory && correctCategory != 'Unknown') {
          print('[DatabaseService] Fixing category mismatch:');
          print('[DatabaseService]   - Question ID: $questionId');
          print('[DatabaseService]   - Current Category: $currentCategory');
          print('[DatabaseService]   - Correct Category: $correctCategory');
          
          // Update the response with the correct category
          await studentResponseCollection.updateOne(
            where.eq('_id', response['_id']),
            modify
              .set('category', correctCategory)
              .set('categoryFixed', true)
              .set('originalCategory', currentCategory)
              .set('fixedAt', DateTime.now().toIso8601String())
          );
          
          fixedResponses++;
        }
      }
    }
    
    print('[DatabaseService] Fixed $fixedResponses category mismatches for user $userId');
    
  } catch (e) {
    print('[DatabaseService] Error validating category mismatches: $e');
  }
}

// Helper method to determine category from question ID
String _determineCategoryFromQuestionId(String questionId) {
  final id = questionId.toLowerCase();
  
  if (id.startsWith('ak_') || id.startsWith('pre_ak') || id.contains('alphabet')) {
    return 'Alphabet Knowledge';
  }
  if (id.startsWith('pa_') || id.startsWith('pre_pa') || id.contains('phono')) {
    return 'Phonological Awareness';
  }
  if (id.startsWith('dc_') || id.startsWith('pre_dc') || id.contains('decod')) {
    return 'Decoding';
  }
  if (id.startsWith('wr_') || id.startsWith('pre_wr') || id.contains('word')) {
    return 'Word Recognition';
  }
  if (id.startsWith('rc_') || id.startsWith('pre_rc') || id.contains('reading') || id.contains('comprehension')) {
    return 'Reading Comprehension';
  }
  
  return 'Unknown';
}

  /// Check if a user has already completed a specific assessment
  Future<bool> hasCompletedAssessment(String userId, String assessmentId) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Ensure we have a valid connection before proceeding
      if (!await ensureConnection()) {
        print('[DatabaseService] Cannot establish MongoDB connection, checking local database');
        return false;
      }

      // Check in category_results collection
      final categoryResultsCollection = _db!.collection('category_results');
      
      // Convert userId to the appropriate type
      dynamic userIdValue;
      try {
        userIdValue = int.parse(userId);
      } catch (e) {
        userIdValue = userId;
      }

      // Query for existing results
      final query = where.eq('studentId', userIdValue).and(where.eq('assessmentId', assessmentId));
      final count = await categoryResultsCollection.count(query);
      
      if (count > 0) {
        print('[DatabaseService] Found existing assessment results for user $userId and assessment $assessmentId');
        return true;
      }

      // Also check student_responses collection
      final studentResponsesCollection = _db!.collection('student_responses');
      final responseQuery = where.eq('studentId', userIdValue).and(where.eq('categoryId', assessmentId));
      final responseCount = await studentResponsesCollection.count(responseQuery);
      
      if (responseCount > 0) {
        print('[DatabaseService] Found existing student responses for user $userId and assessment $assessmentId');
        return true;
      }

      print('[DatabaseService] No existing assessment results found for user $userId and assessment $assessmentId');
      return false;
    } catch (e) {
      print('[DatabaseService] Error checking for completed assessment: $e');
      return false;
    }
  }

  // Enhanced method to better detect lesson completion
Future<bool> isLessonCompletedEnhanced(String userId, int lessonIndex) async {
  try {
    print('[DatabaseService] Enhanced check: Is lesson $lessonIndex completed for user $userId?');
    
    // Method 1: Check MongoDB user document
    if (isConnected && _db != null) {
      try {
        final usersCollection = _db!.collection('users');
        
        dynamic userIdValue;
        try {
          userIdValue = int.parse(userId);
        } catch (e) {
          userIdValue = userId;
        }
        
        final userDoc = await usersCollection.findOne(where.eq('idNumber', userIdValue));
        if (userDoc != null) {
          final completedLessons = userDoc['completedLessons'] as List? ?? [];
          
          bool isCompleted = completedLessons.contains(lessonIndex) || 
                            completedLessons.contains(lessonIndex.toString());
          
          if (isCompleted) {
            print('[DatabaseService] Lesson $lessonIndex completed (found in user document)');
            return true;
          }
        }
      } catch (e) {
        print('[DatabaseService] Error checking user document: $e');
      }
    }
    
    // Method 2: Check local database
    if (_localDb != null) {
      try {
        final localResults = await _localDb!.query(
          'completed_lessons',
          where: 'userId = ? AND lessonId = ?',
          whereArgs: [userId, lessonIndex],
        );
        
        if (localResults.isNotEmpty) {
          print('[DatabaseService] Lesson $lessonIndex completed (found in local DB)');
          return true;
        }
      } catch (e) {
        print('[DatabaseService] Error checking local DB: $e');
      }
    }
    
    // Method 3: Check category results - ONLY consider main assessment results for specific lesson
    if (isConnected && _db != null) {
      try {
        final categoryResultsCollection = _db!.collection('category_results');
        
        dynamic userIdValue;
        try {
          userIdValue = int.parse(userId);
        } catch (e) {
          userIdValue = userId;
        }
        
        // Get all category results for this user
        final categoryResults = await categoryResultsCollection.find(
          where.eq('studentId', userIdValue)
        ).toList();
        
        // Filter for main assessment results only
        final mainAssessmentResults = categoryResults.where((result) =>
          result['isPreAssessment'] != true // false or missing
        ).toList();
        
        // Map lesson index to category name
        const lessonCategoryMap = {
          1: 'Alphabet Knowledge',
          2: 'Phonological Awareness',
          3: 'Decoding',
          4: 'Word Recognition',
          5: 'Reading Comprehension',
        };
        
        // Check if there's a result specifically for this lesson number
        for (final result in mainAssessmentResults) {
          final assessmentId = result['assessmentId']?.toString() ?? '';
          final category = result['category']?.toString() ?? '';
          final expectedCategory = lessonCategoryMap[lessonIndex] ?? '';
          
          if (assessmentId.contains('ARALIN $lessonIndex') ||
              assessmentId.contains('Lesson $lessonIndex') ||
              category == expectedCategory) {
            print('[DatabaseService] Lesson $lessonIndex completed (found specific main assessment result)');
            return true;
          }
        }
      } catch (e) {
        print('[DatabaseService] Error checking category results: $e');
      }
    }
    
    print('[DatabaseService] Lesson $lessonIndex not completed');
    return false;
    
  } catch (e) {
    print('[DatabaseService] Error in enhanced lesson completion check: $e');
    return false;
  }
}

  /// Creates test intervention data for debugging purposes
  Future<void> createTestInterventionData(String userId) async {
    if (!isConnected || _db == null) {
      print('[DatabaseService] Cannot create test intervention data - not connected to DB');
      return;
    }

    try {
      print('[DatabaseService] Creating test intervention data for user: $userId');
      
      // Get the interventions collection
      final interventionsCollection = _db!.collection('interventions');
      
      // Create a test intervention document
      final testIntervention = {
        'userId': userId,
        'type': 'reading_intervention',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'assessmentId': 'test_assessment_${DateTime.now().millisecondsSinceEpoch}',
        'readingLevel': 'Beginner',
        'score': 65,
        'threshold': 70,
        'isActive': true,
        'notes': 'Test intervention created for debugging',
      };
      
      // Insert the test intervention
      final result = await interventionsCollection.insertOne(testIntervention);
      
      if (result.isSuccess) {
        print('[DatabaseService] Successfully created test intervention data');
      } else {
        print('[DatabaseService] Failed to create test intervention data: ${result.writeError?.errmsg ?? "Unknown error"}');
      }
    } catch (e) {
      print('[DatabaseService] Error creating test intervention data: $e');
    }
  }

  Future<bool> markLessonAsCompletedByCategory(String userId, String category) async {
    try {
      print('[DatabaseService] Marking lesson as completed by category: $category for user: $userId');
      
      // Map categories to lesson indices
      final categoryToLessonMap = {
        'Alphabet Knowledge': 1,
        'Phonological Awareness': 2,
        'Decoding': 3,
        'Word Recognition': 4,
        'Reading Comprehension': 5,
      };

      final lessonIndex = categoryToLessonMap[category];
      
      if (lessonIndex != null) {
        await markLessonAsCompletedAndUpdateNext(userId, lessonIndex);
        return true;
      } else {
        print('[DatabaseService] Unknown category: $category');
        return false;
      }
    } catch (e) {
      print('[DatabaseService] Error marking lesson as completed by category: $e');
      return false;
    }
  }

  /// Save partial lesson progress for partially completed lessons
  Future<void> saveLessonProgress(String userId, int lessonIndex, int currentQuestion, int totalQuestions, int progressPercentage, String category) async {
    try {
      print('[DatabaseService] Saving lesson progress: User=$userId, Lesson=$lessonIndex, Progress=$currentQuestion/$totalQuestions ($progressPercentage%)');

      // Save to MongoDB if connected
      if (_db != null) {
        final progressCollection = _db!.collection('lesson_progress');
        
        // Upsert (insert or update) the progress record
        await progressCollection.update(
          where.eq('userId', userId).and(where.eq('lessonIndex', lessonIndex)),
          {
            r'$set': {
              'userId': userId,
              'lessonIndex': lessonIndex,
              'currentQuestion': currentQuestion,
              'totalQuestions': totalQuestions,
              'progressPercentage': progressPercentage,
              'category': category,
              'updatedAt': DateTime.now().toIso8601String(),
              'isCompleted': false, // Partial progress
            }
          },
          upsert: true,
        );
        
        print('[DatabaseService] Saved lesson progress to MongoDB');
      }

      // Save to local database
      if (_localDb != null) {
        // Ensure the table exists
        await _localDb!.execute(
          'CREATE TABLE IF NOT EXISTS lesson_progress(id INTEGER PRIMARY KEY, userId TEXT, lessonIndex INTEGER, currentQuestion INTEGER, totalQuestions INTEGER, progressPercentage INTEGER, category TEXT, updatedAt TEXT, isCompleted INTEGER)',
        );

        // Insert or replace the progress record
        await _localDb!.insert(
          'lesson_progress',
          {
            'userId': userId,
            'lessonIndex': lessonIndex,
            'currentQuestion': currentQuestion,
            'totalQuestions': totalQuestions,
            'progressPercentage': progressPercentage,
            'category': category,
            'updatedAt': DateTime.now().toIso8601String(),
            'isCompleted': 0, // False in SQLite
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        print('[DatabaseService] Saved lesson progress to local DB');
      }
    } catch (e) {
      print('[DatabaseService] Error saving lesson progress: $e');
    }
  }

  /// Save partial assessment progress
  Future<void> saveAssessmentProgress(String userId, String assessmentId, int currentQuestion, int totalQuestions, int progressPercentage) async {
    try {
      print('[DatabaseService] Saving assessment progress: User=$userId, Assessment=$assessmentId, Progress=$currentQuestion/$totalQuestions ($progressPercentage%)');

      // Save to MongoDB if connected
      if (_db != null) {
        final progressCollection = _db!.collection('assessment_progress');
        
        // Upsert (insert or update) the progress record
        await progressCollection.update(
          where.eq('userId', userId).and(where.eq('assessmentId', assessmentId)),
          {
            r'$set': {
              'userId': userId,
              'assessmentId': assessmentId,
              'currentQuestion': currentQuestion,
              'totalQuestions': totalQuestions,
              'progressPercentage': progressPercentage,
              'updatedAt': DateTime.now().toIso8601String(),
              'isCompleted': false, // Partial progress
            }
          },
          upsert: true,
        );
        
        print('[DatabaseService] Saved assessment progress to MongoDB');
      }

      // Save to local database
      if (_localDb != null) {
        // Ensure the table exists
        await _localDb!.execute(
          'CREATE TABLE IF NOT EXISTS assessment_progress(id INTEGER PRIMARY KEY, userId TEXT, assessmentId TEXT, currentQuestion INTEGER, totalQuestions INTEGER, progressPercentage INTEGER, updatedAt TEXT, isCompleted INTEGER)',
        );

        // Insert or replace the progress record
        await _localDb!.insert(
          'assessment_progress',
          {
            'userId': userId,
            'assessmentId': assessmentId,
            'currentQuestion': currentQuestion,
            'totalQuestions': totalQuestions,
            'progressPercentage': progressPercentage,
            'updatedAt': DateTime.now().toIso8601String(),
            'isCompleted': 0, // False in SQLite
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        print('[DatabaseService] Saved assessment progress to local DB');
      }
    } catch (e) {
      print('[DatabaseService] Error saving assessment progress: $e');
    }
  }

  /// Get lesson progress for display on home screen
  Future<Map<String, dynamic>?> getLessonProgress(String userId, int lessonIndex) async {
    try {
      // Try MongoDB first
      if (_db != null) {
        final progressCollection = _db!.collection('lesson_progress');
        final progressDoc = await progressCollection.findOne(
          where.eq('userId', userId).and(where.eq('lessonIndex', lessonIndex)
        ));
        
        if (progressDoc != null) {
          return {
            'currentQuestion': progressDoc['currentQuestion'] ?? 0,
            'totalQuestions': progressDoc['totalQuestions'] ?? 0,
            'progressPercentage': progressDoc['progressPercentage'] ?? 0,
            'category': progressDoc['category'] ?? '',
            'updatedAt': progressDoc['updatedAt'] ?? '',
            'isCompleted': progressDoc['isCompleted'] ?? false,
          };
        }
      }

      // Fallback to local database
      if (_localDb != null) {
        final List<Map<String, dynamic>> results = await _localDb!.query(
          'lesson_progress',
          where: 'userId = ? AND lessonIndex = ?',
          whereArgs: [userId, lessonIndex],
          limit: 1,
        );
        
        if (results.isNotEmpty) {
          final progress = results.first;
          return {
            'currentQuestion': progress['currentQuestion'] ?? 0,
            'totalQuestions': progress['totalQuestions'] ?? 0,
            'progressPercentage': progress['progressPercentage'] ?? 0,
            'category': progress['category'] ?? '',
            'updatedAt': progress['updatedAt'] ?? '',
            'isCompleted': (progress['isCompleted'] ?? 0) == 1,
          };
        }
      }

      return null;
    } catch (e) {
      print('[DatabaseService] Error getting lesson progress: $e');
      return null;
    }
  }
}

List<Map<String, dynamic>> getOptions(Map<String, dynamic> question) {
  if (question['options'] != null && (question['options'] as List).isNotEmpty) {
    return List<Map<String, dynamic>>.from(question['options']);
  } else if (question['sentenceQuestions'] != null && (question['sentenceQuestions'] as List).isNotEmpty) {
    final sq = question['sentenceQuestions'][0];
    final correct = sq['correctAnswer'] ?? '';
    final incorrect = sq['incorrectAnswer'] ?? '';
    // Only add non-empty answers
    final options = <Map<String, dynamic>>[];
    if (correct.isNotEmpty) options.add({'optionText': correct, 'isCorrect': true});
    if (incorrect.isNotEmpty) options.add({'optionText': incorrect, 'isCorrect': false});
    // Optionally shuffle
    options.shuffle();
    return options;
  }
  return [];
  
}