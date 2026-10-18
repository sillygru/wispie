import '../../domain/models/listening_insights.dart';
import '../../l10n/app_localizations.dart';

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
  static String duration(Duration value, AppLocalizations l10n) {
    if (value.inSeconds < 60) {
      return l10n.statsDurationSeconds(value.inSeconds);
    }
    if (value.inMinutes < 60) {
      return l10n.statsDurationMinutes(value.inMinutes);
    }
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return minutes == 0
        ? l10n.statsDurationHours(hours)
        : l10n.statsDurationHoursMinutes(hours, minutes);
  }

  /// Hours and minutes, for a histogram tooltip where the bar already shows
  /// proportion and the readout carries the detail.
  static String hoursMinutes(Duration value, AppLocalizations l10n) {
    if (value.inHours == 0) {
      return l10n.statsDurationMinutes(value.inMinutes);
    }
    final minutes = value.inMinutes.remainder(60);
    return minutes == 0
        ? l10n.statsDurationHours(value.inHours)
        : l10n.statsDurationHoursMinutes(value.inHours, minutes);
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
  static String? signedPercent(double? change, AppLocalizations l10n) {
    if (change == null) return null;
    final rounded = (change * 100).round();
    if (rounded == 0) return l10n.statsSameAsBefore;
    return '${rounded > 0 ? '+' : ''}$rounded%';
  }

  /// 0 -> 12 AM, 13 -> 1 PM. Delegates to the domain's label so this screen
  /// and the backup export cannot word the same hour differently.
  static String hour(int hour) => hourLabel(hour);

  /// Compact hour for an axis tick.
  static String hourTick(int hour, AppLocalizations l10n) {
    if (hour == 0) return l10n.statsHourTickAm(12);
    if (hour == 12) return l10n.statsHourTickPm(12);
    return hour < 12
        ? l10n.statsHourTickAm(hour)
        : l10n.statsHourTickPm(hour - 12);
  }

  /// Monday -> "Mon". Truncated from the domain's weekday names so the two
  /// cannot fall out of step.
  static String weekday(int index) {
    final name = weekdayName(index);
    return name.length >= 3 ? name.substring(0, 3) : name;
  }

  /// One-letter weekday for an axis tick, derived from the weekday name so the
  /// chart cannot disagree with the readout above it.
  static String weekdayInitial(int index) {
    final name = weekdayName(index);
    return name.isEmpty ? '' : name.substring(0, 1);
  }

  /// First listening day ever recorded, or null when there is none.
  static String? firstListen(ListeningInsights insights) {
    final first = insights.firstPlayAt;
    if (first == null) return null;
    return '${first.day} ${shortMonth(first.month)} ${first.year}';
  }
}
