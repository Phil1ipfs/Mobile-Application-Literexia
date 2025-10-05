# ReadingPercentage and PreAssessmentCompleted Flow Analysis

## Flow Diagram

```
USER REGISTRATION/LOGIN
    ↓
preAssessmentCompleted = false
readingPercentage = null
    ↓
    ↓
HOME SCREEN CHECK
    ↓
    ↓
┌─────────────────────────────────────┐
│ if (preAssessmentCompleted == false) │
│     OR readingLevel == null          │
└─────────────────────────────────────┘
    ↓
    ↓
PRE-ASSESSMENT FLOW
    ↓
    ↓
┌─────────────────────────────────────┐
│ AssessmentProvider                  │
│ - Loads pre-assessment questions    │
│ - Tracks user answers               │
│ - Calculates score                  │
└─────────────────────────────────────┘
    ↓
    ↓
SCORE CALCULATION
    ↓
    ↓
┌─────────────────────────────────────┐
│ readingPercentage =                 │
│   ((score / totalQuestions) * 100)  │
│   .round()                          │
└─────────────────────────────────────┘
    ↓
    ↓
READING LEVEL DETERMINATION
    ↓
    ↓
┌─────────────────────────────────────┐
│ Dynamic Scoring Rules Applied:      │
│ - Part 1 Score Range               │
│ - Reading Percentage Range          │
│ - Comprehension Score Range        │
└─────────────────────────────────────┘
    ↓
    ↓
DATABASE UPDATES
    ↓
    ↓
┌─────────────────────────────────────┐
│ MongoDB:                            │
│ - Update user document              │
│ - Set preAssessmentCompleted = true │
│ - Set readingPercentage             │
│ - Set readingLevel                  │
└─────────────────────────────────────┘
    ↓
    ↓
┌─────────────────────────────────────┐
│ Local SQLite:                       │
│ - Update users table                │
│ - Set preAssessmentCompleted = 1    │
│ - Set readingPercentage             │
│ - Set readingLevel                  │
└─────────────────────────────────────┘
    ↓
    ↓
AUTH PROVIDER UPDATE
    ↓
    ↓
┌─────────────────────────────────────┐
│ AuthProvider:                       │
│ - Update currentUser object         │
│ - Set preAssessmentCompleted = true │
│ - Set readingPercentage             │
│ - Save session                      │
└─────────────────────────────────────┘
    ↓
    ↓
NAVIGATION LOGIC
    ↓
    ↓
┌─────────────────────────────────────┐
│ Home Screen:                        │
│ if (preAssessmentCompleted == true) │
│   → Show lessons and main assessments│
│ else                                │
│   → Redirect to pre-assessment     │
└─────────────────────────────────────┘
```

## Key Components

### 1. AssessmentProvider (assessment_provider.dart)
- **State Management**: Manages `_readingPercentage` and assessment state
- **Calculation Logic**: Handles both pre-assessment and main assessment calculations
- **Dynamic Scoring**: Uses database-driven scoring rules for reading level determination

### 2. DatabaseService (database_service.dart)
- **MongoDB Operations**: Updates user documents with assessment results
- **Local SQLite**: Maintains local cache of user data
- **Completion Tracking**: Manages `preAssessmentCompleted` status

### 3. AuthProvider (auth_provider.dart)
- **User Session**: Maintains current user state in memory
- **State Updates**: Handles `setPreAssessmentCompleted()` and `updateReadingPercentage()`
- **Session Persistence**: Saves user state to local storage

### 4. User Model (user_model.dart)
- **Data Structure**: Defines `readingPercentage` and `preAssessmentCompleted` fields
- **Type Safety**: Handles type conversions and null safety
- **Copy Operations**: Supports immutable updates via `copyWith()`

## Critical Flow Points

### Pre-Assessment Completion
1. **Trigger**: User completes all pre-assessment categories
2. **Calculation**: `readingPercentage = (score / totalQuestions) * 100`
3. **Database Update**: `preAssessmentCompleted = true`
4. **Navigation**: User gains access to lessons and main assessments

### Main Assessment Flow
1. **Trigger**: User takes category-specific assessments
2. **Calculation**: Similar percentage calculation
3. **Update**: Reading level and percentage may be updated
4. **Navigation**: Return to home screen or next lesson

## Potential Issues Identified

### 1. Type Conversion Issues
- **Problem**: `preAssessmentCompleted` stored as integer (0/1) in SQLite but boolean in MongoDB
- **Impact**: Potential type mismatch during data synchronization

### 2. State Synchronization
- **Problem**: Multiple sources of truth (AuthProvider, DatabaseService, AssessmentProvider)
- **Impact**: Potential inconsistencies between memory and database state

### 3. Null Safety
- **Problem**: `readingPercentage` can be null in User model
- **Impact**: Need for null checks throughout the application

### 4. Assessment Type Confusion
- **Problem**: Both pre-assessment and main assessment update the same fields
- **Impact**: Potential overwriting of pre-assessment results with main assessment results

## Recommendations

### 1. Centralize State Management
- Use a single source of truth for user assessment state
- Implement proper state synchronization between components

### 2. Improve Type Safety
- Standardize data types across all storage layers
- Implement proper type conversion utilities

### 3. Add Validation
- Validate assessment completion before allowing navigation
- Implement proper error handling for state updates

### 4. Separate Assessment Types
- Consider separate fields for pre-assessment vs main assessment results
- Implement proper assessment type tracking
