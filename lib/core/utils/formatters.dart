import 'package:intl/intl.dart';

class Formatters {
  static final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  static final _date = DateFormat('dd/MM/yyyy', 'vi_VN');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN');
  static final _month = DateFormat('MM/yyyy', 'vi_VN');

  static String currency(int amount) => _vnd.format(amount);
  static String date(DateTime dt) => _date.format(dt);
  static String dateTime(DateTime dt) => _dateTime.format(dt);
  static String month(DateTime dt) => _month.format(dt);

  static String shortAmount(int amount) {
    if (amount >= 1000000000) return '${(amount / 1e9).toStringAsFixed(1)}B ₫';
    if (amount >= 1000000) return '${(amount / 1e6).toStringAsFixed(1)}M ₫';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K ₫';
    return '$amount ₫';
  }

  /// Parse user input string to int VND, returns null if invalid
  static int? parseAmount(String input) {
    final cleaned = input.replaceAll(RegExp(r'[,.\s₫]'), '');
    return int.tryParse(cleaned);
  }
}
