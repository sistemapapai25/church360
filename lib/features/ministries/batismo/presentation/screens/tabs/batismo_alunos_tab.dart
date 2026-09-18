import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../../../core/widgets/app_filter_bar.dart';
import '../../../data/baptism_repository.dart';
import '../../../domain/models/baptism_student.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';
import '../../widgets/baptism_turmas_sheet.dart';
import '../../widgets/student_card.dart';
import '../../widgets/student_form_sheet.dart';

/// Critérios de ordenação da lista de alunos.
enum StudentSort {
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  ageAsc('Idade (menor primeiro)'),
  ageDesc('Idade (maior primeiro)');

  final String label;

  const StudentSort(this.label);
}

/// Filtro de turma. `semTurma` não existe: `baptism_student.turma_id` é
/// NOT NULL, então todo aluno tem turma. A opção "Sem turma" do sistema de
/// referência não tem correspondente aqui.
class _TurmaFilter {
  static const all = 'all';
}

/// Aba Alunos do workspace do Batismo — a tela do print.
class BatismoAlunosTab extends ConsumerStatefulWidget {
  final String ministryId;

  const BatismoAlunosTab({super.key, required this.ministryId});

  @override
  ConsumerState<BatismoAlunosTab> createState() => _BatismoAlunosTabState();
}

class _BatismoAlunosTabState extends ConsumerState<BatismoAlunosTab> {
  final _search = TextEditingController();
  String _query = '';
  BaptismStudentStatus? _status;
  String _turmaId = _TurmaFilter.all;
  StudentSort _sort = StudentSort.nameAsc;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Filtro e ordenação (puros, para poderem ser testados)
  // -------------------------------------------------------------------

  List<BaptismStudent> _apply(List<BaptismStudent> students) {
    final query = _normalize(_query);
    final digits = _query.replaceAll(RegExp(r'[^0-9]'), '');

    final filtered = students.where((s) {
      if (_status != null && s.status != _status) return false;
      if (_turmaId != _TurmaFilter.all && s.turmaId != _turmaId) return false;
      if (query.isEmpty) return true;

      // A busca é por nome OU telefone. Comparar telefone só por dígitos é o
      // que faz "11912345678" achar quem está gravado como "(11) 91234-5678".
      if (_normalize(s.fullName).contains(query)) return true;
      if (digits.isNotEmpty) {
        final phone = (s.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isNotEmpty && phone.contains(digits)) return true;
      }
      return false;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case StudentSort.nameAsc:
          return _normalize(a.fullName).compareTo(_normalize(b.fullName));
        case StudentSort.nameDesc:
          return _normalize(b.fullName).compareTo(_normalize(a.fullName));
        case StudentSort.ageAsc:
        case StudentSort.ageDesc:
          // Aluno sem data de nascimento vai para o fim nos DOIS sentidos:
          // ele não é "o mais novo" nem "o mais velho", é desconhecido. Com
          // data em 4% do cadastro, jogá-lo para o topo encheria a tela de
          // linhas sem idade.
          final ageA = a.age;
          final ageB = b.age;
          if (ageA == null && ageB == null) {
            return _normalize(a.fullName).compareTo(_normalize(b.fullName));
          }
          if (ageA == null) return 1;
          if (ageB == null) return -1;
          return _sort == StudentSort.ageAsc
              ? ageA.compareTo(ageB)
              : ageB.compareTo(ageA);
      }
    });

    return filtered;
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  // -------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------

  Future<void> _newStudent(List<BaptismTurma> turmas) async {
    if (turmas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crie uma turma antes de cadastrar alunos.'),
        ),
      );
      return;
    }
    final saved = await showStudentFormSheet(context: context, turmas: turmas);
    if (saved && mounted) invalidateBaptismData(ref, widget.ministryId);
  }

  Future<void> _editStudent(
    BaptismStudent student,
    List<BaptismTurma> turmas,
  ) async {
    final saved = await showStudentFormSheet(
      context: context,
      turmas: turmas,
      student: student,
    );
    if (saved && mounted) invalidateBaptismData(ref, widget.ministryId);
  }

  Future<void> _deleteStudent(BaptismStudent student) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${student.fullName}?'),
        content: const Text('Esta ação não pode ser desfeita.'),
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
    if (ok != true) return;

    try {
      await ref.read(baptismRepositoryProvider).deleteStudent(student.id);
      if (mounted) invalidateBaptismData(ref, widget.ministryId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir: $e')),
        );
      }
    }
  }

  Future<void> _whatsApp(BaptismStudent student) async {
    final result = await launchWhatsAppMessage(
      phone: student.phone,
      message: 'Olá, ${student.firstName}!',
    );
    if (!mounted) return;
    if (result == WhatsAppLaunchResult.launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == WhatsAppLaunchResult.invalidPhone
              ? 'Este aluno não tem um telefone válido cadastrado.'
              : 'Não foi possível abrir o WhatsApp neste dispositivo.',
        ),
      ),
    );
  }

  Future<void> _openTurmas({
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  }) async {
    final changed = await showBaptismTurmasSheet(
      context: context,
      ministryId: widget.ministryId,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
    );
    if (changed && mounted) invalidateBaptismData(ref, widget.ministryId);
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
                style: CommunityDesign.titleStyle(context)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
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

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(baptismStudentsProvider(widget.ministryId));
    final turmasAsync = ref.watch(baptismTurmasProvider(widget.ministryId));
    final turmas = turmasAsync.maybeWhen(
      data: (t) => t,
      orElse: () => const <BaptismTurma>[],
    );

    bool can(BaptismWriteAction action) => ref
        .watch(
          baptismCanWriteProvider(
            (ministryId: widget.ministryId, action: action),
          ),
        )
        .maybeWhen(data: (v) => v, orElse: () => false);

    final canCreate = can(BaptismWriteAction.create);
    final canEdit = can(BaptismWriteAction.edit);
    final canDelete = can(BaptismWriteAction.delete);

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AlunosError(
        message: '$error',
        onRetry: () => invalidateBaptismData(ref, widget.ministryId),
      ),
      data: (students) {
        final visible = _apply(students);

        return RefreshIndicator(
          onRefresh: () async {
            invalidateBaptismData(ref, widget.ministryId);
            await ref.read(baptismStudentsProvider(widget.ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por nome ou WhatsApp...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  AppFilterButton(
                    label: _status?.label ?? 'Todos os status',
                    icon: Icons.flag_outlined,
                    active: _status != null,
                    onTap: () async {
                      final picked = await _pickOption<String>(
                        title: 'Status',
                        current: _status?.code ?? 'all',
                        options: [
                          ('all', 'Todos os status'),
                          for (final s in BaptismStudentStatus.values)
                            (s.code, s.label),
                        ],
                      );
                      if (picked == null) return;
                      setState(() {
                        _status = picked == 'all'
                            ? null
                            : BaptismStudentStatus.fromCode(picked);
                      });
                    },
                  ),
                  AppFilterButton(
                    label: _turmaLabel(turmas),
                    icon: Icons.groups_2_outlined,
                    active: _turmaId != _TurmaFilter.all,
                    onTap: () async {
                      final picked = await _pickOption<String>(
                        title: 'Turma',
                        current: _turmaId,
                        options: [
                          (_TurmaFilter.all, 'Todas as turmas'),
                          for (final t in turmas) (t.id, t.name),
                        ],
                      );
                      if (picked != null) setState(() => _turmaId = picked);
                    },
                  ),
                ],
                onSort: () async {
                  final picked = await _pickOption<StudentSort>(
                    title: 'Ordenar por',
                    current: _sort,
                    options: [
                      for (final s in StudentSort.values) (s, s.label),
                    ],
                  );
                  if (picked != null) setState(() => _sort = picked);
                },
                sortTooltip: 'Ordenar (${_sort.label})',
                secondaryAction: AppFilterAction(
                  label: 'Turmas',
                  icon: Icons.groups_2_outlined,
                  onPressed: () => _openTurmas(
                    canCreate: canCreate,
                    canEdit: canEdit,
                    canDelete: canDelete,
                  ),
                ),
                primaryAction: canCreate
                    ? AppFilterAction(
                        label: 'Novo aluno',
                        icon: Icons.person_add_alt,
                        onPressed: () => _newStudent(turmas),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              _CountLine(visible: visible.length, total: students.length),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                _EmptyState(
                  hasStudents: students.isNotEmpty,
                  hasTurmas: turmas.isNotEmpty,
                )
              else
                for (final s in visible)
                  StudentCard(
                    student: s,
                    onWhatsApp: (s.phone?.trim().isEmpty ?? true)
                        ? null
                        : () => _whatsApp(s),
                    onEdit: canEdit ? () => _editStudent(s, turmas) : null,
                    onDelete: canDelete ? () => _deleteStudent(s) : null,
                  ),
            ],
          ),
        );
      },
    );
  }

  String _turmaLabel(List<BaptismTurma> turmas) {
    if (_turmaId == _TurmaFilter.all) return 'Todas as turmas';
    for (final t in turmas) {
      if (t.id == _turmaId) return t.name;
    }
    return 'Turma';
  }
}

class _CountLine extends StatelessWidget {
  final int visible;
  final int total;

  const _CountLine({required this.visible, required this.total});

  @override
  Widget build(BuildContext context) {
    final text = visible == total
        ? '$total ${total == 1 ? 'aluno' : 'alunos'}'
        : '$visible de $total alunos';

    return Text(text, style: CommunityDesign.metaStyle(context));
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasStudents;
  final bool hasTurmas;

  const _EmptyState({required this.hasStudents, required this.hasTurmas});

  @override
  Widget build(BuildContext context) {
    final String message;
    if (hasStudents) {
      message = 'Nenhum aluno encontrado com esses filtros.';
    } else if (!hasTurmas) {
      message = 'Crie a primeira turma para começar a cadastrar alunos.';
    } else {
      message = 'Nenhum aluno cadastrado nesta turma ainda.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            hasStudents ? Icons.search_off : Icons.school_outlined,
            size: 36,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 10),
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

class _AlunosError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AlunosError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os alunos.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
