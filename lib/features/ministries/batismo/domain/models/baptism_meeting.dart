/// Encontro (aula) de uma turma de batismo (`public.baptism_meeting`).
///
/// É o objeto que faltava para existir chamada: até a Etapa D o módulo
/// sabia quem era aluno e o que ele tinha cumprido, mas não sabia que
/// houve uma aula na terça.
///
/// Uma turma pode ter dois encontros no mesmo dia (manhã e noite) — o
/// UNIQUE do banco é `(turma_id, meeting_date, title)`, não
/// `(turma_id, meeting_date)`.
class BaptismMeeting {
  final String id;
  final String tenantId;
  final String turmaId;

  /// Dia do encontro. `DATE` no banco, de propósito.
  ///
  /// As colunas `timestamptz` deste banco guardam hora de parede de São
  /// Paulo rotulada como UTC; lidas como instante erram 3h e uma aula das
  /// 20h de quinta cai na sexta. `DATE` escapa do contrato inteiro, e é
  /// por isso que só a parte de data trafega — ver [toWriteJson].
  final DateTime meetingDate;

  final String title;
  final String? notes;
  final DateTime createdAt;

  /// Nome da turma vindo do embed, quando a consulta o traz.
  final String? turmaName;

  const BaptismMeeting({
    required this.id,
    required this.tenantId,
    required this.turmaId,
    required this.meetingDate,
    required this.title,
    this.notes,
    required this.createdAt,
    this.turmaName,
  });

  factory BaptismMeeting.fromJson(Map<String, dynamic> json) {
    final turma = json['baptism_turma'];
    final turmaMap = turma is Map<String, dynamic> ? turma : null;

    return BaptismMeeting(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      turmaId: json['turma_id'] as String,
      meetingDate:
          DateTime.tryParse('${json['meeting_date']}') ?? DateTime.now(),
      title: json['title'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      turmaName: turmaMap?['name'] as String?,
    );
  }

  /// Campos graváveis. `id`, `tenant_id` e `created_at` ficam de fora: o
  /// primeiro é a chave, os outros dois são do banco (`tenant_id` tem
  /// `DEFAULT current_tenant_id()` e a policy exige que ele bata com o
  /// tenant da sessão).
  Map<String, dynamic> toWriteJson() {
    return {
      'turma_id': turmaId,
      'meeting_date': dateOnly(meetingDate),
      'title': title.trim(),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    };
  }

  /// O dia do encontro sem hora, para comparar e agrupar sem esbarrar em
  /// fuso.
  DateTime get day =>
      DateTime(meetingDate.year, meetingDate.month, meetingDate.day);

  BaptismMeeting copyWith({
    String? turmaId,
    DateTime? meetingDate,
    String? title,
    String? notes,
    bool clearNotes = false,
    String? turmaName,
  }) {
    return BaptismMeeting(
      id: id,
      tenantId: tenantId,
      turmaId: turmaId ?? this.turmaId,
      meetingDate: meetingDate ?? this.meetingDate,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt,
      turmaName: turmaName ?? this.turmaName,
    );
  }

  /// `meeting_date` é `DATE` no banco: mandar um timestamp reintroduziria
  /// o contrato de hora-de-parede que esta coluna existe para evitar.
  static String dateOnly(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }
}
