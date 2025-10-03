// lib/utils/intervention_validator_example.dart

import 'intervention_validator.dart';

/// Example usage of InterventionValidator
/// This shows how to integrate the revision-based intervention system
class InterventionValidatorExample {
  
  /// Example: Check if a specific category is answerable
  static Future<void> checkCategoryAccess() async {
    const userId = '8090';
    const categoryName = 'Alphabet Knowledge';
    
    print('=== CHECKING CATEGORY ACCESS ===');
    
    // Check if category is answerable
    final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
    print('Category "$categoryName" is answerable: $isAnswerable');
    
    if (isAnswerable) {
      // Get the current intervention ID to use
      final interventionId = await InterventionValidator.getCurrentInterventionId(userId, categoryName);
      print('Current intervention ID: $interventionId');
      
      // Proceed with intervention assessment
      print('✅ Student can take intervention for $categoryName');
    } else {
      print('❌ Student must wait for teacher to create new intervention');
    }
  }
  
  /// Example: Get all answerable categories for a student
  static Future<void> getAllAnswerableCategories() async {
    const userId = '8090';
    
    print('=== GETTING ALL ANSWERABLE CATEGORIES ===');
    
    final answerableCategories = await InterventionValidator.getAnswerableCategories(userId);
    print('Answerable categories: $answerableCategories');
    
    for (final category in answerableCategories) {
      final status = await InterventionValidator.getInterventionStatus(userId, category);
      print('Category: $category');
      print('  - Answerable: ${status['isAnswerable']}');
      print('  - Intervention ID: ${status['currentInterventionId']}');
      print('  - Timestamp: ${status['timestamp']}');
      print('');
    }
  }
  
  /// Example: Integration with home screen logic
  static Future<bool> shouldShowInterventionButton(String userId, String categoryName) async {
    // Use the validator to check if category is answerable
    final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
    
    if (isAnswerable) {
      print('✅ Show intervention button for $categoryName');
      return true;
    } else {
      print('❌ Hide intervention button for $categoryName (wait for teacher)');
      return false;
    }
  }
  
  /// Example: Integration with assessment flow
  static Future<Map<String, dynamic>> prepareInterventionAssessment(String userId, String categoryName) async {
    print('=== PREPARING INTERVENTION ASSESSMENT ===');
    
    // Check if category is answerable
    final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
    
    if (!isAnswerable) {
      return {
        'canProceed': false,
        'reason': 'Category not answerable - wait for teacher to create new intervention',
        'categoryName': categoryName
      };
    }
    
    // Get current intervention ID
    final interventionId = await InterventionValidator.getCurrentInterventionId(userId, categoryName);
    
    if (interventionId == null) {
      return {
        'canProceed': false,
        'reason': 'No active intervention found for category',
        'categoryName': categoryName
      };
    }
    
    return {
      'canProceed': true,
      'interventionId': interventionId,
      'categoryName': categoryName,
      'userId': userId
    };
  }
}

/// Integration points for existing code:

/// 1. In HomeScreen - Replace existing category lock logic:
/// 
/// ```dart
/// // OLD CODE:
/// bool _isCategoryLocked(String category) {
///   // existing logic...
/// }
/// 
/// // NEW CODE:
/// Future<bool> _isCategoryLocked(String category) async {
///   final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, category);
///   return !isAnswerable;
/// }
/// ```

/// 2. In InterventionProvider - Add validation before starting intervention:
/// 
/// ```dart
/// Future<void> startIntervention(String categoryName) async {
///   // Validate before starting
///   final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
///   if (!isAnswerable) {
///     throw Exception('Category not answerable - wait for teacher');
///   }
///   
///   // Get current intervention ID
///   final interventionId = await InterventionValidator.getCurrentInterventionId(userId, categoryName);
///   if (interventionId == null) {
///     throw Exception('No active intervention found');
///   }
///   
///   // Proceed with intervention...
/// }
/// ```

/// 3. In Assessment Screens - Add validation before allowing access:
/// 
/// ```dart
/// Future<void> _checkInterventionAccess() async {
///   final isAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
///   if (!isAnswerable) {
///     // Show message: "Please wait for your teacher to create a new intervention"
///     _showWaitMessage();
///     return;
///   }
///   
///   // Proceed with intervention assessment
///   _startInterventionAssessment();
/// }
/// ```
