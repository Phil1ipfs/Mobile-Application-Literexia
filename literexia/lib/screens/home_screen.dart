// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import '../config/router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/logic/auth_provider.dart';
import '../screens/settings_screen.dart';
// Include this import at the top of your file (along with other imports)
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection, where;

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
    
    // Get lessons directly from main_assessment collection
    final lessons = await _getFallbackLessonsForLevel(readingLevel);
    
    if (!mounted) return;
    
    // Update state with lessons
    setState(() {
      _lessons = lessons;
      _isLoading = false;
    });
    
    // Update AralinProvider with lessons (without waiting for return)
    // This avoids the setState during build issue
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
    final userName = authProvider.currentUser?.firstName ?? 
                 authProvider.currentUser?.name ?? 
                 'Guest';
    final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';

    return Scaffold(
      backgroundColor: AppTheme.primaryLightBlue,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(userName, readingLevel),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _lessons.isEmpty
                  ? _buildNoLessonsMessage()
                  : _buildLessonGrid(readingLevel),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLessonsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 60,
              color: Colors.amber.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'No lessons found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your teacher has not added any lessons yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonGrid(String readingLevel) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _lessons.length,
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0), // Increased spacing between items
          child: _buildLessonCard(
            index: lesson['index'] as int,
            title: lesson['title'] as String,
            description: lesson['description'] as String? ?? 'Engage with interactive Filipino lessons',
            questionCount: lesson['questionCount'] as int? ?? 5,
            isAvailable: lesson['isAvailable'] as bool,
          ),
        );
      },
    );
  }

  Widget _buildLessonCard({
    required int index,
    required String title,
    required String description,
    required int questionCount,
    required bool isAvailable,
  }) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.7,
      child: Card(
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.3),
        color: AppTheme.lessonPanelBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber.withOpacity(0.3), width: 1),
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
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.quiz,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 16),
                
                // Question count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '$questionCount Questions • Filipino',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
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
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'SIMULAN ANG PAGTATASA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 // Modified _startLesson method to fix the AssessmentProvider issue
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
        assessmentId: assessmentId,  // Pass the exact assessmentId from database
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
              lessonIndex
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

 // Add this final version of _getFallbackLessonsForLevel to your HomeScreen class
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
    
    // Query the test collection's main_assessment documents
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
      var query = where.eq('targetReadingLevel', targetReadingLevel).and(where.eq('status', 'active'));
      var assessments = await mainAssessmentCollection.find(query).toList();
      
      // If no results, try case-insensitive match
      if (assessments.isEmpty) {
        print('No assessments found with exact match, trying case-insensitive match');
        
        // Using regex for case-insensitive match
        final regex = RegExp(targetReadingLevel, caseSensitive: false);
        query = where.match('targetReadingLevel', regex.pattern).and(where.eq('status', 'active'));
        assessments = await mainAssessmentCollection.find(query).toList();
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
        // First lesson is always available, subsequent lessons require previous completion
        bool isAvailable = index == 1;
        
        if (index > 1) {
          // Check if previous lesson is completed
          isAvailable = completedLessons.contains(index - 1) || 
                        completedLessons.contains((index - 1).toString());
        }
        
        // Debug exact assessment data
        print('Assessment data: ID=${assessment['_id']} | AssessmentId=${assessment['assessmentId']} | Title=${assessment['title']}');
        
        lessons.add({
          'index': index,
          'title': assessment['title'] ?? 'No Title',
          'description': assessment['description'] ?? 'No Description',
          'questionCount': assessment['totalQuestions'] ?? 5,
          'isAvailable': isAvailable,
          'assessmentId': assessment['assessmentId'],  // Use exact assessmentId from database
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
  
  // If no lessons found, return empty list - don't use hardcoded fallbacks
  return lessons;
}
    

  // Modified header to display reading level
  Widget _buildHeader(String userName, String readingLevel) {
  return Container(
    width: double.infinity,
    height: 65,
    color: AppTheme.primaryDarkBlue,
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            // Reading level text is removed but the variable is still available in the method
            // We're just not displaying it anymore
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3D4B71),
            borderRadius: BorderRadius.circular(4),
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
  );
}

  Widget _buildBottomNavBar() {
  return Container(
    height: 60,
    color: AppTheme.primaryDarkBlue,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(
          icon: Icons.home,
          label: 'Home',
          isSelected: true,
          onTap: () {},
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
        ),
      ],
    ),
  );
}

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.accentAmber : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.accentAmber : Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

}