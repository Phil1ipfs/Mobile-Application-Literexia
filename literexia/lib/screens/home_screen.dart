// lib/screens/home_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/repositories/assessment_repository.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import 'package:literexia/features/assessments/ui/AlphabetKnowledgeScreen.dart';
import 'package:literexia/features/assessments/ui/PhonologicalMatching.dart';
import 'package:literexia/features/assessments/ui/DecodingScreen.dart';
import 'package:literexia/features/assessments/ui/WordRecognitionScreen.dart';
import 'package:literexia/features/assessments/ui/reading_comprehension_screen.dart';
import 'package:literexia/features/intervention/logic/intervention_provider.dart';
import 'package:literexia/features/intervention/repository/intervention_repository.dart';
import 'package:literexia/features/intervention/ui/intervention_status_widget.dart';
import 'package:literexia/features/intervention/ui/intervention_assessment_screen.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/screens/settings_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/core/theme/app_theme.dart';
import 'package:literexia/services/database_service.dart';
import 'package:literexia/utils/reading_level_utils.dart';
import 'package:literexia/utils/category_results_helper.dart';
import 'package:literexia/services/background_music_service.dart';
import 'package:provider/provider.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection, where;

class HomeScreen extends StatefulWidget {
  final bool forceRefresh;

  const HomeScreen({
    Key? key,
    this.forceRefresh = false,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lessons = [];
  String? _errorMessage;
  int _currentNavIndex = 0;
  String? _userReadingLevel;
  String? _userId;
  List<int> _completedLessons = [];

  // NEW: Add intervention-related state variables
  bool _needsIntervention = false;
  String _interventionReason = '';
  List<String> _failedCategories = [];
  double _overallAverage = 0.0;
  bool _isCheckingIntervention = false;

  // NEW: Category assessment status tracking
  Map<String, String> _categoryStatus = {}; // 'not_taken', 'passed', 'failed'
  Map<String, double> _categoryScores = {};

  // Popup card state management
  int? _selectedLessonIndex;
  bool _isLessonPopupVisible = false;

  // Animation controller for floating speech bubble
  late AnimationController _animationController;

  // Animation controllers for enhanced UI
  late AnimationController _iconAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _iconAnimation;
  late Animation<double> _pulseAnimation;

  // NEW: Animation controllers for sky effects
  late AnimationController _cloudAnimationController;
  late AnimationController _starAnimationController;
  late AnimationController _starTwinkleController;
  late Animation<double> _cloudAnimation;
  late Animation<double> _starAnimation;
  late Animation<double> _starTwinkleAnimation;

  // Function to get time-based greeting in Filipino
  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return 'Magandang Umaga'; // Good Morning (6AM-12PM)
    } else if (hour >= 12 && hour < 18) {
      return 'Magandang Hapon'; // Good Afternoon (12PM-6PM)
    } else {
      return 'Magandang Gabi'; // Good Evening (6PM-6AM)
    }
  }

  // Get current lesson category based on user's actual current lesson/assessment
  String _getCurrentLessonCategory() {
    // If lessons are loaded, get the category from the current/next lesson
    if (_lessons.isNotEmpty) {
      // Find the next available lesson (not completed)
      final nextLesson = _lessons.firstWhere(
        (lesson) => lesson['isCompleted'] != true,
        orElse: () => _lessons.isNotEmpty ? _lessons.first : <String, dynamic>{}, // Fallback to first lesson
      );

      // Extract category from lesson data
      final category = nextLesson['category']?.toString().toUpperCase() ?? '';
      if (category.isNotEmpty) {
        return category;
      }

      // Extract from lesson title if no category field
      final title = nextLesson['title']?.toString().toUpperCase() ?? '';
      if (title.contains('PHONOLOGICAL')) return 'Mag hintay lamang...';
      if (title.contains('LETTER')) return 'LETTER RECOGNITION';
      if (title.contains('WORD')) return 'WORD FORMATION';
      if (title.contains('READING')) return 'READING COMPREHENSION';
      if (title.contains('SYLLABLE')) return 'SYLLABLE AWARENESS';
      if (title.contains('RHYME')) return 'RHYMING SKILLS';
    }

    // Fallback to reading level-based categories if no lesson data
    switch (_userReadingLevel?.toLowerCase()) {
      case 'pre-reader':
      case 'emergent reader':
        return 'Mag hintay lamang...'; // Filipino for "Please wait..."
      case 'beginning reader':
        return 'LETTER RECOGNITION';
      case 'developing reader':
        return 'WORD FORMATION';
      case 'fluent reader':
        return 'READING COMPREHENSION';
      default:
        return 'Mag hintay lamang...'; // Default category
    }
  }

  // Get current task status based on lesson progress
  String _getCurrentTaskStatus() {
    if (_lessons.isEmpty) {
      return 'Naglo-load na gawain...';
    }

    // Check if user needs intervention
    if (_needsIntervention) {
      return 'Kailangan pa ng pag sasanay!';
    }

    // Find next available lesson
    final nextLesson =
        _lessons.where((lesson) => lesson['isCompleted'] != true).toList();

    if (nextLesson.isEmpty) {
      return 'ALL TASKS COMPLETE!';
    }

    return 'Ang Gawain ngayon';
  }

  // Get current lesson title for more specific information
  String _getCurrentLessonTitle() {
    if (_lessons.isEmpty) {
      return 'Please wait while we load your lessons...';
    }

    // Find the next available lesson (not completed)
    final nextLesson = _lessons.firstWhere(
      (lesson) => lesson['isCompleted'] != true,
      orElse: () => _lessons.isNotEmpty ? _lessons.last : <String, dynamic>{}, // If all completed, show last lesson
    );

    final title = nextLesson['title']?.toString() ?? '';
    final lessonNumber = nextLesson['index']?.toString() ?? '';

    if (title.isNotEmpty && lessonNumber.isNotEmpty) {
      return 'Lesson $lessonNumber: $title';
    } else if (title.isNotEmpty) {
      return title;
    } else if (lessonNumber.isNotEmpty) {
      return 'Lesson $lessonNumber';
    }

    return 'Ready to start your next lesson!';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Stop background music when home screen is initialized
    _stopBackgroundMusicOnHomeNavigation();

    // Initialize all animation controllers
    _initializeAnimationControllers();

    // Initialize floating animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // Continuous floating animation

    // Start animations
    _startAnimations();

    // Initialize user data and load lessons
    _initializeUserData();
  }

  void _initializeAnimationControllers() {
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cloudAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _starAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _starTwinkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Initialize all animations
    _iconAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
          parent: _iconAnimationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
          parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    _cloudAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cloudAnimationController, curve: Curves.linear),
    );

    _starAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _starAnimationController, curve: Curves.easeInOut),
    );

    _starTwinkleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _starTwinkleController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _pulseAnimationController.repeat(reverse: true);
    _cloudAnimationController.repeat();
    _starAnimationController.repeat(reverse: true);
    _starTwinkleController.repeat(reverse: true);
  }

  Future<void> _initializeUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get user data from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        print('[HomeScreen] No user found in auth provider');
        setState(() {
          _isLoading = false;
          _errorMessage = 'User session expired';
        });
        return;
      }

      // Store user data
      _userReadingLevel = user.readingLevel;
      _userId = user.idNumber.toString();
      _completedLessons = user.completedLessons ?? [];

      print('[HomeScreen] User initialized:');
      print('[HomeScreen]   - Reading Level: $_userReadingLevel');
      print('[HomeScreen]   - User ID: $_userId');
      print('[HomeScreen]   - Completed Lessons: $_completedLessons');

      // Check if user has completed pre-assessment
      final hasCompletedAssessment = user.preAssessmentCompleted == true ||
          (_userReadingLevel != null && _userReadingLevel!.isNotEmpty);

      // Load lessons for user's reading level
      await _loadLessonsForUserLevel();

      // Check intervention status
      await _checkInterventionStatusEnhanced();
    } catch (e) {
      print('[HomeScreen] Error initializing user data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadLessonsForUserLevel() async {
    if (_userReadingLevel == null || _userId == null) return;

    try {
      print('[HomeScreen] Loading lessons for $_userReadingLevel level');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // CRITICAL: Only get lessons for user's exact reading level
      final loadedLessons = await dbService.getLessonsForLevel(
        _userReadingLevel!,
        userIdNumber: _userId,
        completedLessons: _completedLessons,
      );

      print('[HomeScreen] Loaded ${loadedLessons.length} lessons');

      // Debug: Print all loaded lessons
      for (int i = 0; i < loadedLessons.length; i++) {
        final lesson = loadedLessons[i];
        print(
            '[HomeScreen] Loaded lesson $i: ${lesson['category']} - Available: ${lesson['isAvailable']}');
      }

      // Sort lessons by category in the correct order
      final sortedLessons = _sortLessonsByCategory(loadedLessons);

      // Ensure all lessons are available (fallback)
      for (var lesson in sortedLessons) {
        lesson['isAvailable'] = true;
        print(
            '[HomeScreen] Force setting lesson ${lesson['category']} as available');
      }

      if (mounted) {
        setState(() {
          _lessons = sortedLessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[HomeScreen] Error loading lessons: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // NEW: Helper method to determine if it's day or night
  bool _isDaytime() {
    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 18; // 6AM-6PM is daytime
  }

  // NEW: Build cloud effects for daytime
  Widget _buildCloudEffects() {
    return AnimatedBuilder(
        animation: _cloudAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Cloud 1
              Positioned(
                top: 10,
                left: -50 +
                    (_cloudAnimation.value *
                        (MediaQuery.of(context).size.width + 100)),
                child: _buildCloud(30, Colors.white.withOpacity(0.3)),
              ),
              // Cloud 2 (slower, different position)
              Positioned(
                top: 25,
                left: -80 +
                    ((_cloudAnimation.value * 0.7) *
                        (MediaQuery.of(context).size.width + 160)),
                child: _buildCloud(40, Colors.white.withOpacity(0.2)),
              ),
              // Cloud 3
              Positioned(
                top: 5,
                left: -60 +
                    ((_cloudAnimation.value * 1.3) *
                        (MediaQuery.of(context).size.width + 120)),
                child: _buildCloud(25, Colors.white.withOpacity(0.25)),
              ),
            ],
          );
        });
  }

  // NEW: Build individual cloud shape
  Widget _buildCloud(double size, Color color) {
    return Container(
      width: size * 2,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
      ),
      child: Row(
        children: [
          Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.6),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(size * 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Build milky way effects for nighttime
  Widget _buildMilkyWayEffects() {
    return AnimatedBuilder(
        animation: _starAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Milky way gradient background
              Container(
                width: double.infinity,
                height: 65,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.withOpacity(0.1),
                      Colors.blue.withOpacity(0.05),
                      Colors.purple.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              // Stars
              ..._generateStars(),
            ],
          );
        });
  }

  // NEW: Generate star positions for milky way
  List<Widget> _generateStars() {
    final stars = <Widget>[];
    final random = math.Random(42); // Fixed seed for consistent positions

    // Generate more stars for a denser milky way effect
    for (int i = 0; i < 35; i++) {
      final left =
          math.Random(42).nextDouble() * MediaQuery.of(context).size.width;
      final top =
          math.Random(42).nextDouble() * 60; // Slightly increased height range
      final size = 0.8 +
          math.Random(42).nextDouble() * 2.5; // More variety in star sizes
      final opacity = 0.2 + math.Random(42).nextDouble() * 0.8;
      final useTwinkle =
          math.Random(42).nextBool(); // Randomly choose which animation to use

      // Create different star colors for more realism
      Color starColor = Colors.white;
      if (math.Random(42).nextDouble() > 0.8) {
        // 20% chance for colored stars
        starColor = [
          Colors.blue.shade100,
          Colors.yellow.shade100,
          Colors.red.shade100,
        ][math.Random(42).nextInt(3)];
      }

      stars.add(
        Positioned(
            left: left,
            top: top,
            child: AnimatedBuilder(
                animation: useTwinkle ? _starTwinkleAnimation : _starAnimation,
                builder: (context, child) {
                  final animValue = useTwinkle
                      ? _starTwinkleAnimation.value
                      : _starAnimation.value;
                  return Opacity(
                    opacity: opacity * animValue,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * animValue), // Subtle scaling effect
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: starColor,
                          borderRadius: BorderRadius.circular(size / 2),
                          boxShadow: [
                            BoxShadow(
                              color: starColor.withOpacity(0.6 * animValue),
                              blurRadius: size > 2.0 ? 4 : 2,
                              spreadRadius: size > 2.0 ? 1.5 : 0.8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })),
      );
    }

    // Add some extra tiny sparkle dots for more density
    for (int i = 0; i < 25; i++) {
      final left =
          math.Random(42).nextDouble() * MediaQuery.of(context).size.width;
      final top = math.Random(42).nextDouble() * 55;
      final opacity = 0.1 + math.Random(42).nextDouble() * 0.4;
      final useTwinkle = math.Random(42).nextBool();

      stars.add(
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: useTwinkle ? _starTwinkleAnimation : _starAnimation,
            builder: (context, child) {
              final animValue = useTwinkle
                  ? _starTwinkleAnimation.value
                  : _starAnimation.value;
              return Opacity(
                opacity: opacity * animValue,
                child: Container(
                  width: 0.5 + (0.3 * animValue), // Tiny size variation
                  height: 0.5 + (0.3 * animValue),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3 * animValue),
                        blurRadius: 1,
                        spreadRadius: 0.2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Add some medium-sized constellation stars
    for (int i = 0; i < 8; i++) {
      final left =
          math.Random(42).nextDouble() * MediaQuery.of(context).size.width;
      final top = math.Random(42).nextDouble() * 50;
      final size = 2.5 + math.Random(42).nextDouble() * 1.5;
      final opacity = 0.4 + math.Random(42).nextDouble() * 0.6;

      stars.add(
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: _starAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: opacity * _starAnimation.value,
                child: Transform.scale(
                  scale: 0.9 + (0.1 * _starAnimation.value),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(size / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return stars;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceRefresh && !oldWidget.forceRefresh) {
      print(
          '[HomeScreen] Force refresh flag detected, performing comprehensive refresh (equivalent to hot restart)');
      _performHotRestartEquivalent();
    }
  }

  // Add this method to force refresh intervention status when returning to home
  void _refreshInterventionStatus() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final interventionProvider =
        Provider.of<InterventionProvider>(context, listen: false);

    final userId = authProvider.currentUser?.idNumber.toString() ?? '';
    if (userId.isNotEmpty) {
      interventionProvider.checkInterventionStatus(userId);
    }
  }

  // Comprehensive refresh method equivalent to hot restart
  Future<void> _performHotRestartEquivalent() async {
    print(
        '[HomeScreen] Starting comprehensive refresh (hot restart equivalent)');

    if (!mounted) return;

    try {
      // Stop background music when navigating to home screen
      await _stopBackgroundMusicOnHomeNavigation();

      // Reset all state variables to initial values
      setState(() {
        _isLoading = true;
        _lessons = [];
        _errorMessage = null;
        _currentNavIndex = 0;
        _userReadingLevel = null;
        _userId = null;
        _completedLessons = [];
        _needsIntervention = false;
        _interventionReason = '';
        _failedCategories = [];
        _overallAverage = 0.0;
        _isCheckingIntervention = false;
        _categoryStatus = {};
        _categoryScores = {};
        _selectedLessonIndex = null;
        _isLessonPopupVisible = false;
      });

      // Reset animation controllers
      _animationController.reset();
      _iconAnimationController.reset();
      _pulseAnimationController.reset();
      _cloudAnimationController.reset();
      _starAnimationController.reset();
      _starTwinkleController.reset();

      // Restart animations
      _animationController.repeat();
      _iconAnimationController.repeat(reverse: true);
      _pulseAnimationController.repeat();
      _cloudAnimationController.repeat();
      _starAnimationController.repeat();
      _starTwinkleController.repeat(reverse: true);

      // Force refresh all providers and data
      await _loadLessons();
      _refreshInterventionStatus();

      print('[HomeScreen] Comprehensive refresh completed successfully');
    } catch (e) {
      print('[HomeScreen] Error during comprehensive refresh: $e');
      // Fallback to basic refresh
      _loadLessons();
      _refreshInterventionStatus();
    }
  }

  // Method to stop background music when navigating to home screen
  Future<void> _stopBackgroundMusicOnHomeNavigation() async {
    try {
      if (BackgroundMusicService.isPlaying) {
        await BackgroundMusicService.stopBackgroundMusic();
        print(
            '[HomeScreen] Background music stopped on home screen navigation');
      }
    } catch (e) {
      print(
          '[HomeScreen] Error stopping background music on home navigation: $e');
    }
  }

  // Replace the existing _loadLessons() method in home_screen.dart
  Future<void> _loadLessons() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isCheckingIntervention = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        print('[HomeScreen] No user found in auth provider');
        setState(() {
          _isLoading = false;
          _errorMessage = 'User session expired';
        });
        return;
      }

      // Check if user has completed pre-assessment
      final hasCompletedAssessment = user.preAssessmentCompleted == true ||
          (user.readingLevel != null && user.readingLevel!.isNotEmpty);

      if (!hasCompletedAssessment) {
        print(
            '[HomeScreen] User has not completed pre-assessment, redirecting...');
        return;
      }

      // Load lessons with enhanced completion checking
      final readingLevel = user.readingLevel ?? 'Undefined';
      final userId = user.idNumber.toString();
      print(
          '[HomeScreen] Loading lessons for user $userId with reading level: $readingLevel');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final lessons = await dbService.getLessonsForLevel(
        readingLevel,
        userIdNumber: userId,
      );

      print(
          '[HomeScreen] Found ${lessons.length} lessons for reading level: $readingLevel');

      // Enhanced completion status checking with progress loading
      List<Map<String, dynamic>> updatedLessons = [];

      if (lessons.isNotEmpty) {
        for (var lesson in lessons) {
          if (lesson.containsKey('index')) {
            final lessonIndex = lesson['index'];
            final category = lesson['category'] ?? '';

            // Enhanced completion check using multiple methods
            bool isCompleted = await _checkLessonCompletionEnhanced(
                userId, lessonIndex, category);

            // Update availability based on completion of previous lessons
            bool isAvailable =
                _determineLessonAvailability(lessonIndex, updatedLessons);

            // Load progress data for lessons that are available (whether completed or not)
            Map<String, dynamic>? progressData;
            if (isAvailable) {
              progressData =
                  await dbService.getLessonProgress(userId, lessonIndex);
            }

            lesson['isCompleted'] = isCompleted;
            lesson['isAvailable'] = isAvailable;
            lesson['progress'] = progressData;

            print(
                '[HomeScreen] Lesson $lessonIndex ($category): Completed=$isCompleted, Available=$isAvailable, Progress=${progressData?['progressPercentage'] ?? 0}%');

            // Additional debug for Phonological Awareness
            if (category == 'Phonological Awareness') {
              print(
                  '[HomeScreen] PHONOLOGICAL AWARENESS DEBUG: isAvailable=$isAvailable, lesson data: $lesson');
            }
          }
          updatedLessons.add(lesson);
        }
      }

      // Check intervention status
      await _checkInterventionStatusEnhanced();

      if (mounted) {
        setState(() {
          _lessons = updatedLessons;
          _isLoading = false;
          _isCheckingIntervention = false;
        });
        print('[HomeScreen] Lessons loaded and intervention status checked');
      }
    } catch (e) {
      print('[HomeScreen] Error loading lessons: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingIntervention = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // Updated _getFallbackLessonsForLevel to respect reading level filtering
  Future<List<Map<String, dynamic>>> _getFallbackLessonsForLevel(
    String readingLevel, {
    String? userIdNumber,
    List<int>? completedLessons,
  }) async {
    print('[HomeScreen] Getting lessons for reading level: $readingLevel');

    try {
      // Get DatabaseService instance
      final dbService = DatabaseService();

      // Make sure the database is initialized
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Query the database for lessons specific to this reading level
      if (dbService.isConnected) {
        print(
            '[HomeScreen] Querying database for reading level: $readingLevel');

        // Use the updated method that strictly filters by reading level
        final dbLessons = await dbService.getLessonsForLevel(
          readingLevel,
          userIdNumber: userIdNumber,
          completedLessons: completedLessons,
        );

        if (dbLessons.isNotEmpty) {
          print(
              '[HomeScreen] Found ${dbLessons.length} lessons from database for level: $readingLevel');
          return dbLessons;
        } else {
          print(
              '[HomeScreen] No lessons found in database for reading level: $readingLevel');
          // Do NOT fallback to hardcoded lessons from other levels
          return [];
        }
      }

      print('[HomeScreen] Database not connected, cannot load lessons.');
      return [];
    } catch (e) {
      print('[HomeScreen] Error in _getFallbackLessonsForLevel: $e');
      return [];
    }
  }

  // Sort lessons by category in the correct order
  List<Map<String, dynamic>> _sortLessonsByCategory(
      List<Map<String, dynamic>> lessons) {
    // Define the correct order
    final categoryOrder = [
      'Alphabet Knowledge',
      'Phonological Awareness',
      'Decoding',
      'Word Recognition',
      'Reading Comprehension',
    ];

    // Sort lessons based on category order
    lessons.sort((a, b) {
      final categoryA = a['category']?.toString() ?? '';
      final categoryB = b['category']?.toString() ?? '';

      final indexA = categoryOrder.indexOf(categoryA);
      final indexB = categoryOrder.indexOf(categoryB);

      // If category not found in order, put it at the end
      if (indexA == -1 && indexB == -1) return 0;
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;

      return indexA.compareTo(indexB);
    });

    return lessons;
  }

  // Build lesson popup card with triangle connector
  Widget _buildLessonPopupCard(
      Map<String, dynamic> lesson, ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    final rawLessonTitle = lesson['title']?.toString() ?? 'Please wait...';

    // Extract just the category name from the lesson title
    // If title contains "ARALIN X: Category Name", extract just "Category Name"
    String lessonTitle;
    if (rawLessonTitle.contains('ARALIN') && rawLessonTitle.contains(':')) {
      final parts = rawLessonTitle.split(':');
      if (parts.length > 1) {
        lessonTitle = parts[1].trim();
      } else {
        lessonTitle = rawLessonTitle;
      }
    } else {
      lessonTitle = rawLessonTitle;
    }

    // Calculate correct lesson number based on category order
    final category = lesson['category']?.toString() ?? '';
    final categoryOrder = [
      'Alphabet Knowledge',
      'Phonological Awareness',
      'Decoding',
      'Word Recognition',
      'Reading Comprehension',
    ];
    final correctLessonNumber = categoryOrder.indexOf(category) + 1;
    final lessonNumber =
        correctLessonNumber > 0 ? correctLessonNumber.toString() : '1';

    // Debug logging for lesson number calculation
    print(
        '[HomeScreen] Popup for $category: Database index=${lesson['index']}, Correct lesson number=$lessonNumber');

    final isCompleted = lesson['isCompleted'] == true;
    final progress = lesson['progress'] as Map<String, dynamic>?;
    final hasProgress =
        progress != null && (progress['progressPercentage'] ?? 0) > 0;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Triangle connector pointing up
              CustomPaint(
                size: const Size(20, 10),
                painter: TrianglePainter(color: Colors.grey[800]!),
              ),
              // Main popup card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e2846).withOpacity(0.95),
                  border: Border.all(color: const Color(0xFFFFC107), width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      lessonTitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFFC107),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        height: 1.3,
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Subtitle
                    Text(
                      'ARALIN $lessonNumber: $lessonTitle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Question
                    Text(
                      'Ready to start this assessment?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Start Button
                    Container(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {
                          _hideLessonPopup();
                          _startLesson(int.parse(lessonNumber));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'SIMULAN',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontFamily: themeProvider.fontFamily,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Cancel Button
                    Container(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          _hideLessonPopup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Kanselahin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: themeProvider.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build category selection buttons
  Widget _buildCategoryButtons(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    final categories = [
      {
        'name': 'Alphabet Knowledge',
        'icon': Icons.abc,
        'color': const Color(0xFF4CAF50),
      },
      {
        'name': 'Phonological Awareness',
        'icon': Icons.record_voice_over,
        'color': const Color(0xFF2196F3),
      },
      {
        'name': 'Decoding',
        'icon': Icons.spellcheck,
        'color': const Color(0xFFFF9800),
      },
      {
        'name': 'Word Recognition',
        'icon': Icons.visibility,
        'color': const Color(0xFF9C27B0),
      },
      {
        'name': 'Reading Comprehension',
        'icon': Icons.menu_book,
        'color': const Color(0xFFF44336),
      },
    ];

    return Column(
      children: categories.map((category) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _hideLessonPopup();
                _startCategoryLesson(category['name'] as String);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: (category['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (category['color'] as Color).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      color: category['color'] as Color,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        category['name'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: themeProvider.getRealFontSize(14),
                          fontWeight: FontWeight.w500,
                          fontFamily: themeProvider.fontFamily,
                          letterSpacing: themeProvider.getRealLetterSpacing(),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: (category['color'] as Color).withOpacity(0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Start lesson for specific category
  void _startCategoryLesson(String category) {
    print('[HomeScreen] Starting lesson for category: $category');

    // Get the lesson by category
    final lesson = _lessons.firstWhere(
      (l) => l['category'] == category,
      orElse: () => <String, dynamic>{},
    );

    if (lesson.isEmpty) {
      print('[HomeScreen] No lesson found for category: $category');
      return;
    }

    final lessonIndex = lesson['index'] as int?;
    if (lessonIndex != null) {
      _startLesson(lessonIndex);
    }
  }

  // Enhanced loading state with animations
  Widget _buildLoadingState(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading circle
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 6.28, // 2π radians = full rotation
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.accentColor.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.accentColor),
                    strokeWidth: 3,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            'Kinukuha ang mga aralin...',
            style: TextStyle(
              color: theme.textColor,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.w500,
              fontFamily: themeProvider.fontFamily,
              letterSpacing: themeProvider.getRealLetterSpacing(),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Sandali lang po...',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.6),
              fontSize: themeProvider.getRealFontSize(14),
              fontFamily: themeProvider.fontFamily,
              letterSpacing: themeProvider.getRealLetterSpacing(),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced error state with helpful information
  Widget _buildErrorState(String errorMessage, ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    // Check if the error message indicates no assessments
    final bool isNoAssessments =
        errorMessage.contains("No lessons available") ||
            errorMessage.contains("No assessments assigned");

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (0.5 * value),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isNoAssessments
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNoAssessments
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isNoAssessments
                          ? Icons.book_outlined
                          : Icons.wifi_off_rounded,
                      size: 60,
                      color: isNoAssessments
                          ? Colors.orange.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Message container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isNoAssessments
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNoAssessments
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isNoAssessments
                        ? 'Walang Naka-assign na Aralin'
                        : 'May Problema sa Koneksyon',
                    style: TextStyle(
                      color: isNoAssessments
                          ? Colors.orange.shade300
                          : Colors.red.shade300,
                      fontSize: themeProvider.getRealFontSize(20),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isNoAssessments
                        ? 'Wala pang naka-assign na aralin para sa inyo ngayon. Makipag-ugnayan sa inyong guro para sa mga susunod na aralin.'
                        : 'Hindi makuha ang mga aralin sa ngayon. Pakisubukan ulit.',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(16),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage.isNotEmpty && !isNoAssessments) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Detalye: $errorMessage',
                      style: TextStyle(
                        color: theme.textColor.withOpacity(0.6),
                        fontSize: themeProvider.getRealFontSize(12),
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Retry button
            ElevatedButton.icon(
              onPressed: () {
                _loadLessons();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.name == 'Blue'
                    ? const Color(0xFF4CAF50)
                    : theme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              icon: Icon(
                Icons.refresh,
                size: 20,
              ),
              label: Text(
                'Subukan Muli',
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                  letterSpacing: themeProvider.getRealLetterSpacing(),
                ),
              ),
            ),

            if (!isNoAssessments) ...[
              const SizedBox(height: 24),

              // Help section - only show for connection errors
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Colors.blue.shade300,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mga Paraan para Makakonekta:',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: themeProvider.getRealFontSize(14),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpItem('📶 Tingnan kung may signal ang wifi', theme,
                        themeProvider),
                    const SizedBox(height: 6),
                    _buildHelpItem('🔌 I-restart ang router o modem', theme,
                        themeProvider),
                    const SizedBox(height: 6),
                    _buildHelpItem('👩‍🏫 Tanungin ang guro kung may problema',
                        theme, themeProvider),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method for help items
  Widget _buildHelpItem(
      String text, AppThemeData theme, ThemeProvider themeProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(top: 8, right: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textColor.withOpacity(0.8),
              fontSize: themeProvider.getRealFontSize(12),
              fontFamily: themeProvider.fontFamily,
              letterSpacing: themeProvider.getRealLetterSpacing(),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // Handle navigation item taps with animation
  void _onNavItemTapped(int index, VoidCallback onTap) {
    if (_currentNavIndex != index) {
      setState(() {
        _currentNavIndex = index;
      });
      onTap();
    }
  }

  // MODIFIED: Updated build method with enhanced header
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    final userName = authProvider.currentUser?.firstName ??
        authProvider.currentUser?.name ??
        'Guest';

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header Section
            Container(
              margin: const EdgeInsets.all(16),
              child: GestureDetector(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _needsIntervention
                        ? const Color(0xFFC60003) // Red for intervention needed
                        : const Color.fromARGB(
                            255, 6, 194, 19), // Default green
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _needsIntervention
                            ? const Color.fromARGB(199, 198, 0,
                                3) // Darker red shadow for intervention
                            : const Color.fromARGB(
                                197, 0, 225, 15), // Default green shadow
                        blurRadius: _needsIntervention ? 0 : 0,
                        offset: const Offset(0, 5),
                        spreadRadius: _needsIntervention ? 0 : 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TASK! text - prominent display
                            Text(
                              _getCurrentTaskStatus(),
                              style: TextStyle(
                                color: _needsIntervention
                                    ? Colors
                                        .white // Red for intervention needed
                                    : Colors.white, // Default dark blue
                                fontSize: themeProvider.getRealFontSize(20),
                                fontWeight: FontWeight.w900,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Current lesson category
                            Text(
                              _getCurrentLessonCategory(),
                              style: TextStyle(
                                color: _needsIntervention
                                    ? Colors.white.withOpacity(
                                        0.9) // White for intervention needed
                                    : Colors.white, // Default dark blue
                                fontSize: themeProvider.getRealFontSize(14),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing:
                                    themeProvider.getRealLetterSpacing(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right side - Book icon (clickable for help)
                      GestureDetector(
                        onTap: _showHelpDialog,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.menu_book,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshHomeScreen,
                child: Stack(
                  children: [
                    // Main content - scrollable
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: <Widget>[
                          // Content area
                          _isLoading
                              ? Container(
                                  height:
                                      MediaQuery.of(context).size.height - 300,
                                  child: _buildLoadingState(themeProvider))
                              : _errorMessage != null
                                  ? Container(
                                      height:
                                          MediaQuery.of(context).size.height -
                                              300,
                                      child: _buildErrorState(
                                          _errorMessage!, themeProvider))
                                  : _lessons.isEmpty
                                      ? Container(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height -
                                              300,
                                          child: _buildNoLessonsMessage(
                                              themeProvider))
                                      : Column(
                                          children: <Widget>[
                                            InterventionStatusWidget(
                                              onTap: () async {
                                                final result = await Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const InterventionAssessmentScreen(),
                                                  ),
                                                );
                                                
                                                // If intervention was completed, refresh the home screen
                                                if (result == true) {
                                                  print('[HomeScreen] Intervention completed - refreshing home screen');
                                                  await _refreshHomeScreen();
                                                }
                                              },
                                              showProgress: true,
                                            ),
                                            _buildCircularLessonProgress(
                                                themeProvider),
                                          ],
                                        ),
                          // Add bottom padding to prevent content from being hidden behind nav bar
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),

                    // Popup overlay
                    if (_isLessonPopupVisible && _selectedLessonIndex != null)
                      GestureDetector(
                        onTap: _hideLessonPopup,
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: GestureDetector(
                            onTap:
                                () {}, // Prevent tap from bubbling to background
                            child: _buildLessonPopupCard(
                              _lessons.firstWhere(
                                (lesson) =>
                                    lesson['index'] == _selectedLessonIndex,
                                orElse: () => <String, dynamic>{
                                  'index': _selectedLessonIndex,
                                  'title': 'Please wait..'
                                },
                              ),
                              themeProvider,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Fixed Bottom Navigation Bar
            Container(
              margin: const EdgeInsets.all(16),
              child: Container(
                height: 75,
                decoration: BoxDecoration(
                  color: theme.name == 'Blue'
                      ? const Color(0xFF354469)
                      : theme.headerColor,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: theme.accentColor.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: theme.accentColor.withOpacity(0.12),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _buildEnhancedNavItemWithImage(
                        imagePath: 'assets/images/icons8-igloo-64.png',
                        label: 'Home',
                        index: 0,
                        isSelected: _currentNavIndex == 0,
                        onTap: () => _onNavItemTapped(0, () {}),
                        themeProvider: themeProvider,
                      ),
                      _buildEnhancedNavItemWithImage(
                        imagePath: 'assets/images/student.png',
                        label: 'Profile',
                        index: 1,
                        isSelected: _currentNavIndex == 1,
                        onTap: () => _onNavItemTapped(1, () {
                          Navigator.of(context)
                              .push(
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          )
                              .then((_) {
                            setState(() {
                              _currentNavIndex = 0;
                            });
                          });
                        }),
                        themeProvider: themeProvider,
                      ),
                      _buildEnhancedNavItemWithImage(
                        imagePath: 'assets/images/settingss.png',
                        label: 'Settings',
                        index: 2,
                        isSelected: _currentNavIndex == 2,
                        onTap: () => _onNavItemTapped(2, () {
                          Navigator.of(context)
                              .push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          )
                              .then((_) {
                            setState(() {
                              _currentNavIndex = 0;
                            });
                          });
                        }),
                        themeProvider: themeProvider,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Build circular lesson progress design like in your images
  Widget _buildCircularLessonProgress(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Build lesson progress circles
          ..._buildLessonCircles(themeProvider),
        ],
      ),
    );
  }

  // NEW: Build individual lesson circles with connections
  List<Widget> _buildLessonCircles(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    List<Widget> circles = [];

    for (int i = 0; i < _lessons.length; i++) {
      final lesson = _lessons[i];
      final isCompleted = lesson['isCompleted'] ?? false;
      final isAvailable = lesson['isAvailable'] ?? false;
      final category = lesson['category'] ?? '';
      final title = lesson['title'] ?? 'Lesson ${i + 1}';

      // Debug logging for lesson availability
      print(
          '[HomeScreen] Lesson $i: Category=$category, Available=$isAvailable, Completed=$isCompleted');

      // Add spacing between lessons - reduced since connection lines are removed
      if (i > 0) {
        circles.add(const SizedBox(
            height: 40)); // Reduced spacing to move circles higher
      }

      // Add lesson circle with animation in subtle zigzag pattern
      circles.add(
        Align(
          alignment: i % 2 == 0
              ? Alignment(-0.3, 0) // Slightly left
              : Alignment(0.3, 0), // Slightly right
          child: _buildLessonCircle(
            lesson: lesson,
            isCompleted: isCompleted,
            isAvailable: isAvailable,
            category: category,
            title: title,
            themeProvider: themeProvider,
            lessonIndex: i,
          ),
        ),
      );

      // Connection lines removed for cleaner look
    }

    return circles;
  }

  // FIXED: Build individual lesson circle with progress support
  Widget _buildLessonCircle({
    required Map<String, dynamic> lesson,
    required bool isCompleted,
    required bool isAvailable,
    required String category,
    required String title,
    required ThemeProvider themeProvider,
    required int lessonIndex,
  }) {
    final theme = themeProvider.currentTheme;

    // Determine circle colors and state based on CATEGORY ASSESSMENT STATUS
    Color circleColor;
    Color iconColor;
    IconData iconData;
    bool showCheckmark = false;
    double progressPercentage = 0.0;
    bool isTrophyLesson =
        lessonIndex == 3; // 4th lesson (0-indexed) - making it the last lesson
    bool isClickable = true;

    // Get category assessment status
    final categoryStatus = _getCategoryStatus(category);
    final categoryScore = _getCategoryScore(category);
    final isLocked = _isCategoryLocked(category);

    // Debug print
    print(
        '[HomeScreen] Lesson $lessonIndex ($category): Status=$categoryStatus, Score=$categoryScore%, Locked=$isLocked');

    if (isLocked) {
      // GRAY CIRCLE WITH LOCK - Category is locked
      circleColor = Colors.grey;
      iconColor = Colors.white;
      iconData = Icons.lock;
      showCheckmark = false;
      isClickable = false;
      print('[HomeScreen] Category $category is LOCKED');
    } else if (categoryStatus == 'failed') {
      // RED CIRCLE WITH X - Category failed, needs intervention
      circleColor = const Color(0xFFC60003); // Red color from guide
      iconColor = Colors.white;
      iconData = Icons.close; // X icon
      showCheckmark = false;
      isClickable = true; // Can click to access intervention
      print(
          '[HomeScreen] Category $category FAILED (${categoryScore}%) - RED CIRCLE');
    } else if (categoryStatus == 'passed') {
      // GREEN CIRCLE WITH STAR - Category passed
      circleColor = const Color(0xFF4CAF50); // Green color
      iconColor = Colors.white;
      iconData = Icons.star; // Star icon
      showCheckmark = true;
      progressPercentage = 100.0;
      isClickable = false; // Passed circles are not clickable
      print(
          '[HomeScreen] Category $category PASSED (${categoryScore}%) - GREEN CIRCLE (NON-CLICKABLE)');
    } else if (categoryStatus == 'not_taken') {
      // YELLOW CIRCLE WITH STAR - Category not taken yet
      circleColor = const Color(0xFFFFCC00); // Updated yellow color
      iconColor = Colors.white;
      iconData = Icons.star;
      showCheckmark = false;
      isClickable = true;
      print('[HomeScreen] Category $category NOT TAKEN - YELLOW CIRCLE');
    } else {
      // Fallback to original logic for trophy lesson
      if (isTrophyLesson) {
        circleColor = const Color(0xFF00E10F);
        iconColor = const Color(0xFF8B4513);
        iconData = Icons.emoji_events;
        showCheckmark = false;
        isClickable = isAvailable;
      } else {
        // Default behavior
        circleColor = isAvailable ? const Color(0xFF00E10F) : Colors.grey;
        iconColor = Colors.white;
        iconData = isCompleted ? Icons.check : Icons.star;
        showCheckmark = isCompleted;
        isClickable = isAvailable;
      }
    }

    return Column(
      children: [
        // Main circle with tap interaction and progress indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Circle and progress ring
            GestureDetector(
              onTap: isClickable
                  ? () {
                      print(
                          '[HomeScreen] Tapping lesson $lessonIndex ($category)');
                      print(
                          '[HomeScreen] Status: $categoryStatus, Clickable: $isClickable');

                      if (categoryStatus == 'failed') {
                        // Navigate to intervention assessment
                        print(
                            '[HomeScreen] Category failed - navigating to intervention');
                        _handleCategoryInterventionTap(category);
                      } else if (!isLocked) {
                        // Normal lesson popup
                        _showLessonPopup(lesson['index'] ?? lessonIndex + 1);
                      }
                    }
                  : () {
                      print(
                          '[HomeScreen] Category $category is LOCKED or not clickable');
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: progressPercentage > 0 && progressPercentage < 100
                    ? 150
                    : 130,
                height: progressPercentage > 0 && progressPercentage < 100
                    ? 150
                    : 130,
                child: Stack(
                  alignment: Alignment.center, // Center everything
                  children: [
                    // Duolingo-style progress ring (properly centered)
                    if (progressPercentage > 0 && progressPercentage < 100)
                      Positioned(
                        top: 20, // Give proper spacing from top
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: CircularProgressIndicator(
                            value: progressPercentage / 100.0,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF00E10F), // Green for in-progress
                            ),
                          ),
                        ),
                      ),
                    // Duolingo-inspired circle design (properly centered)
                    Positioned(
                      top: progressPercentage > 0 && progressPercentage < 100
                          ? 26 // Centered within the progress ring
                          : 15, // Centered when no progress ring
                      child: Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              circleColor, // Use dynamic color based on lesson state
                          boxShadow: categoryStatus == 'not_taken' && !isLocked
                              ? const [
                                  BoxShadow(
                                    color: Color.fromARGB(197, 255, 204, 0),
                                    blurRadius: 0,
                                    spreadRadius: 0,
                                    offset: Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: showCheckmark
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Background circle for better contrast
                                    Container(
                                      width: 65,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    // Main checkmark icon
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 55,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.5),
                                          offset: const Offset(0, 2),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    iconData,
                                    color: Colors.white,
                                    size: 50,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20), // Adjusted spacing below circle

        // Category badge with completion status
        if (category.isNotEmpty)
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : theme.name == 'Blue'
                          ? Colors.white.withOpacity(0.15)
                          : theme.name == 'White'
                              ? const Color(0xFF2F2F2F).withOpacity(0.1)
                              : theme.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFF4CAF50)
                        : theme.name == 'Blue'
                            ? Colors.white.withOpacity(0.3)
                            : theme.name == 'White'
                                ? const Color(0xFF757575).withOpacity(0.3)
                                : theme.accentColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        color: isCompleted
                            ? const Color(0xFF4CAF50)
                            : theme.name == 'Blue'
                                ? Colors.white
                                : theme.name == 'White'
                                    ? const Color(0xFF757575)
                                    : theme.accentColor,
                        fontSize: themeProvider.getRealFontSize(10),
                        fontWeight: FontWeight.w500,
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check,
                        color: const Color(0xFF4CAF50),
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'COMPLETED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: themeProvider.getRealFontSize(8),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

        const SizedBox(height: 20), // Increased spacing before button

        // Floating button removed - categories are now shown in popup
      ],
    );
  }

  // Refined nav item builder with subtle selection states
  Widget _buildEnhancedNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    final theme = themeProvider.currentTheme;

    // Use white colors for Blue theme, otherwise use accent color
    final Color selectedColor =
        theme.name == 'Blue' ? Colors.white : theme.accentColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          splashColor: theme.name == 'White'
              ? const Color(0xFF2F2F2F).withOpacity(0.1)
              : Colors.white.withOpacity(0.1),
          highlightColor: theme.name == 'White'
              ? const Color(0xFF2F2F2F).withOpacity(0.05)
              : Colors.white.withOpacity(0.05),
          child: Container(
            height: 75,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: AnimatedBuilder(
                    animation: _iconAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSelected ? 1.1 : 1.0,
                        child: Icon(
                          icon,
                          color: isSelected
                              ? selectedColor
                              : theme.textColor.withOpacity(0.65),
                          size: 26,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Label with smooth transition
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: isSelected
                        ? selectedColor
                        : theme.textColor.withOpacity(0.65),
                    fontSize: themeProvider.getRealFontSize(12),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: themeProvider.getRealLetterSpacing(),
                  ),
                  child: Text(label),
                ),

                const SizedBox(height: 6),

                // Subtle underline indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 24 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Nav item builder with custom image icons
  Widget _buildEnhancedNavItemWithImage({
    required String imagePath,
    required String label,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    final theme = themeProvider.currentTheme;

    // Use white colors for Blue theme, otherwise use accent color
    final Color selectedColor =
        theme.name == 'Blue' ? Colors.white : theme.accentColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          splashColor: theme.name == 'White'
              ? const Color(0xFF2F2F2F).withOpacity(0.1)
              : Colors.white.withOpacity(0.1),
          highlightColor: theme.name == 'White'
              ? const Color(0xFF2F2F2F).withOpacity(0.05)
              : Colors.white.withOpacity(0.05),
          child: Container(
            height: 75,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image icon with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: AnimatedBuilder(
                    animation: _iconAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSelected ? 1.1 : 1.0,
                        child: Image.asset(
                          imagePath,
                          width: 26,
                          height: 26,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 6),

                // Label with smooth transition
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: isSelected
                        ? selectedColor
                        : theme.textColor.withOpacity(0.65),
                    fontSize: themeProvider.getRealFontSize(12),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: themeProvider.getRealLetterSpacing(),
                  ),
                  child: Text(label),
                ),

                const SizedBox(height: 6),

                // Subtle underline indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 24 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Updated _buildNoLessonsMessage to be more specific about reading level
  Widget _buildNoLessonsMessage(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated book icon with floating animation
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, -10 + (10 * (1 - value))),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 800),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accentColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: theme.accentColor,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Main message - specific to reading level with proper constraints
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 48,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.accentColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary message
                  Text(
                    'Walang Aralin para sa Inyong Level',
                    style: TextStyle(
                      color: theme.accentColor,
                      fontSize: themeProvider.getRealFontSize(24),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),

                  const SizedBox(height: 16),

                  // Reading level specific message with improved text handling
                  Text(
                    'Ang inyong reading level ay "$readingLevel" ngunit walang available na aralin para sa level na ito.',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(16),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),

                  const SizedBox(height: 16),

                  // Instruction message with improved text handling
                  Text(
                    'Makipag-ugnayan sa inyong guro para sa mga aralin na angkop sa inyong level.',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(14),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Refresh button with constraints
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 300,
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Refresh the lessons
                  _loadLessons();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: theme.buttonTextColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  minimumSize: Size(200, 48),
                ),
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                ),
                label: Flexible(
                  child: Text(
                    'Tingnan Muli',
                    style: TextStyle(
                      fontSize: themeProvider.getRealFontSize(16),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Reading level indicator with improved layout
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.blue.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Inyong Reading Level: $readingLevel',
                      style: TextStyle(
                        color: Colors.blue.shade200,
                        fontSize: themeProvider.getRealFontSize(12),
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Added extra bottom padding to ensure content doesn't get cut off
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Helper method to update lesson availability based on completed lessons
  void _updateLessonAvailability() {
    if (_lessons.isEmpty) return;

    // The first lesson is always available
    if (_lessons.length > 0) {
      _lessons[0]['isAvailable'] = true;
    }

    // For each subsequent lesson, it's available if the previous one is completed
    for (int i = 1; i < _lessons.length; i++) {
      final previousLesson = _lessons[i - 1];
      final isCompleted = previousLesson['isCompleted'] == true;

      if (isCompleted) {
        _lessons[i]['isAvailable'] = true;
        print(
            '[HomeScreen] Making lesson ${_lessons[i]['index']} available because previous lesson is completed');
      }
    }
  }

  // ENHANCED: Update lesson availability based on category status (including interventions)
  void _updateLessonAvailabilityBasedOnCategoryStatus() {
    if (_lessons.isEmpty) return;

    print('[HomeScreen] ===== UPDATING LESSON AVAILABILITY BASED ON CATEGORY STATUS =====');

    // The first lesson (Alphabet Knowledge) is always available
    if (_lessons.length > 0) {
      _lessons[0]['isAvailable'] = true;
      print('[HomeScreen] Lesson 0 (${_lessons[0]['category']}) is always available');
    }

    // For each subsequent lesson, check if previous category is completed
    for (int i = 1; i < _lessons.length; i++) {
      final currentLesson = _lessons[i];
      final previousLesson = _lessons[i - 1];
      
      final currentCategory = currentLesson['category'] ?? '';
      final previousCategory = previousLesson['category'] ?? '';
      
      // Check if previous category is completed (passed or intervention completed)
      final isPreviousCompleted = _isCategoryFullyCompleted(previousCategory);
      
      currentLesson['isAvailable'] = isPreviousCompleted;
      
      print('[HomeScreen] Lesson $i ($currentCategory): Available=$isPreviousCompleted (Previous: $previousCategory completed=$isPreviousCompleted)');
    }

    print('[HomeScreen] ===== LESSON AVAILABILITY UPDATE COMPLETE =====');
  }

  // Start lesson method with assessment initialization
  void _startLesson(int lessonIndex) {
    // Get the lesson by index
    final lesson = _lessons.firstWhere(
      (l) => l['index'] == lessonIndex,
      orElse: () => <String, dynamic>{},
    );

    // Enhanced availability check
    if (lesson.isEmpty) {
      print('[HomeScreen] Lesson $lessonIndex not found');
      return;
    }

    // All lessons are now available since they exist in the database
    // Removed availability check to allow all categories to be clickable

    // Get necessary data for the assessment
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userReadingLevel =
        authProvider.currentUser?.readingLevel ?? 'Undefined';
    final userIdNumber = authProvider.currentUser?.idNumber.toString() ?? '';
    final lessonCategory = lesson['category']?.toString() ?? '';
    final lessonReadingLevel = lesson['readingLevel']?.toString() ?? '';

    // Validate reading level match
    if (lessonReadingLevel.isNotEmpty &&
        lessonReadingLevel != userReadingLevel) {
      print(
          '[HomeScreen] Reading level mismatch: User=$userReadingLevel, Lesson=$lessonReadingLevel');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('This lesson is not appropriate for your reading level.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get the specific assessment ID based on category and reading level
    String? specificAssessmentId =
        _getAssessmentIdForLesson(lessonCategory, userReadingLevel);

    if (specificAssessmentId == null) {
      print(
          '[HomeScreen] No assessmentId found for lesson $lessonIndex (Category: $lessonCategory, Level: $userReadingLevel)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Lesson content not available. Please contact your teacher.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('[HomeScreen] Starting lesson $lessonIndex with:');
    print('[HomeScreen] - Assessment ID: $specificAssessmentId');
    print('[HomeScreen] - Category: $lessonCategory');
    print('[HomeScreen] - Reading Level: $lessonReadingLevel');

    // Navigate to the appropriate category screen based on lesson category
    String routeName;
    switch (lessonCategory) {
      case 'Alphabet Knowledge':
        routeName = '/alphabet-knowledge';
        break;
      case 'Decoding':
        routeName = '/decoding';
        break;
      case 'Word Recognition':
        routeName = '/word-recognition';
        break;
      case 'Reading Comprehension':
        routeName = '/reading-comprehension';
        break;
      case 'Phonological Awareness':
        routeName = '/phonological-awareness';
        break;
      default:
        print('[HomeScreen] Unknown category: $lessonCategory');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown lesson category: $lessonCategory'),
            backgroundColor: Colors.red,
          ),
        );
        return;
    }

    print('[HomeScreen] Navigating to $routeName for category $lessonCategory');

    // Navigate to category screen with proper arguments
    Navigator.of(context).pushNamed(
      routeName,
      arguments: {
        'assessmentId': specificAssessmentId,
        'isPreAssessment': false, // This is main assessment, not pre-assessment
        'onComplete': (String readingLevel, int score, int total,
            double readingPercentage) {
          // Handle assessment completion and return to home screen
          print(
              '[HomeScreen] Assessment completed: $readingLevel, $score/$total, $readingPercentage%');
          Navigator.of(context).pop();
        },
        'onOptionSelected': (String optionId) {
          print('[HomeScreen] Option selected: $optionId');
        },
        'onContinue': () {
          print('[HomeScreen] Continue pressed');
        },
      },
    );
  }

  // Helper method to get the correct assessment ID based on category and reading level
  String? _getAssessmentIdForLesson(String category, String readingLevel) {
    // Normalize the reading level for consistent comparison
    final normalizedLevel =
        ReadingLevelUtils.normalizeReadingLevel(readingLevel);

    // Map of assessment IDs based on category and reading level
    final Map<String, Map<String, String>> assessmentIdMap = {
      'Alphabet Knowledge': {
        'Low Emerging': '683a51d3168ffbb611dab96a',
        'High Emerging': '683a51d3168ffbb611dab96b',
        'Developing': '683a51d3168ffbb611dab96c',
        'Transitioning': '683a51d3168ffbb611dab96d',
        'At Grade Level': '683a51d3168ffbb611dab96e',
      },
      'Decoding': {
        'Low Emerging': '683a5524168ffbb611dab9d1',
        'High Emerging': '683a5524168ffbb611dab9d2',
        'Developing': '683a5524168ffbb611dab9d3',
        'Transitioning': '683a5524168ffbb611dab9d4',
        'At Grade Level': '683a5524168ffbb611dab9d5',
      },
      'Phonological Awareness': {
        'Low Emerging': '683a4f2c168ffbb611dab954',
        'High Emerging': '683a4f2c168ffbb611dab955',
        'Developing': '683a4f2c168ffbb611dab956',
        'Transitioning': '683a4f2c168ffbb611dab957',
        'At Grade Level': '683a4f2c168ffbb611dab958',
      },
      'Word Recognition': {
        'Low Emerging': '683a4f2c168ffbb611dab959',
        'High Emerging': '683a4f2c168ffbb611dab95a',
        'Developing': '683a4f2c168ffbb611dab95b',
        'Transitioning': '683a4f2c168ffbb611dab95c',
        'At Grade Level': '683a4f2c168ffbb611dab95d',
      },
      'Reading Comprehension': {
        'Low Emerging': '683a4f2c168ffbb611dab95e',
        'High Emerging': '683a4f2c168ffbb611dab95f',
        'Developing': '683a4f2c168ffbb611dab960',
        'Transitioning': '683a4f2c168ffbb611dab961',
        'At Grade Level': '683a4f2c168ffbb611dab962',
      },
    };

    // Get the assessment ID for the given category and reading level
    final categoryMap = assessmentIdMap[category];
    if (categoryMap != null) {
      final assessmentId = categoryMap[normalizedLevel];
      if (assessmentId != null) {
        print(
            '[HomeScreen] Found assessment ID $assessmentId for category $category and level $normalizedLevel');
        return assessmentId;
      }
    }

    print(
        '[HomeScreen] No assessment ID found for category $category and level $normalizedLevel');
    return null;
  }

  // Helper method to check if a lesson has been completed
  Future<bool> _isLessonCompleted(int lessonIndex, String assessmentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';

    if (userId.isEmpty) {
      return false;
    }

    try {
      // 1. First check completedLessons array in the AuthProvider (in-memory)
      final completedLessons = authProvider.currentUser?.completedLessons ?? [];
      if (completedLessons.contains(lessonIndex) ||
          completedLessons.contains(lessonIndex.toString())) {
        print(
            '[HomeScreen] Lesson $lessonIndex is completed based on AuthProvider data');
        return true;
      }

      // 2. Then check the database
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      if (dbService.isConnected) {
        // Try multiple approaches to detect completion

        // a. Check with assessment ID
        if (assessmentId.isNotEmpty) {
          final isCompleted = await dbService.hasStudentCompletedAssessment(
              userId, assessmentId);
          if (isCompleted) {
            print(
                '[HomeScreen] Lesson $lessonIndex (Assessment $assessmentId) is completed based on assessment check');
            // Update in-memory model for future reference
            if (authProvider.currentUser != null) {
              // Check if the method exists and call it
              authProvider.addCompletedLesson(lessonIndex);
            }
            return true;
          }
        }

        // b. Check completed_lessons table in local DB via DatabaseService
        try {
          // Use dbService to check local DB instead of openDatabase directly
          final completedLocally =
              await dbService.isLessonCompletedLocally(userId, lessonIndex);
          if (completedLocally) {
            print(
                '[HomeScreen] Lesson $lessonIndex is completed based on local DB');
            // Update in-memory model
            if (authProvider.currentUser != null) {
              authProvider.addCompletedLesson(lessonIndex);
            }
            return true;
          }
        } catch (e) {
          print('[HomeScreen] Error checking local DB: $e');
        }
      }

      // Final fallback check
      return false;
    } catch (e) {
      print('[HomeScreen] Error checking lesson completion: $e');
      return false;
    }
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose of all animation controllers
    _iconAnimationController.dispose();
    _pulseAnimationController.dispose();
    _cloudAnimationController.dispose();
    _starAnimationController.dispose();
    _starTwinkleController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we need to update lesson availability
    if (widget.forceRefresh) {
      print(
          '[HomeScreen] Force refresh flag detected in didChangeDependencies, performing comprehensive refresh');
      _performHotRestartEquivalent();
    }
  }

  Future<void> _verifyLessonAvailability() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber?.toString() ?? '';

    if (userId.isEmpty) {
      print(
          '[HomeScreen] Cannot verify lesson availability - no user ID available');
      return;
    }

    print(
        '[HomeScreen] Directly checking lesson availability for user $userId');

    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      if (!dbService.isConnected) {
        print(
            '[HomeScreen] Database not connected, cannot verify lesson availability');
        return;
      }

      // 1. Get user document to check completed lessons
      final usersCollection = dbService.getCollection('users');
      final userQuery = where.eq('idNumber', userId);
      final userDoc = await usersCollection.findOne(userQuery);

      List<dynamic> completedLessons = [];
      if (userDoc != null && userDoc['completedLessons'] is List) {
        completedLessons = userDoc['completedLessons'];
        print('[HomeScreen] User has completed lessons: $completedLessons');
      } else {
        print('[HomeScreen] No completed lessons found in user document');
      }

      // 2. Check and update each lesson's availability
      final lessonsCollection = dbService.getCollection('lessons');

      // First lesson is always available
      final lesson1Query =
          where.eq('studentId', userId).and(where.eq('lessonIndex', 1));
      final lesson1Update = await lessonsCollection.update(
          lesson1Query,
          {
            r'$set': {'isAvailable': true},
          },
          upsert: true);
      print(
          '[HomeScreen] Updated lesson 1 availability: ${lesson1Update['ok'] == 1 ? 'Success' : 'Failed'}');

      // For each completed lesson, make the next one available
      for (final completedLessonIndex in completedLessons) {
        int? nextLessonIndex;

        try {
          // Try to parse the completed lesson index
          if (completedLessonIndex is int) {
            nextLessonIndex = completedLessonIndex + 1;
          } else if (completedLessonIndex is String) {
            nextLessonIndex = int.tryParse(completedLessonIndex) != null
                ? int.parse(completedLessonIndex) + 1
                : null;
          }

          if (nextLessonIndex != null) {
            print(
                '[HomeScreen] Making lesson $nextLessonIndex available because lesson $completedLessonIndex is completed');

            // Make the next lesson available
            final nextLessonQuery = where
                .eq('studentId', userId)
                .and(where.eq('lessonIndex', nextLessonIndex));
            final nextLessonUpdate = await lessonsCollection.update(
                nextLessonQuery,
                {
                  r'$set': {'isAvailable': true},
                },
                upsert: true);
            print(
                '[HomeScreen] Updated lesson $nextLessonIndex availability: ${nextLessonUpdate['ok'] == 1 ? 'Success' : 'Failed'}');
          }
        } catch (e) {
          print(
              '[HomeScreen] Error processing completed lesson $completedLessonIndex: $e');
        }
      }

      // Explicitly check lesson 2 if lesson 1 is completed
      if (completedLessons.contains(1) || completedLessons.contains('1')) {
        print(
            '[HomeScreen] Lesson 1 is completed, explicitly making lesson 2 available');

        final lesson2Query =
            where.eq('studentId', userId).and(where.eq('lessonIndex', 2));
        final lesson2Update = await lessonsCollection.update(
            lesson2Query,
            {
              r'$set': {'isAvailable': true},
            },
            upsert: true);
        print(
            '[HomeScreen] Explicitly updated lesson 2 availability: ${lesson2Update['ok'] == 1 ? 'Success' : 'Failed'}');
      }

      // 3. Force reload lessons to reflect the changes
      if (mounted) {
        print('[HomeScreen] Refreshing lessons after direct database updates');
        _loadLessons();
      }
    } catch (e) {
      print('[HomeScreen] Error verifying lesson availability: $e');
    }
  }

  // Add this method to HomeScreen to directly make Aralin 2 available
  void _makeAralin2Available() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber?.toString() ?? '';

    if (userId.isEmpty) {
      print(
          '[HomeScreen] Cannot make Aralin 2 available - no user ID available');
      return;
    }

    print('[HomeScreen] Directly making Aralin 2 available for user $userId');

    final dbService = DatabaseService();
    dbService.makeLessonAvailable(userId, 2).then((_) {
      _loadLessons();
    }).catchError((e) {
      print('[HomeScreen] Error making Aralin 2 available: $e');
    });
  }

  // Helper method to check if Aralin 1 is completed and make Aralin 2 available
  Future<void> _checkAndMakeNextLessonAvailable() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber?.toString() ?? '';

    if (userId.isEmpty) return;

    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }
      // Check if Aralin 1 is completed
      final isAralin1Completed = await _isLessonCompleted(1, "any_id_here");
      print('[HomeScreen] Is Aralin 1 completed? $isAralin1Completed');
      if (isAralin1Completed) {
        print('[HomeScreen] Aralin 1 is completed, making Aralin 2 available');
        await dbService.makeLessonAvailable(userId, 2);
        if (mounted) {
          _loadLessons();
        }
      }
    } catch (e) {
      print('[HomeScreen] Error checking lesson completion: $e');
    }
  }

  // Helper method to normalize reading level in HomeScreen
  String _normalizeReadingLevel(String readingLevel) {
    // Convert to lowercase for case-insensitive matching
    final lowercaseLevel = readingLevel.toLowerCase().trim();

    // Normalize using pattern matching
    if (lowercaseLevel.contains('low') && lowercaseLevel.contains('emerg') ||
        lowercaseLevel == 'emergent') {
      return 'Low Emerging';
    } else if (lowercaseLevel.contains('high') &&
            lowercaseLevel.contains('emerg') ||
        lowercaseLevel == 'early') {
      return 'High Emerging';
    } else if (lowercaseLevel.contains('develop')) {
      return 'Developing';
    } else if (lowercaseLevel.contains('transit')) {
      return 'Transitioning';
    } else if (lowercaseLevel.contains('grade') ||
        lowercaseLevel.contains('fluent') ||
        lowercaseLevel == 'at grade level') {
      return 'At Grade Level';
    }

    // If no match, return as is
    return readingLevel;
  }

  // Helper method to check lesson completion with enhanced validation
  Future<bool> _checkLessonCompletionEnhanced(
      String userId, int lessonIndex, String category) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userReadingLevel =
          authProvider.currentUser?.readingLevel ?? 'Undefined';

      // Check multiple sources for completion status
      bool isCompleted = false;

      // 1. First check MongoDB using the enhanced method from DatabaseService
      try {
        isCompleted =
            await dbService.isLessonCompletedEnhanced(userId, lessonIndex);
        if (isCompleted) {
          print(
              '[HomeScreen] Lesson $lessonIndex is completed (MongoDB enhanced check)');
          // Update AuthProvider memory for consistency
          authProvider.addCompletedLesson(lessonIndex);
          return true;
        }
      } catch (e) {
        print('[HomeScreen] Error checking MongoDB completion: $e');
      }

      // 2. Check by assessment ID if we have the category and reading level
      if (category.isNotEmpty) {
        try {
          String? assessmentId =
              _getAssessmentIdForLesson(category, userReadingLevel);
          if (assessmentId != null) {
            isCompleted = await dbService.hasStudentCompletedAssessment(
                userId, assessmentId);
            if (isCompleted) {
              print(
                  '[HomeScreen] Lesson $lessonIndex ($category) is completed (Assessment ID: $assessmentId)');
              // Update AuthProvider memory for consistency
              authProvider.addCompletedLesson(lessonIndex);
              return true;
            }
          }
        } catch (e) {
          print('[HomeScreen] Error checking assessment completion: $e');
        }
      }

      // 3. Check local database
      try {
        isCompleted =
            await dbService.isLessonCompletedLocally(userId, lessonIndex);
        if (isCompleted) {
          print('[HomeScreen] Lesson $lessonIndex is completed (local DB)');
          return true;
        }
      } catch (e) {
        print('[HomeScreen] Error checking local completion: $e');
      }

      // 4. Check AuthProvider memory model
      final completedLessons = authProvider.currentUser?.completedLessons ?? [];
      if (completedLessons.contains(lessonIndex) ||
          completedLessons.contains(lessonIndex.toString())) {
        print(
            '[HomeScreen] Lesson $lessonIndex is completed (AuthProvider memory)');
        return true;
      }

      print(
          '[HomeScreen] Lesson $lessonIndex is NOT completed (checked all sources)');
      return false;
    } catch (e) {
      print('[HomeScreen] Error checking lesson completion: $e');
      return false;
    }
  }

  // Helper method to determine lesson availability
  bool _determineLessonAvailability(
      int lessonIndex, List<Map<String, dynamic>> lessons) {
    // First lesson (Alphabet Knowledge) is always available
    if (lessonIndex == 0) {
      print('[HomeScreen] Lesson 0 (Alphabet Knowledge) is always available');
      return true;
    }

    // For subsequent lessons, check if previous category is completed
    // This includes both regular assessment completion AND intervention completion
    bool previousCompleted = _isPreviousCategoryCompleted(lessonIndex, lessons);

    print(
        '[HomeScreen] Lesson $lessonIndex availability: $previousCompleted (based on previous category completion)');
    return previousCompleted;
  }

  // Check if the previous category is fully completed (including interventions if needed)
  bool _isPreviousCategoryCompleted(
      int currentLessonIndex, List<Map<String, dynamic>> lessons) {
    try {
      // Find the previous lesson
      Map<String, dynamic>? previousLesson;
      for (var lesson in lessons) {
        if (lesson['index'] == currentLessonIndex - 1) {
          previousLesson = lesson;
          break;
        }
      }

      if (previousLesson == null) {
        print(
            '[HomeScreen] No previous lesson found for index $currentLessonIndex');
        return false;
      }

      final previousCategory = previousLesson['category'] ?? '';

      // Check if previous category is completed
      // This should check the category_results to see if:
      // 1. Category is passed (isPassed: true) OR
      // 2. Category failed but intervention is completed (interventionCompleted: true)

      bool isCompleted = _isCategoryFullyCompleted(previousCategory);

      print(
          '[HomeScreen] Previous category "$previousCategory" completion status: $isCompleted');
      return isCompleted;
    } catch (e) {
      print('[HomeScreen] Error checking previous category completion: $e');
      return false;
    }
  }

  // Check if a category is fully completed (assessment passed OR intervention completed)
  bool _isCategoryFullyCompleted(String categoryName) {
    try {
      // ENHANCED: Check category_results status first (most accurate)
      final categoryStatus = _categoryStatus[categoryName];
      
      if (categoryStatus == 'passed') {
        print('[HomeScreen] Category "$categoryName" is PASSED (from category_results)');
        return true;
      }
      
      // Fallback: Check lesson completion for backward compatibility
      for (var lesson in _lessons) {
        if (lesson['category'] == categoryName) {
          final isLessonCompleted = lesson['isCompleted'] ?? false;

          print(
              '[HomeScreen] Category "$categoryName" lesson completion fallback: $isLessonCompleted');
          return isLessonCompleted;
        }
      }

      print('[HomeScreen] Category "$categoryName" not found in lessons and not in category status');
      return false;
    } catch (e) {
      print(
          '[HomeScreen] Error checking category completion for "$categoryName": $e');
      return false;
    }
  }

  // Enhanced method to check category completion from database (future implementation)
  Future<bool> _isCategoryFullyCompletedFromDB(
      String categoryName, String userId) async {
    try {
      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Get user data
      final usersCollection = dbService.getCollection('users');
      final userData = await usersCollection
          .findOne(where.eq('idNumber', int.parse(userId)));

      if (userData == null) {
        print('[HomeScreen] User not found when checking category completion');
        return false;
      }

      final studentId = userData['idNumber'] as int;

      // Get category results
      final categoryResultsCollection =
          dbService.getCollection('category_results');
      final categoryResult = await categoryResultsCollection
          .findOne(where.eq('studentId', studentId));

      if (categoryResult == null) {
        print('[HomeScreen] No category results found for student');
        return false;
      }

      final categories =
          List<Map<String, dynamic>>.from(categoryResult['categories'] ?? []);

      // Find the specific category
      for (final category in categories) {
        if (category['categoryName'] == categoryName) {
          final isPassed = category['isPassed'] ?? false;
          final interventionCompleted =
              category['interventionCompleted'] ?? false;

          // Category is completed if either:
          // 1. Assessment was passed directly (isPassed: true) OR
          // 2. Intervention was completed successfully (interventionCompleted: true)
          bool isCompleted = isPassed || interventionCompleted;

          print(
              '[HomeScreen] Category "$categoryName" DB status: isPassed=$isPassed, interventionCompleted=$interventionCompleted, final=$isCompleted');
          return isCompleted;
        }
      }

      print(
          '[HomeScreen] Category "$categoryName" not found in database results');
      return false;
    } catch (e) {
      print('[HomeScreen] Error checking category completion from DB: $e');
      return false;
    }
  }

  // Enhanced intervention status check
  Future<void> _checkInterventionStatusEnhanced() async {
    if (_isCheckingIntervention) return;

    try {
      setState(() {
        _isCheckingIntervention = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final interventionProvider =
          Provider.of<InterventionProvider>(context, listen: false);

      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      if (userId.isEmpty) {
        print(
            '[HomeScreen] Cannot check intervention status - no user ID available');
        return;
      }

      print('[HomeScreen] Checking intervention status for user $userId');

      // Check intervention status through provider
      await interventionProvider.checkInterventionStatus(userId);

      // ENHANCED: Also check failed_category_result collection
      await _checkFailedCategoryResults(userId);

      // Update local state based on provider's state
      if (mounted) {
        setState(() {
          // IMPORTANT: For header color, we use our own failed category detection
          // The intervention provider requires all lessons to be completed first,
          // but the header should turn red immediately when there are failed categories
          bool hasAnyFailedCategories =
              _categoryStatus.values.contains('failed');
          _needsIntervention = hasAnyFailedCategories;

          _interventionReason =
              interventionProvider.getInterventionStatusMessage();
          _failedCategories = interventionProvider.failedCategories;
          _overallAverage = interventionProvider.overallAverage;
        });
      }

      print('[HomeScreen] Intervention status updated:');
      print('[HomeScreen] - Needs Intervention: $_needsIntervention');
      print('[HomeScreen] - Reason: $_interventionReason');
      print('[HomeScreen] - Failed Categories: $_failedCategories');
      print('[HomeScreen] - Overall Average: $_overallAverage');
    } catch (e) {
      print('[HomeScreen] Error checking intervention status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIntervention = false;
        });
      }
    }
  }

  /// Check failed_category_result collection for failed categories
  Future<void> _checkFailedCategoryResults(String userId) async {
    try {
      print(
          '[HomeScreen] Checking failed_category_result collection for user: $userId');

      // CRITICAL: First check all category results to properly initialize status
      await _checkAllCategoryResults(userId);

      // Then check for failed categories (this will only update categories that were actually taken)
      final assessmentRepository = AssessmentRepository();
      final failedCategories =
          await assessmentRepository.getFailedCategories(userId);

      print(
          '[HomeScreen] Failed categories query returned ${failedCategories.length} records for user $userId');

      if (failedCategories.isNotEmpty) {
        print('[HomeScreen] Processing failed categories for user $userId:');
        for (final failed in failedCategories) {
          print(
              '[HomeScreen] - Category: ${failed['categoryName']}, Score: ${failed['score']}, StudentId: ${failed['studentId']}');
        }

        // Update local state to show intervention needed
        final List<String> failedCategoryNames = [];
        final Map<String, double> failedScores = {};

        for (final failed in failedCategories) {
          final categoryName = failed['categoryName']?.toString();
          final score = (failed['score'] as num?)?.toDouble() ?? 0.0;

          if (categoryName != null && categoryName.isNotEmpty) {
            // CRITICAL: Only mark as failed if user has actually taken the category
            // Check if this category exists in our category status (populated by _checkAllCategoryResults)
            final currentStatus = _categoryStatus[categoryName];

            // Only update to failed if the user has taken the category (not 'not_taken')
            if (currentStatus != null && currentStatus != 'not_taken') {
              failedCategoryNames.add(categoryName);
              failedScores[categoryName] = score;

              // Update category status to failed
              _categoryStatus[categoryName] = 'failed';
              _categoryScores[categoryName] = score;

              print(
                  '[HomeScreen] Category $categoryName marked as FAILED (user has taken it)');
            } else {
              print(
                  '[HomeScreen] Category $categoryName found in failed_category_result but user has not taken it - keeping as not_taken');
            }
          }
        }

        if (failedCategoryNames.isNotEmpty && mounted) {
          setState(() {
            _needsIntervention = true;
            _failedCategories = failedCategoryNames;
            _interventionReason = 'Kailangan pa ng pag sasanay!';
          });

          print(
              '[HomeScreen] Updated state for failed categories: $failedCategoryNames');
        }
      } else {
        print(
            '[HomeScreen] No failed categories found for user $userId in failed_category_result collection');
        print(
            '[HomeScreen] User should see yellow circles and go to main_assessment');

        // Explicitly ensure no intervention flag is set for users without failed categories
        if (mounted) {
          setState(() {
            _needsIntervention = false;
            _failedCategories = [];
            _interventionReason = '';
          });
          print(
              '[HomeScreen] Intervention status CLEARED for user without failed categories');
        }
      }
    } catch (e) {
      print('[HomeScreen] Error checking failed_category_result: $e');
    }
  }

  /// Check all category assessment results to determine status
  Future<void> _checkAllCategoryResults(String userId) async {
    try {
      print(
          '[HomeScreen] Checking all category assessment results for user: $userId');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      if (!dbService.isConnected) {
        print('[HomeScreen] Database not connected');
        return;
      }

      // Convert userId to appropriate type
      dynamic studentIdValue;
      try {
        studentIdValue = int.parse(userId);
      } catch (e) {
        studentIdValue = userId;
      }

      // Check category_results collection for passed assessments
      final categoryResultsCollection =
          dbService.getCollection('category_results');
      final categoryResults = await categoryResultsCollection
          .find(where.eq('studentId', studentIdValue))
          .toList();

      print(
          '[HomeScreen] Found ${categoryResults.length} category result records');

      // Process category results
      final standardCategories = [
        'Alphabet Knowledge',
        'Phonological Awareness',
        'Decoding',
        'Word Recognition',
        'Reading Comprehension'
      ];

      // Initialize all categories as not_taken
      for (final category in standardCategories) {
        _categoryStatus[category] = 'not_taken';
        _categoryScores[category] = 0.0;
      }

      // Update status based on results
      for (final result in categoryResults) {
        if (result['categories'] != null) {
          final categories = result['categories'] as List;
          for (final categoryData in categories) {
            if (categoryData is Map) {
              final categoryName = categoryData['categoryName']?.toString();
              final score = (categoryData['score'] as num?)?.toDouble() ?? 0.0;
              final isPassed = categoryData['isPassed'] ?? false;

              if (categoryName != null &&
                  standardCategories.contains(categoryName)) {
                _categoryScores[categoryName] = score;

                // CRITICAL: Only update status if the user has actually taken the assessment
                // Check if this is a real assessment result or placeholder data
                final interventionCompleted = categoryData['interventionCompleted'] ?? false;
                
                if (isPassed || interventionCompleted) {
                  // Category is passed either by:
                  // 1. Passing the main assessment (isPassed: true) OR
                  // 2. Successfully completing intervention (interventionCompleted: true)
                  _categoryStatus[categoryName] = 'passed';
                  if (interventionCompleted && !isPassed) {
                    print('[HomeScreen] Category $categoryName PASSED via INTERVENTION - score: $score%');
                  } else {
                    print('[HomeScreen] Category $categoryName PASSED via main assessment - score: $score%');
                  }
                } else {
                  // User failed the assessment - check if they actually took it
                  // If the category has isCompleted=true, then they took it regardless of score
                  final isCompleted = categoryData['isCompleted'] ?? false;
                  
                  if (isCompleted) {
                    // User completed the assessment but failed (even with 0 score)
                    _categoryStatus[categoryName] = 'failed';
                    print('[HomeScreen] Category $categoryName FAILED - user completed assessment with score $score%');
                  } else if (score > 0.0) {
                    // User took the assessment but failed (score > 0 indicates actual attempt)
                    _categoryStatus[categoryName] = 'failed';
                    print('[HomeScreen] Category $categoryName FAILED - user attempted assessment with score $score%');
                  } else {
                    // Score is 0.0, isPassed=false, and isCompleted=false - likely untaken
                    print('[HomeScreen] Category $categoryName appears untaken - keeping as not_taken');
                    // Don't change the status - it remains 'not_taken' from initialization
                  }
                }

                print(
                    '[HomeScreen] Category: $categoryName, Score: $score%, Status: ${_categoryStatus[categoryName]}');
              }
            }
          }
        }
      }

      print('[HomeScreen] Final category status: $_categoryStatus');
      print(
          '[HomeScreen] Current _needsIntervention before check: $_needsIntervention');

      // CRITICAL: Update lesson availability after category status changes
      _updateLessonAvailabilityBasedOnCategoryStatus();

      // Check if any categories failed and update intervention flag
      final hasFailedCategories = _categoryStatus.values.contains('failed');
      print('[HomeScreen] Has failed categories: $hasFailedCategories');

      if (hasFailedCategories && mounted) {
        final failedCategoryNames = _categoryStatus.entries
            .where((entry) => entry.value == 'failed')
            .map((entry) => entry.key)
            .toList();

        print(
            '[HomeScreen] Setting _needsIntervention = true for categories: $failedCategoryNames');

        setState(() {
          _needsIntervention = true;
          _failedCategories = failedCategoryNames;
          _interventionReason = 'Kailangan pa ng pag sasanay!';
        });

        print('[HomeScreen] _needsIntervention is now: $_needsIntervention');
        print(
            '[HomeScreen] Found failed categories from category status: $failedCategoryNames');
      } else {
        print(
            '[HomeScreen] No failed categories detected, keeping _needsIntervention as: $_needsIntervention');
      }
    } catch (e) {
      print('[HomeScreen] Error checking all category results: $e');
    }
  }

  void _navigateToPreAssessment() {}

  /// Get category assessment status for color determination
  String _getCategoryStatus(String category) {
    return _categoryStatus[category] ?? 'not_taken';
  }

  /// Get category assessment score
  double _getCategoryScore(String category) {
    return _categoryScores[category] ?? 0.0;
  }

  /// Check if category is locked (sequential access logic)
  bool _isCategoryLocked(String category) {
    final standardCategories = [
      'Alphabet Knowledge',
      'Phonological Awareness',
      'Decoding',
      'Word Recognition',
      'Reading Comprehension'
    ];

    final currentIndex = standardCategories.indexOf(category);
    if (currentIndex <= 0) return false; // First category is never locked

    // Check if previous category is completed (passed or failed)
    final previousCategory = standardCategories[currentIndex - 1];
    final previousStatus = _getCategoryStatus(previousCategory);

    // Lock if previous category hasn't been taken or failed
    return previousStatus == 'not_taken' || previousStatus == 'failed';
  }

  /// Handle tap on red circle for specific category intervention
  void _handleCategoryInterventionTap(String categoryName) async {
    try {
      print(
          '[HomeScreen] Handling category intervention tap for: $categoryName');

      // CRITICAL: Validate that the user has actually failed this category
      final categoryStatus = _getCategoryStatus(categoryName);
      if (categoryStatus != 'failed') {
        print(
            '[HomeScreen] ERROR: User tried to access intervention for category $categoryName but status is $categoryStatus (should be failed)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Hindi kayo maaaring mag-intervention sa category na hindi pa natake o napasa.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      if (userId.isEmpty) {
        print('[HomeScreen] Cannot check intervention - no user ID');
        return;
      }

      print(
          '[HomeScreen] Category $categoryName verified as FAILED - checking intervention eligibility');

      // NEW: Check if intervention is available based on attemptNumber matching
      final interventionProvider =
          Provider.of<InterventionProvider>(context, listen: false);
      final interventionRepository = InterventionRepository();

      final matchingIntervention = await interventionRepository
          .getMatchingInterventionAssessment(userId, categoryName);

      if (matchingIntervention != null) {
        print(
            '[HomeScreen] Matching intervention found - checking for retry restrictions');

        // NEW: Check if user has existing failed intervention record for retry restriction
        final assessmentProvider = AssessmentProvider();
        final hasFailedRecord = await assessmentProvider
            .hasExistingFailedIntervention(userId, categoryName);

        if (hasFailedRecord) {
          print(
              '[HomeScreen] User has existing failed intervention record - showing retry restriction dialog');
          _showInterventionRetryRestrictionDialog(categoryName);
        } else {
          print(
              '[HomeScreen] No failed intervention record found - allowing intervention');
          _showInterventionAssessmentDialog(categoryName);
        }
      } else {
        print('[HomeScreen] No matching intervention found - checking reason');

        // Check if it's because user already failed an intervention attempt
        final attemptNumber =
            await CategoryResultsHelper.getInterventionAttempts(
                userId, categoryName);

        if (attemptNumber > 0) {
          print(
              '[HomeScreen] User has failed intervention before (attemptNumber: $attemptNumber) - showing retry restriction dialog');
          _showInterventionRetryRestrictionDialog(categoryName);
        } else {
          print(
              '[HomeScreen] No intervention assessment available yet - showing no assessment dialog');
          _showNoInterventionAssessmentDialog(categoryName);
        }
      }
    } catch (e) {
      print('[HomeScreen] Error handling category intervention tap: $e');
    }
  }

  /// NEW: Enhanced intervention tap handler using direct loader
  void _handleCategoryInterventionTapDirect(String categoryName) async {
    try {
      print('[HomeScreen] ===== DIRECT INTERVENTION TAP HANDLER =====');
      print('[HomeScreen] Category: $categoryName');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      final readingLevel = authProvider.currentUser?.readingLevel ?? '';

      print('[HomeScreen] User ID: $userId');
      print('[HomeScreen] Reading Level: $readingLevel');

      if (userId.isEmpty) {
        print('[HomeScreen] Cannot navigate to intervention - no user ID');
        return;
      }

      // Use the new direct intervention assessment loader
      final assessmentRepository = AssessmentRepository();
      final interventionAssessment =
          await assessmentRepository.loadInterventionAssessmentDirect(
        categoryName,
        readingLevel: readingLevel,
        userId: userId,
      );

      if (interventionAssessment == null) {
        print(
            '[HomeScreen] DIRECT LOADER: No intervention assessment found for category: $categoryName');
        _showNoInterventionAssessmentDialog(categoryName);
        return;
      }

      print(
          '[HomeScreen] DIRECT LOADER SUCCESS: Found intervention assessment');
      print(
          '[HomeScreen] Assessment ID: ${interventionAssessment.assessmentId}');
      print('[HomeScreen] Assessment title: ${interventionAssessment.title}');
      print('[HomeScreen] Assessment type: ${interventionAssessment.type}');
      print(
          '[HomeScreen] Total questions: ${interventionAssessment.totalQuestions}');
      print(
          '[HomeScreen] Questions loaded: ${interventionAssessment.questions.length}');

      // Navigate to the appropriate intervention assessment screen
      _navigateToInterventionAssessment(interventionAssessment, categoryName);
    } catch (e) {
      print('[HomeScreen] ERROR in direct intervention tap handler: $e');
      _showNoInterventionAssessmentDialog(categoryName);
    }
  }

  /// NEW: Direct intervention assessment dialog and navigation
  void _showInterventionAssessmentDialog(String categoryName) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFFC60003), // Red background for intervention
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Intervention icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.medical_services,
                  size: 40,
                  color: Color(0xFFC60003),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Kailangan pa ng Pagsasanay',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Category
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Kailangan mo ng tiyak na pagsasanay sa larangang ito. Kumpletohin ang pagsusuri ng interbensyon upang mapabuti ang iyong mga kasanayan.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Kanselahin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Start button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _navigateDirectToInterventionAssessment(categoryName);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Simulan',
                        style: TextStyle(
                          color: const Color(0xFFC60003),
                          fontWeight: FontWeight.bold,
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// NEW: Direct navigation to intervention assessment screens
  void _navigateDirectToInterventionAssessment(String categoryName) async {
    try {
      print('[HomeScreen] ===== DIRECT INTERVENTION NAVIGATION =====');
      print('[HomeScreen] Category: $categoryName');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      final readingLevel = authProvider.currentUser?.readingLevel ?? '';

      print('[HomeScreen] User ID: $userId');
      print('[HomeScreen] Reading Level: $readingLevel');

      // Use the force intervention loader to get actual intervention data
      await assessmentProvider.loadInterventionAssessmentDirect(
          categoryName, readingLevel,
          userId: userId);

      // Navigate directly to the category screen with intervention assessment type
      switch (categoryName.toLowerCase()) {
        case 'alphabet knowledge':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AlphabetKnowledgeScreen(
                assessmentId:
                    'intervention_${categoryName.toLowerCase().replaceAll(' ', '_')}',
                provider: assessmentProvider,
                assessmentType: 'intervention_assessment',
                onAssessmentComplete:
                    (readingLevel, score, total, readingPercentage) {
                  print(
                      '[HomeScreen] INTERVENTION COMPLETED: $score/$total for $categoryName');
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          );
          break;

        case 'phonological awareness':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PhonologicalMatchingScreen(
                assessmentId:
                    'intervention_${categoryName.toLowerCase().replaceAll(' ', '_')}',
                assessmentType: 'intervention_assessment',
                onOptionSelected: (optionId) {
                  print('[HomeScreen] INTERVENTION option selected: $optionId');
                },
                onContinue: () {
                  print('[HomeScreen] INTERVENTION COMPLETED: $categoryName');
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          );
          break;

        case 'decoding':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DecodingScreen(
                assessmentId:
                    'intervention_${categoryName.toLowerCase().replaceAll(' ', '_')}',
                assessmentType: 'intervention_assessment',
                onContinue: () {
                  print('[HomeScreen] INTERVENTION COMPLETED: $categoryName');
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          );
          break;

        case 'word recognition':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WordRecognitionScreen(
                assessmentId:
                    'intervention_${categoryName.toLowerCase().replaceAll(' ', '_')}',
                isPreAssessment: false,
                onContinue: () {
                  print('[HomeScreen] INTERVENTION COMPLETED: $categoryName');
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          );
          break;

        case 'reading comprehension':
          // For reading comprehension, we need a question - show message for now
          print(
              '[HomeScreen] Reading comprehension intervention not fully implemented yet');
          _showNoInterventionAssessmentDialog(categoryName);
          break;

        default:
          print('[HomeScreen] Unknown category: $categoryName');
          _showNoInterventionAssessmentDialog(categoryName);
      }
    } catch (e) {
      print('[HomeScreen] Error in direct intervention navigation: $e');
      _showNoInterventionAssessmentDialog(categoryName);
    }
  }

  /// Handle tap on intervention header when intervention is needed
  void _handleInterventionTap() async {
    if (!_needsIntervention || _failedCategories.isEmpty) {
      print('[HomeScreen] No intervention needed or no failed categories');
      return;
    }

    try {
      print(
          '[HomeScreen] Handling intervention tap for failed categories: $_failedCategories');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';
      final readingLevel = authProvider.currentUser?.readingLevel ?? '';

      if (userId.isEmpty) {
        print('[HomeScreen] Cannot navigate to intervention - no user ID');
        return;
      }

      // For now, take the first failed category to navigate to intervention
      final failedCategory = _failedCategories.first;
      print(
          '[HomeScreen] Navigating to intervention assessment for category: $failedCategory');

      // Load intervention assessment for the failed category
      final assessmentRepository = AssessmentRepository();
      final interventionAssessment =
          await assessmentRepository.getInterventionAssessment(
        failedCategory,
        readingLevel: readingLevel,
        userId: userId,
      );

      if (interventionAssessment == null) {
        print(
            '[HomeScreen] No intervention assessment found for category: $failedCategory');
        _showNoInterventionAssessmentDialog(failedCategory);
        return;
      }

      // Navigate to the appropriate intervention assessment screen based on category
      _navigateToInterventionAssessment(interventionAssessment, failedCategory);
    } catch (e) {
      print('[HomeScreen] Error handling intervention tap: $e');
    }
  }

  /// Navigate to intervention assessment screen based on category
  void _navigateToInterventionAssessment(
      Assessment assessment, String categoryName) async {
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final readingLevel = authProvider.currentUser?.readingLevel ?? '';

    // Load intervention assessment in provider
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';
    await assessmentProvider
        .loadInterventionAssessment(categoryName, readingLevel, userId: userId);

    // Navigate to appropriate screen based on category
    switch (categoryName.toLowerCase()) {
      case 'alphabet knowledge':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AlphabetKnowledgeScreen(
              assessmentId: assessment.assessmentId,
              provider: assessmentProvider,
              assessmentType: 'intervention_assessment',
              onAssessmentComplete:
                  (readingLevel, score, total, readingPercentage) {
                print(
                    '[HomeScreen] Intervention assessment completed: $score/$total');
                // Return to home screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
        break;
      case 'phonological awareness':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhonologicalMatchingScreen(
              assessmentId: assessment.assessmentId,
              assessmentType: 'intervention_assessment',
              onOptionSelected: (optionId) {
                print('[HomeScreen] Intervention option selected: $optionId');
              },
              onContinue: () {
                print('[HomeScreen] Intervention assessment completed');
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
        break;
      case 'decoding':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DecodingScreen(
              assessmentId: assessment.assessmentId,
              assessmentType: 'intervention_assessment',
              onOptionSelected: (optionId) {
                print('[HomeScreen] Intervention option selected: $optionId');
              },
              onContinue: () {
                print('[HomeScreen] Intervention assessment completed');
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
        break;
      case 'word recognition':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordRecognitionScreen(
              assessmentId: assessment.assessmentId,
              isPreAssessment:
                  false, // WordRecognitionScreen uses isPreAssessment parameter
              onOptionSelected: (optionId) {
                print('[HomeScreen] Intervention option selected: $optionId');
              },
              onContinue: () {
                print('[HomeScreen] Intervention assessment completed');
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
        break;
      case 'reading comprehension':
        // For ReadingComprehensionScreen, we need to pass specific question and callbacks
        if (assessment.questions.isNotEmpty) {
          final rcQuestion =
              assessment.questions.first; // Get first RC question
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReadingComprehensionScreen(
                question: rcQuestion,
                assessmentType: 'intervention_assessment',
                onComplete: () {
                  print(
                      '[HomeScreen] Reading comprehension intervention completed');
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                onAnswerSubmitted: (answer) {
                  print(
                      '[HomeScreen] Reading comprehension answer submitted: $answer');
                },
                handleAllRcQuestions: true,
                rcQuestionsList: assessment.questions,
              ),
            ),
          );
        } else {
          print('[HomeScreen] No reading comprehension questions available');
          _showNoInterventionAssessmentDialog(categoryName);
        }
        break;
      default:
        print(
            '[HomeScreen] No specific intervention screen for category: $categoryName');
        _showNoInterventionAssessmentDialog(categoryName);
    }
  }

  /// Show dialog when no intervention assessment is available
  void _showNoInterventionAssessmentDialog(String categoryName) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(
              0xFFC60003), // Orange background for unavailable assessment
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  size: 40,
                  color: const Color(0xFFC60003),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'ASSESSMENT UNAVAILABLE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Category
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Hindi pa nagagawa ang pagsusulit. Makipag-ugnayan sa inyong guro upang makakuha ng tamang pagsusulit.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Single OK button centered
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    'Nauunawaan',
                    style: TextStyle(
                      color: const Color(0xFFC60003),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// NEW: Show dialog when user has already failed intervention and cannot retry yet
  void _showInterventionRetryRestrictionDialog(String categoryName) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFFC60003), // Red background for restriction
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Restriction icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.block,
                  size: 40,
                  color: Color(0xFFC60003),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'HINDI PA PWEDE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Category
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Subukan muli sa susunod, mag antay na lamang. ang pagsusulit para sa larangang ito at hindi pa nagagawa.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Single OK button centered
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    'Nauunawaan',
                    style: TextStyle(
                      color: const Color(0xFFC60003),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show help dialog with navigation instructions in Tagalog
  void _showHelpDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.currentTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFCAFFCD), // Light green background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00E10F), // Green border
                width: 5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color:
                          const Color(0xFF4CAF50), // Green icon to match theme
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gabay sa Paggamit ng App',
                        style: TextStyle(
                          fontSize: themeProvider.getRealFontSize(15),
                          fontWeight: FontWeight.bold,
                          color: Colors
                              .black87, // Dark text for light green background
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors
                            .black87, // Dark icon for light green background
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Scrollable content with numbered list
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNumberedHelpItem(
                          number: 1,
                          text:
                              'Pindutin ang mga card sa ibaba upang magsimula ng assessment. Piliin ang nais mong kategorya.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 2,
                          text:
                              'I-swipe pababa ang screen o pindutin ang refresh button upang ma-update ang mga assessment.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 3,
                          text:
                              'Pumunta sa Profile screen at pindutin ang "Logout" button upang mag-logout.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 4,
                          text:
                              'Pumunta sa Profile screen at piliin ang gusto mong kulay sa "Theme Color" section.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 5,
                          text:
                              'Pumunta sa Profile screen at gamitin ang slider sa "Font Size" para sa gusto mong laki ng text.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 6,
                          text:
                              'Pumunta sa Profile screen at piliin ang gusto mong font style sa "Font Family" section.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                        _buildNumberedHelpItem(
                          number: 7,
                          text:
                              'Pumunta sa Profile screen at i-toggle ang "Text-to-Speech" switch para ma-on o ma-off ang voice reading.',
                          themeProvider: themeProvider,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1BAC24), // Green button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      'Intindihan ko na',
                      style: TextStyle(
                        fontSize: themeProvider.getRealFontSize(16),
                        fontWeight: FontWeight.w600,
                        fontFamily: themeProvider.fontFamily,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper method to build numbered help items (clean design)
  Widget _buildNumberedHelpItem({
    required int number,
    required String text,
    required ThemeProvider themeProvider,
    required dynamic theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: TextStyle(
              fontSize: themeProvider.getRealFontSize(16),
              fontWeight: FontWeight.w600,
              color: Colors.black87, // Dark text for light green background
              fontFamily: themeProvider.fontFamily,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: themeProvider.getRealFontSize(16),
                color: Colors.black87, // Dark text for light green background
                fontFamily: themeProvider.fontFamily,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Clear lesson progress when lesson is completed
  Future<void> _clearLessonProgress(String userId, int lessonIndex) async {
    try {
      print('[HomeScreen] Clearing progress for completed lesson $lessonIndex');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Clear progress from database
      if (dbService.isConnected) {
        final progressCollection = dbService.getCollection('lesson_progress');
        await progressCollection.remove(where
            .eq('userId', userId)
            .and(where.eq('lessonIndex', lessonIndex)));
        print('[HomeScreen] Progress cleared for lesson $lessonIndex');
      }
    } catch (e) {
      print('[HomeScreen] Error clearing progress: $e');
    }
  }

  // Save partial progress when user exits assessment early
  Future<void> _savePartialProgress(int lessonIndex, int currentQuestion,
      int totalQuestions, int progressPercentage, String category) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      if (userId.isEmpty) {
        print('[HomeScreen] Cannot save progress - no user ID');
        return;
      }

      print(
          '[HomeScreen] Saving partial progress: Lesson $lessonIndex, Question $currentQuestion/$totalQuestions ($progressPercentage%)');

      final dbService = DatabaseService();
      if (!dbService.isInitialized) {
        await dbService.initialize();
      }

      // Save progress to database
      await dbService.saveLessonProgress(userId, lessonIndex, currentQuestion,
          totalQuestions, progressPercentage, category);

      print('[HomeScreen] Partial progress saved successfully');

      // Refresh the UI to show updated progress
      if (mounted) {
        _loadLessons();
      }
    } catch (e) {
      print('[HomeScreen] Error saving partial progress: $e');
    }
  }

  // Show lesson popup card
  void _showLessonPopup(int lessonIndex) {
    setState(() {
      _selectedLessonIndex = lessonIndex;
      _isLessonPopupVisible = true;
    });
  }

  // Hide lesson popup card
  void _hideLessonPopup() {
    setState(() {
      _selectedLessonIndex = null;
      _isLessonPopupVisible = false;
    });
  }

  // Helper methods for Duolingo-style color variations
  Color _getDarkerShade(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }

  Color _getLighterShade(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }

  // Small overlay button for progress lessons with floating animation and tail
  Widget _buildSmallOverlayButton({
    required String text,
    required VoidCallback onPressed,
    required ThemeProvider themeProvider,
  }) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Floating animation (up and down)
        final floatOffset =
            math.sin(_animationController.value * 2 * math.pi) * 4;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Column(
            children: [
              // Speech bubble with tail pointing up to circle
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main speech bubble
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF757575),
                      borderRadius: BorderRadius.circular(
                          0), // Border radius 0 as requested
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPressed,
                        borderRadius: BorderRadius.circular(0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: themeProvider.getRealFontSize(13),
                              fontWeight: FontWeight.bold,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tail pointing upward to circle
                  Positioned(
                    top: -8, // Position above the bubble
                    left:
                        32, // Center the tail (approximately center of button)
                    child: CustomPaint(
                      size: const Size(12, 8),
                      painter: TrianglePainter(
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Comprehensive refresh method that reloads all data like a hot restart
  Future<void> _refreshHomeScreen() async {
    try {
      print('[HomeScreen] ===== REFRESHING HOME SCREEN =====');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.idNumber.toString() ?? '';

      if (userId.isEmpty) {
        print('[HomeScreen] Cannot refresh - no user ID');
        return;
      }

      // Reset all state variables
      if (mounted) {
        setState(() {
          _isLoading = true;
          _categoryStatus = {};
          _categoryScores = {};
          _needsIntervention = false;
          _failedCategories = [];
          _interventionReason = '';
          _overallAverage = 0.0;
          _lessons = [];
          _completedLessons = [];
        });
      }

      // Reload all data from database
      await _loadLessons();
      await _checkInterventionStatusEnhanced();
      await _checkFailedCategoryResults(userId);
      await _checkAllCategoryResults(userId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      print('[HomeScreen] ===== REFRESH COMPLETE =====');
    } catch (e) {
      print('[HomeScreen] Error during refresh: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Duolingo-style floating speech bubble with pointing tail and continuous animation
}

// Custom painter for triangle connector
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0) // Top point
      ..lineTo(0, size.height) // Bottom left
      ..lineTo(size.width, size.height) // Bottom right
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
