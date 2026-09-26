import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/community_design.dart';
import '../../data/baptism_lesson_meeting.dart';
import '../../data/baptism_repository.dart';
import '../../domain/baptism_attendance_roll.dart';
import '../../domain/models/baptism_attendance.dart';
import '../../domain/models/baptism_meeting.dart';
import '../../domain/models/baptism_student.dart';
import '../providers/baptism_providers.dart';
import 'baptism_meeting_roll.dart';

/// "Registrar presença" de uma aula do Batismo (Etapa 5.3).
///
/// Desde 26/09 é o único lugar onde a chamada do Batismo é feita: a
/// presença por aula substituiu o encontro avulso, e a aba Presença virou
/// leitura. Ao abrir, acha o encontro da aula ou o cria
/// ([ensureBaptismLessonMeeting]); depois é a mesma chamada de sempre —
/// três estados, tocar de novo desmarca, "marcar os restantes".
///
/// Marcar e desmarcar pedem `baptism.edit`; abrir a chamada pela primeira
/// vez pede também `baptism.create`, porque cria o encontro.
class BaptismLessonAttendance extends ConsumerStatefulWidget {
  final String ministryId;
  final String turmaId;
  final BaptismLessonRef lesson;

  const BaptismLessonAttendance({
    super.key,
    required this.ministryId,
    required this.turmaId,
    required this.lesson,
  });

  @override
  ConsumerState<BaptismLessonAttendance> createState() =>
      _BaptismLessonAttendanceState();
}

class _BaptismLessonAttendanceState
    extends ConsumerState<BaptismLessonAttendance> {
  late Future<({BaptismMeeting? meeting, bool canEdit})> _opening;

  /// Alunos com marcação em voo, para travar só quem foi tocado.
  final _busy = <String>{};

  BaptismTurmaKey get _key =>
      (ministryId: widget.ministryId, turmaId: widget.turmaId);

  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<bool> _can(BaptismWriteAction action) => ref.read(
    baptismCanWriteProvider((
      ministryId: widget.ministryId,
      action: action,
    )).future,
  );

  Future<({BaptismMeeting? meeting, bool canEdit})> _open() async {
    // Segunda trava do modo travado: turma que não é deste ministério não
    // abre nem cria nada.
    final turma = await ref.read(baptismLockedTurmaProvider(_key).future);
    if (turma == null) {
      throw StateError('Esta turma não pertence ao ministério.');
    }
    final canCreate = await _can(BaptismWriteAction.create);
    final canEdit = await _can(BaptismWriteAction.edit);
    final meeting = await ensureBaptismLessonMeeting(
      ref.read(baptismRepositoryProvider),
      turmaId: widget.turmaId,
      lesson: widget.lesson,
      canCreate: canCreate,
      canEdit: canEdit,
    );
    // O encontro pode ter acabado de nascer: sem isto a chamada abaixo
    // leria a lista de encontros de antes e não o acharia.
    if (mounted) invalidateBaptismData(ref, widget.ministryId);
    return (meeting: meeting, canEdit: canEdit);
  }

  Future<void> _setStatus(
    BaptismMeetingRoll roll,
    BaptismStudent student,
    BaptismAttendanceStatus status,
  ) async {
    if (_busy.contains(student.id)) return;
    setState(() => _busy.add(student.id));
    final repo = ref.read(baptismRepositoryProvider);
    try {
      // Tocar de novo no estado atual devolve o aluno a "não-marcado".
      if (roll.statusOf(student) == status) {
        await repo.unmarkAttendance(
          meetingId: roll.meeting.id,
          studentId: student.id,
        );
      } else {
        await repo.markAttendance([
          (meetingId: roll.meeting.id, studentId: student.id, status: status),
        ]);
      }
      // Realtime não é ligado por migration neste banco: sem o invalidate
      // a folha ficaria mostrando o estado anterior.
      if (mounted) invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(student.id));
    }
  }

  /// Presente para todo mundo ainda sem marca, num upsert só.
  Future<void> _markRemaining(BaptismMeetingRoll roll) async {
    final pending = [
      for (final student in roll.students)
        if (roll.statusOf(student) == null)
          (
            meetingId: roll.meeting.id,
            studentId: student.id,
            status: BaptismAttendanceStatus.presente,
          ),
    ];
    if (pending.isEmpty) return;
    try {
      await ref.read(baptismRepositoryProvider).markAttendance(pending);
      if (mounted) invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $error')));
  }

  @override
  Widget build(BuildContext context) {
    final meta = CommunityDesign.metaStyle(context);

    return FutureBuilder<({BaptismMeeting? meeting, bool canEdit})>(
      future: _opening,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = '${snapshot.error}';
          return _Message(
            error.contains('23505')
                ? 'Já existe um encontro antigo com este nome neste dia. '
                      'Mude o título ou a data da aula e tente de novo.'
                : 'Não foi possível abrir a chamada: $error',
            onRetry: () => setState(() => _opening = _open()),
          );
        }

        final opened = snapshot.data!;
        final meeting = opened.meeting;
        if (meeting == null) {
          return const _Message(
            'A chamada desta aula ainda não foi aberta. Quem pode criar '
            'encontros no Batismo abre a primeira vez.',
          );
        }

        final rollsAsync = ref.watch(baptismTurmaMeetingRollsProvider(_key));
        return rollsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _Message(
            'Não foi possível carregar a chamada: $error',
            onRetry: () => invalidateBaptismData(ref, widget.ministryId),
          ),
          data: (rolls) {
            BaptismMeetingRoll? roll;
            for (final r in rolls) {
              if (r.meeting.id == meeting.id) roll = r;
            }
            if (roll == null) {
              return _Message(
                'Não foi possível carregar a chamada.',
                onRetry: () => invalidateBaptismData(ref, widget.ministryId),
              );
            }
            final current = roll;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Encontro de ${DateFormat('dd/MM/yyyy').format(meeting.day)}',
                  style: meta,
                ),
                const SizedBox(height: 8),
                BaptismRollSummary(roll: current),
                const SizedBox(height: 8),
                BaptismRollStudents(
                  roll: current,
                  busyStudentIds: _busy,
                  onSetStatus: opened.canEdit
                      ? (student, status) =>
                            _setStatus(current, student, status)
                      : null,
                  onMarkRemaining: opened.canEdit
                      ? () => _markRemaining(current)
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Não marcado não é falta. Tocar de novo no mesmo estado '
                  'desmarca.',
                  style: meta,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message(this.text, {this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: CommunityDesign.metaStyle(context)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
