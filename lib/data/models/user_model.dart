import 'package:crypto/crypto.dart';
import 'dart:convert';

enum UserRole { owner, accountant }

extension UserRoleExt on UserRole {
  String get label => this == UserRole.owner ? 'Chủ doanh nghiệp' : 'Kế toán';
  String get dbValue => this == UserRole.owner ? 'OWNER' : 'ACCOUNTANT';
}

class UserModel {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String status; // ACTIVE | INACTIVE
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.status = 'ACTIVE',
    required this.createdAt,
    this.updatedAt,
  });

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  bool checkPassword(String password) => passwordHash == hashPassword(password);

  bool get isActive => status == 'ACTIVE';
  bool get isOwner => role == UserRole.owner;
  bool get isAccountant => role == UserRole.accountant;

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'role': role.dbValue,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> m) {
    final roleStr = (m['role'] as String?) ?? 'ACCOUNTANT';
    return UserModel(
      id: m['id'] as String,
      username: m['username'] as String,
      passwordHash: m['password_hash'] as String,
      role: roleStr.toUpperCase() == 'OWNER' ? UserRole.owner : UserRole.accountant,
      fullName: m['full_name'] as String?,
      email: m['email'] as String?,
      phone: m['phone'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      status: (m['status'] as String?) ?? 'ACTIVE',
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }

  UserModel copyWith({UserRole? role, String? fullName, String? email, String? phone, String? avatarUrl, String? status}) => UserModel(
        id: id,
        username: username,
        passwordHash: passwordHash,
        role: role ?? this.role,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory UserModel.fromSupabase(Map<String, dynamic> m) {
    final roleStr = (m['role'] as String?) ?? 'ACCOUNTANT';
    return UserModel(
      id: m['id'] as String,
      username: m['username'] as String? ?? '',
      passwordHash: '',
      role: roleStr.toUpperCase() == 'OWNER' ? UserRole.owner : UserRole.accountant,
      fullName: m['full_name'] as String?,
      email: m['email'] as String?,
      phone: m['phone'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      status: (m['status'] as String?) ?? 'ACTIVE',
      createdAt: m['created_at'] != null ? DateTime.parse(m['created_at'] as String) : DateTime.now(),
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'] as String) : null,
    );
  }
}
