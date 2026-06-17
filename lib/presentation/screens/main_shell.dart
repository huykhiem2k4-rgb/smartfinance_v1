import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = ['/dashboard', '/transactions', '/invoices', '/reports'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final isWide = MediaQuery.of(context).size.width >= 720;
    final isDark = context.watch<ThemeProvider>().isDark;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: _AppTitle(),
          actions: [_ThemeToggle(), _UserMenu()],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: idx,
              labelType: NavigationRailLabelType.all,
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : AppColors.primary,
              selectedIconTheme: const IconThemeData(color: AppColors.accent),
              unselectedIconTheme: const IconThemeData(color: Colors.white60),
              selectedLabelTextStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
              onDestinationSelected: (i) => context.go(_tabs[i]),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Tổng quan')),
                NavigationRailDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: Text('Giao dịch')),
                NavigationRailDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: Text('Hóa đơn')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Báo cáo')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _AppTitle(),
        actions: [_ThemeToggle(), _UserMenu()],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i]),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz_outlined), activeIcon: Icon(Icons.swap_horiz), label: 'Giao dịch'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description), label: 'Hóa đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Báo cáo'),
        ],
      ),
    );
  }
}

class _AppTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('SmartFinance'),
        ],
      );
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          tp.isDark ? Icons.light_mode : Icons.dark_mode,
          key: ValueKey(tp.isDark),
          color: Colors.white,
        ),
      ),
      onPressed: tp.toggle,
      tooltip: tp.isDark ? 'Chuyển sang sáng' : 'Chuyển sang tối',
    );
  }
}

class _UserMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final initials = (user.fullName?.isNotEmpty == true
            ? user.fullName![0]
            : user.username[0])
        .toUpperCase();

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      onSelected: (v) async {
        if (v == 'admin') {
          context.push('/admin');
        } else if (v == 'logout') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc muốn đăng xuất không?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            context.read<AppProvider>().setUser(null);
            await auth.logout();
            if (context.mounted) context.go('/login');
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName ?? user.username,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('@${user.username}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: user.role.name == 'admin'
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  user.role.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.role.name == 'admin' ? AppColors.primary : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (auth.isAdmin)
          const PopupMenuItem(
            value: 'admin',
            child: Row(children: [
              Icon(Icons.admin_panel_settings, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Quản trị hệ thống'),
            ]),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          child: Text(initials,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
