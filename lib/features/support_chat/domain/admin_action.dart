import 'dart:convert';

/// Pessoa que pode aprovar uma ação que o usuário não tem autoridade para fazer.
class AdminApprover {
  const AdminApprover({required this.id, required this.nome, this.nivel});

  final String id;
  final String nome;
  final int? nivel;
}

/// Ação administrativa proposta pelo Moisés: linha
/// `[[ADMIN_ACTION]]{"id","resumo","pode","motivo","aprovadores":[...]}`.
/// Quem executa (e confere a autoridade) é o banco, nas RPCs admin_action_*;
/// o app só mostra e encaminha o clique.
class AdminAction {
  const AdminAction({
    required this.id,
    required this.resumo,
    required this.pode,
    this.motivo,
    this.aprovadores = const [],
  });

  final String id;
  final String resumo;
  final bool pode;
  final String? motivo;
  final List<AdminApprover> aprovadores;
}

/// Tira a linha `[[ADMIN_ACTION]]` da resposta. JSON quebrado ou sem id/resumo:
/// a linha some do texto mesmo assim e [action] vem nulo (nunca lança).
({String text, AdminAction? action}) parseAdminAction(String reply) {
  const marker = '[[ADMIN_ACTION]]';
  final kept = <String>[];
  AdminAction? action;
  for (final line in reply.split('\n')) {
    if (!line.trimLeft().startsWith(marker)) {
      kept.add(line);
      continue;
    }
    try {
      final d = jsonDecode(line.trim().substring(marker.length).trim());
      if (d is! Map) continue;
      final id = d['id']?.toString().trim() ?? '';
      final resumo = d['resumo']?.toString().trim() ?? '';
      if (id.isEmpty || resumo.isEmpty) continue;
      final aprovadores = <AdminApprover>[];
      for (final a
          in (d['aprovadores'] is List ? d['aprovadores'] as List : const [])) {
        if (a is! Map) continue;
        final aid = a['id']?.toString().trim() ?? '';
        if (aid.isEmpty) continue;
        aprovadores.add(
          AdminApprover(
            id: aid,
            nome: (a['nome']?.toString().trim().isNotEmpty ?? false)
                ? a['nome'].toString().trim()
                : 'aprovador',
            nivel: a['nivel'] is num ? (a['nivel'] as num).toInt() : null,
          ),
        );
      }
      action = AdminAction(
        id: id,
        resumo: resumo,
        pode: d['pode'] == true,
        motivo: d['motivo']?.toString(),
        aprovadores: aprovadores,
      );
    } catch (_) {}
  }
  return (text: kept.join('\n').trimRight(), action: action);
}

/// Texto do resultado de uma ação (jsonb das RPCs admin_action_*).
String adminActionResultText(Map r) {
  final resultado = r['resultado']?.toString() ?? '';
  switch (r['status']) {
    case 'executed':
      return 'Feito.';
    case 'failed':
      return 'Não foi possível: $resultado';
    case 'awaiting_approval':
      return 'Pedido enviado a ${r['aprovador'] ?? 'o aprovador'}. Você será avisado.';
    case 'cancelled':
    case 'rejected':
      return 'Cancelado.';
    default:
      return 'Situação: ${r['status']}';
  }
}
