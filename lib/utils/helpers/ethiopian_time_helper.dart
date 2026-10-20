import 'package:intl/intl.dart';

/// Helper to convert and format Gregorian times into Ethiopian 12-hour cycle time representation.
///
/// Ethiopian Time Rule:
/// - The 12-hour day cycle starts at 7:00 AM Gregorian (1:00 AM Ethiopian) and runs until 6:59 PM (12:59 AM Ethiopian).
/// - The 12-hour night cycle starts at 7:00 PM Gregorian (1:00 PM Ethiopian) and runs until 6:59 AM (12:59 PM Ethiopian).
class EthiopianTimeHelper {
  EthiopianTimeHelper._();

  /// East Africa Time offset: UTC+3 hours.
  static const Duration eastAfricaOffset = Duration(hours: 3);

  /// Safely parses a Supabase/PostgreSQL timestamp string into a UTC DateTime.
  ///
  /// Supabase/PostgreSQL stores and sends timestamps in UTC. However, when serialized
  /// over JSON, the ISO-8601 string often lacks an explicit trailing 'Z' or timezone
  /// offset (e.g. "2026-10-17T18:51:38.241548"). Standard [DateTime.tryParse] in Dart
  /// misinterprets such strings as device local time. If the device is in UTC+3 (EAT),
  /// converting to UTC and then to EAT cancels out, leaving the timestamp 3 hours behind!
  ///
  /// This method guarantees that timestamps without an explicit offset are correctly
  /// treated as UTC.
  static DateTime? parseSupabaseUtc(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (!s.endsWith('Z') &&
        !s.contains('+') &&
        !RegExp(r'-\d{2}(:\d{2})?$').hasMatch(s)) {
      s = '${s}Z';
    }
    return DateTime.tryParse(s);
  }

  /// Parses any timestamp string or [DateTime] and converts it directly to East Africa Time (UTC+3).
  static DateTime? parseToEastAfricaTime(dynamic raw) {
    final utc = parseSupabaseUtc(raw);
    if (utc == null) return null;
    return utc.toUtc().add(eastAfricaOffset);
  }

  /// Converts any [DateTime] into East African Time (UTC+3).
  static DateTime toEastAfricaTime(DateTime dateTime) {
    return dateTime.toUtc().add(eastAfricaOffset);
  }

  /// Converts a [DateTime] into Ethiopian 12-hour formatted time (e.g., "9:00 AM" or "1:30 PM").
  ///
  /// [showPeriod]: whether to append AM/PM or Amharic period indicator.
  /// [useAmharic]: if true, uses 'ጠዋት', 'ከሰዓት', 'ማታ', 'ሌሊት' instead of 'AM'/'PM'.
  static String formatEthiopianTime(
    DateTime dateTime, {
    bool showPeriod = true,
    bool useAmharic = false,
  }) {
    final eat = toEastAfricaTime(dateTime);
    final hour = eat.hour;
    final minute = eat.minute;
    final minuteStr = minute.toString().padLeft(2, '0');

    int ethHour;
    String period;

    if (hour >= 7 && hour <= 18) {
      // Daytime (AM): 7 AM (hour 7) -> 1 AM ... 6 PM (hour 18) -> 12 AM
      ethHour = hour - 6;
      period = useAmharic
          ? (ethHour <= 5 ? 'ጠዋት' : 'ከሰዓት')
          : 'AM';
    } else {
      // Nighttime (PM): 7 PM (hour 19) -> 1 PM ... 6 AM (hour 6) -> 12 PM
      ethHour = hour >= 19 ? hour - 18 : hour + 6;
      period = useAmharic
          ? (ethHour <= 5 ? 'ማታ' : 'ሌሊት')
          : 'PM';
    }

    if (!showPeriod) {
      return '$ethHour:$minuteStr';
    }
    return '$ethHour:$minuteStr $period';
  }

  /// Formats date smartly (omits year if it matches the current year in EAT).
  /// e.g. "Aug 27" for current year, "Aug 27, 2025" for a different year.
  static String formatDate(DateTime dateTime) {
    final eat = toEastAfricaTime(dateTime);
    final nowEat = toEastAfricaTime(DateTime.now());
    final isCurrentYear = eat.year == nowEat.year;
    return isCurrentYear
        ? DateFormat('MMM dd').format(eat)
        : DateFormat('MMM dd, yyyy').format(eat);
  }

  /// Formats standard 12-hour time in East Africa Time (UTC+3) (e.g. "4:00 PM").
  static String formatGregorianTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(toEastAfricaTime(dateTime));
  }

  /// Formats standard 12-hour or 24-hour East Africa Time (UTC+3)
  static String formatEatTime(DateTime dateTime, {bool showSeconds = false}) {
    final eat = toEastAfricaTime(dateTime);
    return DateFormat(showSeconds ? 'h:mm:ss a' : 'h:mm a').format(eat);
  }

  /// Formats date + time in East Africa Time (UTC+3) (e.g. "17 Oct, 20:35")
  static String formatEatDateTime(DateTime dateTime) {
    final eat = toEastAfricaTime(dateTime);
    return DateFormat('d MMM, HH:mm').format(eat);
  }

  /// Current time in East Africa (UTC+3)
  static DateTime nowInEastAfrica() {
    return DateTime.now().toUtc().add(eastAfricaOffset);
  }

  /// Converts a DateTime chosen in East Africa Time (e.g. from date/time pickers)
  /// into a proper UTC DateTime for Supabase/PostgreSQL storage.
  static DateTime eatToUtc(DateTime eatDateTime) {
    return DateTime.utc(
      eatDateTime.year,
      eatDateTime.month,
      eatDateTime.day,
      eatDateTime.hour,
      eatDateTime.minute,
      eatDateTime.second,
      eatDateTime.millisecond,
    ).subtract(eastAfricaOffset);
  }

  /// Formats both standard time and Ethiopian time side-by-side.
  /// e.g. "4:00 PM (10:00 AM ET)"
  static String formatCombinedTime(DateTime dateTime) {
    final eat = toEastAfricaTime(dateTime);
    final gregTime = DateFormat('h:mm a').format(eat);
    final ethTime = formatEthiopianTime(dateTime);
    return '$gregTime ($ethTime ET)';
  }

  /// Formats standard date + time with Ethiopian time suffix.
  /// e.g. "Aug 27 • 4:00 PM (10:00 AM ET)"
  static String formatDateTimeWithEth(
    DateTime dateTime, {
    bool? includeYear,
  }) {
    final eat = toEastAfricaTime(dateTime);
    final nowEat = nowInEastAfrica();
    final isCurrentYear = eat.year == nowEat.year;
    final showYear = includeYear ?? !isCurrentYear;
    final datePattern = showYear ? 'MMM dd, yyyy' : 'MMM dd';
    final dateStr = DateFormat(datePattern).format(eat);
    final gregTime = DateFormat('h:mm a').format(eat);
    final ethTime = formatEthiopianTime(dateTime);

    return '$dateStr • $gregTime ($ethTime ET)';
  }

  /// Formats "Closed: Aug 27 • 4:00 PM (10:00 AM ET)"
  static String formatClosedOn(DateTime dateTime) {
    return 'Closed: ${formatDateTimeWithEth(dateTime)}';
  }

  /// Formats "Starts: Aug 27 • 3:00 PM (9:00 AM ET)"
  static String formatStartsAt(DateTime dateTime) {
    return 'Starts: ${formatDateTimeWithEth(dateTime)}';
  }

  /// Formats "Ends: Aug 27 • 4:00 PM (10:00 AM ET)"
  static String formatEndsAt(DateTime dateTime) {
    return 'Ends: ${formatDateTimeWithEth(dateTime)}';
  }
}
