/// Membro encontrado na busca do cadastro de aluno, com os dados de
/// contato que o formulário preenche sozinho.
///
/// Vem da RPC `baptism_member_lookup`, e não de `user_account` direto nem
/// do diretório de membros: o diretório não expõe contato nenhum, e a
/// leitura direta passa pela RLS de `user_account`, que decide por
/// `role_global`/`access_level` e ignora o RBAC — o líder de batismo sem
/// papel elevado receberia campos em branco, sem erro nenhum.
class BaptismMemberSuggestion {
  final String id;
  final String? fullName;
  final String? nickname;
  final String? phone;
  final String? email;
  final DateTime? birthdate;

  const BaptismMemberSuggestion({
    required this.id,
    this.fullName,
    this.nickname,
    this.phone,
    this.email,
    this.birthdate,
  });

  factory BaptismMemberSuggestion.fromJson(Map<String, dynamic> json) {
    final raw = json['birthdate'];
    return BaptismMemberSuggestion(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      nickname: json['nickname'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      birthdate: raw == null ? null : DateTime.tryParse('$raw'),
    );
  }

  /// Nome para exibição — sempre devolve algo legível.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return 'Sem nome';
  }

  /// Linha de apoio na lista de sugestões. O cadastro de membros é magro
  /// (telefone em 21 das 199 fichas), então dizer "sem telefone na ficha"
  /// é mais honesto do que mostrar um espaço vazio e deixar a pessoa
  /// achar que a busca falhou.
  String get subtitle {
    final parts = <String>[];
    final p = phone?.trim();
    final e = email?.trim();
    if (p != null && p.isNotEmpty) parts.add(p);
    if (e != null && e.isNotEmpty) parts.add(e);
    if (parts.isEmpty) return 'Sem telefone ou e-mail na ficha';
    return parts.join(' · ');
  }
}
