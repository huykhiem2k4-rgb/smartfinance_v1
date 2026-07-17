import 'package:crypto/crypto.dart';
import 'dart:convert';

enum UserRole { admin, user }

extension UserRoleExt on UserRole {
  String get label => this == UserRole.admin ? 'Quản trị viên' : 'Người dùng';
}

class UserModel {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final String? fullName;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.fullName,
    required this.createdAt,
  });

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  bool checkPassword(String password) => passwordHash == hashPassword(password);

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'role': role.name,
        'full_name': fullName,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'],
        username: m['username'],
        passwordHash: m['password_hash'],
        role: UserRole.values.firstWhere((e) => e.name == m['role'],
            orElse: () => UserRole.user),
        fullName: m['full_name'],
        createdAt: DateTime.parse(m['created_at']),
      );

  UserModel copyWith({UserRole? role, String? fullName}) => UserModel(
        id: id,
        username: username,
        passwordHash: passwordHash,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        createdAt: createdAt,
      );

  factory UserModel.fromSupabase(Map<String, dynamic> m) => UserModel(
        id: m['id'],
        username: m['username'] ?? '',
        passwordHash: '',
        role: (m['role'] ?? 'user') == 'admin' ? UserRole.admin : UserRole.user,
        fullName: m['full_name'],
        createdAt: m['created_at'] != null ? DateTime.parse(m['created_at']) : DateTime.now(),
      );
}
