/// Os dois lados do checklist do batismo.
///
/// [BaptismChecklistItem] é o catálogo — as etapas do curso, definidas por
/// quem cuida do ministério. [BaptismChecklistEntry] é o que um aluno já
/// cumpriu.
///
/// A separação existe porque as duas coisas mudam em ritmos diferentes: o
/// catálogo muda uma vez por ano, a marcação muda toda aula.
library;

/// Uma etapa do curso (`public.baptism_checklist_item`).
///
/// [turmaId] nulo significa que a etapa vale para **todas** as turmas do
/// ministério, que é o caso comum — o curso costuma ter as mesmas etapas
/// toda turma. Preenchido, a etapa é só daquela turma (um encontro extra,
/// uma exigência pontual).
class BaptismChecklistItem {
  final String id;
  final String tenantId;
  final String ministryId;

  /// Turma dona da etapa, ou nulo quando a etapa é do ministério inteiro.
  final String? turmaId;

  final String title;
  final String? description;

  /// Posição na lista. Empate cai no título, para a ordem nunca depender
  /// da ordem de inserção do banco.
  final int orderIndex;

  /// Etapa desligada continua no banco e some da tela. Some também do
  /// denominador do progresso: quem tinha 3 de 5 com uma etapa desligada
  /// passa a ter 3 de 4, não 3 de 5 com uma linha invisível.
  final bool isActive;

  final DateTime createdAt;

  const BaptismChecklistItem({
    required this.id,
    required this.tenantId,
    required this.ministryId,
    this.turmaId,
    required this.title,
    this.description,
    this.orderIndex = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory BaptismChecklistItem.fromJson(Map<String, dynamic> json) {
    return BaptismChecklistItem(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      ministryId: json['ministry_id'] as String,
      turmaId: json['turma_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  /// Campos graváveis. `id`, `tenant_id` e `created_at` ficam de fora: o
  /// primeiro é a chave, os outros dois são do banco (`tenant_id` tem
  /// `DEFAULT current_tenant_id()` e a policy exige que ele bata com o
  /// tenant da sessão — mandá-lo do cliente só criaria uma segunda fonte
  /// para a mesma verdade).
  Map<String, dynamic> toWriteJson() {
    return {
      'ministry_id': ministryId,
      'turma_id': turmaId,
      'title': title.trim(),
      'description': description?.trim(),
      'order_index': orderIndex,
      'is_active': isActive,
    };
  }

  /// Se esta etapa cobre o aluno de uma turma.
  ///
  /// Etapa do ministério cobre todo mundo; etapa de turma cobre só a dela.
  bool appliesToTurma(String turmaId) =>
      this.turmaId == null || this.turmaId == turmaId;

  /// Rótulo do alcance, para a tela não precisar reimplementar a regra.
  String get scopeLabel => turmaId == null ? 'Todas as turmas' : 'Só desta turma';

  BaptismChecklistItem copyWith({
    String? turmaId,
    bool clearTurmaId = false,
    String? title,
    String? description,
    bool clearDescription = false,
    int? orderIndex,
    bool? isActive,
  }) {
    return BaptismChecklistItem(
      id: id,
      tenantId: tenantId,
      ministryId: ministryId,
      turmaId: clearTurmaId ? null : (turmaId ?? this.turmaId),
      title: title ?? this.title,
      description:
          clearDescription ? null : (description ?? this.description),
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}

/// Uma etapa cumprida por um aluno (`public.baptism_student_checklist`).
///
/// A linha **existir** é o "feito" — não há coluna booleana. Desmarcar
/// apaga a linha, e é por isso que o DELETE desta tabela pede
/// `baptism.edit` e não `baptism.delete`: marcar e desmarcar são a mesma
/// ação vista dos dois lados.
class BaptismChecklistEntry {
  final String id;
  final String tenantId;
  final String studentId;
  final String itemId;
  final DateTime doneAt;

  /// `auth.uid()` de quem marcou — não `user_account.id`. As duas
  /// convenções convivem neste banco.
  final String? doneBy;

  const BaptismChecklistEntry({
    required this.id,
    required this.tenantId,
    required this.studentId,
    required this.itemId,
    required this.doneAt,
    this.doneBy,
  });

  factory BaptismChecklistEntry.fromJson(Map<String, dynamic> json) {
    return BaptismChecklistEntry(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      studentId: json['student_id'] as String,
      itemId: json['item_id'] as String,
      doneAt: DateTime.tryParse('${json['done_at']}') ?? DateTime.now(),
      doneBy: json['done_by'] as String?,
    );
  }
}
