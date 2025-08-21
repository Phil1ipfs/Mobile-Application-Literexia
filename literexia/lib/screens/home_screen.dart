// lib/screens/home_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/repositories/assessment_repository.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/intervention/logic/intervention_provider.dart';
import 'package:literexia/features/intervention/ui/intervention_status_widget.dart';
import 'package:literexia/features/intervention/ui/intervention_assessment_screen.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/screens/settings_screen.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/core/theme/app_theme.dart';
import 'package:literexia/services/database_service.dart';
import 'package:literexia/utils/reading_level_utils.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection, where;

class HomeScreen extends StatefulWidget {
  final bool forceRefresh;

  const HomeScreen({
    Key? key,
    this.forceRefresh = false,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static AudioPlayer? _staticBackgroundMusicPlayer;
  static Future<void> stopBackgroundMusic() async {
    if (_staticBackgroundMusicPlayer != null) {
      await _staticBackgroundMusicPlayer!.stop();
      await _staticBackgroundMusicPlayer!.dispose();
      _staticBackgroundMusicPlayer = null;
    }
  }
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

  // Popup card state management
  int? _selectedLessonIndex;
  bool _isLessonPopupVisible = false;

  // Animation controller for floating speech bubble
  late AnimationController _animationController;

  // Separate audio players for different purposes
  late AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();

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

  // Function to get time-based emoji
  String _getTimeBasedEmoji() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 18) {
      return '☀️'; // Sun emoji for morning and afternoon (6AM-6PM)
    } else {
      return '🌙'; // Moon emoji for evening and night (6PM-6AM)
    }
  }

  // Get current lesson category based on user's actual current lesson/assessment
  String _getCurrentLessonCategory() {
    // If lessons are loaded, get the category from the current/next lesson
    if (_lessons.isNotEmpty) {
      // Find the next available lesson (not completed)
      final nextLesson = _lessons.firstWhere(
        (lesson) => lesson['isCompleted'] != true,
        orElse: () => _lessons.first, // Fallback to first lesson
      );

      // Extract category from lesson data
      final category = nextLesson['category']?.toString().toUpperCase() ?? '';
      if (category.isNotEmpty) {
        return category;
      }

      // Extract from lesson title if no category field
      final title = nextLesson['title']?.toString().toUpperCase() ?? '';
      if (title.contains('PHONOLOGICAL')) return 'PLEASE WAIT';
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
        return 'PLEASE WAIT';
      case 'beginning reader':
        return 'LETTER RECOGNITION';
      case 'developing reader':
        return 'WORD FORMATION';
      case 'fluent reader':
        return 'READING COMPREHENSION';
      default:
        return 'PLEASE WAIT'; // Default category
    }
  }

  // Get current task status based on lesson progress
  String _getCurrentTaskStatus() {
    if (_lessons.isEmpty) {
      return 'LOADING TASKS...';
    }

    // Check if user needs intervention
    if (_needsIntervention) {
      return 'INTERVENTION NEEDED!';
    }

    // Find next available lesson
    final nextLesson =
        _lessons.where((lesson) => lesson['isCompleted'] != true).toList();

    if (nextLesson.isEmpty) {
      return 'ALL TASKS COMPLETE!';
    }

    return 'TODAY TASK';
  }

  // Get current lesson title for more specific information
  String _getCurrentLessonTitle() {
    if (_lessons.isEmpty) {
      return 'Please wait while we load your lessons...';
    }

    // Find the next available lesson (not completed)
    final nextLesson = _lessons.firstWhere(
      (lesson) => lesson['isCompleted'] != true,
      orElse: () => _lessons.last, // If all completed, show last lesson
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

      if (!hasCompletedAssessment) {
        print(
            '[HomeScreen] User has not completed pre-assessment, redirecting...');
        _startPreAssessment();
        return;
      }

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

      if (mounted) {
        setState(() {
          _lessons = loadedLessons;
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

  void _startPreAssessment() {
    _playButtonAudio();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreAssessmentQuestionScreen(
          assessmentId: 'PRE_ASSESSMENT_001',
          provider: AssessmentProvider(),
          onAssessmentComplete:
              (readingLevel, score, total, readingPercentage) {
            // After assessment, refresh lessons
            _loadLessons();
          },
        ),
      ),
    );
  }

  void _startSpecificAssessment(String specificAssessmentId) {
    _playButtonAudio();
    final assessmentProvider = AssessmentProvider();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreAssessmentQuestionScreen(
          assessmentId: specificAssessmentId,
          provider: assessmentProvider,
          onAssessmentComplete:
              (readingLevel, score, total, readingPercentage) {
            // After assessment, refresh lessons
            _loadLessons();
          },
        ),
      ),
    );
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
    if (state == AppLifecycleState.resumed) {
      _startBackgroundMusic();
    } else if (state == AppLifecycleState.paused) {
      _pauseBackgroundMusic();
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceRefresh && !oldWidget.forceRefresh) {
      print(
          '[HomeScreen] Force refresh flag detected, reloading lessons and intervention status');
      _loadLessons();
      _refreshInterventionStatus(); // Add this line
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

  // Updated _startBackgroundMusic method to be more robust
  void _startBackgroundMusic() async {
    await HomeScreen.stopBackgroundMusic(); // Ensure no duplicate
    HomeScreen._staticBackgroundMusicPlayer = AudioPlayer();
    try {
      // Load the background music
      await HomeScreen._staticBackgroundMusicPlayer!
          .setAsset('assets/audio/homeBg.mp3');
      await HomeScreen._staticBackgroundMusicPlayer!.setVolume(0.3);
      await HomeScreen._staticBackgroundMusicPlayer!.setLoopMode(LoopMode.one);
      await HomeScreen._staticBackgroundMusicPlayer!.play();
      print('[HomeScreen] Background music started successfully');
    } catch (e) {
      print('[HomeScreen] Background music error: $e');
    }
  }

  void _pauseBackgroundMusic() async {
    try {
      await HomeScreen._staticBackgroundMusicPlayer?.pause();
      print('[HomeScreen] Background music paused');
    } catch (e) {
      print('[HomeScreen] Error pausing music: $e');
    }
  }

  // 2. Fix the _resumeBackgroundMusic method to check if music is already playing
  void _resumeBackgroundMusic() async {
    try {
      // Only resume if it's not already playing to prevent duplication
      if (_backgroundMusicPlayer.playing == false) {
        await _backgroundMusicPlayer.play();
        print('[HomeScreen] Background music resumed');
      } else {
        print('[HomeScreen] Background music already playing, not resuming');
      }
    } catch (e) {
      print('[HomeScreen] Error resuming music: $e');
    }
  }

  void _playButtonAudio() async {
    try {
      await _buttonSoundPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _buttonSoundPlayer.play();
    } catch (e) {
      // Handle audio error silently
      print('[HomeScreen] Button sound error: $e');
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

  // Build lesson popup card with triangle connector
  Widget _buildLessonPopupCard(
      Map<String, dynamic> lesson, ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;
    final lessonNumber = lesson['index']?.toString() ?? '1';
    final lessonTitle = lesson['title']?.toString() ?? 'Please wait...';
    final isCompleted = lesson['isCompleted'] == true;
    final progress = lesson['progress'] as Map<String, dynamic>?;
    final hasProgress =
        progress != null && (progress['progressPercentage'] ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(top: 100, left: 16, right: 16),
      child: Column(
        children: [
          // Triangle connector pointing up
          CustomPaint(
            size: const Size(20, 10),
            painter: TrianglePainter(color: Colors.grey[800]!),
          ),
          // Main popup card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[800], // Dark gray/black color
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lesson title in Filipino
                Text(
                  'Aralin $lessonNumber: $lessonTitle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(18),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: themeProvider.getRealLetterSpacing(),
                  ),
                ),
                const SizedBox(height: 16),
                // SIMULAN button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _playButtonAudio();
                      _hideLessonPopup();
                      _startLesson(int.parse(lessonNumber));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.currentTheme.name == 'Blue' ? const Color(0xFF4CAF50) : Colors.white,
                      foregroundColor: themeProvider.currentTheme.name == 'Blue' ? Colors.white : const Color(0xFF00E10F),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isCompleted
                          ? 'ULITIN'
                          : hasProgress
                              ? 'ITULOY'
                              : 'SIMULAN',
                      style: TextStyle(
                        fontSize: themeProvider.getRealFontSize(16),
                        fontWeight: FontWeight.bold,
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  _loadLessons();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.name == 'Blue' ? const Color(0xFF4CAF50) : theme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
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
        child: Stack(
          children: [
            // Main content
            Column(
              children: <Widget>[
                // New Header Section
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                          255, 21, 182, 21), // Dark gray/black color
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 0, 0, 0)
                              .withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  fontSize: themeProvider.getRealFontSize(20),
                                  fontWeight: FontWeight.bold,
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
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255)
                                          .withOpacity(0.9),
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
                        // Right side - Book icon
                        Container(
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState(themeProvider)
                      : _errorMessage != null
                          ? _buildErrorState(_errorMessage!, themeProvider)
                          : _lessons.isEmpty
                              ? _buildNoLessonsMessage(themeProvider)
                              : Column(
                                  children: <Widget>[
                                    InterventionStatusWidget(
                                      onTap: () {
                                        _playButtonAudio();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const InterventionAssessmentScreen(),
                                          ),
                                        );
                                      },
                                      showProgress: true,
                                    ),
                                    Expanded(
                                      child: _buildCircularLessonProgress(
                                          themeProvider),
                                    ),
                                  ],
                                ),
                ),
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
                          color: Colors.black.withOpacity(0.08),
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

            // Popup overlay
            if (_isLessonPopupVisible && _selectedLessonIndex != null)
              GestureDetector(
                onTap: _hideLessonPopup,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap from bubbling to background
                    child: _buildLessonPopupCard(
                      _lessons.firstWhere(
                        (lesson) => lesson['index'] == _selectedLessonIndex,
                        orElse: () => {
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

    // Determine circle colors and state
    Color circleColor;
    Color iconColor;
    IconData iconData;
    bool showCheckmark = false;
    double progressPercentage = 0.0;
    bool isTrophyLesson =
        lessonIndex == 3; // 4th lesson (0-indexed) - making it the last lesson

    // Debug print
    print(
        'Lesson Index: $lessonIndex, Is Trophy: $isTrophyLesson, Total lessons: ${_lessons.length}');

    if (isTrophyLesson) {
      // Special trophy design for 5th lesson - ALWAYS GOLD
      circleColor = const Color(0xFFFFD700); // Gold color
      iconColor = const Color(0xFF8B4513); // Brown for trophy details
      iconData = Icons.emoji_events; // Trophy icon
      showCheckmark = false;
      print('Applied trophy design to lesson $lessonIndex');
    } else if (isCompleted) {
      circleColor = const Color(0xFF00E10F);
      iconColor = Colors.white;
      iconData = Icons.check;
      showCheckmark = true;
      progressPercentage = 100.0;
    } else if (isAvailable) {
      // Check for partial progress
      final progress = lesson['progress'] as Map<String, dynamic>?;
      if (progress != null && progress['progressPercentage'] != null) {
        // Lesson has partial progress
        progressPercentage = (progress['progressPercentage'] as num).toDouble();
        circleColor = progressPercentage > 0
            ? const Color(0xFFFFB800)
            : const Color(
                0xFF00E10F); // Orange for in-progress, green for available
        iconColor = Colors.white;
        iconData = progressPercentage > 0 ? Icons.play_arrow : Icons.star;
      } else {
        // No progress yet, available to start
        circleColor = const Color(0xFF00E10F);
        iconColor = Colors.white;
        iconData = Icons.star;
      }
    } else {
      circleColor = Colors.grey;
      iconColor = Colors.white;
      iconData = Icons.star;
    }

    return Column(
      children: [
        // Main circle with tap interaction and progress indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Circle and progress ring
            GestureDetector(
              onTap: isAvailable
                  ? () => _showLessonPopup(lesson['index'] ?? lessonIndex + 1)
                  : null,
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
                      child: lessonIndex == 1
                          ? Container(
                              width: 98,
                              height: 98,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Container(
                                  width: 98,
                                  height: 98,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage(
                                          'assets/images/philippine.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        iconData == Icons.star
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                child: Icon(
                                                  iconData,
                                                  color: Colors.white,
                                                  size: progressPercentage >
                                                              0 &&
                                                          progressPercentage <
                                                              100
                                                      ? 45
                                                      : 55,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      offset:
                                                          const Offset(0, 1),
                                                      blurRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Icon(
                                                iconData,
                                                color: Colors.white,
                                                size: progressPercentage > 0 &&
                                                        progressPercentage < 100
                                                    ? 45
                                                    : 55,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    offset: const Offset(0, 1),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 98,
                              height: 98,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // Special trophy shadow or Duolingo-style layered shadow
                                boxShadow: isTrophyLesson
                                    ? [
                                        // Golden glow effect for trophy
                                        BoxShadow(
                                          color: const Color(0xFFFFD700)
                                              .withOpacity(0.5),
                                          offset: const Offset(0, 0),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                        // Bottom shadow (darker gold)
                                        BoxShadow(
                                          color: const Color(
                                              0xFFB8860B), // Dark goldenrod
                                          offset: const Offset(0, 8),
                                          blurRadius: 0,
                                          spreadRadius: 0,
                                        ),
                                        // Mid shadow
                                        BoxShadow(
                                          color: const Color(0xFFB8860B)
                                              .withOpacity(0.7),
                                          offset: const Offset(0, 6),
                                          blurRadius: 0,
                                          spreadRadius: 0,
                                        ),
                                      ]
                                    : [
                                        // Bottom shadow (darker)
                                        BoxShadow(
                                          color: _getDarkerShade(circleColor),
                                          offset: const Offset(0, 6),
                                          blurRadius: 0,
                                          spreadRadius: 0,
                                        ),
                                        // Mid shadow
                                        BoxShadow(
                                          color: _getDarkerShade(circleColor)
                                              .withOpacity(0.7),
                                          offset: const Offset(0, 4),
                                          blurRadius: 0,
                                          spreadRadius: 0,
                                        ),
                                      ],
                              ),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: isTrophyLesson
                                      ?
                                      // Special golden gradient for trophy
                                      LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(
                                                0xFFFFF8DC), // Light golden
                                            const Color(0xFFFFD700), // Gold
                                            const Color(
                                                0xFFB8860B), // Dark goldenrod
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        )
                                      :
                                      // Normal gradient for other lessons
                                      LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            _getLighterShade(
                                                circleColor), // Top highlight
                                            circleColor, // Main color
                                            _getDarkerShade(circleColor)
                                                .withOpacity(
                                                    0.3), // Bottom shade
                                          ],
                                          stops: const [0.0, 0.5, 1.0],
                                        ),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    children: [
                                      // Content
                                      Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            iconData == Icons.star
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3),
                                                    child: Icon(
                                                      iconData,
                                                      color: Colors.white,
                                                      size: progressPercentage >
                                                                  0 &&
                                                              progressPercentage <
                                                                  100
                                                          ? 45
                                                          : 55,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          offset: const Offset(
                                                              0, 1),
                                                          blurRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Icon(
                                                    iconData,
                                                    color: Colors.white,
                                                    size: progressPercentage >
                                                                0 &&
                                                            progressPercentage <
                                                                100
                                                        ? 45
                                                        : 55,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        offset:
                                                            const Offset(0, 1),
                                                        blurRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                            // Show progress text for partial progress
                                            if (progressPercentage > 0 &&
                                                progressPercentage < 100)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2),
                                                child: Text(
                                                  '${progressPercentage.round()}%',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: themeProvider
                                                        .fontFamily,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        offset:
                                                            const Offset(0, 1),
                                                        blurRadius: 1,
                                                      ),
                                                    ],
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
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20), // Adjusted spacing below circle

        // Category badge
        if (category.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.name == 'Blue'
                  ? Colors.white.withOpacity(0.15)
                  : theme.name == 'White'
                      ? const Color(0xFF2F2F2F).withOpacity(0.1)
                      : theme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.name == 'Blue'
                    ? Colors.white.withOpacity(0.3)
                    : theme.name == 'White'
                        ? const Color(0xFF757575).withOpacity(0.3)
                        : theme.accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: theme.name == 'Blue'
                    ? Colors.white
                    : theme.name == 'White'
                        ? const Color(0xFF757575)
                        : theme.accentColor,
                fontSize: themeProvider.getRealFontSize(10),
                fontWeight: FontWeight.w500,
                fontFamily: themeProvider.fontFamily,
              ),
            ),
          ),

        const SizedBox(height: 20), // Increased spacing before button

        // Floating action button for available lessons (no REVIEW for completed)
        if (isAvailable && !isCompleted)
          _buildFloatingActionButton(
            text: (progressPercentage > 0 && progressPercentage < 100)
                ? 'ITULOY'
                : 'SIMULAN',
            onPressed: () => _startLesson(lesson['index'] ?? lessonIndex + 1),
            themeProvider: themeProvider,
            isProgress: progressPercentage > 0 && progressPercentage < 100,
          ),
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                  elevation: 0,
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

  // Start lesson method with assessment initialization
  void _startLesson(int lessonIndex) {
    // Play button audio
    _playButtonAudio();

    // Get the lesson by index
    final lesson = _lessons.firstWhere(
      (l) => l['index'] == lessonIndex,
      orElse: () => {},
    );

    // Enhanced availability check
    if (lesson.isEmpty) {
      print('[HomeScreen] Lesson $lessonIndex not found');
      return;
    }

    // Check if lesson is actually available
    if (lesson['isAvailable'] != true) {
      print('[HomeScreen] Lesson $lessonIndex is not available');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'This lesson is not yet available. Complete the previous lesson first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    // Stop background music before navigating
    _backgroundMusicPlayer.stop().then((_) {
      print('[HomeScreen] Background music stopped before starting lesson');

      // Create a new instance of AssessmentProvider
      final assessmentProvider = AssessmentProvider();

      // Navigate to the assessment question screen with enhanced completion callback
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => PreAssessmentQuestionScreen(
            assessmentId: specificAssessmentId!,
            provider: assessmentProvider,
            category: lessonCategory,
            onAssessmentComplete:
                (readingLevel, score, total, readingPercentage) async {
              print(
                  '[HomeScreen] Assessment completed for lesson $lessonIndex');
              print(
                  '[HomeScreen] Result - Level: $readingLevel, Score: $score/$total, Reading: $readingPercentage%');

              // Update reading percentage in AuthProvider
              if (readingPercentage != null) {
                authProvider.updateReadingPercentage(readingPercentage);
              }

              // Mark lesson as completed using enhanced method
              try {
                final dbService = DatabaseService();

                // Method 1: Mark by lesson index
                await dbService.markLessonAsCompletedAndUpdateNext(
                    userIdNumber, lessonIndex);

                // Method 2: Also mark by category for cross-reference
                if (lessonCategory.isNotEmpty) {
                  await dbService.markLessonAsCompletedByCategory(
                      userIdNumber, lessonCategory);
                }

                // Method 3: Update AuthProvider memory model
                authProvider.addCompletedLesson(lessonIndex);

                // Method 4: Clear any partial progress since lesson is now completed
                await _clearLessonProgress(userIdNumber, lessonIndex);

                print(
                    '[HomeScreen] Lesson $lessonIndex marked as completed using multiple methods');

                // Force reload lessons after a delay to ensure DB updates
                Future.delayed(Duration(milliseconds: 1000), () {
                  if (mounted) {
                    _loadLessons();
                  }
                });
              } catch (e) {
                print(
                    '[HomeScreen] Error updating lesson completion status: $e');
              }
            },
          ),
        ),
      )
          .then((_) {
        // Always reload lessons when returning to ensure UI reflects latest changes
        _loadLessons();

        // Restart background music
        if (_backgroundMusicPlayer.playing == false) {
          print(
              '[HomeScreen] Restarting background music after returning from assessment');
          _startBackgroundMusic();
        }
      });
    });
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

    // Dispose of all audio players
    _backgroundMusicPlayer.dispose();
    _buttonSoundPlayer.dispose();

    HomeScreen.stopBackgroundMusic();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we need to update lesson availability
    if (widget.forceRefresh) {
      print(
          '[HomeScreen] Force refresh flag detected in didChangeDependencies');
      _verifyLessonAvailability();
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
      final userReadingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';
      
      // Check multiple sources for completion status
      bool isCompleted = false;
      
      // 1. First check MongoDB using the enhanced method from DatabaseService
      try {
        isCompleted = await dbService.isLessonCompletedEnhanced(userId, lessonIndex);
        if (isCompleted) {
          print('[HomeScreen] Lesson $lessonIndex is completed (MongoDB enhanced check)');
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
          String? assessmentId = _getAssessmentIdForLesson(category, userReadingLevel);
          if (assessmentId != null) {
            isCompleted = await dbService.hasStudentCompletedAssessment(userId, assessmentId);
            if (isCompleted) {
              print('[HomeScreen] Lesson $lessonIndex ($category) is completed (Assessment ID: $assessmentId)');
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
        isCompleted = await dbService.isLessonCompletedLocally(userId, lessonIndex);
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
        print('[HomeScreen] Lesson $lessonIndex is completed (AuthProvider memory)');
        return true;
      }
      
      print('[HomeScreen] Lesson $lessonIndex is NOT completed (checked all sources)');
      return false;
    } catch (e) {
      print('[HomeScreen] Error checking lesson completion: $e');
      return false;
    }
  }

  // Helper method to determine lesson availability
  bool _determineLessonAvailability(
      int lessonIndex, List<Map<String, dynamic>> lessons) {
    // First lesson is always available
    if (lessonIndex == 1) return true;

    // Find the previous lesson
    final previousLesson = lessons.firstWhere(
      (lesson) => lesson['index'] == lessonIndex - 1,
      orElse: () => {'isCompleted': false},
    );

    // Lesson is available if previous lesson is completed
    return previousLesson['isCompleted'] == true;
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

      // Update local state based on provider's state
      if (mounted) {
        setState(() {
          _needsIntervention = interventionProvider.hasFailedCategories;
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

  void _navigateToAssessment(String category, String assessmentId) {
    _playButtonAudio();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreAssessmentQuestionScreen(
          assessmentId: assessmentId,
          provider: AssessmentProvider(),
          category: category,
          onAssessmentComplete:
              (readingLevel, score, total, readingPercentage) {
            // After assessment, refresh lessons
            _loadLessons();
          },
        ),
      ),
    );
  }

  void _navigateToPreAssessment() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PreAssessmentQuestionScreen(
          assessmentId: 'PRE_ASSESSMENT_001',
          provider: AssessmentProvider(),
          onAssessmentComplete:
              (readingLevel, score, total, readingPercentage) {
            // After pre-assessment, reload the home screen
            _initializeUserData();
          },
        ),
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
                      painter: SpeechBubbleTailPainter(
                        color: const Color(0xFF757575),
                        shadowColor: Colors.black.withOpacity(0.3),
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

  // Duolingo-style floating speech bubble with pointing tail and continuous animation
  Widget _buildFloatingActionButton({
    required String text,
    required VoidCallback onPressed,
    required ThemeProvider themeProvider,
    required bool isProgress,
  }) {
    final buttonColor =
        isProgress ? const Color(0xFF00E10F) : const Color(0xFF00E10F);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Continuous floating animation (up and down)
        final floatOffset =
            math.sin(_animationController.value * 2 * math.pi) * 8;

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
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        // Duolingo-style bottom shadow
                        BoxShadow(
                          color: _getDarkerShade(buttonColor),
                          offset: const Offset(0, 6),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                        // Mid shadow
                        BoxShadow(
                          color: _getDarkerShade(buttonColor).withOpacity(0.7),
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPressed,
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _getLighterShade(buttonColor),
                                buttonColor,
                                _getDarkerShade(buttonColor).withOpacity(0.3),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          child: Center(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(14),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                color: Colors.white,
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
                  ),
                  // Pointed tail pointing upward to circle
                  Positioned(
                    top: -12, // Position above the bubble
                    left: 70 - 8, // Center the tail (70 is half of 140 width)
                    child: CustomPaint(
                      size: const Size(16, 12),
                      painter: SpeechBubbleTailPainter(
                        color: buttonColor,
                        shadowColor: _getDarkerShade(buttonColor),
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

// Custom painter for speech bubble tail pointing upward
class SpeechBubbleTailPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  SpeechBubbleTailPainter({
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..style = PaintingStyle.fill;

    // Draw shadow first (slightly offset)
    final shadowPath = Path();
    shadowPath.moveTo(size.width / 2 + 2, 2); // Top point (shadow offset)
    shadowPath.lineTo(2, size.height + 2); // Bottom left (shadow offset)
    shadowPath.lineTo(
        size.width - 2, size.height + 2); // Bottom right (shadow offset)
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw main tail pointing upward
    final path = Path();
    path.moveTo(size.width / 2, 0); // Top point
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
