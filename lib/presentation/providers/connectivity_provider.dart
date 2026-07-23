import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../core/theme/app_theme.dart';
import 'app_provider.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;

  void init(BuildContext context) {
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final nowOnline = results.any((r) => r != ConnectivityResult.none);
      final wasOffline = !_isOnline;
      _isOnline = nowOnline;
      notifyListeners();

      if (!context.mounted) return;

      if (!nowOnline) {
        _showSnackBar(context, 'Đã mất kết nối internet', Colors.orange);
      } else if (wasOffline && nowOnline) {
        _showSnackBar(context, 'Đã kết nối lại internet', AppColors.income);
        await _syncOfflineData();
        if (context.mounted) {
          context.read<AppProvider>().loadAll();
        }
      }
    });
  }

  Future<void> _syncOfflineData() async {
    try {
      await TransactionRepository().syncFromCloud();
      await InvoiceRepository().syncFromCloud();
      await TransactionRepository().syncAllToCloud();
      await InvoiceRepository().syncAllToCloud();
    } catch (_) {}
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            color == AppColors.income ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(message),
        ]),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
