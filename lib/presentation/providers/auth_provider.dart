import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final LocalDatasource _ds;

  AuthProvider({LocalDatasource? datasource})
      : _ds = datasource ?? LocalDatasource();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  String get userId => _currentUser?.id ?? '';
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('current_user_id');
    if (savedId != null) {
      final user = await _ds.getUserById(savedId);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _ds.getUserByUsername(username.trim().toLowerCase());
      if (user == null || !user.checkPassword(password)) {
        _error = 'Tên đăng nhập hoặc mật khẩu không đúng';
        return false;
      }
      _currentUser = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);
      return true;
    } catch (e) {
      _error = 'Lỗi đăng nhập: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existing = await _ds.getUserByUsername(username.trim().toLowerCase());
      if (existing != null) {
        _error = 'Tên đăng nhập đã tồn tại';
        return false;
      }
      final newUser = UserModel(
        id: const Uuid().v4(),
        username: username.trim().toLowerCase(),
        passwordHash: UserModel.hashPassword(password),
        role: UserRole.user,
        fullName: fullName.trim(),
        createdAt: DateTime.now(),
      );
      await _ds.insertUser(newUser);
      _currentUser = newUser;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', newUser.id);
      return true;
    } catch (e) {
      _error = 'Đăng ký thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
