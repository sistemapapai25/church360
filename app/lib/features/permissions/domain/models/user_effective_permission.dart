/// Model: UserEffectivePermission (Permissão Efetiva do Usuário)
/// Representa uma permissão efetiva de um usuário (cargo + customizações)
class UserEffectivePermission {
  final String permissionCode;
  final String permissionName;
  final String source; // 'role' ou 'custom'
  final String? roleName;
  final String? contextName;
  final bool isGranted;

  const UserEffectivePermission({
    required this.permissionCode,
    required this.permissionName,
    required this.source,
    this.roleName,
    this.contextName,
    this.isGranted = true,
  });

  factory UserEffectivePermission.fromJson(Map<String, dynamic> json) {
    return UserEffectivePermission(
      permissionCode: json['permission_code'] as String,
      permissionName: json['permission_name'] as String,
      source: json['source'] as String,
      roleName: json['role_name'] as String?,
      contextName: json['context_name'] as String?,
      isGranted: (json['is_granted'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission_code': permissionCode,
      'permission_name': permissionName,
      'source': source,
      'role_name': roleName,
      'context_name': contextName,
      'is_granted': isGranted,
    };
  }

  UserEffectivePermission copyWith({
    String? permissionCode,
    String? permissionName,
    String? source,
    String? roleName,
    String? contextName,
    bool? isGranted,
  }) {
    return UserEffectivePermission(
      permissionCode: permissionCode ?? this.permissionCode,
      permissionName: permissionName ?? this.permissionName,
      source: source ?? this.source,
      roleName: roleName ?? this.roleName,
      contextName: contextName ?? this.contextName,
      isGranted: isGranted ?? this.isGranted,
    );
  }
}

