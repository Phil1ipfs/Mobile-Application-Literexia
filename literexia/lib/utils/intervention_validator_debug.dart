// lib/utils/intervention_validator_debug.dart

import 'package:mongo_dart/mongo_dart.dart';
import '../services/database_service.dart';

/// Debug version of InterventionValidator to trace the exact issue
class InterventionValidatorDebug {
  static final DatabaseService _dbService = DatabaseService();

  /// Debug method to trace why category is not answerable
  static Future<void> debugCategoryAnswerability(String userId, String categoryName) async {
    try {
      print('=== DEBUGGING CATEGORY ANSWERABILITY ===');
      print('UserId: $userId');
      print('Category: $categoryName');
      print('');

      // Initialize database
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      if (!_dbService.isConnected) {
        print('❌ Database not connected');
        return;
      }

      // STEP 1: Check category_results
      print('STEP 1: Checking category_results...');
      final categoryResultsCollection = _dbService.getCollection('category_results');
      final categoryResult = await categoryResultsCollection.findOne(
        where.eq('studentId', int.parse(userId))
      );

      if (categoryResult == null) {
        print('❌ No category_results found for user $userId');
        return;
      }

      print('✅ Found category_results for user $userId');
      print('');

      // STEP 2: Find specific category
      print('STEP 2: Finding category "$categoryName"...');
      final categories = List<Map<String, dynamic>>.from(categoryResult['categories'] ?? []);
      print('Total categories in record: ${categories.length}');
      
      for (int i = 0; i < categories.length; i++) {
        final cat = categories[i];
        print('Category $i: ${cat['categoryName']}');
      }

      final categoryData = categories.firstWhere(
        (cat) => cat['categoryName'] == categoryName,
        orElse: () => <String, dynamic>{}
      );

      if (categoryData.isEmpty) {
        print('❌ Category "$categoryName" not found in category_results');
        return;
      }

      print('✅ Found category "$categoryName"');
      print('Category data: $categoryData');
      print('');

      // STEP 3: Check basic status
      print('STEP 3: Checking basic status...');
      final isPassed = categoryData['isPassed'] ?? false;
      final interventionRequired = categoryData['interventionRequired'] ?? false;
      
      print('isPassed: $isPassed');
      print('interventionRequired: $interventionRequired');

      if (isPassed) {
        print('✅ Category already passed - should be answerable');
        return;
      }

      if (!interventionRequired) {
        print('✅ Category does not require intervention - should be answerable');
        return;
      }

      print('Category requires intervention and is not passed');
      print('');

      // STEP 4: Check intervention history
      print('STEP 4: Checking intervention history...');
      final interventionHistory = List<Map<String, dynamic>>.from(categoryData['interventionHistory'] ?? []);
      
      print('interventionHistory length: ${interventionHistory.length}');
      
      if (interventionHistory.isEmpty) {
        print('❌ No intervention history - category NOT answerable (wait for teacher)');
        return;
      }

      print('✅ Found intervention history');
      for (int i = 0; i < interventionHistory.length; i++) {
        final attempt = interventionHistory[i];
        print('Attempt $i: $attempt');
      }

      // STEP 5: Get latest attempt
      print('');
      print('STEP 5: Analyzing latest attempt...');
      final latestAttempt = interventionHistory.last;
      final latestAttemptNumber = latestAttempt['attemptNumber'] ?? 0;
      final latestInterventionId = latestAttempt['interventionId'];
      final latestIsPassed = latestAttempt['isPassed'] ?? false;

      print('Latest attempt number: $latestAttemptNumber');
      print('Latest intervention ID: $latestInterventionId');
      print('Latest is passed: $latestIsPassed');

      if (latestIsPassed) {
        print('✅ Latest intervention attempt passed - category should be answerable');
        return;
      }

      print('Latest attempt failed - checking for new intervention');
      print('');

      // STEP 6: Check for new intervention
      print('STEP 6: Checking for new intervention...');
      final nextRevisionNumber = latestAttemptNumber + 1;
      print('Looking for revisionNumber: $nextRevisionNumber');

      final interventionCollection = _dbService.getCollection('intervention_assessment');
      
      // Check all interventions for this user and category
      print('All interventions for user $userId and category $categoryName:');
      final allInterventions = await interventionCollection.find(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
      ).toList();

      print('Found ${allInterventions.length} interventions:');
      for (final intervention in allInterventions) {
        print('- revisionNumber: ${intervention['revisionNumber']}, status: ${intervention['status']}');
      }

      // Check for specific revision number
      final targetIntervention = await interventionCollection.findOne(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
          .eq('revisionNumber', nextRevisionNumber)
          .eq('status', 'active')
      );

      if (targetIntervention != null) {
        print('✅ Found target intervention with revisionNumber $nextRevisionNumber');
        print('Target intervention: $targetIntervention');
        print('✅ Category should be ANSWERABLE');
      } else {
        print('❌ No target intervention found with revisionNumber $nextRevisionNumber');
        print('❌ Category should NOT be answerable (wait for teacher)');
      }

    } catch (e) {
      print('❌ Error during debug: $e');
    }
  }

  /// Debug method to check intervention_assessment collection
  static Future<void> debugInterventionAssessment(String userId, String categoryName) async {
    try {
      print('=== DEBUGGING INTERVENTION_ASSESSMENT COLLECTION ===');
      print('UserId: $userId');
      print('Category: $categoryName');
      print('');

      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      final interventionCollection = _dbService.getCollection('intervention_assessment');
      
      // Get all interventions for this user and category
      final interventions = await interventionCollection.find(
        where.eq('studentId', int.parse(userId))
          .eq('category', categoryName)
      ).toList();

      print('Found ${interventions.length} interventions:');
      for (final intervention in interventions) {
        print('- _id: ${intervention['_id']}');
        print('  revisionNumber: ${intervention['revisionNumber']}');
        print('  status: ${intervention['status']}');
        print('  createdAt: ${intervention['createdAt']}');
        print('  updatedAt: ${intervention['updatedAt']}');
        print('');
      }

    } catch (e) {
      print('❌ Error debugging intervention_assessment: $e');
    }
  }
}

/// Usage:
/// 
/// ```dart
/// // Debug why Alphabet Knowledge is not answerable
/// await InterventionValidatorDebug.debugCategoryAnswerability('8090', 'Alphabet Knowledge');
/// 
/// // Debug intervention_assessment collection
/// await InterventionValidatorDebug.debugInterventionAssessment('8090', 'Alphabet Knowledge');
/// ```
