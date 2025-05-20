// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import '../config/router.dart';
import '../features/auth/logic/auth_provider.dart';
import '../screens/settings_screen.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection, where;
import '../features/settings/provider/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lessons = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid setState during build
    Future.microtask(() => _loadLessons());
  }

  Future<void> _loadLessons() async {
  if (!mounted) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    // Get the current user's reading level
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';

    // Get lessons directly from main_assessment collection
    final lessons = await _getFallbackLessonsForLevel(readingLevel);

    // IMPORTANT NEW CODE: Check completion status for each lesson
    if (lessons.isNotEmpty && userId.isNotEmpty) {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Go through each lesson and check if it's completed
      for (int i = 0; i < lessons.length; i++) {
        final lessonId = lessons[i]['assessmentId'];
        if (lessonId != null && lessonId.toString() != 'default_lesson_1' && lessonId.toString() != 'default_lesson_2') {
          final isCompleted = await dbService.hasStudentCompletedAssessment(userId, lessonId);
          lessons[i]['isCompleted'] = isCompleted;
          print('Lesson ${lessons[i]['index']}: Completion status = $isCompleted');
        }
      }
    }

    if (!mounted) return;

    // Update state with lessons
    setState(() {
      _lessons = lessons;
      _isLoading = false;
    });

    // Update AralinProvider with lessons (without waiting for return)
    final aralinProvider = Provider.of<AralinProvider>(context, listen: false);
    Future(() {
      aralinProvider.setLessons(lessons);
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _errorMessage = "Could not load lessons. Please try again later.";
      _isLoading = false;
    });
    print('Error loading lessons: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    final userName = authProvider.currentUser?.firstName ?? 
                    authProvider.currentUser?.name ?? 
                    'Guest';
    final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';

    return Scaffold(
      // Use theme background color directly
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with themed background
            Container(
              width: double.infinity,
              height: 65,
              color: theme.headerColor, // Use header color
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'H I !   $userName',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: themeProvider.getRealFontSize(18),
                          fontWeight: FontWeight.bold,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.headerColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.accentColor, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/images/penguin.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.accentColor, 
                    fontSize: themeProvider.getRealFontSize(12),
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),

            Expanded(
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.accentColor,
                    ),
                  )
                : _lessons.isEmpty
                  ? _buildNoLessonsMessage(themeProvider)
                  : _buildLessonGrid(readingLevel, themeProvider),
            ),

            // Bottom Navigation with themed background
            Container(
              height: 60,
              color: theme.headerColor, // Use header color for bottom bar
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.home,
                    label: 'Home',
                    isSelected: true,
                    onTap: () {},
                    themeProvider: themeProvider,
                  ),
                  _buildNavItem(
                    icon: Icons.person,
                    label: 'Profile',
                    isSelected: false,
                    onTap: () {
                      // Navigate to profile
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    themeProvider: themeProvider,
                  ),
                  _buildNavItem(
                    icon: Icons.settings,
                    label: 'Setting',
                    isSelected: false,
                    onTap: () {
                      // Navigate to settings
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    themeProvider: themeProvider,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated nav item builder with proper theming
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    final theme = themeProvider.currentTheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? theme.accentColor : theme.textColor.withOpacity(0.7),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? theme.accentColor : theme.textColor.withOpacity(0.7),
              fontSize: themeProvider.getRealFontSize(12),
              fontFamily: themeProvider.fontFamily,
              letterSpacing: themeProvider.getRealLetterSpacing(),
            ),
          ),
        ],
      ),
    );
  }

  // No lessons message with proper theming
  Widget _buildNoLessonsMessage(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 60, color: theme.accentColor),
            const SizedBox(height: 16),
            Text(
              'No lessons found',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(20),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
                letterSpacing: themeProvider.getRealLetterSpacing(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher has not added any lessons yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
                letterSpacing: themeProvider.getRealLetterSpacing(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lesson grid with proper theming
  Widget _buildLessonGrid(String readingLevel, ThemeProvider themeProvider) {
  return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemCount: _lessons.length,
    itemBuilder: (context, index) {
      final lesson = _lessons[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: _buildLessonCard(
          index: lesson['index'] as int,
          title: lesson['title'] as String,
          description: lesson['description'] as String? ?? 'Engage with interactive Filipino lessons',
          questionCount: lesson['questionCount'] as int? ?? 5,
          isAvailable: lesson['isAvailable'] as bool,
          isCompleted: lesson['isCompleted'] as bool? ?? false, // Add this line
          themeProvider: themeProvider,
        ),
      );
    },
  );
}

  // Lesson card with proper theming
  Widget _buildLessonCard({
  required int index,
  required String title,
  required String description,
  required int questionCount,
  required bool isAvailable,
  bool isCompleted = false, // Add this parameter
  required ThemeProvider themeProvider,
}) {
  final theme = themeProvider.currentTheme;

  return Opacity(
    opacity: isAvailable ? 1.0 : 0.7,
    child: Stack(
      children: [
        // The main card
        Card(
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.3),
          color: theme.primaryColor.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isCompleted ? Colors.green : theme.accentColor, 
              width: isCompleted ? 2 : 1
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : theme.accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.quiz,
                          color: theme.buttonTextColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: themeProvider.getRealFontSize(16),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description text
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(14),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Question count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$questionCount Questions • Filipino',
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.7),
                        fontSize: themeProvider.getRealFontSize(12),
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Button at bottom - no spacer, fixed distance from elements above
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isAvailable ? () => _startLesson(index) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? Colors.green : theme.accentColor,
                        foregroundColor: theme.buttonTextColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        disabledBackgroundColor: theme.accentColor.withOpacity(0.3),
                      ),
                      child: Text(
                        isCompleted ? 'REVIEW LESSON' : 'SIMULAN ANG PAGTATASA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: themeProvider.getRealFontSize(14),
                          fontFamily: themeProvider.fontFamily,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Completion badge overlay
        if (isCompleted)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: themeProvider.getRealFontSize(10),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

  // Start lesson method with assessment initialization
  void _startLesson(int lessonIndex) {
    // Get the lesson by index
    final lesson = _lessons.firstWhere(
      (l) => l['index'] == lessonIndex,
      orElse: () => {},
    );

    // Only proceed if the lesson is available
    if (lesson.isEmpty || lesson['isAvailable'] != true) {
      print('Lesson $lessonIndex is not available');
      return;
    }

    // Get the assessment ID from the lesson data
    final assessmentId = lesson['assessmentId'];

    if (assessmentId == null) {
      print('No assessmentId found for lesson $lessonIndex');
      return;
    }

    print('Starting lesson $lessonIndex with assessment ID: $assessmentId');

    // Create a new instance of AssessmentProvider
    final assessmentProvider = AssessmentProvider();

    // Navigate to the assessment question screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreAssessmentQuestionScreen(
          assessmentId: assessmentId, // Pass the exact assessmentId from database
          provider: assessmentProvider,
          onAssessmentComplete: (readingLevel, score, total) async {
            // Update the user's reading level
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.currentUser != null) {
              // Update the reading level
              authProvider.updateUserReadingLevel(readingLevel);

              // Mark this lesson as completed using the database service
              final dbService = DatabaseService();
              await dbService.markLessonAsCompleted(
                authProvider.currentUser!.idNumber.toString(),
                lessonIndex,
              );

              // Reload lessons to update availability status
              if (mounted) {
                Future.microtask(() => _loadLessons());
              }
            }
          },
        ),
      ),
    );
  }

  // Helper method to check if a lesson has been completed
Future<bool> _isLessonCompleted(int lessonIndex, String assessmentId) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userId = authProvider.currentUser?.idNumber.toString() ?? '';
  
  if (userId.isEmpty || assessmentId.isEmpty) {
    return false;
  }
  
  try {
    final dbService = DatabaseService();
    if (!dbService.isInitialized) {
      await dbService.initialize();
    }
    
    if (dbService.isConnected) {
      // Check if this assessment is completed by this student
      final isCompleted = await dbService.hasStudentCompletedAssessment(userId, assessmentId);
      
      if (isCompleted) {
        print('Lesson $lessonIndex (Assessment $assessmentId) is already completed by user $userId');
      } else {
        print('Lesson $lessonIndex (Assessment $assessmentId) is not yet completed by user $userId');
      }
      
      return isCompleted;
    }
  } catch (e) {
    print('Error checking lesson completion: $e');
  }
  
  // If we can't check database, fall back to the completedLessons array in the user object
  final completedLessons = authProvider.currentUser?.completedLessons ?? [];
  return completedLessons.contains(lessonIndex) || 
         completedLessons.contains(lessonIndex.toString());
}


  // Get lessons from the database with fallback options
  Future<List<Map<String, dynamic>>> _getFallbackLessonsForLevel(String readingLevel) async {
    print('Getting lessons for reading level: $readingLevel');

    // Base lessons list that will be populated from the database
    final List<Map<String, dynamic>> lessons = [];

    try {
      // Get DatabaseService instance
      final dbService = DatabaseService();

      // Make sure the database is initialized
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Query the database collections
      if (dbService.isConnected) {
        // Get direct access to the main_assessment collection
        final mainAssessmentCollection = dbService.getCollection('main_assessment');

        // Map reading levels to the format used in the database
        String targetReadingLevel;
        switch (readingLevel.toLowerCase()) {
          case 'emergent':
            targetReadingLevel = 'Low Emerging';
            break;
          case 'early':
            targetReadingLevel = 'High Emerging';
            break;
          case 'fluent':
            targetReadingLevel = 'At Grade Level';
            break;
          default:
            targetReadingLevel = readingLevel;
        }

        print('Querying main_assessment for targetReadingLevel: $targetReadingLevel');

        // First try exact match on targetReadingLevel
        var query = where.eq('readingLevel', targetReadingLevel).and(where.eq('isActive', true));
        var assessments = await mainAssessmentCollection.find(query).toList();

        // If no results, try case-insensitive match
        if (assessments.isEmpty) {
          print('No assessments found with exact match, trying case-insensitive match');

          // Using regex for case-insensitive match
          final regex = RegExp(targetReadingLevel, caseSensitive: false);
          query = where.match('readingLevel', regex.pattern).and(where.eq('isActive', true));
          assessments = await mainAssessmentCollection.find(query).toList();
        }

        // If still no results, fetch any active assessments
        if (assessments.isEmpty) {
          print('No matching assessments found, fetching any active assessments');
          query = where.eq('isActive', true);
          assessments = await mainAssessmentCollection.find(query).take(5).toList();
        }

        print('Found ${assessments.length} assessments for level $targetReadingLevel');

        // Get user's completed lessons to determine availability
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userIdNumber = authProvider.currentUser?.idNumber.toString() ?? '';
        final completedLessons = authProvider.currentUser?.completedLessons ?? [];

        print('User $userIdNumber has completed lessons: $completedLessons');

        // Process lessons in order
        int index = 1;
          for (final assessment in assessments) {
            // Check if this specific assessment has been completed
            final String assessmentIdString = assessment['_id'].toString();
            final bool isCompleted = await _isLessonCompleted(index, assessmentIdString);
            
            // First lesson is always available, subsequent lessons require previous completion
            bool isAvailable = index == 1;
            
            if (index > 1) {
              // Check if previous lesson is completed
              isAvailable = completedLessons.contains(index - 1) ||
                          completedLessons.contains((index - 1).toString()) ||
                          await _isLessonCompleted(index - 1, assessments[index - 2]['_id'].toString());
            }
            
            // Extract category from assessment as title component
            final category = assessment['category'] ?? 'Filipino Lesson';
            
            // Debug exact assessment data
            print('Assessment data: ID=${assessment['_id']} | Category=$category | Completed=${isCompleted}');
            
            lessons.add({
              'index': index,
              'title': 'ARALIN $index: $category',
              'description': assessment['questions']?[0]?['questionText'] ?? 
                            'Interactive Filipino reading activities for ${readingLevel.toLowerCase()} readers',
              'questionCount': (assessment['questions'] as List<dynamic>?)?.length ?? 5,
              'isAvailable': isAvailable,
              'isCompleted': isCompleted,  // Add this new flag
              'assessmentId': assessment['_id'].toString(), // Use the ObjectId as string
            });
            
            index++;
          }
      }

      // Log final results
      print('Final lessons list:');
      for (var lesson in lessons) {
        print('Lesson ${lesson['index']}: ${lesson['title']} | AssessmentId: ${lesson['assessmentId']} | Available: ${lesson['isAvailable']}');
      }
    } catch (e) {
      print('Error in _getFallbackLessonsForLevel: $e');
    }

    // If no lessons found, return hardcoded fallback lessons
    return lessons.isNotEmpty ? lessons : _getHardcodedFallbackLessons(readingLevel);
  }

  // Hardcoded fallback lessons as a last resort
  List<Map<String, dynamic>> _getHardcodedFallbackLessons(String readingLevel) {
    print('Using hardcoded fallback lessons for $readingLevel');
    
    // Always available first lesson
    final List<Map<String, dynamic>> lessons = [
      {
        'index': 1,
        'title': 'ARALIN 1: Panimulang Pagbasa',
        'description': 'Learn the basics of Filipino reading with interactive exercises',
        'questionCount': 5,
        'isAvailable': true,
        'assessmentId': 'default_lesson_1',
      },
    ];
    
    // Add specific lessons based on reading level
    if (readingLevel.toLowerCase().contains('emerging') || 
        readingLevel.toLowerCase().contains('emergent')) {
      lessons.addAll([
        {
          'index': 2,
          'title': 'ARALIN 2: Pagkilala sa mga Titik',
          'description': 'Identify and recognize Filipino alphabet letters',
          'questionCount': 5,
          'isAvailable': false,
          'assessmentId': 'default_lesson_2',
        },
      ]);
    } else {
      lessons.addAll([
        {
          'index': 2,
          'title': 'ARALIN 2: Pagbasa ng mga Pantig',
          'description': 'Reading Filipino syllables and simple words',
          'questionCount': 5,
          'isAvailable': false,
          'assessmentId': 'default_lesson_2',
        },
      ]);
    }
    
    return lessons;
  }
    
    
}