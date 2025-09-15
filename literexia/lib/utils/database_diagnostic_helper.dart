// Database Helper for User Data Operations
// This helper provides direct methods to work with user data

import '../services/database_service.dart';

class DatabaseHelper {
  static final DatabaseService _dbService = DatabaseService();

  /// Direct method to check user data
  static Future<Map<String, dynamic>> checkUserData({
    required String userId,
    bool verbose = true,
  }) async {
    try {
      if (verbose) {
        print('\n🔍 Checking User Data for: $userId');
        print('=' * 50);
      }

      // Get user data directly
      final results = await _dbService.checkUserDataCollections(userId: userId);

      if (verbose) {
        _printUserDataResults(userId, results);
      }

      return results;

    } catch (e) {
      print('❌ Error checking user data: $e');
      return {
        'userResponses': [],
        'userProfile': null,
        'status': 'error',
        'error': e.toString()
      };
    }
  }

  /// Print user data results
  static void _printUserDataResults(String userId, Map<String, dynamic> results) {
    print('\n📊 USER DATA RESULTS FOR: $userId');
    print('=' * 50);

    // User responses from Pre_Assessment.user_responses
    final userResponses = results['userResponses'] as List<Map<String, dynamic>>;
    print('\n🗂️ User Responses (${userResponses.length} found):');

    if (userResponses.isNotEmpty) {
      for (var response in userResponses) {
        print('   📝 Assessment ID: ${response['assessmentId']}');
        print('   📊 Score: ${response['score']}');
        print('   📚 Reading Level: ${response['readingLevel']}');
        print('   📈 Reading Percentage: ${response['readingPercentage']}%');
        print('   📅 Date: ${response['createdAt']}');
        print('   ---');
      }
    } else {
      print('   ❌ No assessment responses found');
    }

    // User profile from users collection
    final userProfile = results['userProfile'] as Map<String, dynamic>?;
    print('\n👤 User Profile:');

    if (userProfile != null) {
      print('   ✅ Profile found');
      print('   👤 Name: ${userProfile['name']}');
      print('   🆔 ID Number: ${userProfile['idNumber']} (${userProfile['idNumber'].runtimeType})');
      print('   📚 Reading Level: ${userProfile['readingLevel']}');
      print('   ✅ Pre-Assessment Completed: ${userProfile['preAssessmentCompleted']}');
      print('   📈 Reading Percentage: ${userProfile['readingPercentage']}%');
    } else {
      print('   ❌ No user profile found');
    }

    // Status
    print('\n📈 STATUS: ${results['status']}');
    if (results['status'] == 'error') {
      print('   ❌ Error: ${results['error']}');
    }

    print('=' * 50);
  }

  /// Create or update user profile
  static Future<bool> createOrUpdateUser({
    required String userId,
    String? name,
    String? readingLevel,
    bool? preAssessmentCompleted,
    double? readingPercentage,
  }) async {
    try {
      return await _dbService.upsertUserProfile(
        userId: userId,
        name: name,
        readingLevel: readingLevel,
        preAssessmentCompleted: preAssessmentCompleted,
        readingPercentage: readingPercentage,
      );
    } catch (e) {
      print('❌ Error creating/updating user: $e');
      return false;
    }
  }

  /// Get user responses only
  static Future<List<Map<String, dynamic>>> getUserResponses(String userId) async {
    try {
      return await _dbService.fetchUserResponses(userId);
    } catch (e) {
      print('❌ Error fetching user responses: $e');
      return [];
    }
  }

  /// Get user profile only
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _dbService.fetchUserData(userId);
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      return null;
    }
  }

  /// Simple connection test
  static Future<bool> isConnected() async {
    try {
      return _dbService.isConnected;
    } catch (e) {
      print('❌ Error checking connection: $e');
      return false;
    }
  }
}