// lib/features/assessments/ui/assessment_question_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/assessment_provider.dart';
import '../models/assessment_model.dart';

class AssessmentQuestionScreen extends StatefulWidget {
  final dynamic assessmentId;
  final AssessmentProvider? provider;
  final Assessment? assessment; // Optional if loaded via assessmentId
  final Function(Question, AssessmentOption)? onAnswerSelected; // Optional callback
  final Function()? onClose; // Optional callback

  const AssessmentQuestionScreen({
    Key? key,
    required this.assessmentId,
    this.provider,
    this.assessment,
    this.onAnswerSelected,
    this.onClose,
  }) : super(key: key);

  @override
  State<AssessmentQuestionScreen> createState() => _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedOptionId;
  late AssessmentProvider _provider;

  @override
  void initState() {
    super.initState();
    // Initialize provider
    _provider = widget.provider ?? Provider.of<AssessmentProvider>(context, listen: false);
    
    // Load the assessment data when the screen initializes
    _loadAssessment();
  }

  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // If assessment is provided directly, use it
      if (widget.assessment != null) {
        _provider.setAssessment(widget.assessment!);
        setState(() {
          _isLoading = false;
          _selectedOptionId = null;
        });
        return;
      }
      
      // Otherwise load assessment from repository
      await _provider.loadAssessment(widget.assessmentId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedOptionId = null; // Reset selected option when loading new assessment
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

  void _goToNextQuestion() {
    if (_selectedOptionId == null) return; // Don't proceed if no option selected
    
    final currentQuestion = _provider.currentQuestion;
    if (currentQuestion == null) return;
    
    // Find the selected option
    final selectedOption = currentQuestion.options.firstWhere(
      (option) => option.optionId == _selectedOptionId,
      orElse: () => throw Exception('Option not found'),
    );
    
    // Call callback if provided
    if (widget.onAnswerSelected != null) {
      widget.onAnswerSelected!(currentQuestion, selectedOption);
    }
    
    // Answer the current question with selected option
    _provider.answerCurrentQuestion(_selectedOptionId!);
    
    // Reset selection for next question
    setState(() {
      _selectedOptionId = null;
    });
  }

  void _handleClose() {
    // Call callback if provided
    if (widget.onClose != null) {
      widget.onClose!();
    }
    Navigator.of(context).pop();
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
                : _buildAssessmentContent(),
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

  Widget _buildAssessmentContent() {
    // Check if assessment is complete
    if (_provider.isAssessmentComplete) {
      return _buildResultsScreen(_provider);
    }

    // Get the current question
    final currentQuestion = _provider.currentQuestion;
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
            onPressed: _handleClose,
          ),
        ),
        
        // Progress indicator (e.g., "1/5")
        _buildProgressIndicator(_provider),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Display letter or content in rounded rectangle
                _buildQuestionLetterDisplay(currentQuestion),
                
                const SizedBox(height: 40),
                
                // Question text
                _buildQuestionText(currentQuestion),
                
                const SizedBox(height: 30),
                
                // Audio/Image content if available
                if (currentQuestion.hasAudio == true || currentQuestion.hasImage == true)
                  _buildMediaContent(currentQuestion),
                  
                const SizedBox(height: 20),
                
                // Answer options
                ...currentQuestion.options.map((option) => 
                  _buildOptionButton(option)
                ),
                
                const Spacer(),
                
                // Continue button
                _buildContinueButton(_provider),
                
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          
          // Yellow progress indicator with pill
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: current / total,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          
          // Pill with progress text
          Container(
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
        ],
      ),
    );
  }

  Widget _buildQuestionLetterDisplay(Question question) {
    // Extract the letter from question or use a placeholder
    
                            
    if (question.questionTypeId == 'audio_image_question') {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: (question.hasImage == true) ? 
          Center(child: Text('Image', style: TextStyle(color: Colors.white))) :
          const SizedBox.shrink(),
      );
    }
    
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber, width: 2),
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  Widget _buildQuestionText(Question question) {
    return Column(
      children: [
        Text(
          question.questionText,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.w500,
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.volume_up, color: Colors.amber, size: 30),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              question.audioText ?? 'APA',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    
    if (question.hasImage == true && question.imageUrl != null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: NetworkImage(question.imageUrl!),
            fit: BoxFit.cover,
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
      child: GestureDetector(
        onTap: () => _selectOption(option.optionId),
        child: Container(
          width: double.infinity,
          height: 70,
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
                fontSize: 24,
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
    
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: isButtonEnabled ? Colors.amber : Colors.grey.shade600,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: isButtonEnabled ? _goToNextQuestion : null,
          child: Center(
            child: Text(
              provider.assessment?.continueButtonText ?? 'MAG PATULOY',
              style: TextStyle(
                color: isButtonEnabled ? Colors.black : Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(AssessmentProvider provider) {
    final score = provider.score;
    final total = provider.totalQuestions;
    final percentage = total > 0 ? (score / total) * 100 : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Score: $score/$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: AppTheme.accentAmber,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                provider.resetAssessment();
              },
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _handleClose,
              child: const Text(
                'Back to Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}