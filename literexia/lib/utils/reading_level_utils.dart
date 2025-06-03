/// Utility class for handling reading level normalization
class ReadingLevelUtils {
  /// Normalizes a reading level string to a standard format
  static String normalizeReadingLevel(String level) {
    // Convert to lowercase and trim for consistent comparison
    final normalized = level.toLowerCase().trim();
    
    // Map variations to standard levels
    if (normalized.contains('low') && normalized.contains('emerging')) {
      return 'Low Emerging';
    } else if (normalized.contains('high') && normalized.contains('emerging')) {
      return 'High Emerging';
    } else if (normalized.contains('developing')) {
      return 'Developing';
    } else if (normalized.contains('transitioning')) {
      return 'Transitioning';
    } else if (normalized.contains('grade') && normalized.contains('level')) {
      return 'At Grade Level';
    }
    
    // Default to the original level if no match found
    return level;
  }
} 