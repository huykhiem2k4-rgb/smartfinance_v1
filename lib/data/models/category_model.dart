class CategoryModel {
  final String categoryId;
  final String categoryName;
  final String type; // INCOME | EXPENSE
  final String? icon;
  final String? color;
  final DateTime createdAt;

  CategoryModel({
    required this.categoryId,
    required this.categoryName,
    required this.type,
    this.icon,
    this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isIncome => type == 'INCOME';
  bool get isExpense => type == 'EXPENSE';

  Map<String, dynamic> toMap() => {
    'category_id': categoryId,
    'category_name': categoryName,
    'type': type,
    'icon': icon,
    'color': color,
    'created_at': createdAt.toIso8601String(),
  };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
    categoryId: m['category_id'] as String,
    categoryName: m['category_name'] as String,
    type: m['type'] as String,
    icon: m['icon'] as String?,
    color: m['color'] as String?,
    createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  CategoryModel copyWith({
    String? categoryId,
    String? categoryName,
    String? type,
    String? icon,
    String? color,
  }) => CategoryModel(
    categoryId: categoryId ?? this.categoryId,
    categoryName: categoryName ?? this.categoryName,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    createdAt: createdAt,
  );
}
