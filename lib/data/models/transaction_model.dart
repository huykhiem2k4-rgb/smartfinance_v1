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
  final int amount;
  final TransactionType type;
  final TransactionCategory category;
  final String? description;
  final DateTime date;
  final String? imagePath;
  final String? createdBy;
  final String? categoryId;
  final String? receiptImageUrl;
  final String status; // POSTED | CANCELLED
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    required this.date,
    this.imagePath,
    this.createdBy,
    this.categoryId,
    this.receiptImageUrl,
    this.status = 'POSTED',
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPosted => status == 'POSTED';
  bool get isCancelled => status == 'CANCELLED';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'category': category.name,
        'description': description,
        'date': date.toIso8601String(),
        'image_path': imagePath,
        'created_by': createdBy,
        'category_id': categoryId,
        'receipt_image_url': receiptImageUrl,
        'status': status,
        'cancel_reason': cancelReason,
        'cancelled_by': cancelledBy,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
        id: m['id'] as String,
        title: m['title'] as String,
        amount: (m['amount'] as num).toInt(),
        type: TransactionType.values.firstWhere((e) => e.name == m['type']),
        category: TransactionCategory.values.firstWhere(
          (e) => e.name == m['category'],
          orElse: () => TransactionCategory.otherExpense,
        ),
        description: m['description'] as String?,
        date: DateTime.parse(m['date'] as String),
        imagePath: m['image_path'] as String?,
        createdBy: m['created_by'] as String?,
        categoryId: m['category_id'] as String?,
        receiptImageUrl: m['receipt_image_url'] as String?,
        status: (m['status'] as String?) ?? 'POSTED',
        cancelReason: m['cancel_reason'] as String?,
        cancelledBy: m['cancelled_by'] as String?,
        cancelledAt: m['cancelled_at'] != null ? DateTime.tryParse(m['cancelled_at'] as String) : null,
        createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'] as String) : null,
        updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
      );

  TransactionModel copyWith({
    String? title,
    int? amount,
    TransactionType? type,
    TransactionCategory? category,
    String? description,
    DateTime? date,
    String? imagePath,
    String? status,
    String? cancelReason,
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
        createdBy: createdBy,
        categoryId: categoryId,
        receiptImageUrl: receiptImageUrl,
        status: status ?? this.status,
        cancelReason: cancelReason ?? this.cancelReason,
        cancelledBy: cancelledBy,
        cancelledAt: cancelledAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
