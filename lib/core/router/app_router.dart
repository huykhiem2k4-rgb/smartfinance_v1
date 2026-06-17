import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/admin/admin_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';
import '../../presentation/screens/transactions/add_transaction_screen.dart';
import '../../presentation/screens/invoices/invoices_screen.dart';
import '../../presentation/screens/invoices/add_invoice_screen.dart';
import '../../presentation/screens/invoices/invoice_detail_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/dashboard',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
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
  routes: [
    // Auth routes (không có shell)
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => const RegisterScreen(),
    ),

    // Admin route (không có shell)
    GoRoute(
      path: '/admin',
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => const AdminScreen(),
    ),

    // Main shell (4 tab)
    ShellRoute(
      navigatorKey: _shellKey,
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
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => const AddTransactionScreen(),
    ),
    GoRoute(
      path: '/invoices/add',
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => const AddInvoiceScreen(),
    ),
    GoRoute(
      path: '/invoices/:id',
      parentNavigatorKey: _rootKey,
      builder: (ctx, s) => InvoiceDetailScreen(invoiceId: s.pathParameters['id']!),
    ),
  ],
);
