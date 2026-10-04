import '../../domain/models/listening_insights.dart';

/// Presentation formatting for the stats screen.
///
/// Kept out of the widgets so the same duration never gets written two
/// different ways in two different files.
class StatsFormat {
  const StatsFormat._();

  /// Listening time, at the precision that scale deserves.
  ///
  /// Seconds disappear above an hour, minutes above a day: "42h 18m" says more
  /// than "42.3h" without pretending to a precision the log does not have.
  static String duration(Duration value) {
    if (value.inSeconds < 60) return '${value.inSeconds}s';
    if (value.inMinutes < 60) return '${value.inMinutes}m';
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  /// Hours and minutes, for a histogram tooltip where the bar already shows
  /// proportion and the readout carries the detail.
  static String hoursMinutes(Duration value) {
    if (value.inHours == 0) return '${value.inMinutes}m';
    final minutes = value.inMinutes.remainder(60);
    return minutes == 0 ? '${value.inHours}h' : '${value.inHours}h ${minutes}m';
  }

  /// Counts that would overflow a stat tile at six digits.
  static String compactCount(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final thousands = value / 1000;
      return '${thousands < 10 ? thousands.toStringAsFixed(1) : thousands.round()}k';
    }
    final millions = value / 1000000;
    return '${millions < 10 ? millions.toStringAsFixed(1) : millions.round()}m';
  }

  static String percent(double share) => '${(share * 100).round()}%';

  /// A signed change against the previous window, or null when there is no
  /// baseline to compare against.
  static String? signedPercent(double? change) {
    if (change == null) return null;
    final rounded = (change * 100).round();
    if (rounded == 0) return 'same as before';
    return '${rounded > 0 ? '+' : ''}$rounded%';
  }

  /// 0 -> 12 AM, 13 -> 1 PM. Delegates to the domain's label so this screen
  /// and the backup export cannot word the same hour differently.
  static String hour(int hour) => hourLabel(hour);

  /// Compact hour for an axis tick.
  static String hourTick(int hour) {
    if (hour == 0) return '12a';
    if (hour == 12) return '12p';
    return hour < 12 ? '${hour}a' : '${hour - 12}p';
  }

  /// Monday -> "Mon". Truncated from the domain's weekday names so the two
  /// cannot fall out of step.
  static String weekday(int index) {
    final name = weekdayName(index);
    return name.length >= 3 ? name.substring(0, 3) : name;
  }

  /// First listening day ever recorded, or null when there is none.
  static String? firstListen(ListeningInsights insights) {
    final first = insights.firstPlayAt;
    if (first == null) return null;
    return '${first.day} ${shortMonth(first.month)} ${first.year}';
  }
}
