# PowerShell script to fix questionId and questionType issues
 = "literexia\lib\features\assessments\ui\reading_comprehension_screen.dart"
 = Get-Content  -Raw

# Fix 1: Remove the underscore and number suffix from questionId
 =  -replace "final questionKey = '\$\{widget\.question\.questionId\}_\$\{_currentSentenceQuestionIndex\}';", "final questionKey = widget.question.questionId;"

# Fix 2: Use the correct questionType from JSON data
 =  -replace "questionType: 'text_input',", "questionType: widget.question.questionType ?? 'sentence',"

# Write the changes back to the file
Set-Content   -NoNewline

Write-Host "Changes applied successfully!"
Write-Host "1. Fixed questionId to remove _0 suffix"
Write-Host "2. Fixed questionType to use actual value from JSON"
