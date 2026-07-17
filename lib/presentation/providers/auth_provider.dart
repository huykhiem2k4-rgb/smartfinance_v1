import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/models/user_model.dart';
import '../../core/utils/connectivity_helper.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseDatasource _cloud;
  final LocalDatasource _local;

  AuthProvider({SupabaseDatasource? cloud, LocalDatasource? local})
      : _cloud = cloud ?? SupabaseDatasource(),
        _local = local ?? LocalDatasource();

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
    // 1. Try Supabase session first
    if (await ConnectivityHelper.isOnline) {
      try {
        final session = _cloud.currentSession;
        if (session != null) {
          final user = await _cloud.getCurrentUser();
          if (user != null) {
            _currentUser = user;
            await _local.insertUser(user);
            notifyListeners();
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: SharedPreferences + local DB
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('current_user_id');
    if (savedId != null) {
      final user = await _local.getUserById(savedId);
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
      if (await ConnectivityHelper.isOnline) {
        // Supabase Auth signIn
        await _cloud.signIn(username.trim().toLowerCase(), password);
        final user = await _cloud.getCurrentUser();
        if (user == null) {
          _error = 'Đăng nhập thất bại';
          return false;
        }
        _currentUser = user;
        // Ensure user exists locally for FK constraints
        await _local.insertUser(user);
      } else {
        // Offline: local SQLite fallback
        final user = await _local.getUserByUsername(username.trim().toLowerCase());
        if (user == null || !user.checkPassword(password)) {
          _error = 'Tên đăng nhập hoặc mật khẩu không đúng';
          return false;
        }
        _currentUser = user;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', _currentUser!.id);
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
      if (await ConnectivityHelper.isOnline) {
        final response = await _cloud.signUp(username.trim().toLowerCase(), password, fullName.trim());
        final authUser = response.user;
        if (authUser == null) {
          _error = 'Đăng ký thất bại';
          return false;
        }
        final newUser = UserModel(
          id: authUser.id,
          username: username.trim().toLowerCase(),
          passwordHash: '',
          role: UserRole.user,
          fullName: fullName.trim(),
          createdAt: DateTime.parse(authUser.createdAt),
        );
        await _local.insertUser(newUser);
      } else {
        final existing = await _local.getUserByUsername(username.trim().toLowerCase());
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
        await _local.insertUser(newUser);
      }

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
    if (await ConnectivityHelper.isOnline) {
      try {
        await _cloud.signOut();
      } catch (_) {}
    }
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
