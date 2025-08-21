// lib/screens/student_reflect_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import 'dart:async';
import '../features/settings/provider/theme_provider.dart';
import '../features/settings/provider/tts_provider.dart';
import '../features/auth/logic/auth_provider.dart';
import '../services/database_service.dart';
import '../config/router.dart';

class StudentReflectScreen extends StatefulWidget {
  final String assessmentType;
  final String? assessmentId;
  final int? score;
  final int? totalQuestions;
  final VoidCallback? onComplete;

  const StudentReflectScreen({
    Key? key,
    required this.assessmentType,
    this.assessmentId,
    this.score,
    this.totalQuestions,
    this.onComplete,
  }) : super(key: key);

  @override
  State<StudentReflectScreen> createState() => _StudentReflectScreenState();
}

class _StudentReflectScreenState extends State<StudentReflectScreen>
    with TickerProviderStateMixin {
  // Selected emotion data
  EmotionData? _selectedEmotion;
  String? _selectedIntensity;

  // Animation controllers
  late AnimationController _characterController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  // Animations
  late Animation<double> _characterAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Current step in the reflection process
  int _currentStep =
      0; // 0: welcome, 1: emotion selection, 2: intensity, 3: completion

  // Typewriter effect variables
  String _promptText = "";
  String _displayText = "";
  int _currentIndex = 0;
  bool _isTypingComplete = false;
  bool _hasSpokenText = false;
  Timer? _typewriterTimer;

  // TTS state
  bool _isTTSPlaying = false;

  // Store references to providers
  ThemeProvider? _themeProvider;
  TTSProvider? _ttsProvider;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // Initialize welcome prompt text
    _promptText =
        "Na tapos mo na ang pagsusulit! Ngayon, Ano ang iyong nararamdaman? piliin mo kung ano ang iyong nararamdaman ngayon.";

    // Start typewriter effect after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startTypewriterEffect();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references safely during widget lifecycle
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
  }

  void _speakPromptText() {
    if (_hasSpokenText || !mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        _promptText,
        speed: 0.4, // Explicitly set slower speed
        onStart: () {
          if (mounted) {
            setState(() {
              _hasSpokenText = true;
              _isTTSPlaying = true;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
        onError: () {
          // Handle error silently
          print('TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    } else {
      print(
          'TTS not available or enabled. Provider: ${_ttsProvider?.isAvailable}, Theme: ${_themeProvider?.textToSpeechEnabled}');
    }
  }

  void _startTypewriterEffect() {
    // Cancel any existing timer
    _typewriterTimer?.cancel();

    // Reset the text state
    setState(() {
      _displayText = "";
      _currentIndex = 0;
      _isTypingComplete = false;
      _hasSpokenText = false;
    });

    // Start a timer to add one character at a time
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentIndex < _promptText.length) {
        setState(() {
          _displayText = _promptText.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        // Typing is complete
        timer.cancel();
        setState(() {
          _isTypingComplete = true;
        });

        // Small delay before speaking to ensure visual effect is complete
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _speakPromptText();
          }
        });
      }
    });
  }

  void _initializeAnimations() {
    // Character floating animation
    _characterController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _characterAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _characterController,
      curve: Curves.easeInOut,
    ));

    // Pulse animation for selected emotions
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }

  void _playButtonSound() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print('Button sound error: $e');
    }
  }

  void _playSuccessSound() async {
    try {
      await _audioPlayer.setAsset('assets/audio/assessmentsound.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print('Success sound error: $e');
    }
  }

  void _speakCurrentStep() {
    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      String textToSpeak = "";
      switch (_currentStep) {
        case 1:
          textToSpeak = "Pumili ng Emosyon. Anong ang nararamdaman mo ngayon?";
          break;
        case 2:
          textToSpeak = "Gaano kalakas ang inyong nararamdaman?";
          break;
        case 3:
          textToSpeak =
              "Salamat sa Pagbabahagi! Ang inyong mga damdamin ay mahalaga at nakakatulong sa inyong guro na mas maintindihan kayo.";
          break;
      }

      if (textToSpeak.isNotEmpty) {
        _ttsProvider!.speakText(
          textToSpeak,
          speed: 0.4,
          onStart: () {
            if (mounted) {
              setState(() {
                _isTTSPlaying = true;
              });
            }
          },
          onComplete: () {
            if (mounted) {
              setState(() {
                _isTTSPlaying = false;
              });
            }
          },
          onError: () {
            if (mounted) {
              setState(() {
                _isTTSPlaying = false;
              });
            }
          },
        );
      }
    }
  }

  void _nextStep() {
    // Stop any ongoing TTS and typewriter
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }
    _typewriterTimer?.cancel();

    _playButtonSound();
    setState(() {
      if (_currentStep < 3) {
        _currentStep++;
      }
    });

    // Reset fade animation for new step
    _fadeController.reset();
    _fadeController.forward();

    // Speak the new step's text after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _speakCurrentStep();
      }
    });
  }

  void _selectEmotion(EmotionData emotion) {
    _playButtonSound();
    setState(() {
      _selectedEmotion = emotion;
    });
  }

  void _selectIntensity(String intensity) {
    _playButtonSound();
    setState(() {
      _selectedIntensity = intensity;
    });
  }

  void _logReflection() async {
    if (_selectedEmotion == null || _selectedIntensity == null) return;

    // Log reflection data to console
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber.toString() ?? 'unknown';

    final reflectionData = {
      'userId': userId,
      'userName': authProvider.currentUser?.firstName ?? 'Unknown',
      'assessmentType': widget.assessmentType,
      'assessmentId': widget.assessmentId,
      'emotion': _selectedEmotion!.name,
      'emotionCategory': _selectedEmotion!.category,
      'emotionEmoji': _selectedEmotion!.emoji,
      'intensity': _selectedIntensity,
      'timestamp': DateTime.now().toIso8601String(),
      'score': widget.score,
      'totalQuestions': widget.totalQuestions,
      'scorePercentage': widget.score != null && widget.totalQuestions != null
          ? ((widget.score! / widget.totalQuestions!) * 100)
                  .toStringAsFixed(1) +
              '%'
          : null,
    };

    print('=== STUDENT REFLECTION DATA ===');
    print(
        'Student: ${reflectionData['userName']} (ID: ${reflectionData['userId']})');
    print(
        'Assessment: ${reflectionData['assessmentType']} (${reflectionData['assessmentId']})');
    print(
        'Score: ${reflectionData['score']}/${reflectionData['totalQuestions']} (${reflectionData['scorePercentage']})');
    print(
        'Emotion: ${reflectionData['emotionEmoji']} ${reflectionData['emotion']} (${reflectionData['emotionCategory']})');
    print('Intensity: ${reflectionData['intensity']}');
    print('Time: ${reflectionData['timestamp']}');
    print('==============================');
  }

  // Modify _completeReflection() method to remove auto-navigation
void _completeReflection() async {
  _playSuccessSound();
  _logReflection();

  // Move to completion step
  setState(() {
    _currentStep = 3;
  });

  // Speak completion message
  _speakCurrentStep();
  
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCurrentStep(theme, themeProvider),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AppThemeData theme, ThemeProvider themeProvider) {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep(theme, themeProvider);
      case 1:
        return _buildEmotionSelectionStep(theme, themeProvider);
      case 2:
        return _buildIntensityStep(theme, themeProvider);
      case 3:
        return _buildCompletionStep(theme, themeProvider);
      default:
        return _buildWelcomeStep(theme, themeProvider);
    }
  }

  Widget _buildWelcomeStep(AppThemeData theme, ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated character
            AnimatedBuilder(
              animation: _characterAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _characterAnimation.value),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.accentColor.withOpacity(0.3),
                          theme.accentColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🤗',
                        style: TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Welcome message
            Text(
              'Paano ka naramdaman?',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: themeProvider.getRealFontSize(24),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Typewriter effect text container
            Container(
              height: 100, // Fixed height to prevent jumping
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _displayText,
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.8),
                  fontSize: themeProvider.getRealFontSize(16),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 32),

            // TTS controls
            if (_themeProvider != null && _themeProvider!.textToSpeechEnabled)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ElevatedButton.icon(
                  onPressed: _isTTSPlaying
                      ? () {
                          if (_ttsProvider != null) {
                            _ttsProvider!.stopSpeaking();
                          }
                          setState(() {
                            _isTTSPlaying = false;
                          });
                        }
                      : () {
                          _speakPromptText();
                        },
                  icon: Icon(_isTTSPlaying ? Icons.stop : Icons.volume_up),
                  label: Text(_isTTSPlaying ? 'Stop' : 'Listen Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTTSPlaying 
                        ? Colors.red.shade400 
                        : (theme.name == 'Blue' ? const Color(0xFF4CAF50) : theme.accentColor),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.name == 'Blue' ? const Color(0xFF4CAF50) : theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'SIMULAN ANG REFLECTION',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(15),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionSelectionStep(
      AppThemeData theme, ThemeProvider themeProvider) {
    return Column(
      children: [
        // Header - Fixed at top
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Piliin ang Inyong Damdamin',
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: themeProvider.getRealFontSize(22),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Anong damdamin ang nararamdaman ninyo ngayon?',
                style: TextStyle(
                  color: theme.textColor.withOpacity(0.7),
                  fontSize: themeProvider.getRealFontSize(14),
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Emotions grid - Scrollable content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: emotionCategories.length,
              itemBuilder: (context, index) {
                final category = emotionCategories[index];
                final isSelected = _selectedEmotion?.name == category.name;

                return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isSelected ? _pulseAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: () => _selectEmotion(category),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? category.color.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? category.color
                                  : theme.accentColor.withOpacity(0.3),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: category.color.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  category.emoji,
                                  style: TextStyle(fontSize: 36),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? category.color
                                        : theme.textColor,
                                    fontSize: themeProvider.getRealFontSize(14),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontFamily: themeProvider.fontFamily,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  category.description,
                                  style: TextStyle(
                                    color: theme.textColor.withOpacity(0.6),
                                    fontSize: themeProvider.getRealFontSize(10),
                                    fontFamily: themeProvider.fontFamily,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Continue button - Fixed at bottom
        if (_selectedEmotion != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.name == 'Blue' ? const Color(0xFF4CAF50) : _selectedEmotion!.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'MAGPATULOY',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(18),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIntensityStep(AppThemeData theme, ThemeProvider themeProvider) {
    if (_selectedEmotion == null) return Container();

    final intensityLevels = ['Kaunti', 'Katamtaman', 'Malakas'];
    final intensityEmojis = ['😐', '😊', '😍'];
    final intensityColors = [
      _selectedEmotion!.color.withOpacity(0.4),
      _selectedEmotion!.color.withOpacity(0.7),
      _selectedEmotion!.color,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom -
              48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Selected emotion display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedEmotion!.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedEmotion!.color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _selectedEmotion!.emoji,
                    style: TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Naramdaman: ${_selectedEmotion!.name}',
                    style: TextStyle(
                      color: _selectedEmotion!.color,
                      fontSize: themeProvider.getRealFontSize(18),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Gaano kalakas ang inyong damdamin?',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: themeProvider.getRealFontSize(20),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Intensity options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(intensityLevels.length, (index) {
                final level = intensityLevels[index];
                final emoji = intensityEmojis[index];
                final color = intensityColors[index];
                final isSelected = _selectedIntensity == level;

                return Flexible(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSelected ? _pulseAnimation.value : 1.0,
                        child: GestureDetector(
                          onTap: () => _selectIntensity(level),
                          child: Container(
                            width: 90,
                            height: 110,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : theme.accentColor.withOpacity(0.3),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  emoji,
                                  style: TextStyle(fontSize: 32),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  level,
                                  style: TextStyle(
                                    color: isSelected ? color : theme.textColor,
                                    fontSize: themeProvider.getRealFontSize(12),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontFamily: themeProvider.fontFamily,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),

            const SizedBox(height: 48),

            // Complete button
            if (_selectedIntensity != null)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _completeReflection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.name == 'Blue' ? const Color(0xFF4CAF50) : _selectedEmotion!.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'TAPUSIN ANG REFLECTION',
                    style: TextStyle(
                      fontSize: themeProvider.getRealFontSize(18),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

 Widget _buildCompletionStep(AppThemeData theme, ThemeProvider themeProvider) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(24.0),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top -
            MediaQuery.of(context).padding.bottom -
            48,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success animation
          AnimatedBuilder(
            animation: _characterAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _characterAnimation.value),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.withOpacity(0.3),
                        Colors.green.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '🎉',
                      style: TextStyle(fontSize: 80),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          Text(
            'Salamat sa Pagbabahagi!',
            style: TextStyle(
              color: Colors.green,
              fontSize: themeProvider.getRealFontSize(24),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          if (_selectedEmotion != null && _selectedIntensity != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedEmotion!.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedEmotion!.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Naramdaman ninyo: ${_selectedEmotion!.name}',
                    style: TextStyle(
                      color: _selectedEmotion!.color,
                      fontSize: themeProvider.getRealFontSize(16),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lakas: $_selectedIntensity',
                    style: TextStyle(
                      color: theme.textColor.withOpacity(0.8),
                      fontSize: themeProvider.getRealFontSize(14),
                      fontFamily: themeProvider.fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Text(
            'Ang iyong damdamin ay mahalaga at nakakatulong sa inyong guro na mas maintindihan kayo.',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.8),
              fontSize: themeProvider.getRealFontSize(14),
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),
          
          // Manual back to home button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                // Get reading level from AuthProvider for navigation
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final readingLevel = authProvider.currentUser?.readingLevel ?? 'Undefined';
                
                // Play button sound
                _playButtonSound();
                
                if (widget.onComplete != null) {
                  print('Using provided onComplete callback to navigate');
                  widget.onComplete!();
                } else {
                  print('No onComplete callback provided, navigating directly to HomeScreen');
                  Navigator.of(context).pushReplacementNamed(
                    AppRouter.home,
                    arguments: {'readingLevel': readingLevel},
                  );
                }
              },
              icon: Icon(Icons.home_rounded),
              label: Text(
                'BACK TO HOME',
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(18),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.name == 'Blue' ? const Color(0xFF4CAF50) : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  @override
  void dispose() {
    _characterController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    _typewriterTimer?.cancel();

    // Stop any ongoing TTS when leaving
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
    }

    super.dispose();
  }
}

// Emotion data models
class EmotionData {
  final String name;
  final String emoji;
  final String category;
  final String description;
  final Color color;

  const EmotionData({
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
    required this.color,
  });
}

// Predefined emotion categories
final List<EmotionData> emotionCategories = [
  EmotionData(
    name: 'Masaya',
    emoji: '😊',
    category: 'positive',
    description: 'Natutuwa, nasisiyahan',
    color: Colors.green,
  ),
  EmotionData(
    name: 'Excited',
    emoji: '🤩',
    category: 'positive',
    description: 'Sabik, enthusiastic',
    color: Colors.orange,
  ),
  EmotionData(
    name: 'Nahihirapan',
    emoji: '😰',
    category: 'challenging',
    description: 'Mahirap, nakakastress',
    color: Colors.amber,
  ),
  EmotionData(
    name: 'Nalilito',
    emoji: '😕',
    category: 'challenging',
    description: 'Hindi maintindihan',
    color: Colors.brown,
  ),
  EmotionData(
    name: 'Confident',
    emoji: '😎',
    category: 'positive',
    description: 'Sigurado sa sarili',
    color: Colors.blue,
  ),
  EmotionData(
    name: 'Worried',
    emoji: '😟',
    category: 'challenging',
    description: 'Nag-aalala, nervous',
    color: Colors.red,
  ),
];
