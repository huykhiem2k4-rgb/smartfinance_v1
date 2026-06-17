/// Pure business logic for currency calculations.
/// Uses only int to avoid floating-point rounding errors.
class CurrencyCalculator {
  /// Calculate VAT amount from subtotal and rate (as percentage, e.g. 10 = 10%)
  static int calculateVat(int subtotal, double vatRatePercent) {
    // Multiply first, then divide to minimize rounding
    return (subtotal * vatRatePercent / 100).round();
  }

  /// Calculate total = subtotal + VAT
  static int calculateTotal(int subtotal, double vatRatePercent) {
    return subtotal + calculateVat(subtotal, vatRatePercent);
  }

  /// Sum all income transactions
  static int totalIncome(List<int> amounts) =>
      amounts.fold(0, (sum, a) => sum + a);

  /// Sum all expense transactions
  static int totalExpense(List<int> amounts) =>
      amounts.fold(0, (sum, a) => sum + a);

  /// Net cash flow = income - expense
  static int netCashFlow(int income, int expense) => income - expense;

  /// Calculate percentage (returns 0–100 as double)
  static double percentage(int part, int total) {
    if (total == 0) return 0;
    return (part / total) * 100;
  }
}
