import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return DateFormat('MMM d, yyyy').format(dt);
  }

  static String formatShort(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return DateFormat('MMM d').format(dt);
  }

  static String formatMonth(String yearMonth) {
    // Expects "YYYY-MM"
    final dt = DateTime.tryParse('$yearMonth-01');
    if (dt == null) return yearMonth;
    return DateFormat('MMMM yyyy').format(dt);
  }

  static String toApiDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
}
