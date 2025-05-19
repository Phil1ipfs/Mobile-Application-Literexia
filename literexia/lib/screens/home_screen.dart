// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:provider/provider.dart';
import '../config/router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/logic/auth_provider.dart';

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
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the aralinProvider
      final aralinProvider = Provider.of<AralinProvider>(
        context,
        listen: false,
      );

      // Get the current user's reading level
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final readingLevel =
          authProvider.currentUser?.readingLevel ?? 'Undefined';

      // Load lessons from MongoDB via provider
      await aralinProvider.fetchLessonsForLevel(readingLevel);

      // If lessons are loaded successfully, update the state
      if (aralinProvider.lessons.isNotEmpty) {
        setState(() {
          _lessons = aralinProvider.lessons;
          _isLoading = false;
        });
      } else {
        // If no lessons found, use fallback data
        setState(() {
          _lessons = _getFallbackLessonsForLevel(readingLevel);
          _isLoading = false;
        });
      }
    } catch (e) {
      // If there's an error, use fallback data
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final readingLevel =
          authProvider.currentUser?.readingLevel ?? 'Undefined';

      setState(() {
        _errorMessage =
            "Could not load lessons from database. Using local data.";
        _lessons = _getFallbackLessonsForLevel(readingLevel);
        _isLoading = false;
      });
      print('Error loading lessons: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName =
        authProvider.currentUser?.firstName ??
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
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
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
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
          padding: const EdgeInsets.only(
            bottom: 16.0,
          ), // Increased spacing between items
          child: _buildLessonCard(
            index: lesson['index'] as int,
            title: lesson['title'] as String,
            description:
                lesson['description'] as String? ??
                'Engage with interactive Filipino lessons',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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

  void _startLesson(int lessonIndex) {
    // Navigate to selected lesson
    // This would be replaced with actual navigation code
    print('Starting lesson $lessonIndex');
  }

  // Fallback method for getting lessons if database retrieval fails
  List<Map<String, dynamic>> _getFallbackLessonsForLevel(String readingLevel) {
    // Base lessons that are always available
    final List<Map<String, dynamic>> baseLessons = [
      {
        'index': 1,
        'title': 'ARALIN 1: Panimulang Pagbasa',
        'description':
            'Learn the basics of Filipino reading with interactive exercises',
        'questionCount': 5,
        'isAvailable': true,
      },
    ];

    // Add more lessons based on reading level
    switch (readingLevel.toLowerCase()) {
      case 'emergent':
        // Emergent readers get basic lessons
        baseLessons.addAll([
          {
            'index': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
          {
            'index': 4,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'description': 'Learn animal sounds in Filipino language',
            'questionCount': 6,
            'isAvailable': false,
          },
        ]);
        break;

      case 'early':
        // Early readers get intermediate lessons
        baseLessons.addAll([
          {
            'index': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
          {
            'index': 4,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'description': 'Learn animal sounds in Filipino language',
            'questionCount': 6,
            'isAvailable': true,
          },
          {
            'index': 5,
            'title': 'ARALIN 5: Mga Salitang may Katunog',
            'description': 'Learn words that rhyme in Filipino',
            'questionCount': 7,
            'isAvailable': true,
          },
          {
            'index': 6,
            'title': 'ARALIN 6: Mga Uri ng Pangungusap',
            'description': 'Learn different types of sentences in Filipino',
            'questionCount': 5,
            'isAvailable': false,
          },
        ]);
        break;

      case 'fluent':
        // Fluent readers get advanced lessons
        baseLessons.addAll([
          {
            'index': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': true,
          },
          {
            'index': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': true,
          },
          {
            'index': 4,
            'title': 'ARALIN 4: Mga Huni o Tunog ng mga Hayop',
            'description': 'Learn animal sounds in Filipino language',
            'questionCount': 6,
            'isAvailable': true,
          },
          {
            'index': 5,
            'title': 'ARALIN 5: Mga Salitang may Katunog',
            'description': 'Learn words that rhyme in Filipino',
            'questionCount': 7,
            'isAvailable': true,
          },
          {
            'index': 6,
            'title': 'ARALIN 6: Mga Uri ng Pangungusap',
            'description': 'Learn different types of sentences in Filipino',
            'questionCount': 5,
            'isAvailable': true,
          },
          {
            'index': 7,
            'title': 'ARALIN 7: Pag-unawa sa Binasa',
            'description': 'Comprehension exercises for Filipino texts',
            'questionCount': 4,
            'isAvailable': true,
          },
          {
            'index': 8,
            'title': 'ARALIN 8: Pagsulat ng Maikling Kwento',
            'description': 'Write short stories in Filipino',
            'questionCount': 3,
            'isAvailable': true,
          },
        ]);
        break;

      default:
        // Default lessons for undefined or other levels
        baseLessons.addAll([
          {
            'index': 2,
            'title': 'ARALIN 2: Pagkilala sa mga Titik',
            'description': 'Identify and recognize Filipino alphabet letters',
            'questionCount': 8,
            'isAvailable': false,
          },
          {
            'index': 3,
            'title': 'ARALIN 3: Mga Tunog ng mga Titik',
            'description': 'Learn the sounds of Filipino alphabet letters',
            'questionCount': 10,
            'isAvailable': false,
          },
        ]);
    }

    return baseLessons;
  }

  // Modified header to display reading level
  Widget _buildHeader(String userName, String readingLevel) {
    return Container(
      width: double.infinity,
      height: 70,
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
              const SizedBox(height: 4),
              Text(
                'Reading Level: $readingLevel',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            },
          ),
          _buildNavItem(
            icon: Icons.settings,
            label: 'Setting',
            isSelected: false,
            onTap: () {
              // Navigate to settings
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
