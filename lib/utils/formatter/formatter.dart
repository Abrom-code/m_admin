import 'package:intl/intl.dart';

class AppFormatter {
  AppFormatter._();

  static String formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formattedTime(int second) {
    final hours = second ~/ 3600;
    final minutes = (second % 3600) ~/ 60;
    final seconds = second % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
