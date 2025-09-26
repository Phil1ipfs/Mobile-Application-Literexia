// lib/features/interventions/ui/intervention_assessment_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/intervention/logic/intervention_provider.dart';
import 'package:literexia/features/intervention/model/intervention_model.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:confetti/confetti.dart';

class InterventionAssessmentScreen extends StatefulWidget {
  const InterventionAssessmentScreen({Key? key}) : super(key: key);

  @override
  State<InterventionAssessmentScreen> createState() =>
      _InterventionAssessmentScreenState();
}

class _InterventionAssessmentScreenState
    extends State<InterventionAssessmentScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _selectedOptionId;
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackDescription = '';

  // Audio players
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _correctAnswerPlayer = AudioPlayer();
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _incorrectAnswerPlayer = AudioPlayer();

  // TTS state
  bool _isTTSPlaying = false;
  String? _currentPlayingOptionId;
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Confetti controller for celebration animation
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Initialize providers and audio after the build is complete
    Future.microtask(() {
      if (mounted) {
        _initializeScreen();
      }
    });
  }

  Future<void> _initializeScreen() async {
    // Get providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final interventionProvider =
        Provider.of<InterventionProvider>(context, listen: false);
    _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
    _themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Start background music
    _startBackgroundMusic();

    // Check if the user has any interventions
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';

    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    await interventionProvider.checkInterventionStatus(userId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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

      print(
          '[InterventionAssessmentScreen] Background music started successfully');
    } catch (e) {
      print('[InterventionAssessmentScreen] Background music error: $e');
    }
  }

  void _pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
      print('[InterventionAssessmentScreen] Background music paused');
    } catch (e) {
      print('[InterventionAssessmentScreen] Error pausing music: $e');
    }
  }

  void _resumeBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.play();
      print('[InterventionAssessmentScreen] Background music resumed');
    } catch (e) {
      print('[InterventionAssessmentScreen] Error resuming music: $e');
    }
  }

  void _playButtonAudio() async {
    try {
      await _audioPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print('[InterventionAssessmentScreen] Button sound error: $e');
    }
  }

  void _playCorrectAnswerSound() async {
    try {
      // Reset player to ensure clean playback
      await _correctAnswerPlayer.stop();

      // Load and play the assessment sound
      await _correctAnswerPlayer.setAsset('assets/audio/assessmentsound.mp3');

      // Temporarily lower background music volume
      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer.setVolume(currentVolume * 0.3);

      // Play the sound
      await _correctAnswerPlayer.play();

      // Start fireworks animation
      _confettiController.play();

      // Restore background music volume after sound plays
      _correctAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
        }
      });
    } catch (e) {
      print('[InterventionAssessmentScreen] Correct answer sound error: $e');
    }
  }

  void _playIncorrectAnswerSound() async {
    try {
      // Reset player to ensure clean playback
      await _incorrectAnswerPlayer.stop();

      // Load and play the wrong answer sound
      await _incorrectAnswerPlayer.setAsset('assets/audio/wronganswer.mp3');

      // Temporarily lower background music volume
      double currentVolume = _backgroundMusicPlayer.volume;
      await _backgroundMusicPlayer.setVolume(currentVolume * 0.3);

      // Play the sound
      await _incorrectAnswerPlayer.play();

      // Restore background music volume after sound plays
      _incorrectAnswerPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _backgroundMusicPlayer.setVolume(currentVolume);
        }
      });
    } catch (e) {
      print('[InterventionAssessmentScreen] Incorrect answer sound error: $e');
    }
  }

  void _selectOption(String optionId) {
    final interventionProvider =
        Provider.of<InterventionProvider>(context, listen: false);
    final currentQuestion = interventionProvider.currentQuestion;

    if (currentQuestion == null) return;

    // Find the selected option
    final selectedOption = currentQuestion.choices.firstWhere(
      (option) => option.id == optionId,
      orElse: () => InterventionChoice(
        optionText: '',
        isCorrect: false,
        description: '',
      ),
    );

    // Get the description from the selected option
    String description = selectedOption.description;

    // If no description is available, use a generic one based on correctness
    if (description.isEmpty) {
      if (selectedOption.isCorrect) {
        description = 'Ito ang tamang sagot.';
      } else {
        // Try to find the correct answer for reference
        final correctOption = currentQuestion.choices.firstWhere(
          (option) => option.isCorrect,
          orElse: () => InterventionChoice(
            optionText: '',
            isCorrect: false,
            description: '',
          ),
        );
        description =
            'Hindi ito ang tamang sagot. Ang tamang sagot ay: ${correctOption.optionText}';
      }
    }

    // Save the answer in the provider (this now captures timing automatically)
    interventionProvider.answerQuestion(currentQuestion.questionId, optionId);

    // Set state to show feedback
    setState(() {
      _selectedOptionId = optionId;
      _showFeedback = true;
      _isCorrectAnswer = selectedOption.isCorrect;
      _feedbackDescription = description;
    });

    // Play appropriate sound effect
    if (selectedOption.isCorrect) {
      _playCorrectAnswerSound();
    } else {
      _playIncorrectAnswerSound();
    }
  }

  void _goToNextStep() {
    _playButtonAudio();

    final interventionProvider =
        Provider.of<InterventionProvider>(context, listen: false);

    // If showing feedback, hide it and continue
    if (_showFeedback) {
      setState(() {
        _showFeedback = false;
      });

      // Check if this was the last question
      if (interventionProvider.currentQuestionIndex ==
          interventionProvider.currentIntervention!.questions.length - 1) {
        // This is the last question - complete the intervention
        // First, ensure the provider calculates the score
        interventionProvider.completeIntervention();
        // Then handle the UI completion
        _handleInterventionComplete();
      } else {
        // Move to the next question
        interventionProvider.goToNextQuestion();
      }

      return;
    }

    // If a choice is selected, show feedback
    if (_selectedOptionId != null) {
      // Find the selected option to get feedback
      final currentQuestion = interventionProvider.currentQuestion;
      if (currentQuestion == null) return;

      final selectedOption = currentQuestion.choices.firstWhere(
        (option) => option.id == _selectedOptionId,
        orElse: () => InterventionChoice(
          optionText: '',
          isCorrect: false,
          description: '',
        ),
      );

      // Show feedback
      setState(() {
        _showFeedback = true;
        _isCorrectAnswer = selectedOption.isCorrect;
        _feedbackDescription = selectedOption.description.isNotEmpty
            ? selectedOption.description
            : (selectedOption.isCorrect
                ? 'Ito ang tamang sagot!'
                : 'Hindi ito ang tamang sagot.');
      });

      // Play appropriate sound
      if (selectedOption.isCorrect) {
        _playCorrectAnswerSound();
      } else {
        _playIncorrectAnswerSound();
      }
    }
  }

  Future<void> _handleInterventionComplete() async {
    print('[INTERVENTION] Starting completion process');

    final interventionProvider =
        Provider.of<InterventionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Save the intervention results
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';
    final studentNumber = authProvider.currentUser?.idNumber.toString() ?? '';

    print('[INTERVENTION] UserID: $userId, Score: ${interventionProvider.score}%, Answers: ${interventionProvider.userAnswers.length}');

    if (userId.isEmpty) {
      print('[INTERVENTION] ERROR: No user ID');
      return;
    }

    // Save results
    final success = await interventionProvider.saveInterventionResults(
        userId, studentNumber);

    print('[INTERVENTION] Save result: $success');

    // Pause background music before navigating
    _pauseBackgroundMusic();

    // Show completion dialog instead of navigating to result screen
    _showCompletionDialog(
        interventionProvider.score, interventionProvider.isPassed);
  }

  void _showCompletionDialog(double score, bool isPassed) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.currentTheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: isPassed ? Colors.green : Colors.red,
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isPassed ? Colors.green : Colors.red,
                      fontFamily: themeProvider.fontFamily,
                      fontSize: themeProvider.getRealFontSize(20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isPassed ? 'PASSED' : 'FAILED',
                    style: TextStyle(
                      color: isPassed ? Colors.green : Colors.red,
                      fontFamily: themeProvider.fontFamily,
                      fontSize: themeProvider.getRealFontSize(10),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPassed
                  ? 'Napagtagumpayan mo ang intervention!'
                  : 'Hindi mo pa napagtagumpayan ang intervention.',
              style: TextStyle(
                color: isPassed ? Colors.green : Colors.red,
                fontSize: themeProvider.getRealFontSize(18),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          isPassed
              ? 'Mahusay! Nagpakita ka ng mahusay na pag-unawa.'
              : 'Kailangan mo ng karagdagang pagsasanay. Subukan muli!',
          style: TextStyle(
            color: theme.textColor.withOpacity(0.8),
            fontSize: themeProvider.getRealFontSize(16),
            fontFamily: themeProvider.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.buttonTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'BUMALIK SA HOME',
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ),
          if (!isPassed) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Reset the assessment to try again
                  final interventionProvider =
                      Provider.of<InterventionProvider>(context, listen: false);
                  interventionProvider.resetIntervention();
                  setState(() {
                    _selectedOptionId = null;
                    _showFeedback = false;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accentColor,
                  side: BorderSide(color: theme.accentColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'SUBUKAN MULI',
                  style: TextStyle(
                    fontSize: themeProvider.getRealFontSize(16),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final interventionProvider = Provider.of<InterventionProvider>(context);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: theme.headerColor,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? _buildLoadingState(theme, themeProvider)
                : _buildMainContent(interventionProvider, theme, themeProvider),
          ),
          // Add confetti controller for fireworks animation
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -1.0, // Emit downward
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              maxBlastForce: 15,
              minBlastForce: 5,
              gravity: 0.1,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppThemeData theme, ThemeProvider themeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading intervention assessments...',
            style: TextStyle(
              color: theme.textColor,
              fontFamily: themeProvider.fontFamily,
              fontSize: themeProvider.getRealFontSize(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(InterventionProvider interventionProvider,
      AppThemeData theme, ThemeProvider themeProvider) {
    // Check for failed categories but no interventions
    if (interventionProvider.hasFailedCategories &&
        !interventionProvider.hasInterventions) {
      return _buildWaitForTeacherMessage(
          theme, themeProvider, interventionProvider);
    }

    // Check if user has any interventions
    if (!interventionProvider.hasInterventions) {
      return _buildNoInterventionsMessage(theme, themeProvider);
    }

    // Check if an intervention is selected
    if (interventionProvider.currentIntervention == null) {
      return _buildSelectInterventionScreen(
          interventionProvider, theme, themeProvider);
    }

    // Show the current question
    return _buildQuestionContent(interventionProvider, theme, themeProvider);
  }

  Widget _buildWaitForTeacherMessage(AppThemeData theme,
      ThemeProvider themeProvider, InterventionProvider interventionProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pending_actions,
                color: Colors.orange,
                size: 80,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Maghintay sa inyong guro',
              style: TextStyle(
                color: theme.textColor,
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(24),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Kailangan ninyo ng intervention para sa inyong mga kategorya. Makipag-ugnayan sa inyong guro para sa karagdagang impormasyon.',
              style: TextStyle(
                color: theme.textColor.withOpacity(0.8),
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(16),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Text(
              'Mga kategoryang kailangan ng intervention:',
              style: TextStyle(
                color: theme.textColor,
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...interventionProvider.failedCategories.map((category) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: themeProvider.fontFamily,
                        fontSize: themeProvider.getRealFontSize(16),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInterventionsMessage(
      AppThemeData theme, ThemeProvider themeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule,
                color: Colors.orange,
                size: 80,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Maghintay para sa Intervention',
              style: TextStyle(
                color: theme.textColor,
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(24),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Wala pang available na intervention assessment para sa inyo. Makipag-ugnayan sa inyong guro para sa karagdagang impormasyon.',
              style: TextStyle(
                color: theme.textColor.withOpacity(0.8),
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(16),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.arrow_back),
              label: Text(
                'Bumalik sa Home',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: themeProvider.getRealFontSize(16),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectInterventionScreen(
      InterventionProvider interventionProvider,
      AppThemeData theme,
      ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Piliin ang Intervention Assessment',
            style: TextStyle(
              color: theme.textColor,
              fontFamily: themeProvider.fontFamily,
              fontSize: themeProvider.getRealFontSize(20),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Piliin ang intervention para sa kategoryang nais ninyong pagbutihin.',
            style: TextStyle(
              color: theme.textColor.withOpacity(0.8),
              fontFamily: themeProvider.fontFamily,
              fontSize: themeProvider.getRealFontSize(16),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: interventionProvider.interventions.length,
              itemBuilder: (context, index) {
                final intervention = interventionProvider.interventions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      interventionProvider.selectIntervention(intervention.id);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      _getCategoryColor(intervention.category)
                                          .withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getCategoryIcon(intervention.category),
                                  color:
                                      _getCategoryColor(intervention.category),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      intervention.name,
                                      style: TextStyle(
                                        color: theme.textColor,
                                        fontFamily: themeProvider.fontFamily,
                                        fontSize:
                                            themeProvider.getRealFontSize(18),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Category: ${intervention.category}',
                                      style: TextStyle(
                                        color: _getCategoryColor(
                                            intervention.category),
                                        fontFamily: themeProvider.fontFamily,
                                        fontSize:
                                            themeProvider.getRealFontSize(14),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            intervention.description,
                            style: TextStyle(
                              color: theme.textColor.withOpacity(0.8),
                              fontFamily: themeProvider.fontFamily,
                              fontSize: themeProvider.getRealFontSize(14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reading Level: ${intervention.readingLevel}',
                                style: TextStyle(
                                  color: theme.textColor.withOpacity(0.7),
                                  fontFamily: themeProvider.fontFamily,
                                  fontSize: themeProvider.getRealFontSize(14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${intervention.questions.length} Questions',
                                  style: TextStyle(
                                    color: theme.accentColor,
                                    fontFamily: themeProvider.fontFamily,
                                    fontSize: themeProvider.getRealFontSize(12),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(InterventionProvider interventionProvider,
      AppThemeData theme, ThemeProvider themeProvider) {
    final currentQuestion = interventionProvider.currentQuestion;

    if (currentQuestion == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No questions available',
              style: TextStyle(
                color: theme.textColor,
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This intervention may not be properly configured.\nPlease contact your teacher.',
              style: TextStyle(
                color: theme.textColor.withOpacity(0.7),
                fontFamily: themeProvider.fontFamily,
                fontSize: themeProvider.getRealFontSize(14),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back'),
            ),
          ],
        ),
      );
    }

    // Log question info for debugging
    if (currentQuestion.choices.isEmpty && currentQuestion.questionType != 'patinig' && currentQuestion.questionType != 'katinig') {
      print('[InterventionAssessmentScreen] Unsupported question type: ${currentQuestion.questionType}');
    }

    return Column(
      children: [
        // Progress indicator
        _buildProgressIndicator(interventionProvider, theme, themeProvider),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _showFeedback
                ? _buildFeedbackContent(
                    theme, themeProvider) // Show feedback when answer selected
                : ListView(
                    children: [
                      const SizedBox(height: 10),

                      // Question text
                      _buildQuestionText(
                          currentQuestion.questionText, theme, themeProvider),

                      // Question image if available
                      if (currentQuestion.questionImage != null &&
                          currentQuestion.questionImage!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              currentQuestion.questionImage!,
                              fit: BoxFit.contain,
                              height: 150,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 150,
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image,
                                    color: Colors.grey, size: 40),
                              ),
                            ),
                          ),
                        ),

                      // Question value (displayed text)
                      if (currentQuestion.questionValue != null &&
                          currentQuestion.questionValue!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: theme.accentColor),
                          ),
                          child: Center(
                            child: Text(
                              currentQuestion.questionValue!,
                              style: TextStyle(
                                color: theme.accentColor,
                                fontSize: themeProvider.getRealFontSize(40),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Answer options
                      if (currentQuestion.choices.isNotEmpty)
                        ...currentQuestion.choices
                            .map((choice) => _buildOptionButton(
                                  choice,
                                  choice.id ?? '',
                                  theme,
                                  themeProvider,
                                ))
                      else
                        // Show message for questions without choices
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                              const SizedBox(height: 12),
                              Text(
                                'Question Type: ${currentQuestion.questionType}',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontSize: themeProvider.getRealFontSize(16),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: themeProvider.fontFamily,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This question type is not yet supported in the mobile app. Please use a computer or contact your teacher.',
                                style: TextStyle(
                                  color: theme.textColor.withOpacity(0.8),
                                  fontSize: themeProvider.getRealFontSize(14),
                                  fontFamily: themeProvider.fontFamily,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Skip this question for now
                                  final interventionProvider = Provider.of<InterventionProvider>(context, listen: false);
                                  // Mark as answered with a placeholder to avoid blocking progress
                                  interventionProvider.answerQuestion(currentQuestion.questionId, 'SKIPPED');
                                  _goToNextStep();
                                },
                                child: Text('Skip Question'),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Continue button
                      _buildContinueButton(
                          interventionProvider, theme, themeProvider),

                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(InterventionProvider provider,
      AppThemeData theme, ThemeProvider themeProvider) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.currentIntervention?.questions.length ?? 0;

    // Calculate the total width and the position for the progress pill
    final totalWidth =
        MediaQuery.of(context).size.width - 40; // 40 for left and right margins
    final progressRatio = current / total;

    // Calculate the position of the pill
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Stack(
        children: [
          // Background track
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Progress indicator - filled portion
          FractionallySizedBox(
            widthFactor: progressRatio,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Position the pill based on progress
          Positioned(
            left: progressRatio < 0.1
                ? 0
                : progressRatio > 0.9
                    ? totalWidth - pillWidth
                    : pillPosition,
            top: 0,
            child: Container(
              height: 40,
              width: pillWidth,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$current/$total',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                    fontSize: themeProvider.getRealFontSize(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionText(
      String text, AppThemeData theme, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.accentColor, width: 1),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          if (_ttsProvider?.isAvailable == true) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isTTSPlaying ? _stopTTS : () => _speakText(text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: _isTTSPlaying
                            ? Colors.red.withOpacity(0.15)
                            : theme.accentColor.withOpacity(0.15),
                        border: Border.all(
                          color: _isTTSPlaying ? Colors.red : theme.accentColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isTTSPlaying
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: _isTTSPlaying ? 22 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isTTSPlaying ? 'Ihinto' : 'Pakinggan',
                            style: TextStyle(
                              fontSize: themeProvider.getRealFontSize(14),
                              fontWeight: FontWeight.w600,
                              fontFamily: themeProvider.fontFamily,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton(InterventionChoice option, String optionId,
      AppThemeData theme, ThemeProvider themeProvider) {
    final isSelected = _selectedOptionId == optionId;
    final isThisOptionPlaying =
        _isTTSPlaying && _currentPlayingOptionId == optionId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _selectOption(optionId),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.accentColor, width: 2),
            borderRadius: BorderRadius.circular(30),
            color: isSelected
                ? theme.accentColor
                : theme.accentColor.withOpacity(0.4),
          ),
          child: Row(
            children: [
              // Option text
              Expanded(
                child: Text(
                  option.optionText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: themeProvider.getRealFontSize(18),
                    fontWeight: FontWeight.bold,
                    fontFamily: themeProvider.fontFamily,
                  ),
                ),
              ),

              // Enhanced TTS button for the option
              if (_ttsProvider?.isAvailable == true)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isThisOptionPlaying
                          ? _stopTTS
                          : () => _speakOptionText(option.optionText, optionId),
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isThisOptionPlaying
                              ? Colors.red
                              : theme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: (isThisOptionPlaying
                                      ? Colors.red
                                      : theme.accentColor)
                                  .withOpacity(0.3),
                              blurRadius: isThisOptionPlaying ? 8 : 0,
                              spreadRadius: isThisOptionPlaying ? 2 : 0,
                            ),
                          ],
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isThisOptionPlaying
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: isThisOptionPlaying ? 24 : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(InterventionProvider provider, AppThemeData theme,
      ThemeProvider themeProvider) {
    final isButtonEnabled = _selectedOptionId != null;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _goToNextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isButtonEnabled ? theme.accentColor : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade600,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          'MAG PATULOY',
          style: TextStyle(
            fontSize: themeProvider.getRealFontSize(18),
            fontWeight: FontWeight.bold,
            color:
                isButtonEnabled ? theme.buttonTextColor : Colors.grey.shade800,
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackContent(
      AppThemeData theme, ThemeProvider themeProvider) {
    // Colors for feedback
    final Color backgroundColor = _isCorrectAnswer
        ? const Color(0xFFE3FFEC) // Light green for correct
        : const Color(0xFFFFF0F0); // Light red for incorrect

    final Color textColor = _isCorrectAnswer ? Colors.green : Colors.red;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Feedback card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
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
              // Feedback header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCorrectAnswer ? Colors.green : Colors.red,
                    ),
                    child: Icon(
                      _isCorrectAnswer ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isCorrectAnswer ? 'Tama!' : 'Mali!',
                    style: TextStyle(
                      color: textColor,
                      fontSize: themeProvider.getRealFontSize(32),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Explanation text
              Text(
                _feedbackDescription,
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  color: Colors.black87,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _goToNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'MAG PATULOY',
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
      ],
    );
  }

  // TTS functionality for main text
  void _speakText(String text) {
    if (!mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null && _ttsProvider!.isAvailable) {
      // Reset playing option ID
      _currentPlayingOptionId = null;

      _ttsProvider!.speakText(
        text,
        speed: 0.4, // Explicitly set slower speed
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
      print('TTS not available or enabled');
    }
  }

  // TTS functionality for option text
  void _speakOptionText(String text, String optionId) {
    if (!mounted) return;

    // Check if TTS is available and enabled
    if (_ttsProvider != null && _ttsProvider!.isAvailable) {
      _ttsProvider!.speakText(
        text,
        speed: 0.4, // Explicitly set slower speed
        onStart: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = true;
              _currentPlayingOptionId = optionId;
            });
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _currentPlayingOptionId = null;
            });
          }
        },
        onError: () {
          // Handle error silently
          print('TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
              _currentPlayingOptionId = null;
            });
          }
        },
      );
    } else {
      print('TTS not available or enabled');
    }
  }

  // Stop any ongoing TTS
  void _stopTTS() {
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
      setState(() {
        _isTTSPlaying = false;
        _currentPlayingOptionId = null;
      });
    }
  }

  // Helper function to get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Alphabet Knowledge':
        return Colors.blue;
      case 'Phonological Awareness':
        return Colors.purple;
      case 'Decoding':
        return Colors.orange;
      case 'Word Recognition':
        return Colors.green;
      case 'Reading Comprehension':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  // Helper function to get category icon
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Alphabet Knowledge':
        return Icons.abc;
      case 'Phonological Awareness':
        return Icons.record_voice_over;
      case 'Decoding':
        return Icons.translate;
      case 'Word Recognition':
        return Icons.text_fields;
      case 'Reading Comprehension':
        return Icons.menu_book;
      default:
        return Icons.school;
    }
  }

  @override
  void dispose() {
    // ... existing code ...
  }
}
