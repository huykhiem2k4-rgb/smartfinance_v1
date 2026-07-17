import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/admin/admin_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';
import '../../presentation/screens/transactions/add_transaction_screen.dart';
import '../../presentation/screens/transactions/edit_transaction_screen.dart';
import '../../presentation/screens/invoices/invoices_screen.dart';
import '../../presentation/screens/invoices/add_invoice_screen.dart';
import '../../presentation/screens/invoices/invoice_detail_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/main_shell.dart';
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

GoRouter createRouter(AuthProvider auth) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/dashboard',
    refreshListenable: auth,
    observers: [routeObserver],
    redirect: (context, state) {
      final isLoggedIn = auth.isLoggedIn;
      final path = state.uri.path;

      // Các trang không cần đăng nhập
      if (path == '/login' || path == '/register') {
        return isLoggedIn ? '/dashboard' : null;
      }
      // Admin route chỉ dành cho admin
      if (path == '/admin' && !auth.isAdmin) return '/dashboard';
      // Mọi route khác cần đăng nhập
      if (!isLoggedIn) return '/login';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '404',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trang "${state.uri.path}" không tồn tại',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Về trang chủ'),
              onPressed: () => context.go('/dashboard'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      // Auth routes (không có shell)
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => const RegisterScreen(),
      ),

      // Admin route (không có shell)
      GoRoute(
        path: '/admin',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => const AdminScreen(),
      ),

      // Main shell (4 tab)
      ShellRoute(
        navigatorKey: shellKey,
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (ctx, s) => const DashboardScreen()),
          GoRoute(path: '/transactions', builder: (ctx, s) => const TransactionsScreen()),
          GoRoute(path: '/invoices', builder: (ctx, s) => const InvoicesScreen()),
          GoRoute(path: '/reports', builder: (ctx, s) => const ReportsScreen()),
        ],
      ),

      // Push routes (full screen, không có shell)
      GoRoute(
        path: '/transactions/add',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => const AddTransactionScreen(),
      ),
      GoRoute(
        path: '/transactions/edit/:id',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => EditTransactionScreen(transactionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoices/add',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => const AddInvoiceScreen(),
      ),
      GoRoute(
        path: '/invoices/:id',
        parentNavigatorKey: rootKey,
        builder: (ctx, s) => InvoiceDetailScreen(invoiceId: s.pathParameters['id']!),
      ),
    ],
  );
}
