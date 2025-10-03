// lib/utils/intervention_validator_test.dart

import 'intervention_validator.dart';

/// Test the intervention validator logic
/// This helps verify that the revision-based system works correctly
class InterventionValidatorTest {
  
  /// Test the scenario from the user's data:
  /// - Student has interventionHistory with attemptNumber: 1, isPassed: false
  /// - Current intervention has revisionNumber: 1
  /// - No revisionNumber: 2 exists yet
  /// - Expected result: Category should NOT be answerable
  static Future<void> testRevisionBasedLogic() async {
    print('=== TESTING REVISION-BASED INTERVENTION LOGIC ===');
    
    const userId = '8090';
    const categoryName = 'Alphabet Knowledge';
    
    print('Test scenario:');
    print('- Student has failed intervention (attemptNumber: 1, isPassed: false)');
    print('- Current intervention has revisionNumber: 1');
    print('- No revisionNumber: 2 exists yet');
    print('- Expected: Category should NOT be answerable');
    print('');
    
    try {
      // Test the validator
      final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
      
      print('Result:');
      print('- Category is answerable: $isAnswerable');
      
      if (isAnswerable) {
        print('❌ FAIL: Category is answerable when it should NOT be');
        print('   This means the validator is not working correctly');
      } else {
        print('✅ PASS: Category is correctly blocked (not answerable)');
        print('   Student must wait for teacher to create revisionNumber: 2');
      }
      
      // Get detailed status
      final status = await InterventionValidator.getInterventionStatus(userId, categoryName);
      print('');
      print('Detailed status:');
      print('- isAnswerable: ${status['isAnswerable']}');
      print('- currentInterventionId: ${status['currentInterventionId']}');
      print('- categoryName: ${status['categoryName']}');
      print('- userId: ${status['userId']}');
      
    } catch (e) {
      print('❌ ERROR: $e');
    }
  }
  
  /// Test what happens when teacher creates revisionNumber: 2
  static Future<void> testWithRevisionNumber2() async {
    print('=== TESTING WITH REVISION NUMBER 2 ===');
    
    const userId = '8090';
    const categoryName = 'Alphabet Knowledge';
    
    print('Test scenario:');
    print('- Student has failed intervention (attemptNumber: 1, isPassed: false)');
    print('- Teacher creates new intervention with revisionNumber: 2');
    print('- Expected: Category should be answerable');
    print('');
    
    try {
      final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
      
      print('Result:');
      print('- Category is answerable: $isAnswerable');
      
      if (isAnswerable) {
        print('✅ PASS: Category is correctly answerable');
        print('   Student can now retry the intervention');
      } else {
        print('❌ FAIL: Category is not answerable when it should be');
        print('   This means revisionNumber: 2 was not found or validator has issues');
      }
      
    } catch (e) {
      print('❌ ERROR: $e');
    }
  }
  
  /// Test all categories for a student
  static Future<void> testAllCategories() async {
    print('=== TESTING ALL CATEGORIES ===');
    
    const userId = '8090';
    
    try {
      final answerableCategories = await InterventionValidator.getAnswerableCategories(userId);
      
      print('Answerable categories for user $userId:');
      for (final category in answerableCategories) {
        print('- $category');
      }
      
      if (answerableCategories.isEmpty) {
        print('No categories are answerable - student must wait for teachers');
      } else {
        print('${answerableCategories.length} categories are answerable');
      }
      
    } catch (e) {
      print('❌ ERROR: $e');
    }
  }
}

/// Usage:
/// 
/// ```dart
/// // Test the current scenario (should show NOT answerable)
/// await InterventionValidatorTest.testRevisionBasedLogic();
/// 
/// // Test after teacher creates revisionNumber: 2 (should show answerable)
/// await InterventionValidatorTest.testWithRevisionNumber2();
/// 
/// // Test all categories
/// await InterventionValidatorTest.testAllCategories();
/// ```
