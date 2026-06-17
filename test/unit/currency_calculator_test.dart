import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance/core/utils/currency_calculator.dart';

void main() {
  group('CurrencyCalculator', () {
    // ── VAT Tests ─────────────────────────────────────────────
    group('calculateVat', () {
      test('VAT 10% on 1,000,000 = 100,000', () {
        expect(CurrencyCalculator.calculateVat(1000000, 10), 100000);
      });
      test('VAT 8% on 1,000,000 = 80,000', () {
        expect(CurrencyCalculator.calculateVat(1000000, 8), 80000);
      });
      test('VAT 0% on any amount = 0', () {
        expect(CurrencyCalculator.calculateVat(5000000, 0), 0);
      });
      test('VAT rounds correctly for fractional result', () {
        // 13,636,364 * 10% = 1,363,636.4 → rounds to 1,363,636
        expect(CurrencyCalculator.calculateVat(13636364, 10), 1363636);
      });
      test('VAT 8% fractional round', () {
        // 2,963,000 * 8% = 237,040
        expect(CurrencyCalculator.calculateVat(2963000, 8), 237040);
      });
    });

    // ── Total with VAT Tests ──────────────────────────────────
    group('calculateTotal', () {
      test('Total = subtotal + 10% VAT', () {
        expect(CurrencyCalculator.calculateTotal(10000000, 10), 11000000);
      });
      test('Total = subtotal + 8% VAT', () {
        expect(CurrencyCalculator.calculateTotal(10000000, 8), 10800000);
      });
      test('Total with 0% VAT equals subtotal', () {
        expect(CurrencyCalculator.calculateTotal(5000000, 0), 5000000);
      });
      test('Large amount VAT 10%', () {
        // 50,000,000 * 10% = 5,000,000; total = 55,000,000
        expect(CurrencyCalculator.calculateTotal(50000000, 10), 55000000);
      });
    });

    // ── Income Sum Tests ──────────────────────────────────────
    group('totalIncome', () {
      test('Sum of empty list is 0', () {
        expect(CurrencyCalculator.totalIncome([]), 0);
      });
      test('Sum of multiple income amounts', () {
        expect(CurrencyCalculator.totalIncome([85000000, 25000000, 15000000]), 125000000);
      });
      test('Single income amount', () {
        expect(CurrencyCalculator.totalIncome([72000000]), 72000000);
      });
    });

    // ── Expense Sum Tests ─────────────────────────────────────
    group('totalExpense', () {
      test('Sum of expenses', () {
        expect(CurrencyCalculator.totalExpense([32000000, 12000000, 8500000, 2800000]), 55300000);
      });
      test('Sum of empty list is 0', () {
        expect(CurrencyCalculator.totalExpense([]), 0);
      });
    });

    // ── Net Cash Flow Tests ───────────────────────────────────
    group('netCashFlow', () {
      test('Positive net when income > expense', () {
        expect(CurrencyCalculator.netCashFlow(125000000, 55300000), 69700000);
      });
      test('Negative net when expense > income', () {
        expect(CurrencyCalculator.netCashFlow(10000000, 15000000), -5000000);
      });
      test('Zero net when income == expense', () {
        expect(CurrencyCalculator.netCashFlow(20000000, 20000000), 0);
      });
    });

    // ── Percentage Tests ──────────────────────────────────────
    group('percentage', () {
      test('50% of total', () {
        expect(CurrencyCalculator.percentage(5000000, 10000000), 50.0);
      });
      test('Returns 0 when total is 0', () {
        expect(CurrencyCalculator.percentage(5000000, 0), 0.0);
      });
      test('100% when part equals total', () {
        expect(CurrencyCalculator.percentage(1000000, 1000000), 100.0);
      });
    });

    // ── No floating-point errors ──────────────────────────────
    group('int precision', () {
      test('Large VAT calculation stays int (no 0.1 problem)', () {
        // Classic 0.1 + 0.2 != 0.3 issue should not affect int calculations
        final vat = CurrencyCalculator.calculateVat(3000000, 10);
        expect(vat, 300000);
        expect(vat, isA<int>());
      });
      test('Total remains exact int', () {
        final total = CurrencyCalculator.calculateTotal(3000000, 10);
        expect(total, 3300000);
        expect(total, isA<int>());
      });
    });
  });
}
