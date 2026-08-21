/// Entrada leve do diretório de membros do tenant (nome, apelido, foto,
/// gênero) — usada em telas de busca de pessoa (ex: adicionar responsável)
/// para usuários sem papel elevado, que não têm acesso à linha completa de
/// `user_account` de terceiros via RLS. Vem do RPC
/// `get_tenant_member_directory`, que expõe só esses campos.
class MemberDirectoryEntry {
  final String id;
  final String? fullName;
  final String? nickname;
  final String? avatarUrl;
  final String? gender;

  MemberDirectoryEntry({
    required this.id,
    this.fullName,
    this.nickname,
    this.avatarUrl,
    this.gender,
  });

  factory MemberDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return MemberDirectoryEntry(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
    );
  }

  /// Nome para exibição (sempre retorna um valor)
  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!;
    if (nickname != null && nickname!.trim().isNotEmpty) return nickname!;
    return id;
  }

  /// Iniciais para avatar
  String get initials {
    final name = displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
