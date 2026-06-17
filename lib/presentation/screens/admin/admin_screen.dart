import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/datasources/local_datasource.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<UserModel> _users = [];
  Map<String, Map<String, int>> _userStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final ds = LocalDatasource();
    final users = await ds.getAllUsers();
    final stats = <String, Map<String, int>>{};
    for (final u in users) {
      stats[u.id] = await ds.getUserStats(u.id);
    }
    if (mounted) setState(() { _users = users; _userStats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị hệ thống'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Người dùng'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Thống kê'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _UserListTab(
                  users: _users,
                  userStats: _userStats,
                  currentUserId: currentUser?.id ?? '',
                  onRefresh: _loadData,
                ),
                _SystemStatsTab(users: _users, userStats: _userStats),
              ],
            ),
    );
  }
}

// ── Tab 1: Danh sách người dùng ────────────────────────────────
class _UserListTab extends StatelessWidget {
  final List<UserModel> users;
  final Map<String, Map<String, int>> userStats;
  final String currentUserId;
  final VoidCallback onRefresh;

  const _UserListTab({
    required this.users,
    required this.userStats,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _UserCard(
          user: users[i],
          stats: userStats[users[i].id] ?? {},
          isCurrentUser: users[i].id == currentUserId,
          onRoleToggle: () => _toggleRole(ctx, users[i]),
          onDelete: users[i].id == currentUserId ? null : () => _deleteUser(ctx, users[i]),
        ),
      ),
    );
  }

  Future<void> _toggleRole(BuildContext context, UserModel user) async {
    final newRole = user.role == UserRole.admin ? UserRole.user : UserRole.admin;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thay đổi quyền'),
        content: Text('Đổi quyền "${user.username}" thành ${newRole.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LocalDatasource().updateUser(user.copyWith(role: newRole));
      onRefresh();
    }
  }

  Future<void> _deleteUser(BuildContext context, UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa người dùng'),
        content: Text('Xóa "${user.fullName ?? user.username}"?\nToàn bộ giao dịch và hóa đơn của họ cũng sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LocalDatasource().deleteUser(user.id);
      onRefresh();
    }
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final Map<String, int> stats;
  final bool isCurrentUser;
  final VoidCallback onRoleToggle;
  final VoidCallback? onDelete;

  const _UserCard({
    required this.user,
    required this.stats,
    required this.isCurrentUser,
    required this.onRoleToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRole.admin;
    final income = stats['income'] ?? 0;
    final expense = stats['expense'] ?? 0;
    final invoices = stats['invoices'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdmin ? AppColors.primary : AppColors.accent,
                  child: Text(
                    (user.fullName?.isNotEmpty == true ? user.fullName![0] : user.username[0]).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user.fullName ?? user.username,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Bạn', style: TextStyle(fontSize: 10, color: AppColors.accent)),
                            ),
                          ],
                        ],
                      ),
                      Text('@${user.username}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAdmin ? AppColors.primary : Colors.orange).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role.label,
                    style: TextStyle(
                      color: isAdmin ? AppColors.primary : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(Icons.trending_up, Formatters.shortAmount(income), AppColors.income),
                const SizedBox(width: 8),
                _StatChip(Icons.trending_down, Formatters.shortAmount(expense), AppColors.expense),
                const SizedBox(width: 8),
                _StatChip(Icons.receipt_long, '$invoices HĐ', Colors.blueGrey),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.manage_accounts,
                    size: 20,
                    color: Colors.orange,
                  ),
                  tooltip: isAdmin ? 'Hạ xuống User' : 'Nâng lên Admin',
                  onPressed: isCurrentUser ? null : onRoleToggle,
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    tooltip: 'Xóa người dùng',
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      );
}

// ── Tab 2: Thống kê toàn hệ thống ─────────────────────────────
class _SystemStatsTab extends StatelessWidget {
  final List<UserModel> users;
  final Map<String, Map<String, int>> userStats;

  const _SystemStatsTab({required this.users, required this.userStats});

  @override
  Widget build(BuildContext context) {
    int totalIncome = 0, totalExpense = 0, totalInvoices = 0;
    for (final s in userStats.values) {
      totalIncome += s['income'] ?? 0;
      totalExpense += s['expense'] ?? 0;
      totalInvoices += s['invoices'] ?? 0;
    }
    final admins = users.where((u) => u.role == UserRole.admin).length;
    final regularUsers = users.length - admins;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng quan hệ thống',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _SysCard('Tổng người dùng', '${users.length}', Icons.people, AppColors.primary),
              _SysCard('Quản trị viên', '$admins', Icons.admin_panel_settings, Colors.orange),
              _SysCard('Người dùng thường', '$regularUsers', Icons.person, Colors.blueGrey),
              _SysCard('Tổng hóa đơn', '$totalInvoices', Icons.receipt_long, AppColors.accent),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Dòng tiền toàn hệ thống',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _FinanceRow('Tổng thu', totalIncome, AppColors.income, Icons.trending_up),
          const SizedBox(height: 8),
          _FinanceRow('Tổng chi', totalExpense, AppColors.expense, Icons.trending_down),
          const SizedBox(height: 8),
          _FinanceRow(
            'Dòng tiền ròng',
            totalIncome - totalExpense,
            (totalIncome - totalExpense) >= 0 ? AppColors.income : AppColors.expense,
            Icons.account_balance,
          ),
          const SizedBox(height: 20),
          const Text('Thống kê theo người dùng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...users.map((u) {
            final s = userStats[u.id] ?? {};
            final net = (s['income'] ?? 0) - (s['expense'] ?? 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                leading: CircleAvatar(
                  backgroundColor: u.role == UserRole.admin ? AppColors.primary : AppColors.accent,
                  child: Text(
                    (u.fullName?.isNotEmpty == true ? u.fullName![0] : u.username[0]).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                title: Text(u.fullName ?? u.username, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                subtitle: Text('@${u.username} · ${u.role.label}', style: const TextStyle(fontSize: 11)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.shortAmount(net.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? AppColors.income : AppColors.expense,
                        fontSize: 14,
                      ),
                    ),
                    Text(net >= 0 ? '▲ Dương' : '▼ Âm',
                        style: TextStyle(
                          fontSize: 10,
                          color: net >= 0 ? AppColors.income : AppColors.expense,
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SysCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SysCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FinanceRow extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  const _FinanceRow(this.label, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              Formatters.currency(amount.abs()),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ],
        ),
      );
}
