import 'role.dart';
import 'role_context.dart';

/// Model: UserRole (Atribuição de Cargo)
/// Representa a atribuição de um cargo a um usuário
class UserRole {
  final String id;
  final String userId;
  final String roleId;
  final String? roleContextId;
  final DateTime? assignedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final String? assignedBy;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Dados relacionados (joins)
  final Role? role;
  final RoleContext? roleContext;

  const UserRole({
    required this.id,
    required this.userId,
    required this.roleId,
    this.roleContextId,
    this.assignedAt,
    this.expiresAt,
    this.isActive = true,
    this.assignedBy,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.role,
    this.roleContext,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      roleId: json['role_id'] as String,
      roleContextId: json['role_context_id'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
      assignedBy: json['assigned_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      role: json['role'] != null
          ? Role.fromJson(json['role'] as Map<String, dynamic>)
          : null,
      roleContext: json['role_context'] != null
          ? RoleContext.fromJson(json['role_context'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role_id': roleId,
      'role_context_id': roleContextId,
      'assigned_at': assignedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'assigned_by': assignedBy,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'role': role?.toJson(),
      'role_context': roleContext?.toJson(),
    };
  }

  UserRole copyWith({
    String? id,
    String? userId,
    String? roleId,
    String? roleContextId,
    DateTime? assignedAt,
    DateTime? expiresAt,
    bool? isActive,
    String? assignedBy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Role? role,
    RoleContext? roleContext,
  }) {
    return UserRole(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roleId: roleId ?? this.roleId,
      roleContextId: roleContextId ?? this.roleContextId,
      assignedAt: assignedAt ?? this.assignedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      assignedBy: assignedBy ?? this.assignedBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      roleContext: roleContext ?? this.roleContext,
    );
  }
}

