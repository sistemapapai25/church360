import 'baptism_attendance.dart';

/// Um encontro da turma visto pelo próprio aluno: data, título e a marca
/// dele. Linha de `my_baptism_attendance(turma_id)`.
///
/// [status] `null` é não marcado — nunca falta (regra do Batismo).
class BaptismMyMeeting {
  final String meetingId;
  final DateTime meetingDate;
  final String title;
  final BaptismAttendanceStatus? status;

  const BaptismMyMeeting({
    required this.meetingId,
    required this.meetingDate,
    required this.title,
    this.status,
  });

  factory BaptismMyMeeting.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    return BaptismMyMeeting(
      meetingId: json['meeting_id'] as String,
      // `date` no banco: sem fuso, é o dia da parede.
      meetingDate: DateTime.parse(json['meeting_date'] as String),
      title: (json['title'] as String?) ?? '',
      status: status == null ? null : BaptismAttendanceStatus.fromCode(status),
    );
  }
}
