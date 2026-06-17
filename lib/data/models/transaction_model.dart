enum TransactionType { income, expense }

enum TransactionCategory {
  // Income
  sales,
  serviceRevenue,
  investment,
  otherIncome,
  // Expense
  salary,
  rent,
  utilities,
  supplies,
  marketing,
  tax,
  otherExpense,
}

extension TransactionCategoryExt on TransactionCategory {
  String get label {
    switch (this) {
      case TransactionCategory.sales:          return 'Doanh thu bán hàng';
      case TransactionCategory.serviceRevenue: return 'Doanh thu dịch vụ';
      case TransactionCategory.investment:     return 'Thu từ đầu tư';
      case TransactionCategory.otherIncome:    return 'Thu nhập khác';
      case TransactionCategory.salary:         return 'Lương nhân viên';
      case TransactionCategory.rent:           return 'Thuê mặt bằng';
      case TransactionCategory.utilities:      return 'Điện/Nước/Internet';
      case TransactionCategory.supplies:       return 'Vật tư & Hàng hóa';
      case TransactionCategory.marketing:      return 'Marketing & Quảng cáo';
      case TransactionCategory.tax:            return 'Thuế & Phí';
      case TransactionCategory.otherExpense:   return 'Chi phí khác';
    }
  }

  TransactionType get type {
    switch (this) {
      case TransactionCategory.sales:
      case TransactionCategory.serviceRevenue:
      case TransactionCategory.investment:
      case TransactionCategory.otherIncome:
        return TransactionType.income;
      default:
        return TransactionType.expense;
    }
  }
}

class TransactionModel {
  final String id;
  final String title;
  /// Amount in VND (integer to avoid floating-point rounding errors)
  final int amount;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final DateTime date;
  final String? imagePath;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    required this.date,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category.name,
        'description': description,
        'date': date.toIso8601String(),
        'image_path': imagePath,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
        id: m['id'],
        title: m['title'],
        amount: (m['amount'] as num).toInt(),
        type: TransactionType.values.firstWhere((e) => e.name == m['type']),
        category: TransactionCategory.values.firstWhere(
          (e) => e.name == m['category'],
          orElse: () => TransactionCategory.otherExpense,
        ),
        description: m['description'],
        date: DateTime.parse(m['date']),
        imagePath: m['image_path'],
      );

  TransactionModel copyWith({
    String? title,
    int? amount,
    TransactionType? type,
    TransactionCategory? category,
    String? description,
    DateTime? date,
    String? imagePath,
  }) =>
      TransactionModel(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        category: category ?? this.category,
        description: description ?? this.description,
        date: date ?? this.date,
        imagePath: imagePath ?? this.imagePath,
      );
}
