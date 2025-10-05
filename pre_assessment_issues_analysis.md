# Pre-Assessment Issues Analysis

## Problem Identified

Based on the user profile data shown and code analysis, there are **two critical issues**:

### 1. **Data Duplication Issue**
Pre-assessment responses are being saved to **BOTH** collections:
- ✅ **Correct**: `Pre_Assessment.user_responses` (via `saveIndividualQuestionResponse`)
- ❌ **Incorrect**: `test.student_responses` (via `saveDirectToStudentResponses`)

### 2. **User Profile Update Issue**
The `readingLevel`, `readingPercentage`, and `preAssessmentCompleted` fields are not being updated in the user document after pre-assessment completion.

## Root Cause Analysis

### Data Duplication Root Cause

Looking at the code flow in `assessment_provider.dart` lines 2828-2832:

```dart
final result = isInterventionQuestion
    ? await _databaseService.saveInterventionQuestionResponse(responseData)
    : _isPreAssessment
        ? await _databaseService.saveIndividualQuestionResponse(responseData)  // ✅ Correct
        : await _databaseService.saveMainAssessmentQuestionResponse(responseData);
```

**However**, there are multiple places where `saveDirectToStudentResponses` is being called:

1. **Line 2906**: `await _databaseService.saveDirectToStudentResponses(responseData);`
2. **Line 2854**: `saveDirectToStudentResponses` method exists and bypasses assessment type detection
3. **Line 2631**: `saveDirectToStudentResponses` forces save to `test.student_responses`

### User Profile Update Root Cause

The user profile update flow has multiple potential failure points:

1. **Database Connection Issues**: If MongoDB is not connected, updates fail silently
2. **Type Conversion Issues**: `preAssessmentCompleted` stored as integer (0/1) in SQLite but boolean in MongoDB
3. **Multiple Update Paths**: Different components trying to update the same fields
4. **Error Handling**: Some update operations don't have proper error handling

## Code Evidence

### Data Duplication Evidence

```dart
// In assessment_provider.dart line 2854
/// Save individual response directly to student_responses collection (bypasses assessment type detection)
Future<void> saveDirectToStudentResponses({
  // ... parameters
}) async {
  // ...
  final result = await _databaseService.saveDirectToStudentResponses(responseData);
  // This bypasses the assessment type detection and always saves to student_responses
}
```

```dart
// In database_service.dart line 2631
/// Direct save to student_responses collection (bypasses assessment type detection)
Future<bool> saveDirectToStudentResponses(Map<String, dynamic> responseData) async {
  // ...
  final collection = _db!.collection('student_responses');  // ❌ Always saves to student_responses
  // ...
}
```

### User Profile Update Evidence

```dart
// In database_service.dart line 1589
await updateUserPreAssessmentCompletion(userId, readingLevel, readingPercentage);
```

But the `updateUserPreAssessmentCompletion` method may be failing silently.

## Solutions

### 1. Fix Data Duplication

**Remove or fix the `saveDirectToStudentResponses` calls for pre-assessments:**

```dart
// In assessment_provider.dart - Remove or conditionally call saveDirectToStudentResponses
// Only call it for main assessments, not pre-assessments
if (!_isPreAssessment && !isInterventionQuestion) {
  await _databaseService.saveDirectToStudentResponses(responseData);
}
```

### 2. Fix User Profile Updates

**Add proper error handling and logging:**

```dart
// In database_service.dart - updateUserPreAssessmentCompletion method
Future<void> updateUserPreAssessmentCompletion(String userId, String readingLevel, double readingPercentage) async {
  try {
    print('[DatabaseService] Updating user pre-assessment completion...');
    
    final result = await updateUserPreAssessmentStatus(
      userId,
      true,  // completed
      readingLevel,
      readingPercentage,
    );
    
    if (result) {
      print('[DatabaseService] ✅ User profile updated successfully');
    } else {
      print('[DatabaseService] ❌ Failed to update user profile');
    }
  } catch (e) {
    print('[DatabaseService] ❌ Error updating user profile: $e');
  }
}
```

### 3. Add Validation

**Add validation to ensure pre-assessment data goes to correct collection:**

```dart
// In assessment_provider.dart - add validation
if (_isPreAssessment && targetCollection != 'Pre_Assessment.user_responses') {
  print('[AssessmentProvider] ❌ ERROR: Pre-assessment data being routed to wrong collection!');
  return;
}
```

## Immediate Action Items

1. **Remove duplicate saves**: Find and remove calls to `saveDirectToStudentResponses` for pre-assessments
2. **Fix user profile updates**: Add proper error handling to `updateUserPreAssessmentCompletion`
3. **Add validation**: Ensure pre-assessment data only goes to `Pre_Assessment.user_responses`
4. **Test the flow**: Verify that user profile is updated after pre-assessment completion

## Files to Modify

1. `literexia/lib/features/assessments/logic/assessment_provider.dart`
2. `literexia/lib/services/database_service.dart`
3. `literexia/lib/features/assessments/repositories/assessment_repository.dart`

## Expected Outcome

After fixes:
- Pre-assessment responses should only be saved to `Pre_Assessment.user_responses`
- User profile should be updated with `readingLevel`, `readingPercentage`, and `preAssessmentCompleted: true`
- No data duplication between collections
