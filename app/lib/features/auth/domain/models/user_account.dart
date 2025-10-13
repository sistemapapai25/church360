/// Modelo de UserAccount
/// Representa um usuário do sistema
class UserAccount {
  final String id;
  final String email;
  final String fullName;
  final String? photoUrl;
  final String roleGlobal;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserAccount({
    required this.id,
    required this.email,
    required this.fullName,
    this.photoUrl,
    required this.roleGlobal,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  /// Criar a partir do JSON do Supabase
  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      photoUrl: json['photo_url'] as String?,
      roleGlobal: json['role_global'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converter para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'photo_url': photoUrl,
      'role_global': roleGlobal,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Copiar com modificações
  UserAccount copyWith({
    String? id,
    String? email,
    String? fullName,
    String? photoUrl,
    String? roleGlobal,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      roleGlobal: roleGlobal ?? this.roleGlobal,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verificar se é owner
  bool get isOwner => roleGlobal == 'owner';

  /// Verificar se é admin
  bool get isAdmin => roleGlobal == 'admin';

  /// Verificar se é líder
  bool get isLeader => roleGlobal == 'leader';
}

