import '../../../../../core/widgets/status_badge.dart';

/// Aluno de uma turma de batismo (`public.baptism_student`).
///
/// `userId` é opcional de propósito: o candidato ao batismo quase sempre
/// ainda não tem ficha em `user_account`. `fullName` fica gravado na linha
/// para que o aluno continue legível se a ficha for apagada — a FK é
/// `ON DELETE SET NULL`.
class BaptismStudent {
  final String id;
  final String tenantId;
  final String turmaId;
  final String? userId;
  final String fullName;
  final String? phone;
  final String? email;
  final DateTime? birthDate;
  final BaptismStudentStatus status;
  final BaptismStudentSource source;
  final String? notes;
  final DateTime createdAt;

  /// Nome da turma vindo do embed, quando a consulta o traz.
  final String? turmaName;

  const BaptismStudent({
    required this.id,
    required this.tenantId,
    required this.turmaId,
    this.userId,
    required this.fullName,
    this.phone,
    this.email,
    this.birthDate,
    required this.status,
    required this.source,
    this.notes,
    required this.createdAt,
    this.turmaName,
  });

  factory BaptismStudent.fromJson(Map<String, dynamic> json) {
    final turma = json['baptism_turma'];
    final turmaMap = turma is Map<String, dynamic> ? turma : null;

    return BaptismStudent(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      turmaId: json['turma_id'] as String,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.tryParse('${json['birth_date']}'),
      status: BaptismStudentStatus.fromCode(json['status'] as String?),
      source: BaptismStudentSource.fromCode(json['source'] as String?),
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      turmaName: turmaMap?['name'] as String?,
    );
  }

  /// Campos graváveis. `source` fica de fora: quem cadastra pela tela é
  /// sempre `manual`, e o valor `publica` só pode vir do formulário público
  /// (que ainda não existe). Deixar a tela escrever nessa coluna permitiria
  /// forjar a etiqueta de origem.
  Map<String, dynamic> toWriteJson() {
    return {
      'turma_id': turmaId,
      'user_id': userId,
      'full_name': fullName.trim(),
      'phone': _nullIfBlank(phone),
      'email': _nullIfBlank(email),
      'birth_date': _dateOnly(birthDate),
      'status': status.code,
      'notes': _nullIfBlank(notes),
    };
  }

  BaptismStudent copyWith({
    String? turmaId,
    String? fullName,
    String? phone,
    String? email,
    DateTime? birthDate,
    bool clearBirthDate = false,
    BaptismStudentStatus? status,
    String? notes,
  }) {
    return BaptismStudent(
      id: id,
      tenantId: tenantId,
      turmaId: turmaId ?? this.turmaId,
      userId: userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      status: status ?? this.status,
      source: source,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      turmaName: turmaName,
    );
  }

  /// Idade em anos completos, ou nulo quando não há data de nascimento.
  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    final hadBirthday = now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : years;
  }

  /// Primeiro nome, para a saudação de uma mensagem.
  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName.trim() : parts.first;
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }
}

/// Ciclo de vida do aluno — espelha o CHECK `baptism_student_status_valid`.
///
/// `desistente` é NEUTRO ([AppStatusTone.dropped]), não vermelho: uma lista
/// de alunos não é uma lista de falhas.
enum BaptismStudentStatus {
  ativo('ativo', 'Ativo', AppStatusTone.active),
  concluido('concluido', 'Concluído', AppStatusTone.done),
  desistente('desistente', 'Desistente', AppStatusTone.dropped);

  final String code;
  final String label;
  final AppStatusTone tone;

  const BaptismStudentStatus(this.code, this.label, this.tone);

  static BaptismStudentStatus fromCode(String? code) {
    return BaptismStudentStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => BaptismStudentStatus.ativo,
    );
  }
}

/// De onde o cadastro veio. `publica` ainda não é produzido por nada: o
/// formulário de inscrição sem login foi adiado (D3 do plano). A coluna já
/// existe no banco para não exigir migration estrutural depois.
enum BaptismStudentSource {
  manual('manual', 'Cadastro manual'),
  publica('publica', 'Inscrição Pública');

  final String code;
  final String label;

  const BaptismStudentSource(this.code, this.label);

  static BaptismStudentSource fromCode(String? code) {
    return BaptismStudentSource.values.firstWhere(
      (s) => s.code == code,
      orElse: () => BaptismStudentSource.manual,
    );
  }
}
