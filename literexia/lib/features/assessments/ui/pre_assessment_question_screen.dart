// lib/features/assessments/ui/pre_assessment_question_screen.dart
import 'package:flutter/material.dart';
import 'package:literexia/features/settings/provider/theme_provider.dart';
import 'package:provider/provider.dart';

import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'package:literexia/features/assessments/models/assessment_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/logic/auth_provider.dart';

import 'pre_assessment_result_screen.dart';

class PreAssessmentQuestionScreen extends StatefulWidget {
  final dynamic assessmentId;
  final AssessmentProvider provider;
  final Function(String readingLevel, int score, int total, double readingPercentage)? onAssessmentComplete;

  const PreAssessmentQuestionScreen({
    super.key,
    required this.assessmentId,
    required this.provider,
    this.onAssessmentComplete,
  });

  @override
  State<PreAssessmentQuestionScreen> createState() => _PreAssessmentQuestionScreenState();
}

class _PreAssessmentQuestionScreenState extends State<PreAssessmentQuestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedOptionId;
  
  // Reading comprehension flow management
  int _flowStep = 0; // 0: initial instruction, 1: passage viewing, 2: question with choices
  int _currentPassageIndex = 0; // For tracking position in multi-page passages
  
  // Timer for tracking time spent reading
  DateTime? _readingStartTime;
  
  // Track content viewed for reading percentage calculation
  int _contentViewed = 0;
  
  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _flowStep = 0; // Reset flow step
      _currentPassageIndex = 0; // Reset passage index
      _readingStartTime = null;
      _contentViewed = 0;
    });

    try {
      await widget.provider.loadAssessment(widget.assessmentId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedOptionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
      print('Error loading assessment: $e');
    }
  }

  void _selectOption(String optionId) {
    setState(() {
      _selectedOptionId = optionId;
    });
  }

  Future<void> _playAudio(String audioUrl) async {
    // Implementation for audio playback
    print('Playing audio: $audioUrl');
    // Actual implementation would use an audio player package
  }

  void _goToNextStep() {
    final currentQuestion = widget.provider.currentQuestion;
    if (currentQuestion == null) return;
    
    // For reading comprehension questions
    if (currentQuestion.questionTypeId == 'reading_comprehension') {
      // If we're at the instruction step, start tracking reading time
      if (_flowStep == 0) {
        _readingStartTime = DateTime.now();
        setState(() {
          _flowStep = 1; // Move to passage viewing
          _currentPassageIndex = 0; // Start with first passage
        });
      }
      // If we're showing passages and there are more passages
      else if (_flowStep == 1) {
        final passages = _getPassageData(currentQuestion);
        
        // Record content viewed for reading percentage
        if (passages is List && _currentPassageIndex < passages.length) {
          final passage = passages[_currentPassageIndex];
          if (passage['pageText'] != null) {
            _contentViewed += passage['pageText'].toString().length;
            widget.provider.recordContentViewed(passage['pageText'].toString().length);
          }
        }
        
        // If there are multiple passages and we're not at the last one
        if (passages is List && _currentPassageIndex < passages.length - 1) {
          setState(() {
            _currentPassageIndex++; // Move to next passage
          });
        } else {
          // No more passages, move to the question
          // Stop tracking reading time and record duration
          if (_readingStartTime != null) {
            final readingDuration = DateTime.now().difference(_readingStartTime!);
            widget.provider.recordReadingTime(readingDuration.inSeconds);
            _readingStartTime = null;
          }
          
          setState(() {
            _flowStep = 2; // Show the question
            _selectedOptionId = null; // Reset selected option
          });
        }
      }
      // If we're showing the question with options and an option is selected
      else if (_flowStep == 2 && _selectedOptionId != null) {
        // Submit the answer and move to next question
        widget.provider.answerCurrentQuestion(_selectedOptionId!);
        
        // Check if assessment is complete
        if (widget.provider.isAssessmentComplete) {
          _handleAssessmentComplete();
        } else {
          // Reset for the next question
          setState(() {
            _selectedOptionId = null;
            _flowStep = 0; // Back to initial instruction for next question
            _currentPassageIndex = 0; // Reset passage index
          });
        }
      }
    } 
    // For regular questions (non-reading comprehension)
    else {
      if (_selectedOptionId != null) {
        // Submit answer and move to next question
        widget.provider.answerCurrentQuestion(_selectedOptionId!);
        
        // Check if assessment is complete
        if (widget.provider.isAssessmentComplete) {
          _handleAssessmentComplete();
        } else {
          // Reset for next question
          setState(() {
            _selectedOptionId = null;
            _flowStep = 0;
          });
        }
      }
    }
  }

  void _handleAssessmentComplete() {
    // Calculate reading level
    final score = widget.provider.score;
    final total = widget.provider.totalQuestions;
    
    // Get reading percentage or calculate default based on score
    final readingPercentage = widget.provider.getEffectiveReadingPercentage();

    // Get the determined reading level from the provider
    final readingLevel = widget.provider.readingLevel ?? "Undefined";
    
    // Update user's reading level in the database
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.idNumber.toString() ?? '';
    
    if (userId.isEmpty) {
      print('Error: No user ID available for completing assessment');
      return;
    }
    
    // Save basic assessment results using the public method
    widget.provider.saveResults(userId);
    
    // Save detailed results for additional processing
    widget.provider.saveDetailedResults(userId, widget.assessmentId.toString())
      .then((_) {
        print('Successfully saved detailed assessment results to DB');
      })
      .catchError((e) {
        print('Error saving detailed assessment results: $e');
      });
    
    // Update user profile with new reading level
    widget.provider.updateUserReadingLevel(
      authProvider, 
      readingLevel,
      readingPercentage: readingPercentage,
    );
    
    // Call completion callback if provided
    if (widget.onAssessmentComplete != null) {
      widget.onAssessmentComplete!(readingLevel, score, total, readingPercentage);
    }
    
    // Navigate to results screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PreAssessmentResultScreen(
          readingLevel: readingLevel,
          score: score,
          totalQuestions: total,
          readingPercentage: readingPercentage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(theme)
            : _errorMessage != null
                ? _buildErrorState(theme)
                : _buildQuestionContent(theme),
      ),
    );
  }

  Widget _buildLoadingState(AppThemeData theme) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
      ),
    );
  }

  Widget _buildErrorState(AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              'Error: $_errorMessage',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(16),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.buttonTextColor,
              ),
              onPressed: _loadAssessment,
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: themeProvider.getRealFontSize(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent(AppThemeData theme) {
    final provider = widget.provider;
    final currentQuestion = provider.currentQuestion;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (currentQuestion == null) {
      return Center(
        child: Text(
          'No questions available',
          style: TextStyle(
            color: theme.textColor,
            fontFamily: themeProvider.fontFamily,
            fontSize: themeProvider.getRealFontSize(16),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Close button at top left
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: Icon(Icons.close, color: theme.textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        
        // Progress indicator (e.g., "1/5")
        _buildProgressIndicator(provider, theme),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView(
              children: [
                const SizedBox(height: 10),
                
                // Content changes based on question type and flow step
                _buildFlowContent(currentQuestion, theme),
                
                const SizedBox(height: 20),
                
                // Continue button
                _buildContinueButton(provider, theme),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowContent(Question question, AppThemeData theme) {
    // Handle reading comprehension questions differently
    if (question.questionTypeId == 'reading_comprehension') {
      return _buildReadingComprehensionContent(question, theme);
    } else {
      // For non-reading comprehension questions - simple display
      return _buildRegularQuestionContent(question, theme);
    }
  }

  Widget _buildReadingComprehensionContent(Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (_flowStep == 0) {
      // Step 1: Show just the instruction
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              color: theme.accentColor,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              question.questionText,
              style: TextStyle(
                color: theme.accentColor,
                fontSize: themeProvider.getRealFontSize(18),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Basahin ang kuwento at pagkatapos, sagutin ang tanong.',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(14),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (_flowStep == 1) {
      // Step 2: Show the passage
      // Extract passage from metadata
      dynamic passageData = _getPassageData(question);
      
      if (passageData is List && passageData.isNotEmpty) {
        // Get the current passage based on index
        if (_currentPassageIndex >= passageData.length) {
          _currentPassageIndex = passageData.length - 1;
        }
        
        final currentPassage = passageData[_currentPassageIndex];
        String passageText = currentPassage['pageText'] ?? 'No passage content available';
        String? passageImage = currentPassage['pageImage'];
        int pageNumber = currentPassage['pageNumber'] ?? (_currentPassageIndex + 1);
        
        // Track total content available for reading percentage calculation
        if (_currentPassageIndex == 0) {
          int totalContent = 0;
          for (var passage in passageData) {
            if (passage['pageText'] != null) {
              totalContent += passage['pageText'].toString().length;
            }
          }
          widget.provider.recordAvailableContent(totalContent);
        }
        
        return Column(
          children: [
            // Page indicator
            Text(
              'Page $pageNumber of ${passageData.length}',
              style: TextStyle(
                color: theme.textColor,
                fontSize: themeProvider.getRealFontSize(14),
                fontFamily: themeProvider.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            
            // Show passage image if available
            if (passageImage != null && passageImage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    passageImage,
                    fit: BoxFit.contain,
                    height: 180,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              ),
            
            // Passage content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: theme.accentColor, width: 1),
              ),
              child: Text(
                passageText,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: themeProvider.getRealFontSize(16),
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ],
        );
      } else if (passageData != null) {
        // Handle single passage case
        String passageText = passageData['pageText'] ?? 'No passage content available';
        String? passageImage = passageData['pageImage'];
        
        // Record content for reading percentage
        if (passageText.isNotEmpty) {
          widget.provider.recordAvailableContent(passageText.length);
        }
        
        return Column(
          children: [
            // Show passage image if available
            if (passageImage != null && passageImage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    passageImage,
                    fit: BoxFit.contain,
                    height: 180,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
                    ),
                  ),
                ),
              ),
            
            // Passage content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: theme.accentColor, width: 1),
              ),
              child: Text(
                passageText,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: themeProvider.getRealFontSize(16),
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ],
        );
      } else {
        // Fallback if no passage data available
        return Center(
          child: Text(
            'No reading passage available',
            style: TextStyle(
              color: theme.textColor,
              fontSize: themeProvider.getRealFontSize(16),
              fontFamily: themeProvider.fontFamily,
            ),
          ),
        );
      }
    } else if (_flowStep == 2) {
      // Step 3: Show the question and choices
      // Extract question from metadata
      dynamic sentenceQuestion = _getSentenceQuestionData(question);
      String questionText = sentenceQuestion?['questionText'] ?? 'No question available';
      String? questionImage = sentenceQuestion?['questionImage'];
      
      return Column(
        children: [
          // Question text
          Text(
            questionText,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: themeProvider.getRealFontSize(18),
              fontWeight: FontWeight.bold,
              fontFamily: themeProvider.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Divider(color: theme.accentColor, thickness: 1),
          const SizedBox(height: 20),
          
          // Question image if available
          if (questionImage != null && questionImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  questionImage,
                  fit: BoxFit.contain,
                  height: 150,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                ),
              ),
            ),
          
          // Options
          ...question.options.map((option) => _buildOptionButton(option, theme)),
        ],
      );
    }
    
    // Fallback - should not reach here
    return const SizedBox.shrink();
  }

  // Helper method to get passage data from question metadata
  dynamic _getPassageData(Question question) {
    // Try to extract the passages from the question model first
    if (question.passages != null && question.passages!.isNotEmpty) {
      return question.passages;
    }
    
    try {
      // Try to extract from the original data structure
      final dynamic questionData = widget.provider.getOriginalQuestionData(question.questionId);
      if (questionData != null) {
        // Debug output
        print('[Question] Raw data keys for ${question.questionId}: ${questionData.keys}');
        
        if (questionData['passages'] != null && questionData['passages'] is List && questionData['passages'].isNotEmpty) {
          return questionData['passages'];
        }
      }
    } catch (e) {
      print('Error getting passage data: $e');
    }
    
    // If we couldn't find passages, return a default
    return [{'pageNumber': 1, 'pageText': 'No passage content available', 'pageImage': null}];
  }
  
  // Helper method to get sentence question data from question metadata
  dynamic _getSentenceQuestionData(Question question) {
    // Try to extract from question model first
    if (question.sentenceQuestions != null && question.sentenceQuestions!.isNotEmpty) {
      return question.sentenceQuestions!.first;
    }
    
    try {
      // Try to extract from the original data structure
      final dynamic questionData = widget.provider.getOriginalQuestionData(question.questionId);
      if (questionData != null && 
          questionData['sentenceQuestions'] != null && 
          questionData['sentenceQuestions'] is List &&
          questionData['sentenceQuestions'].isNotEmpty) {
        return questionData['sentenceQuestions'][0];
      }
    } catch (e) {
      print('Error getting sentence question data: $e');
    }
    
    // Default if no data found
    return {'questionText': question.questionText, 'questionImage': null};
  }

  Widget _buildRegularQuestionContent(Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
        // Display image if available
        if (question.hasImage && question.imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                question.imageUrl!,
                fit: BoxFit.contain,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  // If network image fails, try loading as asset
                  return Image.asset(
                    question.imageUrl!,
                    fit: BoxFit.contain,
                    height: 150,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        
        // Question prompt (e.g., "ASO", "BO + LA", etc.)
        if (question.displayedText != null && question.displayedText!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: theme.accentColor),
            ),
            child: Center(
              child: Text(
                question.displayedText!,
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: themeProvider.getRealFontSize(40),
                  fontWeight: FontWeight.bold,
                  fontFamily: themeProvider.fontFamily,
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 20),
        
        // Question text/instruction
        Text(
          question.questionText,
          style: TextStyle(
            color: theme.accentColor,
            fontSize: themeProvider.getRealFontSize(16),
            fontFamily: themeProvider.fontFamily,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Divider(color: theme.accentColor, thickness: 1),
        
        const SizedBox(height: 20),
        
        // Audio content
        if (question.hasAudio && question.audioUrl != null)
          Center(
            child: IconButton(
              icon: Icon(Icons.volume_up, color: theme.accentColor, size: 48),
              onPressed: () => _playAudio(question.audioUrl!),
            ),
          ),
        
        const SizedBox(height: 10),
        
        // Answer options
        ...question.options.map((option) => _buildOptionButton(option, theme)),
      ],
    );
  }

  Widget _buildProgressIndicator(AssessmentProvider provider, AppThemeData theme) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Calculate the total width and the position for the progress pill
    final totalWidth = MediaQuery.of(context).size.width - 40; // 40 for left and right margins
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
          
          // Progress indicator - yellow filled portion
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
          
          // Position the pill with better accuracy
          // For beginning of progress (0-10%), keep pill at start
          // For end of progress (90-100%), keep pill at end
          // For middle, align pill with progress
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

  Widget _buildOptionButton(AssessmentOption option, AppThemeData theme) {
    final isSelected = _selectedOptionId == option.optionId;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _selectOption(option.optionId),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: theme.accentColor, width: 2),
            borderRadius: BorderRadius.circular(30),
            color: isSelected ? theme.accentColor.withOpacity(0.3) : Colors.transparent,
          ),
          child: Center(
            child: Text(
              option.optionText,
              style: TextStyle(
                color: theme.accentColor,
                fontSize: themeProvider.getRealFontSize(18),
                fontWeight: FontWeight.bold,
                fontFamily: themeProvider.fontFamily,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(AssessmentProvider provider, AppThemeData theme) {
    final isButtonEnabled = 
        _selectedOptionId != null || // A choice is selected
        (_flowStep < 2 && provider.currentQuestion?.questionTypeId == 'reading_comprehension'); // In reading flow
    
    final continueBtnText = _getContinueButtonText();
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _goToNextStep : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isButtonEnabled ? theme.accentColor : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade600,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          continueBtnText,
          style: TextStyle(
            fontSize: themeProvider.getRealFontSize(18),
            fontWeight: FontWeight.bold,
            color: isButtonEnabled ? theme.buttonTextColor : Colors.grey.shade800,
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      ),
    );
  }
  
  // Helper to get context-appropriate continue button text
  String _getContinueButtonText() {
    final provider = widget.provider;
    
    // Default from assessment
    final defaultText = provider.assessment?.continueButtonText ?? 'MAG PATULOY';
    
    // If in reading passage flow
    if (provider.currentQuestion?.questionTypeId == 'reading_comprehension') {
      if (_flowStep == 0) {
        return 'SIMULAN ANG PAGBASA'; // Start Reading
      } else if (_flowStep == 1) {
        final passages = _getPassageData(provider.currentQuestion!);
        if (passages is List && _currentPassageIndex < passages.length - 1) {
          return 'SUSUNOD NA PAHINA'; // Next Page
        } else {
          return 'SAGUTIN ANG TANONG'; // Answer the Question
        }
      }
    }
    
    // Default continue text
    return defaultText;
  }
}