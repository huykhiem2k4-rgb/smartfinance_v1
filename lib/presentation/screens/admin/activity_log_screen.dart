import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

const _moduleLabels = {
  'USER': 'Người dùng',
  'TRANSACTION': 'Giao dịch',
  'INVOICE': 'Hóa đơn',
  'PARTNER': 'Đối tác',
  'CATEGORY': 'Danh mục',
  'SYSTEM': 'Hệ thống',
};

const _moduleIcons = {
  'USER': Icons.person,
  'TRANSACTION': Icons.receipt_long,
  'INVOICE': Icons.description,
  'PARTNER': Icons.handshake,
  'CATEGORY': Icons.category,
  'SYSTEM': Icons.settings,
};

const _moduleColors = {
  'USER': AppColors.primary,
  'TRANSACTION': AppColors.income,
  'INVOICE': AppColors.accent,
  'PARTNER': Colors.orange,
  'CATEGORY': Colors.blueGrey,
  'SYSTEM': AppColors.expense,
};

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});
  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String? _selectedModule;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  static const _modules = [
    'USER',
    'TRANSACTION',
    'INVOICE',
    'PARTNER',
    'CATEGORY',
    'SYSTEM',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    final logs = await provider.getActivityLogs(module: _selectedModule);
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký hoạt động')),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(
                        child: Text('Không có dữ liệu',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) =>
                              _LogCard(log: _logs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: _selectedModule == null,
            onSelected: (_) {
              setState(() => _selectedModule = null);
              _loadLogs();
            },
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          ..._modules.map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_moduleLabels[m] ?? m),
                  selected: _selectedModule == m,
                  onSelected: (_) {
                    setState(() =>
                        _selectedModule = _selectedModule == m ? null : m);
                    _loadLogs();
                  },
                  selectedColor:
                      (_moduleColors[m] ?? AppColors.primary)
                          .withValues(alpha: 0.15),
                  checkmarkColor: _moduleColors[m] ?? AppColors.primary,
                ),
              )),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final module = (log['module'] ?? '') as String;
    final actionType = (log['action_type'] ?? '') as String;
    final description = (log['description'] ?? '') as String;
    final createdAt = log['created_at'];
    final icon = _moduleIcons[module] ?? Icons.info_outline;
    final color = _moduleColors[module] ?? Colors.grey;

    DateTime? dt;
    if (createdAt is DateTime) {
      dt = createdAt;
    } else if (createdAt is String) {
      dt = DateTime.tryParse(createdAt);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _moduleLabels[module] ?? module,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _actionLabel(actionType),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (dt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      Formatters.dateTime(dt),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'CREATE':
        return 'Tạo mới';
      case 'UPDATE':
        return 'Cập nhật';
      case 'DELETE':
        return 'Xóa';
      case 'CANCEL':
        return 'Hủy';
      case 'APPROVE':
        return 'Duyệt';
      case 'REJECT':
        return 'Từ chối';
      default:
        return action;
    }
  }
}
