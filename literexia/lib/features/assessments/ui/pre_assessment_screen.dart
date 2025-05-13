// lib/features/assessments/ui/pre_assessment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:literexia/features/assessments/logic/assessment_provider.dart';
import 'pre_assessment_question_screen.dart';

class PreAssessmentScreen extends StatelessWidget {
  const PreAssessmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDarkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDarkBlue,
        elevation: 0,
        title: const Text(
          'Panimulang Kasanayan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro text
              const Text(
                'Sagutin ang mga tanong para malaman kung nasaan ka na sa iyong pag-aaral.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              // Assessment card
              _buildAssessmentCard(
                context,
                title: 'Alphabet Knowledge Pre-Assessment',
                description: 'Assessment for evaluating basic alphabet knowledge in Filipino',
                assessmentId: 1,
              ),

              const Spacer(),

              // Instructions with amber accent
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Mga Panuto:',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Sagutan ang lahat ng mga tanong sa paimulang pagtatasa.',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '2. Kung hindi mo alam ang sagot, pumili ng pinakamalapit na sagot.',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '3. Hindi mo maaaring i-skip ang anumang tanong.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(
    BuildContext context, {
    required String title,
    required String description,
    required int assessmentId,
  }) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      color: AppTheme.lessonPanelBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz,
                  color: Colors.amber,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '5 Questions • Filipino',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _startPreAssessment(context, assessmentId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'SIMULAN ANG PAGTATASA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPreAssessment(BuildContext context, int assessmentId) {
    // Create provider
    final assessmentProvider = AssessmentProvider();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: assessmentProvider,
          child: PreAssessmentQuestionScreen(
            assessmentId: assessmentId,
            provider: assessmentProvider,
            onAssessmentComplete: (readingLevel, score, total) {
              // Handle completion, e.g., save to user profile
              print('Assessment completed: Level=$readingLevel, Score=$score/$total');
            },
          ),
        ),
      ),
    );
  }
}