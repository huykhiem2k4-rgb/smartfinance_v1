import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  static Future<bool> get isOnline async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}
