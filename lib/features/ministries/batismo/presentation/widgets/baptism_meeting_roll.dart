import 'package:flutter/material.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/widgets/status_badge.dart';
import '../../domain/baptism_attendance_roll.dart';
import '../../domain/models/baptism_attendance.dart';
import '../../domain/models/baptism_student.dart';

/// As peças da chamada do Batismo, usadas em dois lugares: a aba Presença
/// (leitura, desde a Etapa 5.3) e a folha "Registrar presença" da aula
/// (onde se marca).

/// As contagens do encontro, em badges.
///
/// "Não marcados" aparece por último e só quando existe: é o número que
/// diz se a chamada foi feita, e mostrá-lo zerado seria ruído.
class BaptismRollSummary extends StatelessWidget {
  final BaptismMeetingRoll roll;

  const BaptismRollSummary({super.key, required this.roll});

  @override
  Widget build(BuildContext context) {
    if (roll.total == 0) {
      return StatusBadge(
        label: 'Turma sem aluno',
        tone: AppStatusTone.dropped,
        icon: Icons.person_off_outlined,
      );
    }

    if (roll.isUntouched) {
      return StatusBadge(
        label: 'Chamada não feita · ${roll.total}',
        tone: AppStatusTone.dropped,
        icon: Icons.pending_actions_outlined,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (roll.present > 0)
          StatusBadge.done(
            label: '${roll.present} presentes',
            icon: Icons.check_circle_outline,
          ),
        if (roll.absent > 0)
          StatusBadge.dropped(
            label: '${roll.absent} faltaram',
            icon: Icons.cancel_outlined,
          ),
        if (roll.justified > 0)
          StatusBadge.active(
            label: '${roll.justified} justificados',
            icon: Icons.event_busy_outlined,
          ),
        if (roll.unmarked > 0)
          StatusBadge(
            label: '${roll.unmarked} sem marca',
            tone: AppStatusTone.dropped,
            icon: Icons.help_outline,
          ),
      ],
    );
  }
}

/// A lista de alunos da chamada. Com [onSetStatus] `null` é só leitura.
class BaptismRollStudents extends StatelessWidget {
  final BaptismMeetingRoll roll;
  final Set<String> busyStudentIds;
  final void Function(BaptismStudent student, BaptismAttendanceStatus status)?
  onSetStatus;
  final VoidCallback? onMarkRemaining;

  const BaptismRollStudents({
    super.key,
    required this.roll,
    this.busyStudentIds = const {},
    this.onSetStatus,
    this.onMarkRemaining,
  });

  @override
  Widget build(BuildContext context) {
    if (roll.students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Text(
          'Nenhum aluno nesta turma ainda. A chamada aparece assim '
          'que alguém entrar nela.',
          style: CommunityDesign.metaStyle(context),
        ),
      );
    }

    final setStatus = onSetStatus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final student in roll.students)
          _StudentRollTile(
            student: student,
            status: roll.statusOf(student),
            busy: busyStudentIds.contains(student.id),
            onSetStatus: setStatus == null
                ? null
                : (status) => setStatus(student, status),
          ),
        if (onMarkRemaining != null && roll.unmarked > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
              child: TextButton.icon(
                onPressed: onMarkRemaining,
                icon: const Icon(AppIcons.doneAll, size: 18),
                label: Text(
                  roll.isUntouched
                      ? 'Marcar todos presentes'
                      : 'Marcar os ${roll.unmarked} restantes',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Um aluno na chamada, com os três estados.
class _StudentRollTile extends StatelessWidget {
  final BaptismStudent student;
  final BaptismAttendanceStatus? status;
  final bool busy;
  final ValueChanged<BaptismAttendanceStatus>? onSetStatus;

  const _StudentRollTile({
    required this.student,
    required this.status,
    required this.busy,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setStatus = onSetStatus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              student.fullName,
              style: CommunityDesign.contentStyle(
                context,
              ).copyWith(fontSize: 14),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            for (final option in BaptismAttendanceStatus.values)
              _StatusDot(
                status: option,
                selected: status == option,
                // Sem escrita os estados ficam desabilitados em vez de
                // sumir: a pessoa precisa enxergar a chamada mesmo sem
                // poder mexer nela.
                onTap: setStatus == null ? null : () => setStatus(option),
              ),
          if (!busy && status == null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.remove,
                size: 14,
                color: theme.hintColor.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Um dos três estados, como botão redondo.
class _StatusDot extends StatelessWidget {
  final BaptismAttendanceStatus status;
  final bool selected;
  final VoidCallback? onTap;

  const _StatusDot({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  ({IconData icon, Color color}) _look(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      BaptismAttendanceStatus.presente => (
        icon: Icons.check,
        color: scheme.primary,
      ),
      BaptismAttendanceStatus.ausente => (
        icon: Icons.close,
        color: scheme.error,
      ),
      BaptismAttendanceStatus.justificado => (
        icon: Icons.event_busy_outlined,
        color: scheme.tertiary,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = _look(context);

    return Tooltip(
      message: status.label,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? look.color.withValues(alpha: 0.14)
              : Colors.transparent,
          shape: const CircleBorder(),
        ),
        icon: Icon(
          look.icon,
          size: 18,
          color: selected ? look.color : theme.hintColor,
        ),
      ),
    );
  }
}
