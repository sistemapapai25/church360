import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../ministries/batismo/domain/baptism_attendance_report.dart';
import '../../../../ministries/batismo/domain/models/baptism_attendance.dart';
import '../../../../ministries/batismo/domain/models/baptism_my_meeting.dart';
import '../../../../ministries/batismo/presentation/providers/baptism_providers.dart';
import '../../../../ministries/batismo/presentation/screens/tabs/batismo_alunos_tab.dart';
import '../../../../ministries/batismo/presentation/screens/tabs/batismo_presenca_tab.dart';
import '../turma_origin.dart';
import '../widgets/turma_sheet.dart';
import 'turma_surfaces.dart';

/// Superfícies da turma do Batismo: as abas do workspace, presas à turma
/// (`lockedTurmaId`, decisão 5), e a frequência do próprio aluno.
///
/// As regras do Batismo moram aqui e no módulo do Batismo — nunca nas abas
/// compartilhadas da tela da turma.
class BatismoTurmaAdapter implements TurmaSurfaces {
  final BatismoTurmaOrigin origin;

  const BatismoTurmaAdapter(this.origin);

  @override
  Widget alunos() => BatismoAlunosTab(
    ministryId: origin.ministryId,
    lockedTurmaId: origin.baptismTurmaId,
  );

  @override
  Widget presenca() => BatismoPresencaTab(
    ministryId: origin.ministryId,
    lockedTurmaId: origin.baptismTurmaId,
  );

  @override
  Widget minhaFrequencia() =>
      BatismoMinhaFrequencia(baptismTurmaId: origin.baptismTurmaId);
}

/// Resumo da chamada de um aluno, com as regras do Batismo:
///
/// - justificada **conta como falta** no percentual, mas aparece em coluna
///   própria;
/// - o denominador é só o que foi marcado;
/// - sem nada marcado o percentual é "—", nunca 0%.
class BatismoMyFrequency {
  final int present;
  final int absent;
  final int justified;
  final int unmarked;

  const BatismoMyFrequency({
    required this.present,
    required this.absent,
    required this.justified,
    required this.unmarked,
  });

  factory BatismoMyFrequency.of(List<BaptismMyMeeting> meetings) {
    var present = 0, absent = 0, justified = 0, unmarked = 0;
    for (final m in meetings) {
      switch (m.status) {
        case BaptismAttendanceStatus.presente:
          present++;
        case BaptismAttendanceStatus.ausente:
          absent++;
        case BaptismAttendanceStatus.justificado:
          justified++;
        case null:
          unmarked++;
      }
    }
    return BatismoMyFrequency(
      present: present,
      absent: absent,
      justified: justified,
      unmarked: unmarked,
    );
  }

  int get marked => present + absent + justified;

  double? get rate => marked == 0 ? null : present / marked;

  String get rateLabel => formatFrequency(rate);
}

/// "Minha frequência" do aluno do Batismo, pela RPC
/// `my_baptism_attendance`.
class BatismoMinhaFrequencia extends ConsumerWidget {
  final String baptismTurmaId;

  const BatismoMinhaFrequencia({super.key, required this.baptismTurmaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBaptismAttendanceProvider(baptismTurmaId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => TurmaMessage.error(
        message: 'Não foi possível carregar sua frequência.',
        onRetry: () =>
            ref.invalidate(myBaptismAttendanceProvider(baptismTurmaId)),
      ),
      data: (meetings) {
        if (meetings.isEmpty) {
          return const TurmaMessage(
            icon: AppIcons.calendar,
            message: 'Nenhum encontro registrado nesta turma ainda.',
          );
        }
        final summary = BatismoMyFrequency.of(meetings);
        final meta = CommunityDesign.metaStyle(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sua frequência', style: meta),
                  const SizedBox(height: 4),
                  Text(
                    summary.rateLabel,
                    key: const ValueKey('batismo-minha-frequencia-taxa'),
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.present} presenças · ${summary.absent} faltas · '
                    '${summary.justified} justificadas · '
                    '${summary.unmarked} sem marcação',
                    style: meta,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Justificada conta como falta no percentual. Encontro '
                    'sem marcação não entra na conta.',
                    style: meta,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final m in meetings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title),
                            Text(
                              DateFormat('dd/MM/yyyy').format(m.meetingDate),
                              style: meta,
                            ),
                          ],
                        ),
                      ),
                      Text(m.status?.label ?? '—', style: meta),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
