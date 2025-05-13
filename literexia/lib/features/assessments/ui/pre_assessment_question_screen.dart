// lib/features/assessments/ui/pre_assessment_question_screen.dart
import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    super.dispose();
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
  widget.provider.updateUserReadingLevel(
    authProvider, 
    readingLevel,
    readingPercentage: readingPercentage, // Pass the reading percentage here
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
        readingPercentage: readingPercentage, // Pass it to the results screen
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildQuestionContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 20),
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
              ),
              onPressed: _loadAssessment,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionContent() {
    final provider = widget.provider;
    final currentQuestion = provider.currentQuestion;
    
    if (currentQuestion == null) {
      return const Center(
        child: Text(
          'No questions available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        // Close button at top left
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        
        // Progress indicator (e.g., "1/5")
        _buildProgressIndicator(provider),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ListView(
              children: [
                const SizedBox(height: 20),
                
                // Question prompt (e.g., "ASO", "BO + LA", etc.)
                _buildQuestionPrompt(currentQuestion),
                
                const SizedBox(height: 20),
                
                // Question text/instruction
                _buildQuestionInstruction(currentQuestion),
                
                const SizedBox(height: 40),
                
                // Media content (audio/image)
                if (currentQuestion.hasAudio == true || currentQuestion.hasImage == true)
                  _buildMediaContent(currentQuestion),
                  
                const SizedBox(height: 20),
                
                // Answer options
                ...currentQuestion.options.map((option) => 
                  _buildOptionButton(option)
                ),
                
                const SizedBox(height: 40),
                
                // Continue button
                _buildContinueButton(provider),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(AssessmentProvider provider) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Stack(
        children: [
          // Background track
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          // Progress indicator
          FractionallySizedBox(
            widthFactor: current / total,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.amber,
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
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$current/$total',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPrompt(Question question) {
    final prompt = question.displayedText ?? '';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber),
      ),
      child: Center(
        child: Text(
          prompt,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionInstruction(Question question) {
    return Column(
      children: [
        Text(
          question.questionText,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        const Divider(color: Colors.amber, thickness: 1),
      ],
    );
  }

  Widget _buildMediaContent(Question question) {
    if (question.hasAudio == true && question.audioUrl != null) {
      return Center(
        child: IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.amber, size: 48),
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
            border: Border.all(color: Colors.white, width: 2),
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

  Widget _buildOptionButton(AssessmentOption option) {
    final isSelected = _selectedOptionId == option.optionId;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _selectOption(option.optionId),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber, width: 2),
            borderRadius: BorderRadius.circular(30),
            color: isSelected ? Colors.amber.withOpacity(0.3) : Colors.transparent,
          ),
          child: Center(
            child: Text(
              option.optionText,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(AssessmentProvider provider) {
    final isButtonEnabled = _selectedOptionId != null;
    
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _goToNextQuestion : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isButtonEnabled ? Colors.amber : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade600,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          provider.assessment?.continueButtonText ?? 'MAG PATULOY',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isButtonEnabled ? Colors.black : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}