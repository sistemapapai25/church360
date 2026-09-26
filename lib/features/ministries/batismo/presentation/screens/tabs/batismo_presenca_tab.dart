import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/design/app_icons.dart';
import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../../core/widgets/glass_card.dart';
import '../../../../../../core/widgets/status_badge.dart';
import '../../../domain/baptism_attendance_roll.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';
import '../../widgets/baptism_locked_turma_unavailable.dart';
import '../../widgets/baptism_meeting_roll.dart';

/// Aba Presença do workspace do Batismo (Etapa D; leitura desde a 5.3).
///
/// Mostra os encontros de cada turma e a chamada de cada um. **Não cria
/// nem marca nada** desde 26/09: a presença por aula substituiu o encontro
/// avulso (decisão do usuário), e a chamada é feita em "Registrar
/// presença", dentro da aula (Cursos → Batismo → turma → Aulas). O banco
/// recusa encontro novo sem aula. Os encontros de antes ficam aqui como
/// histórico, marcados como avulsos.
///
/// **Não marcado não é falta.** Um aluno sem marca é alguém por quem
/// ninguém passou ainda; quem faltou é marcado `Faltou` e tem linha no
/// banco.
///
/// Com [lockedTurmaId] (tela da turma em Cursos) a aba fica presa a essa
/// turma: busca só os encontros dela no banco e some o filtro de turma.
/// Turma que não é do ministério não abre nada
/// ([BaptismLockedTurmaUnavailable]).
class BatismoPresencaTab extends ConsumerStatefulWidget {
  final String ministryId;
  final String? lockedTurmaId;

  const BatismoPresencaTab({
    super.key,
    required this.ministryId,
    this.lockedTurmaId,
  });

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

  BaptismTurmaKey? get _lockedKey {
    final turmaId = widget.lockedTurmaId;
    if (turmaId == null) return null;
    return (ministryId: widget.ministryId, turmaId: turmaId);
  }

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
    final lockedKey = _lockedKey;
    BaptismTurma? lockedTurma;
    if (lockedKey != null) {
      final lockedAsync = ref.watch(baptismLockedTurmaProvider(lockedKey));
      if (lockedAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (lockedAsync.hasError) {
        return _PresencaError(
          message: '${lockedAsync.error}',
          onRetry: () => invalidateBaptismData(ref, widget.ministryId),
        );
      }
      lockedTurma = lockedAsync.value;
      if (lockedTurma == null) return const BaptismLockedTurmaUnavailable();
    }

    final rollsProvider = lockedKey == null
        ? baptismMeetingRollsProvider(widget.ministryId)
        : baptismTurmaMeetingRollsProvider(lockedKey);
    final rollsAsync = ref.watch(rollsProvider);
    final turmas = lockedTurma != null
        ? [lockedTurma]
        : ref
              .watch(baptismTurmasProvider(widget.ministryId))
              .maybeWhen(data: (t) => t, orElse: () => const <BaptismTurma>[]);

    // Na tela da turma a aula está a uma aba de distância; no workspace,
    // é preciso ir até Cursos.
    final whereToMark = lockedKey == null
        ? 'A chamada é feita dentro da aula: Cursos → Batismo → turma → '
              'Aulas → Registrar presença.'
        : 'A chamada é feita dentro da aula: aba Aulas → Registrar presença.';

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
            await ref.read(rollsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar encontro...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  if (lockedKey == null)
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
              ),
              const SizedBox(height: 12),
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
                  message: whereToMark,
                )
              else ...[
                _MarkInLessonHint(message: whereToMark),
                const SizedBox(height: 12),
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
                      onToggleExpanded: () => setState(() {
                        if (!_expanded.remove(roll.meeting.id)) {
                          _expanded.add(roll.meeting.id);
                        }
                      }),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Aviso fixo de onde a chamada é feita agora.
class _MarkInLessonHint extends StatelessWidget {
  final String message;

  const _MarkInLessonHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: CommunityDesign.metaStyle(context)),
        ),
      ],
    );
  }
}

/// Um encontro, com o resumo da chamada e a lista de alunos (leitura).
class _MeetingCard extends StatelessWidget {
  final BaptismMeetingRoll roll;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _MeetingCard({
    required this.roll,
    required this.expanded,
    required this.onToggleExpanded,
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Encontro de antes da 5.3: não tem aula onde
                              // corrigir a chamada, fica só como histórico.
                              if (meeting.isAvulso)
                                StatusBadge(
                                  label: 'Avulso · histórico',
                                  tone: AppStatusTone.dropped,
                                  icon: Icons.history,
                                ),
                              BaptismRollSummary(roll: roll),
                            ],
                          ),
                        ],
                      ),
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
              BaptismRollStudents(roll: roll),
            ],
          ],
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
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
