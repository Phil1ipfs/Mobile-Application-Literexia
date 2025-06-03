// lib/features/intervention/ui/intervention_status_widget.dart - Enhanced for Prominence

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/intervention_provider.dart';
import '../../settings/provider/theme_provider.dart';
import '../ui/intervention_assessment_screen.dart';

class InterventionStatusWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showProgress;
  
  const InterventionStatusWidget({
    Key? key,
    this.onTap,
    this.showProgress = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final interventionProvider = Provider.of<InterventionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    // ENHANCED DEBUG: Print current status
    print('[InterventionStatusWidget] ENHANCED Current Status:');
    print('[InterventionStatusWidget] - Has Completed All Lessons: ${interventionProvider.hasCompletedAllLessons}');
    print('[InterventionStatusWidget] - Has Completed All Categories: ${interventionProvider.hasCompletedAllCategories}');
    print('[InterventionStatusWidget] - Has Failed Categories: ${interventionProvider.hasFailedCategories}');
    print('[InterventionStatusWidget] - Failed Categories List: ${interventionProvider.failedCategories}');
    print('[InterventionStatusWidget] - Has Interventions: ${interventionProvider.hasInterventions}');
    print('[InterventionStatusWidget] - Category Details Count: ${interventionProvider.categoryDetails.length}');
    print('[InterventionStatusWidget] - Overall Average: ${interventionProvider.overallAverage}');

    // ENHANCED LOGIC: Show intervention widget under multiple conditions
    bool shouldShow = _shouldShowInterventionWidget(interventionProvider);
    
    print('[InterventionStatusWidget] Should show intervention: $shouldShow');

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final hasInterventions = interventionProvider.hasInterventions;
    final urgencyLevel = _getUrgencyLevel(interventionProvider);
    final urgencyColor = _getUrgencyColor(urgencyLevel);

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 8,
        shadowColor: urgencyColor.withOpacity(0.4),
        color: theme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: urgencyColor, width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                urgencyColor.withOpacity(0.1),
                urgencyColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onTap ?? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InterventionAssessmentScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROMINENT HEADER
                  Row(
                    children: [
                      // Animated attention-grabbing icon
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: urgencyColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          hasInterventions ? Icons.assignment_turned_in : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INTERVENTION REQUIRED',
                              style: TextStyle(
                                color: urgencyColor,
                                fontSize: themeProvider.getRealFontSize(18),
                                fontWeight: FontWeight.bold,
                                fontFamily: themeProvider.fontFamily,
                                letterSpacing: themeProvider.getRealLetterSpacing(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasInterventions ? 'Assessment Ready' : 'Contact Teacher',
                              style: TextStyle(
                                color: hasInterventions ? Colors.green : Colors.orange,
                                fontSize: themeProvider.getRealFontSize(14),
                                fontWeight: FontWeight.w600,
                                fontFamily: themeProvider.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Urgency indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          urgencyLevel.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: themeProvider.getRealFontSize(12),
                            fontWeight: FontWeight.bold,
                            fontFamily: themeProvider.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // INTERVENTION STATUS MESSAGE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.textColor.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      _getStatusMessage(interventionProvider),
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: themeProvider.getRealFontSize(15),
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FAILED CATEGORIES DISPLAY (if any)
                  if (interventionProvider.failedCategories.isNotEmpty) ...[
                    Text(
                      'Categories needing improvement:',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: themeProvider.getRealFontSize(14),
                        fontWeight: FontWeight.bold,
                        fontFamily: themeProvider.fontFamily,
                        letterSpacing: themeProvider.getRealLetterSpacing(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: interventionProvider.failedCategories.map((category) {
                        final score = interventionProvider.getCategoryScore(category);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                score > 0 ? '$category (${score.toStringAsFixed(0)}%)' : category,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: themeProvider.getRealFontSize(12),
                                  fontFamily: themeProvider.fontFamily,
                                  letterSpacing: themeProvider.getRealLetterSpacing(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OVERALL SCORE INFO (if available)
                  if (interventionProvider.overallAverage > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Overall Score: ${interventionProvider.overallAverage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: themeProvider.getRealFontSize(14),
                              fontWeight: FontWeight.w600,
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing: themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Need: 75%+',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: themeProvider.getRealFontSize(12),
                              fontFamily: themeProvider.fontFamily,
                              letterSpacing: themeProvider.getRealLetterSpacing(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // PROMINENT ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: hasInterventions
                          ? (onTap ?? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const InterventionAssessmentScreen(),
                                ),
                              );
                            })
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please contact your teacher to assign intervention assessments.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: urgencyColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: urgencyColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      icon: Icon(
                        hasInterventions ? Icons.play_arrow : Icons.contact_support,
                        size: 24,
                      ),
                      label: Text(
                        hasInterventions ? 'TAKE ASSESSMENT NOW' : 'CONTACT TEACHER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: themeProvider.getRealFontSize(16),
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
      ),
    );
  }

  /// Enhanced logic to determine if intervention widget should be shown
  bool _shouldShowInterventionWidget(InterventionProvider provider) {
    // FIXED: Only show intervention widget if student has REALLY completed everything
    
    // Condition 1: Must have completed all lessons
    if (!provider.hasCompletedAllLessons) {
      print('[InterventionStatusWidget] Not showing: Lessons not completed');
      return false;
    }
    
    // Condition 2: Must have completed all category assessments (not just pre-assessment)
    if (!provider.hasCompletedAllCategories) {
      print('[InterventionStatusWidget] Not showing: Categories not completed');
      return false;
    }
    
    // Condition 3: Must have real category results with meaningful scores
    if (provider.categoryDetails.isEmpty) {
      print('[InterventionStatusWidget] Not showing: No category details');
      return false;
    }
    
    // Check if we have real scores (not just zeros from pre-assessment)
    int categoriesWithRealScores = 0;
    for (final category in provider.categoryDetails) {
      final score = (category['score'] as num?)?.toDouble() ?? 0.0;
      if (score > 0) {
        categoriesWithRealScores++;
      }
    }
    
    if (categoriesWithRealScores < 3) {
      print('[InterventionStatusWidget] Not showing: Not enough real category scores ($categoriesWithRealScores)');
      return false;
    }
    
    // Condition 4: Must have failed categories that need intervention
    if (!provider.hasFailedCategories || provider.failedCategories.isEmpty) {
      print('[InterventionStatusWidget] Not showing: No failed categories');
      return false;
    }
    
    print('[InterventionStatusWidget] Show because: All conditions met for intervention');
    return true;
  }

  /// Get status message based on current intervention state - UPDATED
  String _getStatusMessage(InterventionProvider provider) {
    // Check the specific reason why intervention might not be available
    if (!provider.hasCompletedAllLessons) {
      return 'Complete all your lessons first. You need to finish Aralin 1 through 5 before intervention becomes available.';
    }
    
    if (!provider.hasCompletedAllCategories || provider.categoryDetails.isEmpty) {
      return 'Complete your category assessments first. After finishing all lessons, you need to take category assessments.';
    }
    
    // Check for real scores
    int categoriesWithRealScores = 0;
    for (final category in provider.categoryDetails) {
      final score = (category['score'] as num?)?.toDouble() ?? 0.0;
      if (score > 0) {
        categoriesWithRealScores++;
      }
    }
    
    if (categoriesWithRealScores < 3) {
      return 'You need to complete more category assessments. Pre-assessment results alone are not sufficient for intervention.';
    }
    
    if (provider.hasInterventions) {
      return 'You have intervention assessments available. Complete them to improve your reading skills in areas that need attention.';
    }
    
    if (provider.failedCategories.isNotEmpty) {
      return 'You need to improve in ${provider.failedCategories.length} reading categories. Contact your teacher to get intervention assignments.';
    }
    
    return 'Great job! All your reading categories are at passing level.';
  }

  /// Get urgency level based on scores and completion status
  String _getUrgencyLevel(InterventionProvider provider) {
    if (provider.overallAverage > 0) {
      if (provider.overallAverage < 50.0) return 'critical';
      if (provider.overallAverage < 65.0) return 'high';
      if (provider.overallAverage < 75.0) return 'medium';
    }
    
    // Based on number of failed categories
    if (provider.failedCategories.length >= 4) return 'critical';
    if (provider.failedCategories.length >= 2) return 'high';
    if (provider.failedCategories.length >= 1) return 'medium';
    
    return 'low';
  }

  /// Get color based on urgency level
  Color _getUrgencyColor(String urgencyLevel) {
    switch (urgencyLevel) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.blue;
    }
  }
}