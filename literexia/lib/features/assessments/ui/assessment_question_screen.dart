// lib/features/assessments/ui/assessment_question_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/assessment_provider.dart';
import '../models/assessment_model.dart';

class AssessmentQuestionScreen extends StatefulWidget {
  final dynamic assessmentId;
  final AssessmentProvider? provider;

  const AssessmentQuestionScreen({
    Key? key,
    required this.assessmentId,
    this.provider,
  }) : super(key: key);

  @override
  State<AssessmentQuestionScreen> createState() => _AssessmentQuestionScreenState();
}

class _AssessmentQuestionScreenState extends State<AssessmentQuestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load the assessment data when the screen initializes
    _loadAssessment();
  }

  Future<void> _loadAssessment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the provider from the widget if provided, otherwise from context
      final provider = widget.provider ?? Provider.of<AssessmentProvider>(context, listen: false);
      
      // Load the assessment with the specified ID
      await provider.loadAssessment(widget.assessmentId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDarkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _buildAssessmentContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
          SizedBox(height: 20),
          Text(
            'Loading assessment...',
            style: TextStyle(color: Colors.white),
          ),
        ],
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
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentContent() {
    return Consumer<AssessmentProvider>(
      builder: (context, provider, child) {
        // Check if assessment is complete
        if (provider.isAssessmentComplete) {
          return _buildResultsScreen(provider);
        }

        // Get the current question
        final currentQuestion = provider.currentQuestion;
        if (currentQuestion == null) {
          return const Center(
            child: Text(
              'No questions available',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Display the progress indicator, question type, and question content
        return Column(
          children: [
            _buildProgressIndicator(provider),
            _buildQuestionTypeIndicator(provider),
            Expanded(
              child: _buildQuestionContent(currentQuestion, provider),
            ),
            _buildContinueButton(provider),
          ],
        );
      },
    );
  }

  Widget _buildProgressIndicator(AssessmentProvider provider) {
    final current = provider.currentQuestionIndex + 1;
    final total = provider.totalQuestions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$current/$total',
                style: TextStyle(
                  color: AppTheme.accentAmber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeIndicator(AssessmentProvider provider) {
    // This is the key part that fixes the "Unknown question type" issue
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Text(
        provider.currentQuestionTypeName, // Use the getter from provider
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildQuestionContent(Question question, AssessmentProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          // Display question media if available
          if (question.hasImage == true && question.imageUrl != null)
            _buildQuestionImage(question.imageUrl!, question.imageAlt),

          if (question.hasAudio == true && question.audioUrl != null)
            _buildAudioPlayer(question.audioUrl!),

          const SizedBox(height: 24),

          // Answer options
          ...question.options.map((option) => _buildOptionButton(
            context,
            provider,
            option,
          )),
        ],
      ),
    );
  }

  Widget _buildQuestionImage(String imageUrl, String? imageAlt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: imageAlt != null
          ? Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                color: Colors.black54,
                child: Text(
                  imageAlt,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAudioPlayer(String audioUrl) {
    // Simplified audio player UI - would need plugin implementation
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            onPressed: () {
              // Audio playback logic would go here
              print('Play audio: $audioUrl');
            },
          ),
          const SizedBox(width: 16),
          const Text(
            'Play Audio',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context,
    AssessmentProvider provider,
    AssessmentOption option,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () {
          provider.answerCurrentQuestion(option.optionId);
        },
        child: Text(
          option.optionText,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildContinueButton(AssessmentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentAmber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          // This button would be used for text input questions
          // For multiple choice, we handle directly in the option buttons
        },
        child: Text(
          provider.assessment?.continueButtonText ?? 'MAG PATULOY',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
              onPressed: () {
                Navigator.of(context).pop();
              },
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