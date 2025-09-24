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
          'interventionAttempts': 0,
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
          'interventionAttempts': 0,
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
          'interventionAttempts': 0,
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
        // Update existing category
        print('[CategoryResultsHelper] Updating existing category: $categoryName');
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
}
