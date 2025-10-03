// lib/utils/intervention_validator.dart

import 'package:mongo_dart/mongo_dart.dart';
import '../services/database_service.dart';

/// Validator for intervention-based category access control
/// Implements revision-based system where students can only retry interventions
/// after teacher creates new intervention with incremented revisionNumber
class InterventionValidator {
  static final DatabaseService _dbService = DatabaseService();

  /// Check if a category is answerable based on intervention history and revision numbers
  /// 
  /// Logic:
  /// 1. If category never failed → Always answerable
  /// 2. If category failed but no intervention history → Not answerable (wait for teacher)
  /// 3. If category failed with intervention history → Check revision numbers
  ///    - Find latest intervention attempt in interventionHistory
  ///    - Check if there's a new intervention with revisionNumber = latestAttempt + 1
  ///    - If found → Answerable, If not found → Not answerable
  static Future<bool> isCategoryAnswerable(String userId, String categoryName) async {
    try {
      print('[InterventionValidator] ===== STARTING VALIDATION =====');
      print('[InterventionValidator] Checking if category "$categoryName" is answerable for user $userId');
      
      // Initialize database connection
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      
      if (!_dbService.isConnected) {
        print('[InterventionValidator] Database not connected');
        return false;
      }

      // STEP 1: Get category_results record
      final categoryResultsCollection = _dbService.getCollection('category_results');
      final categoryResult = await categoryResultsCollection.findOne(
        where.eq('studentId', int.parse(userId))
      );

      if (categoryResult == null) {
        print('[InterventionValidator] No category_results found for user $userId');
        return false;
      }

      // STEP 2: Find the specific category
      final categories = List<Map<String, dynamic>>.from(categoryResult['categories'] ?? []);
      final categoryData = categories.firstWhere(
        (cat) => cat['categoryName'] == categoryName,
        orElse: () => <String, dynamic>{}
      );

      if (categoryData.isEmpty) {
        print('[InterventionValidator] Category "$categoryName" not found in category_results');
        return false;
      }

      // STEP 3: Check if category was ever failed
      final isPassed = categoryData['isPassed'] ?? false;
      final interventionRequired = categoryData['interventionRequired'] ?? false;
      
      if (isPassed) {
        print('[InterventionValidator] Category "$categoryName" already passed - always answerable');
        return true;
      }

      if (!interventionRequired) {
        print('[InterventionValidator] Category "$categoryName" does not require intervention - answerable');
        return true;
      }

      // STEP 4: Check intervention history
      final interventionHistory = List<Map<String, dynamic>>.from(categoryData['interventionHistory'] ?? []);
      
      if (interventionHistory.isEmpty) {
        // No intervention history yet - check if there's an active intervention with revisionNumber: 1
        print('[InterventionValidator] Category "$categoryName" requires intervention but no history - checking for first intervention (revisionNumber: 1)');
        final hasFirstIntervention = await _checkForNewIntervention(userId, categoryName, 1);
        
        if (hasFirstIntervention) {
          print('[InterventionValidator] ✅ Found first intervention (revisionNumber: 1) - category is answerable');
          return true;
        } else {
          print('[InterventionValidator] ❌ No first intervention found (revisionNumber: 1) - NOT answerable (wait for teacher)');
          return false;
        }
      }

      // STEP 5: Get latest intervention attempt
      final latestAttempt = interventionHistory.last;
      final latestAttemptNumber = latestAttempt['attemptNumber'] ?? 0;
      final latestInterventionId = latestAttempt['interventionId'];
      final latestIsPassed = latestAttempt['isPassed'] ?? false;

      print('[InterventionValidator] Latest attempt: #$latestAttemptNumber, Passed: $latestIsPassed, InterventionId: $latestInterventionId');

      // If latest attempt passed, category is answerable
      if (latestIsPassed) {
        print('[InterventionValidator] Latest intervention attempt passed - category answerable');
        return true;
      }

      // STEP 6: Check if there's a new intervention with incremented revision number
      final nextRevisionNumber = latestAttemptNumber + 1;
      print('[InterventionValidator] Looking for new intervention with revisionNumber: $nextRevisionNumber');
      final hasNewIntervention = await _checkForNewIntervention(userId, categoryName, nextRevisionNumber);

      if (hasNewIntervention) {
        print('[InterventionValidator] ✅ Found new intervention with revisionNumber $nextRevisionNumber - category is answerable');
        return true;
      } else {
        print('[InterventionValidator] ❌ No new intervention found with revisionNumber $nextRevisionNumber - NOT answerable (wait for teacher)');
        return false;
      }

    } catch (e) {
      print('[InterventionValidator] Error checking category answerability: $e');
      return false;
    }
  }

  /// Check if there's a new intervention with the specified revision number
  static Future<bool> _checkForNewIntervention(String userId, String categoryName, int expectedRevisionNumber) async {
    try {
      print('[InterventionValidator] _checkForNewIntervention called:');
      print('[InterventionValidator] - userId: $userId');
      print('[InterventionValidator] - categoryName: $categoryName');
      print('[InterventionValidator] - expectedRevisionNumber: $expectedRevisionNumber');
      
      final interventionCollection = _dbService.getCollection('intervention_assessment');
      
      // First, let's see all interventions for this user and category
      print('[InterventionValidator] Checking all interventions for user $userId and category $categoryName...');
      final allInterventions = await interventionCollection.find(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
      ).toList();
      
      print('[InterventionValidator] Found ${allInterventions.length} total interventions:');
      for (final intervention in allInterventions) {
        print('[InterventionValidator] - revisionNumber: ${intervention['revisionNumber']}, status: ${intervention['status']}');
      }
      
      // Look for intervention with matching studentId, category, and revisionNumber
      print('[InterventionValidator] Looking for specific intervention with revisionNumber $expectedRevisionNumber and status active...');
      final intervention = await interventionCollection.findOne(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
          .eq('revisionNumber', expectedRevisionNumber)
          .eq('status', 'active') // Only active interventions
      );

      if (intervention != null) {
        print('[InterventionValidator] ✅ Found target intervention: revisionNumber=${intervention['revisionNumber']}, status=${intervention['status']}');
        return true;
      } else {
        print('[InterventionValidator] ❌ No intervention found with revisionNumber $expectedRevisionNumber and status active');
        return false;
      }

    } catch (e) {
      print('[InterventionValidator] Error checking for new intervention: $e');
      return false;
    }
  }

  /// Get the current intervention ID that should be used for this category
  /// Returns the intervention ID with the highest revision number for this category
  static Future<String?> getCurrentInterventionId(String userId, String categoryName) async {
    try {
      final interventionCollection = _dbService.getCollection('intervention_assessment');
      
      // Find the intervention with highest revision number for this category
      final interventions = await interventionCollection.find(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
          .eq('status', 'active')
      ).toList();

      if (interventions.isEmpty) {
        print('[InterventionValidator] No active interventions found for category "$categoryName"');
        return null;
      }

      // Sort by revision number descending to get the latest
      interventions.sort((a, b) => (b['revisionNumber'] ?? 0).compareTo(a['revisionNumber'] ?? 0));
      final latestIntervention = interventions.first;
      final interventionId = latestIntervention['_id'].toString();

      print('[InterventionValidator] Current intervention ID for "$categoryName": $interventionId (revisionNumber: ${latestIntervention['revisionNumber']})');
      return interventionId;

    } catch (e) {
      print('[InterventionValidator] Error getting current intervention ID: $e');
      return null;
    }
  }

  /// Get detailed intervention status for a category
  static Future<Map<String, dynamic>> getInterventionStatus(String userId, String categoryName) async {
    try {
      final isAnswerable = await isCategoryAnswerable(userId, categoryName);
      final currentInterventionId = await getCurrentInterventionId(userId, categoryName);
      
      return {
        'isAnswerable': isAnswerable,
        'currentInterventionId': currentInterventionId,
        'categoryName': categoryName,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String()
      };

    } catch (e) {
      print('[InterventionValidator] Error getting intervention status: $e');
      return {
        'isAnswerable': false,
        'currentInterventionId': null,
        'categoryName': categoryName,
        'userId': userId,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }

  /// Check if student has any answerable interventions
  static Future<List<String>> getAnswerableCategories(String userId) async {
    try {
      final categories = [
        'Alphabet Knowledge',
        'Phonological Awareness', 
        'Decoding',
        'Word Recognition',
        'Reading Comprehension'
      ];

      final answerableCategories = <String>[];

      for (final category in categories) {
        final isAnswerable = await isCategoryAnswerable(userId, category);
        if (isAnswerable) {
          answerableCategories.add(category);
        }
      }

      print('[InterventionValidator] Answerable categories for user $userId: $answerableCategories');
      return answerableCategories;

    } catch (e) {
      print('[InterventionValidator] Error getting answerable categories: $e');
      return [];
    }
  }
}
