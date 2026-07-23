import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../../data/models/category_model.dart';
import '../../../core/theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<CategoryModel> _filterByType(List<CategoryModel> categories, String type) {
    return categories.where((c) => c.type == type).toList();
  }

  void _showAddDialog({CategoryModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategoryFormSheet(
        existing: existing,
        onSave: (cat) async {
          final provider = context.read<AppProvider>();
          if (existing != null) {
            await provider.updateCategory(cat);
          } else {
            await provider.addCategory(cat);
          }
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _confirmDelete(CategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text('Xóa "${cat.categoryName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AppProvider>().deleteCategory(cat.categoryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý danh mục'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Thu nhập'),
            Tab(icon: Icon(Icons.trending_down), text: 'Chi tiêu'),
          ],
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (ctx, provider, _) {
          final incomeCategories = _filterByType(provider.categories, 'INCOME');
          final expenseCategories = _filterByType(provider.categories, 'EXPENSE');

          return TabBarView(
            controller: _tabs,
            children: [
              _CategoryList(
                categories: incomeCategories,
                onTap: (cat) => _showAddDialog(existing: cat),
                onSwipe: _confirmDelete,
              ),
              _CategoryList(
                categories: expenseCategories,
                onTap: (cat) => _showAddDialog(existing: cat),
                onSwipe: _confirmDelete,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onTap;
  final ValueChanged<CategoryModel> onSwipe;

  const _CategoryList({
    required this.categories,
    required this.onTap,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Chưa có danh mục nào', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        return Dismissible(
          key: ValueKey(cat.categoryId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.expense,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            onSwipe(cat);
            return false;
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              onTap: () => onTap(cat),
              leading: CircleAvatar(
                backgroundColor: _parseColor(cat.color).withValues(alpha: 0.15),
                child: Icon(
                  _parseIcon(cat.icon),
                  color: _parseColor(cat.color),
                  size: 20,
                ),
              ),
              title: Text(
                cat.categoryName,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              subtitle: Text(
                cat.type == 'INCOME' ? 'Thu nhập' : 'Chi tiêu',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _parseColor(cat.color),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('FF');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  static IconData _parseIcon(String? iconName) {
    const icons = <String, IconData>{
      'attach_money': Icons.attach_money,
      'payments': Icons.payments,
      'account_balance': Icons.account_balance,
      'work': Icons.work,
      'trending_up': Icons.trending_up,
      'savings': Icons.savings,
      'card_giftcard': Icons.card_giftcard,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'home': Icons.home,
      'health_and_safety': Icons.health_and_safety,
      'school': Icons.school,
      'flight': Icons.flight,
      'pets': Icons.pets,
      'fitness_center': Icons.fitness_center,
      'build': Icons.build,
      'code': Icons.code,
      'coffee': Icons.coffee,
      'checkroom': Icons.checkroom,
      'bolt': Icons.bolt,
      'inventory_2': Icons.inventory_2,
      'campaign': Icons.campaign,
      'receipt_long': Icons.receipt_long,
      'more_horiz': Icons.more_horiz,
      'people': Icons.people,
    };
    return icons[iconName] ?? Icons.category;
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? existing;
  final Future<void> Function(CategoryModel) onSave;

  const _CategoryFormSheet({this.existing, required this.onSave});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late String _type;
  String? _selectedIcon;
  Color _selectedColor = AppColors.primary;

  static const _presetColors = [
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFF1E3A5F),
    Color(0xFF00BFA5),
    Color(0xFFFFA726),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
  ];

  static const _presetIcons = <String, IconData>{
    'attach_money': Icons.attach_money,
    'payments': Icons.payments,
    'account_balance': Icons.account_balance,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'savings': Icons.savings,
    'card_giftcard': Icons.card_giftcard,
    'shopping_cart': Icons.shopping_cart,
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'home': Icons.home,
    'health_and_safety': Icons.health_and_safety,
    'school': Icons.school,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'build': Icons.build,
    'code': Icons.code,
    'coffee': Icons.coffee,
    'checkroom': Icons.checkroom,
  };

  @override
  void initState() {
    super.initState();
    final cat = widget.existing;
    _nameCtrl = TextEditingController(text: cat?.categoryName ?? '');
    _type = cat?.type ?? 'INCOME';
    _selectedIcon = cat?.icon;
    if (cat?.color != null) {
      _selectedColor = _CategoryList._parseColor(cat!.color);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cat = CategoryModel(
      categoryId: widget.existing?.categoryId ?? const Uuid().v4(),
      categoryName: _nameCtrl.text.trim(),
      type: _type,
      icon: _selectedIcon,
      color: _colorToHex(_selectedColor),
    );
    await widget.onSave(cat);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.existing != null ? 'Sửa danh mục' : 'Thêm danh mục',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên danh mục',
                  hintText: 'VD: Lương, Ăn uống...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập tên danh mục' : null,
              ),
              const SizedBox(height: 16),
              const Text('Loại', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TypeChip(
                      label: 'Thu nhập',
                      color: AppColors.income,
                      selected: _type == 'INCOME',
                      onTap: () => setState(() => _type = 'INCOME'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeChip(
                      label: 'Chi tiêu',
                      color: AppColors.expense,
                      selected: _type == 'EXPENSE',
                      onTap: () => setState(() => _type = 'EXPENSE'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((c) {
                  final selected = _selectedColor.value == c.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Biểu tượng', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetIcons.entries.map((e) {
                  final selected = _selectedIcon == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = e.key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? _selectedColor.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: _selectedColor, width: 1.5)
                            : null,
                      ),
                      child: Icon(e.value, size: 20, color: selected ? _selectedColor : Colors.grey),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(widget.existing != null ? 'Cập nhật' : 'Thêm mới'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: selected ? color : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
