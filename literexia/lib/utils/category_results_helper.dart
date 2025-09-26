import 'package:literexia/services/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' show where;

/// Helper class for managing category_results collection
class CategoryResultsHelper {
  /// Update existing category_results record with new category data
  /// This method should be used by subsequent categories (not Alphabet Knowledge)
  /// 
  /// Parameters:
  /// - userId: User ID
  /// - categoryName: Name of the category
  /// - score: For Phonological Awareness = correctMatches, for others = correctAnswers
  /// - total: For Phonological Awareness = totalPossibleMatches, for others = totalQuestions
  /// - scorePercentage: For Phonological Awareness = ignored (calculated), for others = percentage
  /// - totalQuestions: For Phonological Awareness = number of questions, for others = same as total
  static Future<void> updateCategoryResults(String userId, String categoryName, int score, int total, double scorePercentage, {int? totalQuestions}) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Get user data from test.users collection
      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));
      
      if (userData == null) {
        print('[CategoryResultsHelper] User not found in test.users collection');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final readingLevel = userData['readingLevel'] as String? ?? 'Low Emerging';

      print('[CategoryResultsHelper] Updating category_results - StudentId: $studentId, Category: $categoryName, Score: $scorePercentage%');

      // Create category data matching the MongoDB Atlas image structure
      Map<String, dynamic> categoryData;
      
      if (categoryName == 'Phonological Awareness') {
        // Special handling for Phonological Awareness
        // Uses: totalPossibleMatches and correctMatches
        final totalPossibleMatches = total; // total parameter represents totalPossibleMatches
        final correctMatches = score; // score parameter represents correctMatches
        final actualTotalQuestions = totalQuestions ?? total; // Use provided totalQuestions or fallback to total
                final phonologicalScore = totalPossibleMatches > 0 ? (correctMatches / totalPossibleMatches) * 100.0 : 0.0;
        
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': actualTotalQuestions, // Actual number of questions
          'correctAnswers': 0, // Always 0 for Phonological Awareness
          'totalPossibleMatches': totalPossibleMatches,
          'correctMatches': correctMatches,
          'score': phonologicalScore,
          'isPassed': phonologicalScore >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': phonologicalScore < 75.0,
          'interventionAttempts': phonologicalScore < 75.0 ? 1 : 0, // Set to 1 if failed
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      } else if (categoryName == 'Reading Comprehension') {
        // Special handling for Reading Comprehension
        // TODO: Define the correct structure for Reading Comprehension
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': total,
          'correctAnswers': score,
          'totalPossibleMatches': 0,
          'correctMatches': 0,
          'score': scorePercentage,
          'isPassed': scorePercentage >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': scorePercentage < 75.0,
          'interventionAttempts': scorePercentage < 75.0 ? 1 : 0, // Set to 1 if failed
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      } else {
        // Standard handling for Alphabet Knowledge, Decoding, Word Recognition
        // Uses: totalQuestions and correctAnswers
        categoryData = {
          'categoryName': categoryName,
          'totalQuestions': total,
          'correctAnswers': score,
          'totalPossibleMatches': 0,
          'correctMatches': 0,
          'score': scorePercentage,
          'isPassed': scorePercentage >= 75.0,
          'passingThreshold': 75.0,
          'isCompleted': true,
          'lastQuestionAnswered': '',
          'interventionRequired': scorePercentage < 75.0,
          'interventionAttempts': scorePercentage < 75.0 ? 1 : 0, // Set to 1 if failed
          'interventionCompleted': false,
          'currentInterventionId': null,
          'interventionHistory': []
        };
      }

      // Update existing category_results record
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(where.eq('studentId', studentId));

      if (existingResult == null) {
        print('[CategoryResultsHelper] ERROR: No existing category_results record found for student $studentId');
        print('[CategoryResultsHelper] This method should only be called for subsequent categories after Alphabet Knowledge');
        return;
      }

      // Update existing record - add/update the new category
      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);
      
      print('[CategoryResultsHelper] ===== BEFORE UPDATE =====');
      print('[CategoryResultsHelper] Current categories count: ${categories.length}');
      print('[CategoryResultsHelper] Current readingLevel: ${existingResult['readingLevel']}');
      print('[CategoryResultsHelper] Current completedCategories: ${existingResult['completedCategories']}');
      
      // Check if category already exists
      final existingCategoryIndex = categories.indexWhere(
        (cat) => cat['categoryName'] == categoryName
      );

      if (existingCategoryIndex >= 0) {
        // Update existing category - preserve attemptNumber if category still failed
        print('[CategoryResultsHelper] Updating existing category: $categoryName');
        final existingCategory = categories[existingCategoryIndex];
        final existingAttemptNumber = existingCategory['attemptNumber'] ?? 0;

        // IMPORTANT: Always preserve attemptNumber - it should never reset
        // attemptNumber only increments when intervention fails, never resets
        categoryData['attemptNumber'] = existingAttemptNumber; // Always preserve

        if (categoryData['isPassed'] == true) {
          print('[CategoryResultsHelper] Category $categoryName passed - preserving attemptNumber: $existingAttemptNumber');
        } else {
          print('[CategoryResultsHelper] Category $categoryName still failed - preserving attemptNumber: $existingAttemptNumber');
        }

        categories[existingCategoryIndex] = categoryData;
      } else {
        // Add new category
        print('[CategoryResultsHelper] Adding new category: $categoryName');
        categories.add(categoryData);
      }
      
      print('[CategoryResultsHelper] After update - categories count: ${categories.length}');
      print('[CategoryResultsHelper] ===== END BEFORE UPDATE =====');

      // Calculate updated overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      final allCategoriesPassed = categories.every((cat) => cat['isPassed'] == true);
      
      // Calculate overall score safely
      double overallScore;
      if (categories.isNotEmpty) {
        print('[CategoryResultsHelper] Calculating overall score from ${categories.length} categories');
        final scores = categories.map((cat) => (cat['score'] as num).toDouble()).toList();
        print('[CategoryResultsHelper] Individual scores: $scores');
        final sum = scores.reduce((a, b) => a + b);
        print('[CategoryResultsHelper] Sum of scores: $sum');
        overallScore = sum / categories.length.toDouble();
        print('[CategoryResultsHelper] Calculated overall score: $overallScore');
      } else {
        overallScore = scorePercentage;
        print('[CategoryResultsHelper] Using scorePercentage as overall score: $overallScore');
      }

      final updatedResult = {
        'assessmentDate': DateTime.now().toIso8601String(),
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'totalCategories': 5,
        'allCategoriesPassed': allCategoriesPassed,
        'readingLevel': readingLevel,
        'readingLevelUpdated': false,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId),
        {'\$set': updatedResult}
      );
      
      // Display the updated record details
      print('[CategoryResultsHelper] ===== UPDATED CATEGORY_RESULTS RECORD =====');
      print('[CategoryResultsHelper] StudentId: $studentId');
      print('[CategoryResultsHelper] ReadingLevel: $readingLevel');
      print('[CategoryResultsHelper] OverallScore: ${overallScore.toStringAsFixed(1)}%');
      print('[CategoryResultsHelper] CompletedCategories: $completedCategories/5');
      print('[CategoryResultsHelper] AllCategoriesPassed: $allCategoriesPassed');
      print('[CategoryResultsHelper] Updated Category: $categoryName');
      print('[CategoryResultsHelper] Category Details:');
      print('[CategoryResultsHelper]   - totalQuestions: ${categoryData['totalQuestions']}');
      print('[CategoryResultsHelper]   - correctAnswers: ${categoryData['correctAnswers']}');
      print('[CategoryResultsHelper]   - totalPossibleMatches: ${categoryData['totalPossibleMatches']}');
      print('[CategoryResultsHelper]   - correctMatches: ${categoryData['correctMatches']}');
      print('[CategoryResultsHelper]   - score: ${categoryData['score'].toStringAsFixed(1)}%');
      print('[CategoryResultsHelper]   - isPassed: ${categoryData['isPassed']}');
      print('[CategoryResultsHelper]   - interventionRequired: ${categoryData['interventionRequired']}');
      print('[CategoryResultsHelper] ===== END UPDATED RECORD =====');
      
      // Show final record summary
      print('[CategoryResultsHelper] ===== FINAL RECORD SUMMARY =====');
      print('[CategoryResultsHelper] StudentId: $studentId');
      print('[CategoryResultsHelper] ReadingLevel: $readingLevel (updated from test.users)');
      print('[CategoryResultsHelper] Categories Array: ${categories.length} items');
      for (int i = 0; i < categories.length; i++) {
        final cat = categories[i];
        print('[CategoryResultsHelper]   [$i] ${cat['categoryName']} - Score: ${cat['score'].toStringAsFixed(1)}% - Passed: ${cat['isPassed']}');
      }
      print('[CategoryResultsHelper] Overall Score: ${overallScore.toStringAsFixed(1)}%');
      print('[CategoryResultsHelper] Completed Categories: $completedCategories/5');
      print('[CategoryResultsHelper] All Categories Passed: $allCategoriesPassed');
      print('[CategoryResultsHelper] ===== END FINAL SUMMARY =====');
    } catch (e) {
      print('[CategoryResultsHelper] Error updating category_results: $e');
      rethrow;
    }
  }

  /// Increment interventionAttempts for a failed category after intervention failure
  /// This method is called when a student fails an intervention assessment
  static Future<void> incrementInterventionAttempts(String userId, String categoryName) async {
    try {
      print('[CategoryResultsHelper] Incrementing interventionAttempts for $categoryName, user: $userId');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when incrementing attemptNumber');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(where.eq('studentId', studentId));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for interventionAttempts increment');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and increment the specific category's interventionAttempts
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          final currentInterventionAttempts = categories[i]['interventionAttempts'] ?? 0;
          categories[i]['interventionAttempts'] = currentInterventionAttempts + 1;

          print('[CategoryResultsHelper] Incremented interventionAttempts for $categoryName: $currentInterventionAttempts -> ${currentInterventionAttempts + 1}');
          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for interventionAttempts increment');
        return;
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId),
        {'\$set': updatedResult}
      );

      print('[CategoryResultsHelper] Successfully incremented interventionAttempts for $categoryName');
    } catch (e) {
      print('[CategoryResultsHelper] Error incrementing interventionAttempts: $e');
      rethrow;
    }
  }

  /// Handle intervention completion - increment interventionAttempts only on failure
  /// When intervention passes, the category is updated but interventionAttempts is preserved
  /// When intervention fails, interventionAttempts is incremented for next attempt
  static Future<void> handleInterventionFailure(String userId, String categoryName) async {
    try {
      print('[CategoryResultsHelper] Handling intervention FAILURE for $categoryName');

      // Increment interventionAttempts for next intervention attempt
      await incrementInterventionAttempts(userId, categoryName);

      print('[CategoryResultsHelper] Intervention failed - interventionAttempts incremented, user must wait for next revision');
    } catch (e) {
      print('[CategoryResultsHelper] Error handling intervention failure: $e');
      rethrow;
    }
  }

  /// Handle successful intervention completion - sets interventionCompleted: true
  /// This method is called when a student passes an intervention assessment
  static Future<void> handleInterventionSuccess(String userId, String categoryName, double interventionScore) async {
    try {
      print('[CategoryResultsHelper] Handling intervention SUCCESS for $categoryName with score: ${interventionScore.toStringAsFixed(1)}%');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when handling intervention success');
        return;
      }

      final studentId = userData['idNumber'] as int;
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(where.eq('studentId', studentId));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for intervention success');
        return;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find and update the specific category
      bool categoryFound = false;
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['categoryName'] == categoryName) {
          // Mark intervention as completed and update category status
          categories[i]['interventionCompleted'] = true;
          categories[i]['isPassed'] = true;
          categories[i]['interventionRequired'] = false;
          categories[i]['score'] = interventionScore;

          print('[CategoryResultsHelper] Updated category $categoryName:');
          print('[CategoryResultsHelper] - interventionCompleted: true');
          print('[CategoryResultsHelper] - isPassed: true');
          print('[CategoryResultsHelper] - interventionRequired: false');
          print('[CategoryResultsHelper] - score: ${interventionScore.toStringAsFixed(1)}%');

          categoryFound = true;
          break;
        }
      }

      if (!categoryFound) {
        print('[CategoryResultsHelper] Category $categoryName not found for intervention success');
        return;
      }

      // Recalculate overall statistics
      final completedCategories = categories.where((cat) => cat['isCompleted'] == true).length;
      final allCategoriesPassed = categories.every((cat) => cat['isPassed'] == true);

      // Calculate overall score
      double overallScore = 0.0;
      if (categories.isNotEmpty) {
        final scores = categories.map((cat) => (cat['score'] as num).toDouble()).toList();
        final sum = scores.reduce((a, b) => a + b);
        overallScore = sum / categories.length.toDouble();
      }

      // Update the record
      final updatedResult = {
        'categories': categories,
        'overallScore': overallScore,
        'completedCategories': completedCategories,
        'allCategoriesPassed': allCategoriesPassed,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await categoryResultsCollection.updateOne(
        where.eq('studentId', studentId),
        {'\$set': updatedResult}
      );

      print('[CategoryResultsHelper] Successfully marked intervention as completed for $categoryName');
      print('[CategoryResultsHelper] Category is now PASSED and next category should be unlocked');
    } catch (e) {
      print('[CategoryResultsHelper] Error handling intervention success: $e');
      rethrow;
    }
  }

  /// Get interventionAttempts for a specific category
  /// Returns the current intervention attempts for intervention matching with revisionNumber
  static Future<int> getInterventionAttempts(String userId, String categoryName) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection.findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[CategoryResultsHelper] User not found when getting interventionAttempts');
        return 0;
      }

      final studentId = userData['idNumber'] as int;
      final categoryResultsCollection = dbService.getCollection('category_results');
      final existingResult = await categoryResultsCollection.findOne(where.eq('studentId', studentId));

      if (existingResult == null) {
        print('[CategoryResultsHelper] No category_results record found for interventionAttempts lookup');
        return 0;
      }

      final categories = List<Map<String, dynamic>>.from(existingResult['categories'] ?? []);

      // Find the specific category's interventionAttempts
      for (final category in categories) {
        if (category['categoryName'] == categoryName) {
          final interventionAttempts = category['interventionAttempts'] ?? 0;
          print('[CategoryResultsHelper] Found interventionAttempts for $categoryName: $interventionAttempts');
          return interventionAttempts;
        }
      }

      print('[CategoryResultsHelper] Category $categoryName not found, returning interventionAttempts: 0');
      return 0;
    } catch (e) {
      print('[CategoryResultsHelper] Error getting interventionAttempts: $e');
      return 0;
    }
  }
}
