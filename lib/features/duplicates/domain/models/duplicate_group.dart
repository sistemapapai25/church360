// Modelos da deteccao de cadastros duplicados.
//
// Chave repetida e' CANDIDATA, nunca veredito: quem decide e' a pessoa na
// tela. Por isso a unidade de decisao aqui e' sempre o PAR, nunca o grupo
// inteiro — um grupo de tres fichas que dividem o telefone de casa pode ter
// duas iguais e uma diferente.

/// Uma ficha dentro de um grupo devolvido por find_duplicate_user_accounts.
class DuplicateAccount {
  final String id;
  final String nome;
  final String? email;
  final String? telefone;
  final String? cpf;
  final String? status;
  final String? memberType;
  final String? roleGlobal;

  /// A ficha esta amarrada a um usuario de autenticacao. Duas fichas com
  /// login nao podem ser fundidas: apagar um auth.users exige a Admin API,
  /// e a RPC barra antes de mexer em qualquer coisa.
  final bool temLogin;

  final DateTime? criadoEm;

  const DuplicateAccount({
    required this.id,
    required this.nome,
    required this.temLogin,
    this.email,
    this.telefone,
    this.cpf,
    this.status,
    this.memberType,
    this.roleGlobal,
    this.criadoEm,
  });

  factory DuplicateAccount.fromJson(Map<String, dynamic> json) {
    final nome = (json['nome'] as String?)?.trim();
    return DuplicateAccount(
      id: json['id'] as String,
      nome: (nome == null || nome.isEmpty) ? 'Sem nome' : nome,
      email: _texto(json['email']),
      telefone: _texto(json['telefone']),
      cpf: _texto(json['cpf']),
      status: _texto(json['status']),
      memberType: _texto(json['member_type']),
      roleGlobal: _texto(json['role_global']),
      temLogin: json['tem_login'] == true,
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
    );
  }

  static String? _texto(dynamic valor) {
    final texto = valor?.toString().trim();
    return (texto == null || texto.isEmpty) ? null : texto;
  }
}

/// Um grupo de fichas que repetem a mesma chave.
class DuplicateGroup {
  final String motivo;
  final String chave;
  final int confianca;
  final List<DuplicateAccount> fichas;

  const DuplicateGroup({
    required this.motivo,
    required this.chave,
    required this.confianca,
    required this.fichas,
  });

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) {
    final fichas = (json['fichas'] as List? ?? const [])
        .map((f) => DuplicateAccount.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList();

    return DuplicateGroup(
      motivo: json['motivo']?.toString() ?? '',
      chave: json['chave']?.toString() ?? '',
      confianca: (json['confianca'] as num?)?.toInt() ?? 0,
      fichas: fichas,
    );
  }

  String get motivoLabel => switch (motivo) {
        'login' => 'Mesmo login',
        'cpf' => 'Mesmo CPF',
        'telefone' => 'Mesmo telefone',
        'email' => 'Mesmo e-mail',
        _ => motivo,
      };

  /// Quanto mais alta a confianca, menos provavel que seja coincidencia.
  /// Login (4) e CPF (3) quase sempre sao a mesma pessoa; telefone (2) e
  /// e-mail (1) sao compartilhados dentro de casa o tempo todo.
  String get confiancaLabel => switch (confianca) {
        >= 4 => 'Quase certo',
        3 => 'Forte',
        2 => 'Media',
        _ => 'Fraca',
      };
}
