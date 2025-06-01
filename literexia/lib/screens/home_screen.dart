// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/pre_assessment_question_screen.dart';
import 'package:literexia/features/lessons/logic/aralin/aralin_provider.dart';
import 'package:literexia/screens/profile_screen.dart';
import 'package:literexia/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _lessons = [];
  String? _errorMessage;
  int _currentNavIndex = 0;

  // Separate audio players for different purposes
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();

  // Animation controllers for enhanced UI
  late AnimationController _iconAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _iconAnimation;
  late Animation<double> _pulseAnimation;

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

  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer for proper audio management
    WidgetsBinding.instance.addObserver(this);

    // Initialize animation controllers
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _iconAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
          parent: _iconAnimationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
          parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    // Start pulse animation
    _pulseAnimationController.repeat(reverse: true);

    // Start background music first
    _startBackgroundMusic();

    // Use Future.microtask to avoid setState during build
    Future.microtask(() => _loadLessons());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        _pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        _resumeBackgroundMusic();
        break;
      case AppLifecycleState.detached:
        _backgroundMusicPlayer.dispose();
        break;
      default:
        break;
    }
  }

  void _startBackgroundMusic() async {
    try {
      // Load the background music
      await _backgroundMusicPlayer.setAsset('assets/audio/homeBg.mp3');

      // Set volume to 30%
      await _backgroundMusicPlayer.setVolume(0.3);

      // Enable looping for continuous playback
      await _backgroundMusicPlayer.setLoopMode(LoopMode.one);

      // Start playing
      await _backgroundMusicPlayer.play();

      print('[HomeScreen] Background music started successfully');
    } catch (e) {
      // Handle audio error silently
      print('[HomeScreen] Background music error: $e');
    }
  }

  void _pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      print('[HomeScreen] Background music paused');
    } catch (e) {
      print('[HomeScreen] Error pausing music: $e');
    }
  }

  void _resumeBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.play();
      print('[HomeScreen] Background music resumed');
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

  Future<void> _loadLessons() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        print('No user found in auth provider');
        return;
      }

      // Set the current user ID in the database service for future queries
      final dbService = DatabaseService();
      dbService.setCurrentUserId(user.idNumber.toString());

      // ADD THIS: Test database connection before proceeding
      print('[HomeScreen] Testing database connection...');
      await dbService.testDatabaseConnection();

      // Check if user has completed pre-assessment
      final hasCompletedAssessment = user.preAssessmentCompleted == true ||
          (user.readingLevel != null &&
              user.readingLevel!.isNotEmpty &&
              user.readingLevel != 'Undefined');

      if (!hasCompletedAssessment) {
        print('User has not completed pre-assessment, redirecting...');
        // Create assessment provider and navigate to pre-assessment
        final assessmentProvider = AssessmentProvider();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: assessmentProvider,
                child: PreAssessmentQuestionScreen(
                  assessmentId: 'PRE_ASSESSMENT_001',
                  provider: assessmentProvider,
                  onAssessmentComplete:
                      (readingLevel, score, total, readingPercentage) async {
                    // Update user's reading level and pre-assessment status
                    try {
                      // Use the repository pattern to update the user
                      final success = await assessmentProvider.saveResults();

                      // Also update the local auth provider
                      authProvider.updateUserReadingLevel(readingLevel);
                      authProvider.setPreAssessmentCompleted(true);
                      authProvider.updateReadingPercentage(readingPercentage);

                      print(
                          'Updated user assessment status: Level=$readingLevel, Completed=true, Success=$success');
                    } catch (e) {
                      print('Error updating assessment status: $e');
                    }
                  },
                ),
              ),
            ),
          );
        }
        return;
      }

      // User has completed assessment, load lessons based on reading level
      final readingLevel = user.readingLevel ?? 'Undefined';
      print('[HomeScreen] Loading lessons for reading level: $readingLevel');

      // Use the repository to get lessons for the reading level with the user ID
      // for checking completion status
      final lessons = await _getAvailableLessonsForUser(
        readingLevel.trim(),
        user.idNumber.toString(),
        user.completedLessons,
      );

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading lessons: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // In home_screen.dart - Update _getAvailableLessonsForUser method
  Future<List<Map<String, dynamic>>> _getAvailableLessonsForUser(
    String readingLevel,
    String userId,
    List<int>? completedLessons,
  ) async {
    print(
        '[HomeScreen] Getting lessons for reading level: $readingLevel, User: $userId');

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

        // CHANGE HERE: Use mainAssessmentCollection instead of lessonsCollection
        final mainAssessmentCollection = dbService.mainAssessmentCollection;
        if (mainAssessmentCollection == null) {
          throw Exception('Main assessment collection is not initialized.');
        }

        // Query main_assessment collection for documents matching the reading level
        final assessments = await mainAssessmentCollection
            .find({'readingLevel': readingLevel, 'isActive': true}).toList();

        print(
            '[HomeScreen] Found ${assessments.length} assessments for reading level: $readingLevel');

        // Transform assessments into lesson format
        final lessons = <Map<String, dynamic>>[];

        for (int i = 0; i < assessments.length; i++) {
          final assessment = assessments[i];
          final category =
              assessment['category'] as String? ?? 'Unknown Category';
          final questionCount = assessment['questions'] is List
              ? (assessment['questions'] as List).length
              : 0;

          // Check if this category is completed by the user
          bool isCompleted = false;
          if (userId.isNotEmpty) {
            isCompleted =
                await dbService.hasStudentCompletedCategory(userId, category);
          }

          // First lesson is always available, others depend on previous completion
          bool isAvailable = i == 0;
          if (i > 0 && userId.isNotEmpty) {
            final prevCategory = assessments[i - 1]['category'];
            isAvailable = await dbService.hasStudentCompletedCategory(
                userId, prevCategory);
          }

          lessons.add({
            'index': i + 1,
            'title': 'ARALIN ${i + 1}: $category',
            'description':
                'Assessment for $readingLevel reading level: $category',
            'questionCount': questionCount,
            'isAvailable': isAvailable,
            'isCompleted': isCompleted,
            'assessmentId': assessment['_id'].toString(),
            'readingLevel': readingLevel,
            'category': category,
          });
        }

        print('[DatabaseService] Categories found: $lessons');

        return lessons;
      } else {
        throw Exception('Database not connected, cannot load lessons');
      }
    } catch (e) {
      print('[HomeScreen] Error getting lessons: $e');
      return [];
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
                  backgroundColor: theme.accentColor,
                  foregroundColor: theme.buttonTextColor,
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
  void _onNavItemTapped(int index, VoidCallback action) {
    // Play button sound
    _playButtonAudio();

    // Trigger icon animation
    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse();
    });

    setState(() {
      _currentNavIndex = index;
    });

    // Add haptic feedback
    if (index != 0) {
      // Don't navigate away from home if already on home
      // Execute the navigation action
      action();
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
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with themed background and time-based greeting
            Container(
              width: double.infinity,
              height: 65,
              color: theme.headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_getTimeBasedGreeting()}, $userName!',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: themeProvider.getRealFontSize(14),
                            fontWeight: FontWeight.bold,
                            letterSpacing: themeProvider.getRealLetterSpacing(),
                            fontFamily: themeProvider.fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Text(
                          _getTimeBasedEmoji(),
                          style: TextStyle(fontSize: 32),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? _buildLoadingState(themeProvider)
                  : _errorMessage != null
                      ? _buildErrorState(_errorMessage!, themeProvider)
                      : _lessons.isEmpty
                          ? _buildNoLessonsMessage(themeProvider)
                          : _buildLessonGrid(readingLevel, themeProvider),
            ),

            // Enhanced Bottom Navigation with subtle modern design
            Container(
              margin: const EdgeInsets.all(16),
              child: Container(
                height: 75,
                decoration: BoxDecoration(
                  color: theme.headerColor,
                  borderRadius: BorderRadius.circular(30),
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
                  borderRadius: BorderRadius.circular(30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildEnhancedNavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        index: 0,
                        isSelected: _currentNavIndex == 0,
                        onTap: () => _onNavItemTapped(0, () {}),
                        themeProvider: themeProvider,
                      ),
                      _buildEnhancedNavItem(
                        icon: Icons.person_rounded,
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
                            // Reset to home when returning
                            setState(() {
                              _currentNavIndex = 0;
                            });
                          });
                        }),
                        themeProvider: themeProvider,
                      ),
                      _buildEnhancedNavItem(
                        icon: Icons.settings_rounded,
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
                            // Reset to home when returning
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

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          splashColor: theme.accentColor.withOpacity(0.1),
          highlightColor: theme.accentColor.withOpacity(0.05),
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
                              ? theme.accentColor
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
                        ? theme.accentColor
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
                    color: theme.accentColor,
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

            // Main message - specific to reading level
            Container(
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
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Reading level specific message
                  Text(
                    'Ang inyong reading level ay "$readingLevel" ngunit walang available na aralin para sa level na ito.',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(16),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Instruction message
                  Text(
                    'Makipag-ugnayan sa inyong guro para sa mga aralin na angkop sa inyong level.',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(14),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Refresh button
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
                ),
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                ),
                label: Text(
                  'Tingnan Muli',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(16),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    letterSpacing: themeProvider.getRealLetterSpacing(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Reading level indicator
            Container(
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
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.blue.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Inyong Reading Level: $readingLevel',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: themeProvider.getRealFontSize(12),
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: themeProvider.getRealLetterSpacing(),
                    ),
                  ),
                ],
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
            description: lesson['description'] as String? ??
                'Engage with interactive Filipino lessons',
            questionCount: lesson['questionCount'] as int? ?? 5,
            isAvailable: lesson['isAvailable'] as bool,
            isCompleted: lesson['isCompleted'] as bool? ?? false,
            assessmentId: lesson['assessmentId'].toString(),
            lessonReadingLevel:
                lesson['readingLevel']?.toString() ?? readingLevel,
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
    required String assessmentId,
    bool isCompleted = false,
    required String lessonReadingLevel,
    required ThemeProvider themeProvider,
  }) {
    final theme = themeProvider.currentTheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final userReadingLevel =
        authProvider.currentUser?.readingLevel ?? 'Undefined';

    // Check reading level compatibility
    final isReadingLevelMatch = lessonReadingLevel == userReadingLevel;

    // Determine final availability
    final finalAvailability = isAvailable && isReadingLevelMatch;

    return Opacity(
      opacity: finalAvailability ? 1.0 : 0.7,
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
                  width: isCompleted ? 2 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and icon with reading level indicator
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                isCompleted ? Colors.green : theme.accentColor,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: themeProvider.getRealFontSize(16),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                  letterSpacing:
                                      themeProvider.getRealLetterSpacing(),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Reading level indicator
                              if (lessonReadingLevel.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Level: $lessonReadingLevel',
                                    style: TextStyle(
                                      color: isReadingLevelMatch
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize:
                                          themeProvider.getRealFontSize(12),
                                      fontFamily: themeProvider.fontFamily,
                                    ),
                                  ),
                                ),
                            ],
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

                    // Question count and user level match indicator
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
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
                              letterSpacing:
                                  themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                        ),
                        if (!isReadingLevelMatch)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Button with appropriate state
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: finalAvailability
                            ? () => _startLesson(
                                index, assessmentId, userReadingLevel)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isCompleted ? Colors.green : theme.accentColor,
                          foregroundColor: theme.buttonTextColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          disabledBackgroundColor:
                              theme.accentColor.withOpacity(0.3),
                        ),
                        child: Text(
                          finalAvailability
                              ? (isCompleted
                                  ? 'REVIEW LESSON'
                                  : 'SIMULAN ANG PAGSAGOT')
                              : (!isReadingLevelMatch
                                  ? 'WRONG LEVEL'
                                  : 'NOT AVAILABLE'),
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

          // Reading level mismatch warning overlay
          if (!isReadingLevelMatch)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
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
                      Icons.warning,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'WRONG LEVEL',
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
  void _startLesson(int lessonIndex, String assessmentId, String readingLevel) {
    // Play button audio
    _playButtonAudio();

    print(
        '[HomeScreen] Starting lesson $lessonIndex with assessment ID: $assessmentId');
    print('[HomeScreen] User reading level: $readingLevel');

    // IMPORTANT: Pause home screen background music to prevent duplication
    _pauseBackgroundMusic();

    // Create a new instance of AssessmentProvider
    final assessmentProvider = AssessmentProvider();

    // Navigate to the assessment question screen with reading level context
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: assessmentProvider,
          child: PreAssessmentQuestionScreen(
            assessmentId: assessmentId,
            provider: assessmentProvider,
            onAssessmentComplete:
                (readingLevel, score, total, readingPercentage) async {
              print('[HomeScreen] Assessment completed');
              print(
                  '[HomeScreen] Result - Level: $readingLevel, Score: $score/$total, Reading: $readingPercentage%');

              // Update the user's reading level if it has changed
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.currentUser != null) {
                // For main assessments, the reading level shouldn't change
                // Only update reading percentage
                if (readingPercentage != null) {
                  authProvider.updateReadingPercentage(readingPercentage);
                }

                // Mark this lesson as completed using the database service
                final dbService = DatabaseService();
                try {
                  await dbService.markLessonAsCompleted(
                    authProvider.currentUser!.idNumber.toString(),
                    lessonIndex,
                  );

                  // Also update the completedLessons in AuthProvider
                  await authProvider.updateCompletedLessons(lessonIndex);

                  print('[HomeScreen] Marked lesson $lessonIndex as completed');
                } catch (e) {
                  print('[HomeScreen] Error marking lesson as completed: $e');
                }

                // Reload lessons to update availability status
                if (mounted) {
                  Future.microtask(() => _loadLessons());
                }
              }
            },
          ),
        ),
      ),
    )
        .then((_) {
      // Resume home screen background music when returning from assessment
      print('[HomeScreen] Returned from assessment, resuming background music');
      _resumeBackgroundMusic();
    });
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
        final isCompleted =
            await dbService.hasStudentCompletedAssessment(userId, assessmentId);

        if (isCompleted) {
          print(
              'Lesson $lessonIndex (Assessment $assessmentId) is already completed by user $userId');
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

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Dispose of animation controllers
    _iconAnimationController.dispose();
    _pulseAnimationController.dispose();

    // Dispose of all audio players
    _backgroundMusicPlayer.dispose();
    _buttonSoundPlayer.dispose();

    super.dispose();
  }
}
