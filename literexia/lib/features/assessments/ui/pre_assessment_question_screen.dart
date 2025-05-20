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
  final Function(String readingLevel, int score, int total)? onAssessmentComplete;
  

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

  @override
  void initState() {
    super.initState();
    _loadAssessment();
  }

  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
  }

  void _goToNextQuestion() {
    if (_selectedOptionId == null) return;
    
    // Answer the current question with selected option
    widget.provider.answerCurrentQuestion(_selectedOptionId!);
    
    // Check if assessment is complete
    if (widget.provider.isAssessmentComplete) {
      _handleAssessmentComplete();
    } else {
      // Reset selection for next question
      setState(() {
        _selectedOptionId = null;
      });
    }
  }

 void _handleAssessmentComplete() {
  // Calculate reading level
  final score = widget.provider.score;
  final total = widget.provider.totalQuestions;
  
  // Get reading percentage or calculate default based on score
  final readingPercentage = widget.provider.getEffectiveReadingPercentage();

  String readingLevel = "Undefined";
  
  // Use scoring rules to determine level
  if (score <= 1) {
    readingLevel = "Emergent";
  } else if (score <= 3) {
    readingLevel = "Developing";
  } else {
    readingLevel = "Transitioning";
  }
  
  // Update user's reading level in the database
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userId = authProvider.currentUser?.idNumber.toString() ?? '';
  
  // Save detailed assessment results including student responses and category results
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
    widget.onAssessmentComplete!(readingLevel, score, total);
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
                const SizedBox(height: 20),
                
                // Question prompt (e.g., "ASO", "BO + LA", etc.)
                _buildQuestionPrompt(currentQuestion, theme),
                
                const SizedBox(height: 20),
                
                // Question text/instruction
                _buildQuestionInstruction(currentQuestion, theme),
                
                const SizedBox(height: 40),
                
                // Media content (audio/image)
                if (currentQuestion.hasAudio == true || currentQuestion.hasImage == true)
                  _buildMediaContent(currentQuestion, theme),
                  
                const SizedBox(height: 20),
                
                // Answer options
                ...currentQuestion.options.map((option) => 
                  _buildOptionButton(option, theme)
                ),
                
                const SizedBox(height: 40),
                
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

  Widget _buildProgressIndicator(AssessmentProvider provider, AppThemeData theme) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;
    final themeProvider = Provider.of<ThemeProvider>(context);

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
          
          // Progress indicator
          FractionallySizedBox(
            widthFactor: current / total,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          // Progress pill
          Positioned(
            left: (MediaQuery.of(context).size.width - 80) * ((current - 1) / total),
            child: Container(
              height: 40,
              width: 80,
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$current/$total',
                  style: TextStyle(
                    color: theme.buttonTextColor,
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

  Widget _buildQuestionPrompt(Question question, AppThemeData theme) {
    final prompt = question.displayedText ?? '';
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.accentColor),
      ),
      child: Center(
        child: Text(
          prompt,
          style: TextStyle(
            color: theme.accentColor,
            fontSize: themeProvider.getRealFontSize(40),
            fontWeight: FontWeight.bold,
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionInstruction(Question question, AppThemeData theme) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildMediaContent(Question question, AppThemeData theme) {
    if (question.hasAudio == true && question.audioUrl != null) {
      return Center(
        child: IconButton(
          icon: Icon(Icons.volume_up, color: theme.accentColor, size: 48),
          onPressed: () => _playAudio(question.audioUrl!),
        ),
      );
    }
    
    if (question.hasImage == true && question.imageUrl != null) {
      return Center(
        child: Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.textColor, width: 2),
          ),
          child: ClipOval(
            child: Image.asset(
              question.imageUrl!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
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
    final isButtonEnabled = _selectedOptionId != null;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _goToNextQuestion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isButtonEnabled ? theme.accentColor : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade600,
          foregroundColor: theme.buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          provider.assessment?.continueButtonText ?? 'MAG PATULOY',
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
}