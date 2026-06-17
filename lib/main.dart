import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const SmartFinanceApp(),
    ),
  );
}

class SmartFinanceApp extends StatefulWidget {
  const SmartFinanceApp({super.key});
  @override
  State<SmartFinanceApp> createState() => _SmartFinanceAppState();
}

class _SmartFinanceAppState extends State<SmartFinanceApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.tryAutoLogin();
      if (auth.isLoggedIn && context.mounted) {
        final appProv = context.read<AppProvider>();
        appProv.setUser(auth.userId, isAdmin: auth.isAdmin);
        await appProv.loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp.router(
      title: 'SmartFinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
