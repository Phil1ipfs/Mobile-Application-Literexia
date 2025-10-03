// lib/utils/enhanced_category_access.dart

import 'intervention_validator.dart';

/// Enhanced category access control that integrates with InterventionValidator
/// This replaces the simple sequential locking with revision-based intervention logic
class EnhancedCategoryAccess {
  
  /// Check if a category is accessible (not locked) using intervention validator
  /// This is the main method to replace _isCategoryLocked() in HomeScreen
  static Future<bool> isCategoryAccessible(String userId, String categoryName) async {
    try {
      print('[EnhancedCategoryAccess] Checking accessibility for category: $categoryName');
      
      // STEP 1: Check basic sequential access (existing logic)
      final isSequentiallyLocked = _isSequentiallyLocked(categoryName);
      if (isSequentiallyLocked) {
        print('[EnhancedCategoryAccess] Category $categoryName is sequentially locked');
        return false;
      }
      
      // STEP 2: Check intervention-based access using validator
      final isInterventionAnswerable = await InterventionValidator.isCategoryAnswerable(userId, categoryName);
      
      if (isInterventionAnswerable) {
        print('[EnhancedCategoryAccess] Category $categoryName is accessible (intervention available)');
        return true;
      } else {
        print('[EnhancedCategoryAccess] Category $categoryName is not accessible (wait for teacher)');
        return false;
      }
      
    } catch (e) {
      print('[EnhancedCategoryAccess] Error checking category accessibility: $e');
      return false;
    }
  }
  
  /// Basic sequential access check (preserves existing logic)
  static bool _isSequentiallyLocked(String category) {
    final standardCategories = [
      'Alphabet Knowledge',
      'Phonological Awareness',
      'Decoding',
      'Word Recognition',
      'Reading Comprehension'
    ];

    final currentIndex = standardCategories.indexOf(category);
    if (currentIndex <= 0) return false; // First category is never locked

    // For now, allow all categories after first (intervention validator will handle the rest)
    // This can be enhanced later with more sophisticated sequential logic
    return false;
  }
  
  /// Get detailed access status for a category
  static Future<Map<String, dynamic>> getCategoryAccessStatus(String userId, String categoryName) async {
    try {
      final isAccessible = await isCategoryAccessible(userId, categoryName);
      final interventionStatus = await InterventionValidator.getInterventionStatus(userId, categoryName);
      
      return {
        'categoryName': categoryName,
        'isAccessible': isAccessible,
        'isSequentiallyLocked': _isSequentiallyLocked(categoryName),
        'interventionStatus': interventionStatus,
        'timestamp': DateTime.now().toIso8601String()
      };
      
    } catch (e) {
      return {
        'categoryName': categoryName,
        'isAccessible': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String()
      };
    }
  }
  
  /// Get all accessible categories for a student
  static Future<List<String>> getAccessibleCategories(String userId) async {
    try {
      final allCategories = [
        'Alphabet Knowledge',
        'Phonological Awareness',
        'Decoding',
        'Word Recognition',
        'Reading Comprehension'
      ];
      
      final accessibleCategories = <String>[];
      
      for (final category in allCategories) {
        final isAccessible = await isCategoryAccessible(userId, category);
        if (isAccessible) {
          accessibleCategories.add(category);
        }
      }
      
      print('[EnhancedCategoryAccess] Accessible categories for user $userId: $accessibleCategories');
      return accessibleCategories;
      
    } catch (e) {
      print('[EnhancedCategoryAccess] Error getting accessible categories: $e');
      return [];
    }
  }
  
  /// Check if student should see intervention button for a category
  static Future<bool> shouldShowInterventionButton(String userId, String categoryName) async {
    try {
      // Only show intervention button if category is accessible AND has intervention available
      final isAccessible = await isCategoryAccessible(userId, categoryName);
      final interventionStatus = await InterventionValidator.getInterventionStatus(userId, categoryName);
      
      final shouldShow = isAccessible && 
                        interventionStatus['isAnswerable'] == true && 
                        interventionStatus['currentInterventionId'] != null;
      
      print('[EnhancedCategoryAccess] Should show intervention button for $categoryName: $shouldShow');
      return shouldShow;
      
    } catch (e) {
      print('[EnhancedCategoryAccess] Error checking intervention button visibility: $e');
      return false;
    }
  }
  
  /// Get user-friendly message for why a category is not accessible
  static Future<String> getAccessDeniedMessage(String userId, String categoryName) async {
    try {
      final isSequentiallyLocked = _isSequentiallyLocked(categoryName);
      
      if (isSequentiallyLocked) {
        return 'Please complete the previous category first';
      }
      
      final interventionStatus = await InterventionValidator.getInterventionStatus(userId, categoryName);
      
      if (interventionStatus['isAnswerable'] == false) {
        return 'Please wait for your teacher to create a new intervention for this category';
      }
      
      if (interventionStatus['currentInterventionId'] == null) {
        return 'No active intervention available. Please contact your teacher';
      }
      
      return 'Category is not accessible at this time';
      
    } catch (e) {
      return 'Unable to determine access status. Please try again later';
    }
  }
}

/// Integration guide for HomeScreen:
/// 
/// 1. Replace _isCategoryLocked() method:
/// 
/// ```dart
/// // OLD:
/// bool _isCategoryLocked(String category) {
///   // existing logic...
/// }
/// 
/// // NEW:
/// Future<bool> _isCategoryLocked(String category) async {
///   final isAccessible = await EnhancedCategoryAccess.isCategoryAccessible(userId, category);
///   return !isAccessible;
/// }
/// ```
/// 
/// 2. Update category tap handling:
/// 
/// ```dart
/// void _handleCategoryTap(String categoryName) async {
///   final isAccessible = await EnhancedCategoryAccess.isCategoryAccessible(userId, categoryName);
///   
///   if (!isAccessible) {
///     final message = await EnhancedCategoryAccess.getAccessDeniedMessage(userId, categoryName);
///     _showAccessDeniedDialog(message);
///     return;
///   }
///   
///   // Proceed with category access...
/// }
/// ```
/// 
/// 3. Update intervention button visibility:
/// 
/// ```dart
/// Future<bool> _shouldShowInterventionButton(String categoryName) async {
///   return await EnhancedCategoryAccess.shouldShowInterventionButton(userId, categoryName);
/// }
/// ```
