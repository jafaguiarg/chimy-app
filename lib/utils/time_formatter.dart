/// Utility class for formatting time to military format (HH:mm)
class TimeFormatter {
  /// Formats a DateTime to military time format (HH:mm)
  /// Example: DateTime(2024, 1, 1, 13, 30) -> "13:30"
  static String toMilitaryTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formats current time to military format
  static String currentMilitaryTime() {
    return toMilitaryTime(DateTime.now());
  }
}

