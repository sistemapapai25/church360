/// Um par ja marcado como "nao e a mesma pessoa", vindo de
/// list_dismissed_duplicate_pairs.
class DismissedPair {
  final String userAId;
  final String userBId;
  final String nomeA;
  final String nomeB;
  final String? motivo;

  /// Nulo quando a dispensa veio de uma sessao administrativa (SQL Editor),
  /// onde nao ha usuario autenticado para creditar.
  final String? dispensadoPor;

  final DateTime? dispensadoEm;

  const DismissedPair({
    required this.userAId,
    required this.userBId,
    required this.nomeA,
    required this.nomeB,
    this.motivo,
    this.dispensadoPor,
    this.dispensadoEm,
  });

  factory DismissedPair.fromJson(Map<String, dynamic> json) {
    return DismissedPair(
      userAId: json['user_a_id'] as String,
      userBId: json['user_b_id'] as String,
      nomeA: json['nome_a']?.toString() ?? 'Sem nome',
      nomeB: json['nome_b']?.toString() ?? 'Sem nome',
      motivo: json['motivo']?.toString(),
      dispensadoPor: json['dispensado_por']?.toString(),
      dispensadoEm: DateTime.tryParse(json['dispensado_em']?.toString() ?? ''),
    );
  }
}
