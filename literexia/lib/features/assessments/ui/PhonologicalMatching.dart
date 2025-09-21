import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:literexia/features/settings/provider/tts_provider.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/ui/DecodingScreen.dart';
import '../../../Tutorial/Decoding_tutorial.dart';
import 'package:literexia/features/assessments/ui/WordRecognitionScreen.dart';
import 'pre_assessment_result_screen.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:literexia/features/auth/logic/auth_provider.dart';
import 'package:literexia/screens/home_screen.dart';

class PhonologicalMatchingScreen extends StatefulWidget {
  final String assessmentId;
  final Function(String optionId)? onOptionSelected;
  final Function()? onContinue;
  final bool isPreAssessment; // Added parameter

  const PhonologicalMatchingScreen({
    Key? key,
    required this.assessmentId,
    this.onOptionSelected,
    this.onContinue,
    this.isPreAssessment = false, // Default to main assessment
  }) : super(key: key);

  @override
  State<PhonologicalMatchingScreen> createState() =>
      _PhonologicalMatchingScreenState();
}

class _PhonologicalMatchingScreenState extends State<PhonologicalMatchingScreen>
    with TickerProviderStateMixin {
  // Audio players
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _buttonAudioPlayer = AudioPlayer();
  final AudioPlayer _correctSoundPlayer = AudioPlayer();
  final AudioPlayer _buttonSoundPlayer = AudioPlayer();
  final AudioPlayer _wrongSoundPlayer = AudioPlayer();

  // Confetti controllers for fireworks animation
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // TTS state for question text
  bool _isTTSPlaying = false;
  TTSProvider? _ttsProvider;
  ThemeProvider? _themeProvider;

  // Typewriter effect state
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  String _displayedText = '';
  String _fullQuestionText = '';

  // Flow control state
  bool _typewriterCompleted = false;
  bool _showTTSButton = false;
  bool _showImage = false;
  bool _showChoices = false;
  bool _userListened = false;

  // Heartbeat animation for TTS button
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  // Wave animation for audio buttons
  AnimationController? _waveController;
  Animation<double>? _waveAnimation;

  // Assessment data from database
  List<String> _audioTexts = [];
  List<String> _matchingOptions = [];
  List<Map<String, dynamic>> _correctPairs = [];
  String _questionText = '';
  bool _isLoading = true;
  String? _errorMessage;

  // Sequential logic state - CRITICAL IMPLEMENTATION
  int _currentAudioIndex = 0; // Current active audio (0-based)
  List<String> _selectedChoices =
      []; // Tracks what user selected for each audio
  Set<String> _usedOptions =
      {}; // Tracks which options have been used (can't be selected again)
  bool _isCurrentQuestionAnswered =
      false; // Has user selected an answer for current audio?
  int? _currentPlayingAudioIndex; // Which audio is currently playing?

  // Feedback and validation state
  bool _showFeedback = false;
  bool _isCorrectAnswer = false;
  String _feedbackMessage = '';
  bool _allAudiosCompleted = false;

  // Track which audio items are fully completed after pressing PAKITSEK
  final Set<int> _completedAudios = {};
  // Track per-audio correctness after pressing PAKITSEK
  final Map<int, bool> _audioResults = {};

  // Dynamically normalize questionSet structure from MongoDB into a consistent format
  Map<String, dynamic> _normalizeQuestionSet(Map<String, dynamic> raw) {
    print(
        '[PhonologicalMatching] ===== DYNAMIC NORMALIZATION FROM MONGODB =====');
    print('[PhonologicalMatching] Raw data keys: ${raw.keys.toList()}');
    print('[PhonologicalMatching] Raw data: $raw');

    // Dynamically find correct pairs with multiple possible field names
    final List<dynamic> rawPairs = _extractDynamicPairs(raw);
    final List<Map<String, String>> normalizedPairs = [];

    for (final item in rawPairs) {
      if (item is Map) {
        final pairMap = _normalizePairItem(item);
        if (pairMap != null) {
          normalizedPairs.add(pairMap);
        }
      } else if (item is String) {
        // Handle single string items - might be in format "key:value"
        if (item.contains(':')) {
          final parts = item.split(':');
          if (parts.length == 2) {
            normalizedPairs.add({
              'audio': parts[0].trim(),
              'match': parts[1].trim(),
            });
          }
        }
      }
    }

    // Dynamically extract audio texts with multiple possible field names
    List<String> audioTexts = _extractDynamicList(
        raw, ['audioTexts', 'audio', 'sounds', 'audioItems', 'audioOptions']);

    // Dynamically extract matching options with multiple possible field names
    List<String> matchingOptions = _extractDynamicList(
        raw, ['matchingOptions', 'options', 'choices', 'matches', 'answers']);

    // If no audio texts found, try to extract from pairs
    if (audioTexts.isEmpty && normalizedPairs.isNotEmpty) {
      audioTexts = normalizedPairs
          .map((pair) => pair['audio'] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // If no matching options found, try to extract from pairs
    if (matchingOptions.isEmpty && normalizedPairs.isNotEmpty) {
      matchingOptions = normalizedPairs
          .map((pair) => pair['match'] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Update normalizedPairs to use the actual matching options for validation
    if (normalizedPairs.isNotEmpty && matchingOptions.isNotEmpty) {
      for (int i = 0;
          i < normalizedPairs.length && i < matchingOptions.length;
          i++) {
        normalizedPairs[i]['match'] = matchingOptions[i];
      }
    }

    // SHUFFLE BOTH AUDIO AND CHOICES dynamically to make it more challenging
    final shuffledAudioTexts = List<String>.from(audioTexts);
    final shuffledMatchingOptions = List<String>.from(matchingOptions);

    shuffledAudioTexts.shuffle(Random());
    shuffledMatchingOptions.shuffle(Random());

    print('[PhonologicalMatching] Dynamic audio texts: $audioTexts');
    print('[PhonologicalMatching] Shuffled audio: $shuffledAudioTexts');
    print('[PhonologicalMatching] Dynamic matching options: $matchingOptions');
    print('[PhonologicalMatching] Shuffled choices: $shuffledMatchingOptions');
    print('[PhonologicalMatching] Normalized pairs: $normalizedPairs');
    print('[PhonologicalMatching] ===== END DYNAMIC NORMALIZATION =====');

    return {
      'audioTexts': shuffledAudioTexts,
      'matchingOptions': shuffledMatchingOptions,
      'correctPairs': normalizedPairs,
    };
  }

  // Extract dynamic pairs with flexible field names
  List<dynamic> _extractDynamicPairs(Map<String, dynamic> raw) {
    final possibleFields = [
      'correctPairs',
      'pairs',
      'matches',
      'answers',
      'mapping'
    ];

    for (String field in possibleFields) {
      if (raw.containsKey(field) && raw[field] is List) {
        return raw[field] as List;
      }
    }

    // Try to find object-style mapping
    for (String field in possibleFields) {
      if (raw.containsKey(field) && raw[field] is Map) {
        final mapData = raw[field] as Map;
        return mapData.entries
            .map((entry) => {
                  'audio': entry.key.toString(),
                  'match': entry.value.toString()
                })
            .toList();
      }
    }

    return [];
  }

  // Normalize individual pair item dynamically
  Map<String, String>? _normalizePairItem(Map item) {
    String? audio;
    String? match;

    // Try different field names for audio
    final audioFields = ['audio', 'sound', 'audioText', 'key', 'from'];
    for (String field in audioFields) {
      if (item.containsKey(field)) {
        audio = item[field].toString();
        break;
      }
    }

    // Try different field names for match
    final matchFields = ['match', 'option', 'choice', 'answer', 'to', 'value'];
    for (String field in matchFields) {
      if (item.containsKey(field)) {
        match = item[field].toString();
        break;
      }
    }

    // Handle single key-value pair
    if (audio == null && match == null && item.length == 1) {
      final entry = item.entries.first;
      audio = entry.key.toString();
      match = entry.value.toString();
    }

    if (audio != null && match != null) {
      return {'audio': audio, 'match': match};
    }

    return null;
  }

  // Extract dynamic list with multiple possible field names
  List<String> _extractDynamicList(
      Map<String, dynamic> raw, List<String> possibleFields) {
    for (String field in possibleFields) {
      if (raw.containsKey(field) && raw[field] is List) {
        try {
          return List<String>.from(
              (raw[field] as List).map((e) => e.toString()));
        } catch (e) {
          print('[PhonologicalMatching] Error parsing $field as list: $e');
        }
      }
    }
    return [];
  }

  // Dynamically load current question data from provider without reloading assessment
  void _loadCurrentQuestionDataFromProvider() {
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final currentQuestion = assessmentProvider.currentQuestion;
      print(
          '[PhonologicalMatching] [NextQ] Dynamic provider.currentQuestionIndex='
          '${assessmentProvider.currentQuestionIndex} of '
          '${assessmentProvider.assessment?.questions.length ?? 0}');
      if (currentQuestion == null) {
        return;
      }

      // Prefer original question data for reliable questionSet from MongoDB
      final originalData = assessmentProvider
          .getOriginalQuestionData(currentQuestion.questionId);

      Map<String, dynamic>? questionSet;
      String source = 'none';

      if (originalData != null) {
        // Try multiple field names for questionSet dynamically
        final possibleFields = [
          'questionSet',
          'data',
          'content',
          'phonologicalData'
        ];

        for (String field in possibleFields) {
          if (originalData.containsKey(field) && originalData[field] != null) {
            questionSet = Map<String, dynamic>.from(originalData[field]);
            source = 'originalData.$field';
            break;
          }
        }

        // If no specific questionSet field found, use originalData itself
        if (questionSet == null) {
          questionSet = Map<String, dynamic>.from(originalData);
          source = 'originalData.direct';
        }
      } else if (currentQuestion.questionSet != null) {
        questionSet = currentQuestion.questionSet!;
        source = 'currentQuestion.questionSet';
      }

      if (questionSet != null) {
        print('[PhonologicalMatching] ===== DYNAMIC NEXT QUESTION DATA =====');
        print('[PhonologicalMatching] Source: $source');
        print('[PhonologicalMatching] QuestionSet: $questionSet');

        final Map<String, dynamic> firstMap =
            Map<String, dynamic>.from(questionSet as Map);
        final normalized = _normalizeQuestionSet(firstMap);

        // Dynamic fallback validation
        List<Map<String, dynamic>> normalizedPairs =
            List<Map<String, dynamic>>.from(normalized['correctPairs'] ?? []);

        if (normalizedPairs.length < 2) {
          // Adjusted threshold for dynamic data
          print(
              '[PhonologicalMatching] Dynamic fallback needed - insufficient pairs: ${normalizedPairs.length}');
          try {
            final provider =
                Provider.of<AssessmentProvider>(context, listen: false);
            final alt =
                provider.getOriginalQuestionData(currentQuestion.questionId);
            if (alt != null) {
              // Try different questionSet fields in fallback
              for (String field in ['questionSet', 'data', 'content']) {
                if (alt.containsKey(field) && alt[field] != null) {
                  final altNorm = _normalizeQuestionSet(
                      Map<String, dynamic>.from(alt[field] as Map));
                  final altPairs = List<Map<String, dynamic>>.from(
                      altNorm['correctPairs'] ?? []);
                  if (altPairs.length > normalizedPairs.length) {
                    print('[PhonologicalMatching] Dynamic fallback successful '
                        'for ${currentQuestion.questionId}: '
                        '${altPairs.length} pairs vs ${normalizedPairs.length}');
                    questionSet = Map<String, dynamic>.from(alt[field] as Map);
                    source = 'fallback.$field';
                    break;
                  }
                }
              }
            }
          } catch (e) {
            print('[PhonologicalMatching] Dynamic fallback check error: $e');
          }
        }

        final Map<String, dynamic> finalMap =
            Map<String, dynamic>.from(questionSet as Map);
        final finalNormalized = _normalizeQuestionSet(finalMap);
        final normAudio =
            (finalNormalized['audioTexts'] as List?)?.length ?? -1;
        final normOpts =
            (finalNormalized['matchingOptions'] as List?)?.length ?? -1;
        final normPairs =
            (finalNormalized['correctPairs'] as List?)?.length ?? -1;
        print('[PhonologicalMatching] DYNAMIC NORMALIZED ($source) lengths: '
            'audioTexts=$normAudio, options=$normOpts, pairs=$normPairs');

        setState(() {
          _audioTexts = List<String>.from(finalNormalized['audioTexts'] ?? []);
          _matchingOptions =
              List<String>.from(finalNormalized['matchingOptions'] ?? []);
          _correctPairs = List<Map<String, dynamic>>.from(
              finalNormalized['correctPairs'] ?? []);

          // Dynamically extract question text with multiple fallback options
          _questionText = originalData != null
              ? (originalData['questionText'] ??
                  originalData['question'] ??
                  originalData['text'] ??
                  currentQuestion.questionText ??
                  '')
              : (currentQuestion.questionText ?? '');

          // Reset per-question state dynamically
          _selectedChoices = List.filled(_audioTexts.length, '');
          _usedOptions.clear();
          _completedAudios.clear();
          _audioResults.clear();
          _currentAudioIndex = 0;
          _isCurrentQuestionAnswered = false;
          _showFeedback = false;
          _allAudiosCompleted = false;
        });

        // Start typewriter flow for next dynamic question
        _startTypewriterFlow();

        // Debug information for next dynamic question load
        print('[PhonologicalMatching] Loaded dynamic next question: '
            '${currentQuestion.questionId} | audioTexts=${_audioTexts.length}, '
            'options=${_matchingOptions.length}, pairs=${_correctPairs.length}');
        print(
            '[PhonologicalMatching] ===== END DYNAMIC NEXT QUESTION DATA =====');
      }
    } catch (e) {
      print(
          '[PhonologicalMatching] Error loading dynamic current question data: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize typewriter animation controller
    _typewriterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Initialize heartbeat animation controller
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _heartbeatAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _heartbeatController,
      curve: Curves.easeInOut,
    ));

    // Start heartbeat animation loop
    _heartbeatController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _heartbeatController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _heartbeatController.forward();
      }
    });

    // Initialize wave animation controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 2000), // Longer duration for visible filling
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController!,
      curve: Curves.easeInOut,
    ));

    // Initialize confetti controllers
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Initialize audio players
    _preloadButtonAudio();
    _preloadAudioFiles();

    // Load phonological awareness assessment data
    _loadPhonologicalData();

    // Initialize TTS and Theme providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ttsProvider = Provider.of<TTSProvider>(context, listen: false);
        _themeProvider = Provider.of<ThemeProvider>(context, listen: false);

        // Set current user ID in assessment provider for saving responses
        try {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          final userId = authProvider.currentUser?.idNumber?.toString();
          if (userId != null && userId.isNotEmpty) {
            Provider.of<AssessmentProvider>(context, listen: false)
                .setCurrentUserId(userId);
            print(
                '[PhonologicalMatching] Set userId in AssessmentProvider: $userId');
          }
        } catch (e) {
          print('[PhonologicalMatching] Failed setting userId in provider: $e');
        }
      }
    });
  }

  Future<void> _loadPhonologicalData() async {
    try {
      print(
          '[PhonologicalMatching] ===== LOADING DYNAMIC PHONOLOGICAL DATA FROM MONGODB =====');
      print(
          '[PhonologicalMatching] Is Pre-Assessment: ${widget.isPreAssessment}');
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);

      // Load phonological awareness assessment based on context
      if (widget.isPreAssessment) {
        // Load from pre-assessment database
        await assessmentProvider.loadPhonologicalAwarenessAssessment();
      } else {
        // Load from main assessment database
        await assessmentProvider.loadPhonologicalAwarenessMainAssessment();
      }

      // Get the current question data dynamically
      final currentQuestion = assessmentProvider.currentQuestion;
      if (currentQuestion != null) {
        print(
            '[PhonologicalMatching] Current dynamic question: ${currentQuestion.questionId}');

        // Get the original question data which contains the questionSet from MongoDB
        final originalData = assessmentProvider
            .getOriginalQuestionData(currentQuestion.questionId);

        if (originalData != null) {
          print(
              '[PhonologicalMatching] ===== DYNAMIC ORIGINAL DATA FROM MONGODB =====');
          print(
              '[PhonologicalMatching] Original data keys: ${originalData.keys.toList()}');
          print('[PhonologicalMatching] Original data: $originalData');

          // Try multiple field names for questionSet
          Map<String, dynamic>? questionSet;
          final possibleQuestionSetFields = [
            'questionSet',
            'data',
            'content',
            'phonologicalData'
          ];

          for (String field in possibleQuestionSetFields) {
            if (originalData.containsKey(field) &&
                originalData[field] != null) {
              questionSet = Map<String, dynamic>.from(originalData[field]);
              print(
                  '[PhonologicalMatching] Found questionSet in field: $field');
              break;
            }
          }

          // If no questionSet found, use the originalData itself as questionSet
          if (questionSet == null) {
            questionSet = Map<String, dynamic>.from(originalData);
            print('[PhonologicalMatching] Using originalData as questionSet');
          }

          print(
              '[PhonologicalMatching] Found dynamic questionSet: $questionSet');

          final normalized = _normalizeQuestionSet(questionSet);
          setState(() {
            _audioTexts = List<String>.from(normalized['audioTexts'] ?? []);
            _matchingOptions =
                List<String>.from(normalized['matchingOptions'] ?? []);
            _correctPairs = List<Map<String, dynamic>>.from(
                normalized['correctPairs'] ?? []);

            // Dynamically extract question text with fallback options
            _questionText = originalData['questionText'] ??
                currentQuestion.questionText ??
                originalData['question'] ??
                originalData['text'] ??
                '';

            // Initialize tracking arrays dynamically
            _selectedChoices = List.filled(
                _audioTexts.length, ''); // Empty strings for unselected
            _currentAudioIndex = 0; // Start with first audio
            _isCurrentQuestionAnswered = false;
            _showFeedback = false;
            _allAudiosCompleted = false;
            _usedOptions.clear();
            _completedAudios.clear();
            _isLoading = false;
          });

          // Start the typewriter effect flow when dynamic assessment is loaded
          _startTypewriterFlow();

          print('[PhonologicalMatching] ===== DYNAMIC LOADED DATA DEBUG =====');
          print('[PhonologicalMatching] Audio texts: $_audioTexts');
          print('[PhonologicalMatching] Matching options: $_matchingOptions');
          print('[PhonologicalMatching] Question text: $_questionText');
          print('[PhonologicalMatching] CorrectPairs: $_correctPairs');
          print(
              '[PhonologicalMatching] ===== END DYNAMIC LOADED DATA DEBUG =====');
        } else {
          // Fallback: try to get data from the question itself if available
          print(
              '[PhonologicalMatching] No originalData, trying fallback from currentQuestion');
          if (currentQuestion.questionSet != null) {
            final questionSet = currentQuestion.questionSet!;
            final normalized =
                _normalizeQuestionSet(Map<String, dynamic>.from(questionSet));
            setState(() {
              _audioTexts = List<String>.from(normalized['audioTexts'] ?? []);
              _matchingOptions =
                  List<String>.from(normalized['matchingOptions'] ?? []);
              _correctPairs = List<Map<String, dynamic>>.from(
                  normalized['correctPairs'] ?? []);
              _questionText = currentQuestion.questionText ?? '';

              // Initialize tracking arrays
              _selectedChoices = List.filled(_audioTexts.length, '');
              _currentAudioIndex = 0;
              _isCurrentQuestionAnswered = false;
              _showFeedback = false;
              _allAudiosCompleted = false;
              _usedOptions.clear();
              _completedAudios.clear();
              _audioResults.clear();
              _isLoading = false;
            });

            // Start the typewriter effect flow when fallback assessment is loaded
            _startTypewriterFlow();
          } else {
            setState(() {
              _errorMessage =
                  'No phonological assessment data available in MongoDB';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'No current question available in MongoDB';
          _isLoading = false;
        });
      }
    } catch (e) {
      print(
          '[PhonologicalMatching] Error loading dynamic phonological data: $e');
      setState(() {
        _errorMessage = 'Error loading dynamic assessment from MongoDB: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadButtonAudio() async {
    try {
      // Preload button sound effect if needed
    } catch (e) {
      print('[PhonologicalMatching] Error preloading button audio: $e');
    }
  }

  Future<void> _preloadAudioFiles() async {
    try {
      await _correctSoundPlayer.setAsset('assets/audio/assessmentsound.mp3');
      await _buttonSoundPlayer.setAsset('assets/audio/MagpatuloyButton.mp3');
      await _wrongSoundPlayer.setAsset('assets/audio/incorrectanswer.mp3');
    } catch (e) {
      print('[PhonologicalMatching] Error preloading audio files: $e');
    }
  }

  Future<void> _playCorrectSound() async {
    try {
      await _correctSoundPlayer.seek(Duration.zero);
      await _correctSoundPlayer.play();
    } catch (e) {
      print('[PhonologicalMatching] Error playing correct sound: $e');
    }
  }

  Future<void> _playButtonClickSound() async {
    try {
      await _buttonSoundPlayer.seek(Duration.zero);
      await _buttonSoundPlayer.play();
    } catch (e) {
      print('[PhonologicalMatching] Error playing button sound: $e');
    }
  }

  Future<void> _playWrongSound() async {
    try {
      await _wrongSoundPlayer.seek(Duration.zero);
      await _wrongSoundPlayer.play();
    } catch (e) {
      print('[PhonologicalMatching] Error playing wrong sound: $e');
    }
  }

  void _playButtonSound() {
    _playButtonClickSound();
  }

  // Start the typewriter effect flow
  void _startTypewriterFlow() {
    _fullQuestionText = _questionText;
    _resetFlowState();
    _startTypewriterEffect();
  }

  // Reset flow state for new question
  void _resetFlowState() {
    setState(() {
      _displayedText = '';
      _typewriterCompleted = false;
      _showTTSButton = false;
      _showImage = false;
      _showChoices = false;
      _userListened = false;
    });
    _typewriterController.reset();
    _heartbeatController.stop();
  }

  // Start typewriter effect
  void _startTypewriterEffect() {
    _typewriterAnimation = IntTween(
      begin: 0,
      end: _fullQuestionText.length,
    ).animate(CurvedAnimation(
      parent: _typewriterController,
      curve: Curves.easeOut,
    ));

    _typewriterAnimation.addListener(() {
      setState(() {
        _displayedText =
            _fullQuestionText.substring(0, _typewriterAnimation.value);
      });
    });

    _typewriterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onTypewriterCompleted();
      }
    });

    _typewriterController.forward();
  }

  // Handle typewriter completion
  void _onTypewriterCompleted() {
    setState(() {
      _typewriterCompleted = true;
      _showTTSButton = true;
      _showImage = true;
      // Don't show choices until user clicks Pakinggan
      _showChoices = false;
      _userListened = false;
    });
    // Start heartbeat animation
    _heartbeatController.forward();
  }

  // Handle TTS button press - user listened to question
  void _onTTSButtonPressed() {
    if (!_userListened) {
      _speakText(_fullQuestionText);
      setState(() {
        _userListened = true;
        _showChoices = true;
      });
      // Stop heartbeat animation
      _heartbeatController.stop();
    }
  }

  // CRITICAL: Play audio for specific index - only current audio should be playable
  void _playAudio(int index, String audioText) async {
    // Only allow playing the current active audio
    if (index != _currentAudioIndex) {
      print(
          '[PhonologicalMatching] Cannot play audio $index, current active is $_currentAudioIndex');
      return;
    }

    setState(() {
      _currentPlayingAudioIndex = index;
    });

    // Start wave filling animation
    _waveController?.reset();
    _waveController?.forward();

    print('[PhonologicalMatching] Playing audio $index: $audioText');

    // Use TTS to play the audio text
    final ttsProvider = Provider.of<TTSProvider>(context, listen: false);
    if (ttsProvider.isAvailable) {
      ttsProvider.speakText(
        audioText,
        speed: 0.4, // Slower speed for clear pronunciation
      );
    }

    // Simulate audio completion
    await Future.delayed(const Duration(milliseconds: 2000));

    // Stop wave animation
    _waveController?.stop();
    _waveController?.reset();

    if (mounted) {
      setState(() {
        _currentPlayingAudioIndex = null;
      });
    }
  }

  // CRITICAL: Select a matching option - core logic implementation
  void _selectMatchingOption(String selectedOption) {
    _playButtonSound();

    // Prevent selecting already used options
    if (_usedOptions.contains(selectedOption)) {
      print('[PhonologicalMatching] Option $selectedOption already used');
      return;
    }

    // Record the user's selection for the current audio. Do NOT show feedback yet.
    setState(() {
      // Unmark previous selection for this audio so only one is active
      final previousSelection = _selectedChoices[_currentAudioIndex];
      if (previousSelection.isNotEmpty && previousSelection != selectedOption) {
        _usedOptions.remove(previousSelection);
      }

      _selectedChoices[_currentAudioIndex] = selectedOption;
      _usedOptions.add(selectedOption); // Mark this option as used
      _isCurrentQuestionAnswered = true; // Enable PAKITSEK button
      _showFeedback =
          false; // Ensure dialog is hidden until user presses PAKITSEK
    });

    print(
        '[PhonologicalMatching] Selected $selectedOption for audio $_currentAudioIndex (${_audioTexts[_currentAudioIndex]})');

    // Defer validation until PAKITSEK is pressed
    if (widget.onOptionSelected != null) {
      widget.onOptionSelected!(selectedOption);
    }
  }

  // Validate answer using correctPairs from database with case-insensitive comparison
  bool _validateAnswer(String audioText, String selectedOption) {
    print(
        '[PhonologicalMatching] Validating: "$audioText" -> "$selectedOption"');
    print('[PhonologicalMatching] CorrectPairs: $_correctPairs');

    // Ensure we have correctPairs data
    if (_correctPairs.isEmpty) {
      print('[PhonologicalMatching] ❌ No correctPairs data available');
      return false;
    }

    // Check each pair in correctPairs
    // Structure: [{audio: "H", match: "Hh"}, {audio: "T", match: "Tt"}, ...]
    for (int i = 0; i < _correctPairs.length; i++) {
      var pair = _correctPairs[i];
      print('[PhonologicalMatching] Checking pair $i: $pair');

      // Get the audio and match values from this pair
      String? audioValue = pair['audio']?.toString();
      String? matchValue = pair['match']?.toString();

      print(
          '[PhonologicalMatching] Pair audio: "$audioValue", match: "$matchValue"');

      // Check if this pair matches our input (case-insensitive)
      if (audioValue != null && matchValue != null) {
        if (audioValue.toLowerCase() == audioText.toLowerCase() &&
            matchValue.toLowerCase() == selectedOption.toLowerCase()) {
          print(
              '[PhonologicalMatching] ✅ CORRECT! Match found: "$audioValue" -> "$matchValue"');
          return true;
        }
      }
    }

    print('[PhonologicalMatching] ❌ No matching pair found');
    return false;
  }

  // Get the correct answer for the current audio (for debugging)
  String _getCorrectAnswer(String audioText) {
    for (var pair in _correctPairs) {
      if (pair.containsKey(audioText)) {
        return pair[audioText];
      }
    }
    return '';
  }

  // Move to next audio in sequence
  void _moveToNextAudio() {
    setState(() {
      _showFeedback = false;
      _isCurrentQuestionAnswered = false;

      if (_currentAudioIndex < _audioTexts.length - 1) {
        _currentAudioIndex++; // Move to next audio
        print('[PhonologicalMatching] Moving to audio $_currentAudioIndex');
      } else {
        _allAudiosCompleted = true;
        print('[PhonologicalMatching] All audios completed');
      }
    });
  }

  // Proceed to next question in assessment - DYNAMIC PA_001 → PA_002 → PA_003
  void _proceedToNextQuestion() {
    print('[PhonologicalMatching] Proceeding to next question');

    // Record the phonological response in assessment provider
    final assessmentProvider =
        Provider.of<AssessmentProvider>(context, listen: false);
    final currentQuestion = assessmentProvider.currentQuestion;

    if (currentQuestion != null) {
      // Calculate scoring
      int correctMatches = 0;
      int totalMatches = _audioTexts.length;

      for (int i = 0; i < _audioTexts.length; i++) {
        if (i < _selectedChoices.length && _selectedChoices[i].isNotEmpty) {
          final audioText = _audioTexts[i];
          final selectedOption = _selectedChoices[i];
          if (_validateAnswer(audioText, selectedOption)) {
            correctMatches++;
          }
        }
      }

      final isOverallCorrect =
          correctMatches >= (totalMatches * 0.6); // 60% threshold

      // Create response data in the format expected for phonological awareness
      final responseData = _selectedChoices.asMap().entries.map((entry) {
        final index = entry.key;
        final selectedOption = entry.value;
        final audioText = index < _audioTexts.length ? _audioTexts[index] : '';

        return {
          'audio': audioText,
          'match': selectedOption,
        };
      }).toList();

      // Save individual response in new MongoDB format
      assessmentProvider.saveIndividualResponse(
        questionId: currentQuestion.questionId,
        category: 'Phonological Awareness',
        questionType: currentQuestion.questionType ?? 'malapantig',
        response:
            responseData.map((e) => '${e['audio']}:${e['match']}').toList(),
        isCorrect: isOverallCorrect,
        responseTime: 0,
      );

      // Record the response
      assessmentProvider.recordPhonologicalResponse(
        currentQuestion.questionId,
        responseData,
        correctMatches,
        totalMatches,
        isOverallCorrect,
      );
    }

    // Check if we need to progress within Phonological Awareness or move to next category
    final provider = Provider.of<AssessmentProvider>(context, listen: false);
    final beforeIndex = provider.currentQuestionIndex;
    final beforeId = provider.currentQuestion?.questionId;

    // Check if this is PA_001, PA_002, or PA_003
    if (currentQuestion != null) {
      final currentId = currentQuestion.questionId;

      if (currentId == 'PA_001') {
        // PA_001 completed, move to PA_002
        print('[PhonologicalMatching] PA_001 completed, moving to PA_002');
        provider.moveToNextQuestion(); // This should go to PA_002

        // Refresh UI with PA_002 data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCurrentQuestionDataFromProvider();
          }
        });
        return;
      } else if (currentId == 'PA_002') {
        // PA_002 completed, move to PA_003
        print('[PhonologicalMatching] PA_002 completed, moving to PA_003');
        provider.moveToNextQuestion(); // This should go to PA_003

        // Refresh UI with PA_003 data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCurrentQuestionDataFromProvider();
          }
        });
        return;
      } else if (currentId == 'PA_003') {
        // PA_003 completed, move to PA_004
        print('[PhonologicalMatching] PA_003 completed, moving to PA_004');
        provider.moveToNextQuestion(); // This should go to PA_004

        // Refresh UI with PA_004 data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCurrentQuestionDataFromProvider();
          }
        });
        return;
      } else if (currentId == 'PA_004') {
        // PA_004 completed, move to PA_005
        print('[PhonologicalMatching] PA_004 completed, moving to PA_005');
        provider.moveToNextQuestion(); // This should go to PA_005

        // Refresh UI with PA_005 data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCurrentQuestionDataFromProvider();
          }
        });
        return;
      } else if (currentId == 'PA_005') {
        // PA_005 completed, move to PA_006
        print('[PhonologicalMatching] PA_005 completed, moving to PA_006');
        provider.moveToNextQuestion(); // This should go to PA_006

        // Refresh UI with PA_006 data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadCurrentQuestionDataFromProvider();
          }
        });
        return;
      } else if (currentId == 'PA_006') {
        // PA_006 completed - check if this is pre-assessment or main assessment
        print(
            '[PhonologicalMatching] PA_006 completed, isPreAssessment: ${widget.isPreAssessment}');
        provider.moveToNextQuestion();

        if (widget.isPreAssessment) {
          // Pre-assessment flow: navigate to DecodingTutorial
          print(
              '[PhonologicalMatching] Pre-assessment flow - navigating to DecodingTutorial');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DecodingTutorial(),
            ),
          );
        } else {
          // Main assessment flow: navigate back to home
          print(
              '[PhonologicalMatching] Main assessment flow - navigating back to home');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
        return;
      }
    }

    // Default behavior for any other cases
    provider.moveToNextQuestion();
    print('[PhonologicalMatching] [NextQ] moved index ${beforeIndex} -> '
        '${provider.currentQuestionIndex}; ${beforeId} -> '
        '${provider.currentQuestion?.questionId}');

    // Check if still in PA questions, refresh if so
    final nextQuestion = provider.currentQuestion;
    if (nextQuestion != null && nextQuestion.questionId.startsWith('PA_')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadCurrentQuestionDataFromProvider();
        }
      });
    } else if (nextQuestion != null &&
        nextQuestion.questionId.startsWith('DC_')) {
      // Next question is a Decoding question, navigate to DecodingScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (newContext) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(
                value: Provider.of<AssessmentProvider>(context, listen: false),
              ),
              ChangeNotifierProvider.value(
                value: Provider.of<ThemeProvider>(context, listen: false),
              ),
              ChangeNotifierProvider.value(
                value: Provider.of<TTSProvider>(context, listen: false),
              ),
            ],
            child: DecodingScreen(
              assessmentId: widget.assessmentId,
              onContinue: widget.onContinue,
            ),
          ),
        ),
      );
    } else {
      // Not a PA or DC question anymore, exit screen
      if (widget.onContinue != null) {
        widget.onContinue!();
      } else {
        // No continue callback means this is a standalone category assessment
        // Navigate to PreAssessmentResultScreen
        _navigateToResults();
      }
    }
  }

  void _navigateToResults() {
    // Save assessment results and navigate to PreAssessmentResultScreen
    try {
      final assessmentProvider =
          Provider.of<AssessmentProvider>(context, listen: false);
      final score = assessmentProvider.score;
      final total = assessmentProvider.totalQuestions;
      final readingPercentage =
          assessmentProvider.getEffectiveReadingPercentage();
      final readingLevel = assessmentProvider.readingLevel ?? "Undefined";

      print('[PhonologicalMatching] Navigating to PreAssessmentResultScreen');
      print(
          '[PhonologicalMatching] Final results - Score: $score/$total, Level: $readingLevel');

      // Capture additional providers while context is still valid
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final ttsProvider = Provider.of<TTSProvider>(context, listen: false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: assessmentProvider),
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: ttsProvider),
            ],
            child: PreAssessmentResultScreen(
              score: score,
              totalQuestions: total,
              readingLevel: readingLevel,
              readingPercentage: readingPercentage,
              assessmentType: 'pre-assessment',
            ),
          ),
        ),
      );
    } catch (e) {
      print('[PhonologicalMatching] Error navigating to results: $e');
      // Fallback navigation
      Navigator.of(context).pop();
    }
  }

  // CRITICAL: Continue button logic - handles both feedback dismissal and final progression
  void _continue() {
    _playButtonSound();

    if (_showFeedback) {
      // After showing result, move to next audio
      // If we were on the last audio, advance to next question
      if (_currentAudioIndex >= _audioTexts.length - 1) {
        _allAudiosCompleted = true;
        _proceedToNextQuestion();
      } else {
        _moveToNextAudio();
      }
      return;
    }

    // When PAKITSEK is pressed, check the current selection and show feedback
    if (!_allAudiosCompleted) {
      final currentAudioText = _audioTexts[_currentAudioIndex];
      final selectedOption = _selectedChoices[_currentAudioIndex];
      if (selectedOption.isEmpty) return; // Nothing selected yet

      final isCorrect = _validateAnswer(currentAudioText, selectedOption);

      setState(() {
        // Mark current audio as completed and store correctness
        _completedAudios.add(_currentAudioIndex);
        _audioResults[_currentAudioIndex] = isCorrect;

        _showFeedback = true; // Show Tama/Mali dialog
        _isCorrectAnswer = isCorrect;
        _feedbackMessage = isCorrect
            ? 'Tama!\n\nAng iyong sagot ay tama!'
            : 'Mali!\n\nAng iyong sagot ay Mali!';
        _isCurrentQuestionAnswered = false; // Disable until next interaction

        // If this was the last audio, mark all completed to switch button to MAG PATULOY
        if (_currentAudioIndex >= _audioTexts.length - 1) {
          _allAudiosCompleted = true;
        }
      });

      // Play effects for answer
      if (isCorrect) {
        _playCorrectSound();
        _confettiControllerLeft.play();
        _confettiControllerRight.play();
      } else {
        _playWrongSound();
      }

      return;
    }

    // All audios completed, proceed to next question
    if (_allAudiosCompleted) {
      _proceedToNextQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF1C2B4E),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Removed back arrow

                // Add slight top spacing then progress indicator
                const SizedBox(height: 8),
                _buildProgressIndicator(
                    Provider.of<AssessmentProvider>(context), theme),

                // Question text with TTS
                if (!_isLoading && _questionText.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildQuestionText(themeProvider),
                  ),
                ],

                // Expanded section for matching content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _showFeedback
                        ? _buildFeedbackContent(themeProvider)
                        : (_showChoices
                            ? _buildSequentialMatchingContent(themeProvider)
                            : const SizedBox.shrink()),
                  ),
                ),

                // Continue button or TTS button - CRITICAL STATE MANAGEMENT
                // Only show if user has listened
                if (_userListened)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: (_showFeedback ||
                                        _allAudiosCompleted ||
                                        (_isCurrentQuestionAnswered &&
                                            _userListened))
                                    ? const Color.fromARGB(197, 27, 172, 37)
                                    : const Color.fromARGB(199, 117, 117, 117),
                                offset: const Offset(
                                    0, 5), // Horizontal & vertical offset
                                blurRadius: 0, // Softness of the shadow
                                spreadRadius: 0, // Size expansion
                              ),
                            ],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: (_showFeedback ||
                                    _allAudiosCompleted ||
                                    (_isCurrentQuestionAnswered &&
                                        _userListened))
                                ? _continue
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_showFeedback ||
                                      _allAudiosCompleted ||
                                      (_isCurrentQuestionAnswered &&
                                          _userListened))
                                  ? const Color(
                                      0xFF1BAC24) // Green when enabled
                                  : const Color.fromARGB(
                                      255, 117, 117, 117), // Grey when disabled
                              disabledBackgroundColor:
                                  const Color.fromARGB(255, 117, 117, 117),
                              foregroundColor: (_showFeedback ||
                                      _allAudiosCompleted ||
                                      (_isCurrentQuestionAnswered &&
                                          _userListened))
                                  ? Colors.white
                                  : const Color(0xFF333333),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _showFeedback || _allAudiosCompleted
                                  ? 'MAG PATULOY'
                                  : 'TIGNAN ANG SAGOT',
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(18),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
          // Left side confetti
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiControllerLeft,
              blastDirection: 0, // Shoot to the right
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 15,
              minBlastForce: 5,
              gravity: 0.8,
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
          // Right side confetti
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiControllerRight,
              blastDirection: 3.14159, // Shoot to the left (pi radians)
              emissionFrequency: 0.05,
              numberOfParticles: 20,
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

  // CRITICAL: Sequential matching content with Row-based layout - implements the exact flow from your PDF
  Widget _buildSequentialMatchingContent(ThemeProvider themeProvider) {
    // Show loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFCC00)),
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white,
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show content with fetched data - ROW-BASED LAYOUT
    if (_audioTexts.isEmpty || _matchingOptions.isEmpty) {
      return Center(
        child: Text(
          'No phonological matching data available',
          style: TextStyle(
            color: Colors.white,
            fontSize: themeProvider.getRealFontSize(16),
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      );
    }

    // Create pairs of audio and matching options following the attached design
    final int pairCount = _correctPairs.isNotEmpty
        ? _correctPairs.length
        : (_audioTexts.length < _matchingOptions.length
            ? _audioTexts.length
            : _matchingOptions.length);

    final pairs = List.generate(pairCount, (index) {
      return {
        'audioText': index < _audioTexts.length ? _audioTexts[index] : '',
        'matchingOption':
            index < _matchingOptions.length ? _matchingOptions[index] : '',
      };
    });

    return ListView.builder(
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final String audioText = pair['audioText'] ?? '';
        final String matchingOption = pair['matchingOption'] ?? '';

        // SEQUENTIAL LOGIC - maintain the flow from PDF
        final bool isCurrentAudio = index == _currentAudioIndex;
        final bool isPlaying = _currentPlayingAudioIndex == index;
        final bool isCompleted = _completedAudios.contains(index);
        final bool? isResultCorrect = _audioResults[index];
        final bool isOptionUsed = _usedOptions.contains(matchingOption);

        return Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: Row(
            children: [
              // Left side - Audio button with sequential logic
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: isCompleted
                              ? (isResultCorrect == true
                                  ? const Color.fromARGB(197, 27, 172,
                                      37) // Green shadow for correct
                                  : const Color.fromARGB(197, 247, 87,
                                      74)) // Red shadow for incorrect
                              : (isCurrentAudio || isPlaying
                                  ? const Color.fromARGB(200, 255, 217,
                                      102) // Yellow shadow for active
                                  : const Color.fromARGB(197, 117, 117,
                                      117)), // Gray shadow for inactive
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      // CRITICAL: Only current audio can be played
                      onPressed: isCurrentAudio
                          ? () => _playAudio(index, audioText)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted
                            ? (isResultCorrect == true
                                ? const Color(0xFF1BAC24)
                                : const Color(0xFFE53935))
                            : (isCurrentAudio || isPlaying
                                ? const Color(0xFFFFD966)
                                : const Color(0xFF666666)),
                        disabledBackgroundColor: isCompleted
                            ? (isResultCorrect == true
                                ? const Color(0xFF1BAC24)
                                : const Color(0xFFE53935))
                            : const Color(0xFF666666),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation:
                            0, // Remove elevation since we use Container shadow
                        shadowColor: Colors.transparent,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            isCompleted
                                ? (isResultCorrect == true
                                    ? Icons.check
                                    : Icons.close)
                                : Icons.volume_up,
                            size: 40,
                            color: isCompleted
                                ? Colors.white
                                : ((isCurrentAudio || isPlaying)
                                    ? Colors.black
                                    : Colors.white),
                          ),
                          const SizedBox(width: 8),
                          if (isCompleted) ...[
                            Text(
                              isResultCorrect == true ? 'Tama' : 'Mali',
                              style: TextStyle(
                                fontSize: themeProvider.getRealFontSize(15),
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(255, 255, 255, 255),
                              ),
                            ),
                          ] else ...[
                            // Sound wave visualization with animation
                            AnimatedBuilder(
                              animation: _waveAnimation ??
                                  const AlwaysStoppedAnimation(0.0),
                              builder: (context, child) {
                                return Row(
                                  children: List.generate(
                                      10,
                                      (i) => Container(
                                            width: 3,
                                            height: isPlaying
                                                ? 20 +
                                                    (15 *
                                                        (sin(((_waveAnimation?.value ??
                                                                            0.0) *
                                                                        2 *
                                                                        pi) +
                                                                    (i * 0.5)) *
                                                                0.5 +
                                                            0.5))
                                                : 20 + (i % 3) * 4,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1),
                                            decoration: BoxDecoration(
                                              color: isPlaying
                                                  ? () {
                                                      double progress =
                                                          (_waveAnimation
                                                                      ?.value ??
                                                                  0.0) *
                                                              11; // 0 to 11 for smoother transition
                                                      if (progress > i + 1) {
                                                        return Colors
                                                            .black; // Fully filled
                                                      } else if (progress > i) {
                                                        // Partially filled - create gradient effect
                                                        double fillPercent =
                                                            progress - i;
                                                        return Color.lerp(
                                                              const Color
                                                                  .fromARGB(255,
                                                                  83, 83, 83),
                                                              Colors.black,
                                                              fillPercent,
                                                            ) ??
                                                            Colors.black;
                                                      } else {
                                                        return const Color
                                                            .fromARGB(255, 83,
                                                            83, 83); // Unfilled
                                                      }
                                                    }()
                                                  : (isCurrentAudio
                                                      ? Colors.black
                                                      : Colors.white),
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          )),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Right side - Matching option button with sequential logic
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: isOptionUsed
                          ? [
                              BoxShadow(
                                color: const Color.fromARGB(197, 255, 217,
                                    102), // Yellow shadow when used/selected
                                offset: const Offset(0, 4),
                                blurRadius: 0,
                                spreadRadius: 0,
                              ),
                            ]
                          : null, // No shadow when unselected
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: OutlinedButton(
                      // CRITICAL: Make all choice buttons available; still prevent reusing and during feedback
                      onPressed: (!isOptionUsed && !_showFeedback)
                          ? () => _selectMatchingOption(matchingOption)
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFFFFD966), // Gold/yellow border
                          width: 2,
                        ),
                        backgroundColor: isOptionUsed
                            ? const Color(
                                0xFFFFD966) // Yellow when already used
                            : Colors
                                .transparent, // Keep available choices clear
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        matchingOption,
                        style: TextStyle(
                          fontSize: themeProvider.getRealFontSize(24),
                          fontWeight: FontWeight.bold,
                          fontFamily: themeProvider.fontFamily,
                          color: isOptionUsed
                              ? Colors.black // Black text when used
                              : Colors.white, // White text when available
                        ),
                      ),
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

  // Progress indicator specifically for PA questions (counts only PA_* questions)
  Widget _buildProgressIndicator(
      AssessmentProvider provider, AppThemeData theme) {
    // Filter only PA questions from the loaded assessment (PA_001, PA_002, PA_003 only)
    final allQuestions = provider.assessment?.questions ?? [];
    final paQuestions = allQuestions
        .where((q) =>
            q.questionId.startsWith('PA_') &&
            q.questionId.length == 6 &&
            RegExp(r'^PA_\d{3}$').hasMatch(q.questionId))
        .toList();

    // Filter to only include PA_001 to PA_006 (the ones used in this flow)
    final activePAQuestions = paQuestions
        .where((q) =>
            q.questionId == 'PA_001' ||
            q.questionId == 'PA_002' ||
            q.questionId == 'PA_003' ||
            q.questionId == 'PA_004' ||
            q.questionId == 'PA_005' ||
            q.questionId == 'PA_006')
        .toList();

    // Ensure consistent order PA_001 -> PA_006
    activePAQuestions.sort((a, b) => a.questionId.compareTo(b.questionId));

    int current = 1;
    final total = activePAQuestions.length; // Should be 6 (PA_001 to PA_006)

    final currentPAQuestion = provider.currentQuestion;
    if (currentPAQuestion != null &&
        currentPAQuestion.questionId.startsWith('PA_')) {
      final idx = activePAQuestions
          .indexWhere((q) => q.questionId == currentPAQuestion.questionId);
      if (idx != -1) {
        current = idx + 1;
      }
    }

    final themeProvider = Provider.of<ThemeProvider>(context);

    final totalWidth = MediaQuery.of(context).size.width - 40;
    final progressRatio = total == 0 ? 0.0 : current / total;
    final pillWidth = 80.0;
    final pillPosition = (totalWidth - pillWidth) * progressRatio;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: theme.textColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progressRatio,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color.fromARGB(197, 255, 204, 0), // Shadow color
                    offset: Offset(0, 5), // Horizontal & vertical offset
                    blurRadius: 0, // Softness of the shadow
                    spreadRadius: 0, // Size expansion
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: progressRatio < 0.1
                ? 0
                : progressRatio > 0.9
                    ? totalWidth - pillWidth
                    : pillPosition,
            top: -10,
            child: Container(
              height: 40,
              width: pillWidth,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(197, 255, 204, 0),
                    blurRadius: 0,
                    spreadRadius: 0,
                    offset: Offset(0, 5),
                  ),
                ],
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

  // Feedback content - shows correct/incorrect dialogs
  Widget _buildFeedbackContent(ThemeProvider themeProvider) {
    final Color backgroundColor =
        _isCorrectAnswer ? const Color(0xFFCAFFCD) : const Color(0xFFFFF0F0);

    // Get current audio and selected option for display
    String selectedOption = '';
    if (_currentAudioIndex < _selectedChoices.length) {
      selectedOption = _selectedChoices[_currentAudioIndex];
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isCorrectAnswer
                  ? const Color(0xFF00E10F)
                  : const Color(0xFFF7574A),
              width: 3,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCorrectAnswer
                          ? const Color(0xFF00E10F)
                          : Colors.red,
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
                      color: _isCorrectAnswer ? Colors.green : Colors.red,
                      fontSize: themeProvider.getRealFontSize(32),
                      fontWeight: FontWeight.bold,
                      fontFamily: themeProvider.fontFamily,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: _isCorrectAnswer
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        _isCorrectAnswer ? const Color(0xFF00E10F) : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedOption,
                        style: TextStyle(
                          fontSize: themeProvider.getRealFontSize(20),
                          fontWeight: FontWeight.bold,
                          color: _isCorrectAnswer
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontFamily: themeProvider.fontFamily,
                        ),
                      ),
                    ),
                    Icon(
                      _isCorrectAnswer ? Icons.check_circle : Icons.cancel,
                      color: _isCorrectAnswer
                          ? const Color(0xFF00E10F)
                          : Colors.red,
                      size: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _feedbackMessage,
                style: TextStyle(
                  fontSize: themeProvider.getRealFontSize(16),
                  color: Colors.black87,
                  fontFamily: themeProvider.fontFamily,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  // Question text with TTS functionality
  Widget _buildQuestionText(ThemeProvider themeProvider) {
    final theme = themeProvider.currentTheme;

    if (_questionText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(11),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: theme.accentColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.accentColor, width: 1),
      ),
      child: Column(
        children: [
          // Typewriter text display
          Text(
            _displayedText,
            style: TextStyle(
              color: Colors.white,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          // Show Nakinig na status when user has listened
          if (_userListened && themeProvider.textToSpeechEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.green.withOpacity(0.15),
                    border: Border.all(
                      color: Colors.green,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nakinig na',
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
              ],
            ),
          ],
          // TTS button with heartbeat animation - only show after typewriter completes and user hasn't listened
          if (_showTTSButton &&
              themeProvider.textToSpeechEnabled &&
              !_userListened) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _heartbeatAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _heartbeatAnimation.value,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _onTTSButtonPressed,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: theme.accentColor.withOpacity(0.15),
                              border: Border.all(
                                color: theme.accentColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    color: const Color(0xFFFFCC00),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pakinggan',
                                  style: TextStyle(
                                    fontSize: themeProvider.getRealFontSize(14),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: themeProvider.fontFamily,
                                    color: const Color(0xFFFFCC00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _speakText(String text) {
    if (!mounted) return;

    if (_ttsProvider != null &&
        _ttsProvider!.isAvailable &&
        _themeProvider != null &&
        _themeProvider!.textToSpeechEnabled) {
      _ttsProvider!.speakText(
        text,
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
          print('[PhonologicalMatching] ElevenLabs TTS Error occurred');
          if (mounted) {
            setState(() {
              _isTTSPlaying = false;
            });
          }
        },
      );
    }
  }

  void _stopTTS() {
    if (_ttsProvider != null) {
      _ttsProvider!.stopSpeaking();
      setState(() {
        _isTTSPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _stopTTS();
    _audioPlayer.dispose();
    _buttonAudioPlayer.dispose();
    _correctSoundPlayer.dispose();
    _buttonSoundPlayer.dispose();
    _wrongSoundPlayer.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _typewriterController.dispose();
    _heartbeatController.dispose();
    _waveController?.dispose();
    super.dispose();
  }
}
