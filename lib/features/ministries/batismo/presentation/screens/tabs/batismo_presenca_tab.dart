import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/design/app_icons.dart';
import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../../core/widgets/glass_card.dart';
import '../../../../../../core/widgets/status_badge.dart';
import '../../../data/baptism_repository.dart';
import '../../../domain/baptism_attendance_roll.dart';
import '../../../domain/models/baptism_attendance.dart';
import '../../../domain/models/baptism_meeting.dart';
import '../../../domain/models/baptism_student.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';

/// Aba Presença do workspace do Batismo (Etapa D).
///
/// Chamada por encontro: quem cuida do curso cria a aula (data + título) e
/// marca quem esteve lá. Cada encontro é de uma turma, e a chamada dele
/// lista os alunos daquela turma.
///
/// **Não marcado não é falta.** Um aluno sem marca é alguém por quem
/// ninguém passou ainda; quem faltou é marcado `Faltou` e tem linha no
/// banco. Essa diferença é o que permite cadastrar um aluno depois da aula
/// sem o sistema acusá-lo de ter faltado a ela.
///
/// Marcar e desmarcar pedem `baptism.edit` — as duas, de propósito.
/// Desmarcar apaga a linha, mas é a outra metade de marcar; se pedisse
/// `baptism.delete`, quem tem edit marcaria sem conseguir corrigir.
class BatismoPresencaTab extends ConsumerStatefulWidget {
  final String ministryId;

  const BatismoPresencaTab({super.key, required this.ministryId});

  @override
  ConsumerState<BatismoPresencaTab> createState() => _BatismoPresencaTabState();
}

class _BatismoPresencaTabState extends ConsumerState<BatismoPresencaTab> {
  static const _allTurmas = 'all';

  final _search = TextEditingController();
  String _query = '';
  String _turmaId = _allTurmas;

  /// Só encontros com chamada incompleta — "onde ainda falta marcar".
  bool _onlyPending = false;

  /// Encontros com a chamada aberta.
  final _expanded = <String>{};

  /// Marcações em voo, por "meetingId:studentId", para travar só o aluno
  /// tocado em vez da tela inteira.
  final _busy = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Filtro (puro, para poder ser testado)
  // -------------------------------------------------------------------

  List<BaptismMeetingRoll> applyFilters(List<BaptismMeetingRoll> rolls) {
    final query = _query.trim().toLowerCase();

    return rolls.where((r) {
      if (_turmaId != _allTurmas && r.meeting.turmaId != _turmaId) return false;
      // Encontro de turma vazia não conta como pendente: não há chamada a
      // fazer. Sem isso, uma turma sem aluno deixaria a aba eternamente
      // "com pendência".
      if (_onlyPending && (r.total == 0 || r.isComplete)) return false;
      if (query.isEmpty) return true;
      return r.meeting.title.toLowerCase().contains(query);
    }).toList();
  }

  // -------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------

  /// Marca um aluno, ou o desmarca se ele já estava naquele estado.
  ///
  /// Tocar de novo no estado atual devolve o aluno a "não-marcado" — é
  /// como se desfaz um toque errado sem precisar de um botão de apagar.
  Future<void> _setStatus({
    required BaptismMeetingRoll roll,
    required BaptismStudent student,
    required BaptismAttendanceStatus status,
  }) async {
    final key = '${roll.meeting.id}:${student.id}';
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));

    final repo = ref.read(baptismRepositoryProvider);
    final current = roll.statusOf(student);

    try {
      if (current == status) {
        await repo.unmarkAttendance(
          meetingId: roll.meeting.id,
          studentId: student.id,
        );
      } else {
        await repo.markAttendance([
          (meetingId: roll.meeting.id, studentId: student.id, status: status),
        ]);
      }
      if (!mounted) return;
      // Realtime não é habilitado por migration neste banco: sem este
      // invalidate a tela ficaria mostrando o estado anterior até alguém
      // trocar de aba.
      invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Marca presente, de uma vez, todo mundo que ainda não foi tocado.
  ///
  /// Um upsert só, com `onConflict` — quem já tem marca fica como está,
  /// porque só os não-marcados entram no lote. É o caminho normal da
  /// chamada: a maioria veio, e só as exceções merecem toque individual.
  Future<void> _markRemainingPresent(BaptismMeetingRoll roll) async {
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
      if (!mounted) return;
      invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _openForm({
    required List<BaptismTurma> turmas,
    BaptismMeeting? meeting,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MeetingFormSheet(turmas: turmas, meeting: meeting),
    );
    if (saved == true && mounted) invalidateBaptismData(ref, widget.ministryId);
  }

  Future<void> _delete(BaptismMeeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir encontro?'),
        content: Text(
          'A chamada de "${meeting.title}" vai junto e não tem volta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(baptismRepositoryProvider).deleteMeeting(meeting.id);
      if (!mounted) return;
      invalidateBaptismData(ref, widget.ministryId);
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $error')));
  }

  Future<T?> _pickOption<T>({
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                title: Text(option.$2),
                trailing: option.$1 == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
  }

  String _turmaLabel(List<BaptismTurma> turmas) {
    if (_turmaId == _allTurmas) return 'Todas as turmas';
    for (final t in turmas) {
      if (t.id == _turmaId) return t.name;
    }
    return 'Turma';
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rollsAsync = ref.watch(
      baptismMeetingRollsProvider(widget.ministryId),
    );
    final turmas = ref
        .watch(baptismTurmasProvider(widget.ministryId))
        .maybeWhen(data: (t) => t, orElse: () => const <BaptismTurma>[]);

    bool can(BaptismWriteAction action) => ref
        .watch(
          baptismCanWriteProvider((
            ministryId: widget.ministryId,
            action: action,
          )),
        )
        .maybeWhen(data: (v) => v, orElse: () => false);

    final canCreate = can(BaptismWriteAction.create);
    final canEdit = can(BaptismWriteAction.edit);
    final canDelete = can(BaptismWriteAction.delete);

    return rollsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _PresencaError(
        message: '$error',
        onRetry: () => invalidateBaptismData(ref, widget.ministryId),
      ),
      data: (rolls) {
        final visible = applyFilters(rolls);

        return RefreshIndicator(
          onRefresh: () async {
            invalidateBaptismData(ref, widget.ministryId);
            await ref.read(
              baptismMeetingRollsProvider(widget.ministryId).future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar encontro...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  AppFilterButton(
                    label: _turmaLabel(turmas),
                    icon: Icons.groups_2_outlined,
                    active: _turmaId != _allTurmas,
                    onTap: () async {
                      final picked = await _pickOption<String>(
                        title: 'Turma',
                        current: _turmaId,
                        options: [
                          (_allTurmas, 'Todas as turmas'),
                          for (final t in turmas) (t.id, t.name),
                        ],
                      );
                      if (picked != null) setState(() => _turmaId = picked);
                    },
                  ),
                  AppFilterButton(
                    label: _onlyPending ? 'Chamada aberta' : 'Todos',
                    icon: Icons.pending_actions_outlined,
                    active: _onlyPending,
                    onTap: () => setState(() => _onlyPending = !_onlyPending),
                  ),
                ],
                secondaryActions: [
                  if (canCreate && turmas.isNotEmpty)
                    AppFilterAction(
                      label: 'Novo encontro',
                      icon: AppIcons.add,
                      onPressed: () => _openForm(turmas: turmas),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Três vazios diferentes, três saídas diferentes: sem turma
              // não dá nem para criar encontro; sem encontro o caminho é
              // criar o primeiro; sem resultado no filtro o caminho é
              // limpar o filtro.
              if (turmas.isEmpty)
                const _EmptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'Nenhuma turma cadastrada',
                  message:
                      'O encontro pertence a uma turma. Cadastre a '
                      'primeira turma na aba Alunos e a chamada passa a '
                      'fazer sentido aqui.',
                )
              else if (rolls.isEmpty)
                _EmptyState(
                  icon: AppIcons.registration,
                  title: 'Nenhum encontro registrado',
                  message: canCreate
                      ? 'Crie a aula — data e nome — e marque quem esteve '
                            'presente. Quem você não tocar fica como '
                            'não-marcado, não como falta.'
                      : 'Ainda não há encontros registrados neste ministério.',
                  action: canCreate
                      ? _EmptyStateAction(
                          label: 'Registrar o primeiro encontro',
                          icon: AppIcons.add,
                          onPressed: () => _openForm(turmas: turmas),
                        )
                      : null,
                )
              else ...[
                _SectionLabel(
                  label: 'Encontros',
                  count: visible.length,
                  total: rolls.length,
                ),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  _EmptyState(
                    icon: AppIcons.searchEmpty,
                    title: 'Nenhum encontro neste filtro',
                    message: _onlyPending
                        ? 'Nenhuma chamada em aberto no filtro atual.'
                        : 'Nenhum encontro bate com a busca.',
                  )
                else
                  for (final roll in visible)
                    _MeetingCard(
                      roll: roll,
                      expanded: _expanded.contains(roll.meeting.id),
                      canEdit: canEdit,
                      canDelete: canDelete,
                      busyKeys: _busy,
                      onToggleExpanded: () => setState(() {
                        if (!_expanded.remove(roll.meeting.id)) {
                          _expanded.add(roll.meeting.id);
                        }
                      }),
                      onSetStatus: (student, status) => _setStatus(
                        roll: roll,
                        student: student,
                        status: status,
                      ),
                      onMarkRemaining: () => _markRemainingPresent(roll),
                      onEdit: () =>
                          _openForm(turmas: turmas, meeting: roll.meeting),
                      onDelete: () => _delete(roll.meeting),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Um encontro, com o resumo da chamada e a lista de alunos.
class _MeetingCard extends StatelessWidget {
  final BaptismMeetingRoll roll;
  final bool expanded;
  final bool canEdit;
  final bool canDelete;
  final Set<String> busyKeys;
  final VoidCallback onToggleExpanded;
  final void Function(BaptismStudent student, BaptismAttendanceStatus status)
  onSetStatus;
  final VoidCallback onMarkRemaining;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MeetingCard({
    required this.roll,
    required this.expanded,
    required this.canEdit,
    required this.canDelete,
    required this.busyKeys,
    required this.onToggleExpanded,
    required this.onSetStatus,
    required this.onMarkRemaining,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meeting = roll.meeting;
    final turma = meeting.turmaName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.title,
                            style: CommunityDesign.titleStyle(context).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              DateFormat('dd/MM/yyyy').format(meeting.day),
                              if (turma != null && turma.isNotEmpty) turma,
                            ].join(' · '),
                            style: CommunityDesign.metaStyle(context),
                          ),
                          const SizedBox(height: 8),
                          _RollSummary(roll: roll),
                        ],
                      ),
                    ),
                    if (canEdit || canDelete)
                      PopupMenuButton<String>(
                        itemBuilder: (context) => [
                          if (canEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                          if (canDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir'),
                            ),
                        ],
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              onEdit();
                            case 'delete':
                              onDelete();
                          }
                        },
                      ),
                    Icon(
                      expanded ? AppIcons.expandLess : AppIcons.expandMore,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Divider(height: 1, color: theme.dividerColor),
              if (roll.students.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(
                    'Nenhum aluno nesta turma ainda. A chamada aparece assim '
                    'que alguém entrar nela.',
                    style: CommunityDesign.metaStyle(context),
                  ),
                )
              else ...[
                for (final student in roll.students)
                  _StudentRollTile(
                    student: student,
                    status: roll.statusOf(student),
                    canEdit: canEdit,
                    busy: busyKeys.contains('${roll.meeting.id}:${student.id}'),
                    onSetStatus: (status) => onSetStatus(student, status),
                  ),
                if (canEdit && roll.unmarked > 0)
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
            ],
          ],
        ),
      ),
    );
  }
}

/// As contagens do encontro, em badges.
///
/// "Não marcados" aparece por último e só quando existe: é o número que
/// diz se a chamada foi feita, e mostrá-lo zerado seria ruído.
class _RollSummary extends StatelessWidget {
  final BaptismMeetingRoll roll;

  const _RollSummary({required this.roll});

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

/// Um aluno na chamada, com os três estados.
class _StudentRollTile extends StatelessWidget {
  final BaptismStudent student;
  final BaptismAttendanceStatus? status;
  final bool canEdit;
  final bool busy;
  final ValueChanged<BaptismAttendanceStatus> onSetStatus;

  const _StudentRollTile({
    required this.student,
    required this.status,
    required this.canEdit,
    required this.busy,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                // Sem baptism.edit os estados ficam desabilitados em vez
                // de sumir: a pessoa precisa enxergar a chamada mesmo sem
                // poder mexer nela.
                onTap: canEdit ? () => onSetStatus(option) : null,
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

/// Formulário de um encontro.
class _MeetingFormSheet extends ConsumerStatefulWidget {
  final List<BaptismTurma> turmas;
  final BaptismMeeting? meeting;

  const _MeetingFormSheet({required this.turmas, this.meeting});

  @override
  ConsumerState<_MeetingFormSheet> createState() => _MeetingFormSheetState();
}

class _MeetingFormSheetState extends ConsumerState<_MeetingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;

  late String? _turmaId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final meeting = widget.meeting;
    _title = TextEditingController(text: meeting?.title ?? '');
    _notes = TextEditingController(text: meeting?.notes ?? '');
    _date = meeting?.day ?? _today();
    _turmaId =
        meeting?.turmaId ??
        (widget.turmas.length == 1 ? widget.turmas.first.id : null);
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Dia do encontro',
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final turmaId = _turmaId;
    if (turmaId == null) return;

    setState(() => _saving = true);

    final repo = ref.read(baptismRepositoryProvider);
    final existing = widget.meeting;

    try {
      if (existing == null) {
        await repo.createMeeting(
          BaptismMeeting(
            // O banco gera os três: id por DEFAULT, tenant_id por
            // current_tenant_id() e created_at por now(). O que vai no
            // INSERT é só o que toWriteJson() monta.
            id: '',
            tenantId: '',
            turmaId: turmaId,
            meetingDate: _date,
            title: _title.text,
            notes: _notes.text,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.updateMeeting(
          existing.copyWith(
            turmaId: turmaId,
            meetingDate: _date,
            title: _title.text,
            notes: _notes.text,
            clearNotes: _notes.text.trim().isEmpty,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // 23505 é a UNIQUE (turma_id, meeting_date, title): já existe
            // um encontro com este nome, nesta turma, neste dia. Mostrar o
            // código cru não ajudaria ninguém.
            '$error'.contains('23505')
                ? 'Esta turma já tem um encontro com este nome neste dia.'
                : 'Não foi possível salvar: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.meeting == null ? 'Novo encontro' : 'Editar encontro',
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome do encontro',
                  hintText: 'Ex.: Aula 3 — O batismo nas Escrituras',
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Dê um nome para o encontro'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _turmaId,
                decoration: const InputDecoration(labelText: 'Turma'),
                items: [
                  for (final t in widget.turmas)
                    DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) => setState(() => _turmaId = v),
                validator: (v) => v == null ? 'Escolha a turma' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Dia',
                    // O encontro guarda DATE, não horário: duas aulas no
                    // mesmo dia se distinguem pelo nome, e é o que o
                    // UNIQUE do banco espera.
                    helperText: 'Duas aulas no mesmo dia? Mude o nome.',
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.dateRange,
                        size: 18,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(_date)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rótulo da seção, com a contagem do filtro.
class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final int total;

  const _SectionLabel({
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // "3 de 12" só aparece quando o filtro está escondendo alguém: sem
    // filtro, o segundo número seria ruído.
    final suffix = count == total ? '$total' : '$count de $total';

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '${label.toUpperCase()} · $suffix',
        style: CommunityDesign.metaStyle(
          context,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}

/// Botão opcional de um estado vazio.
class _EmptyStateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final _EmptyStateAction? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).hintColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: action!.onPressed,
              icon: Icon(action!.icon, size: 18),
              label: Text(action!.label),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresencaError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PresencaError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar a presença.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
