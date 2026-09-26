import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/study_group_provider.dart';
import '../../domain/models/study_group.dart';
import '../../../courses/domain/models/course.dart';
import '../../../courses/presentation/providers/courses_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/glass_card.dart';

/// Cursos em que o formulário pode criar turma: todos menos os
/// cursos-programa (`code` preenchido, ex.: Batismo), cuja turma nasce só
/// pelo ministério (trigger de `baptism_turma`).
List<Course> turmaFormSelectableCourses(List<Course> courses) {
  final list = [
    for (final c in courses)
      if (c.code == null) c,
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return list;
}

class StudyGroupFormScreen extends ConsumerStatefulWidget {
  final String? groupId;

  /// Curso já escolhido quando se abre "Nova turma" de dentro do curso.
  final String? initialCourseId;

  const StudyGroupFormScreen({super.key, this.groupId, this.initialCourseId});

  @override
  ConsumerState<StudyGroupFormScreen> createState() =>
      _StudyGroupFormScreenState();
}

class _StudyGroupFormScreenState extends ConsumerState<StudyGroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _studyTopicController = TextEditingController();
  final _meetingDayController = TextEditingController();
  final _meetingTimeController = TextEditingController();
  final _meetingLocationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  String? _courseId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isPublic = true;
  StudyGroupStatus _status = StudyGroupStatus.active;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _courseId = widget.initialCourseId;
    if (widget.groupId != null) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    final group = await ref.read(
      studyGroupByIdProvider(widget.groupId!).future,
    );
    if (group != null && mounted) {
      setState(() {
        _nameController.text = group.name;
        _descriptionController.text = group.description ?? '';
        _studyTopicController.text = group.studyTopic ?? '';
        _meetingDayController.text = group.meetingDay ?? '';
        _meetingTimeController.text = group.meetingTime ?? '';
        _meetingLocationController.text = group.meetingLocation ?? '';
        _maxParticipantsController.text =
            group.maxParticipants?.toString() ?? '';
        _startDate = group.startDate;
        _endDate = group.endDate;
        _isPublic = group.isPublic;
        _status = group.status;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _studyTopicController.dispose();
    _meetingDayController.dispose();
    _meetingTimeController.dispose();
    _meetingLocationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final requiredPermission = widget.groupId == null
        ? 'study_groups.create'
        : 'study_groups.edit';
    final hasPermission = await ref.read(
      currentUserHasPermissionProvider(requiredPermission).future,
    );
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para esta ação'),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(studyGroupActionsProvider);

      String? createdRoute;
      if (widget.groupId == null) {
        // Toda turma nasce num curso (Etapa 7).
        final courseId = _courseId!;
        final group = await actions.createGroup(
          courseId: courseId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          studyTopic: _studyTopicController.text.trim().isEmpty
              ? null
              : _studyTopicController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          meetingDay: _meetingDayController.text.trim().isEmpty
              ? null
              : _meetingDayController.text.trim(),
          meetingTime: _meetingTimeController.text.trim().isEmpty
              ? null
              : _meetingTimeController.text.trim(),
          meetingLocation: _meetingLocationController.text.trim().isEmpty
              ? null
              : _meetingLocationController.text.trim(),
          maxParticipants: _maxParticipantsController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxParticipantsController.text.trim()),
          isPublic: _isPublic,
        );
        createdRoute = '/courses/$courseId/turmas/${group.id}';
      } else {
        // Atualizar grupo existente
        await actions.updateGroup(
          widget.groupId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          studyTopic: _studyTopicController.text.trim().isEmpty
              ? null
              : _studyTopicController.text.trim(),
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          meetingDay: _meetingDayController.text.trim().isEmpty
              ? null
              : _meetingDayController.text.trim(),
          meetingTime: _meetingTimeController.text.trim().isEmpty
              ? null
              : _meetingTimeController.text.trim(),
          meetingLocation: _meetingLocationController.text.trim().isEmpty
              ? null
              : _meetingLocationController.text.trim(),
          maxParticipants: _maxParticipantsController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxParticipantsController.text.trim()),
          isPublic: _isPublic,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.groupId == null
                  ? 'Turma criada com sucesso!'
                  : 'Turma atualizada com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        if (createdRoute != null) {
          context.pushReplacement(createdRoute);
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar turma: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Curso obrigatório na criação. Sem curso elegível, o formulário diz
  /// isso em vez de oferecer uma lista vazia.
  Widget _buildCourseField() {
    final coursesAsync = ref.watch(allCoursesProvider);
    return coursesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Row(
        children: [
          const Expanded(child: Text('Não foi possível carregar os cursos.')),
          TextButton(
            onPressed: () => ref.invalidate(allCoursesProvider),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
      data: (all) {
        final courses = turmaFormSelectableCourses(all);
        if (courses.isEmpty) {
          return const Text(
            'Nenhum curso disponível. Crie um curso antes de abrir uma turma.',
          );
        }
        final selected = courses.any((c) => c.id == _courseId)
            ? _courseId
            : null;
        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Curso *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(AppIcons.study),
          ),
          items: [
            for (final c in courses)
              DropdownMenuItem(
                value: c.id,
                child: Text(c.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _courseId = value),
          validator: (value) => value == null ? 'Escolha o curso' : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId == null ? 'Nova turma' : 'Editar turma'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informações da turma',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (widget.groupId == null) ...[
                    _buildCourseField(),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da turma *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.group),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nome é obrigatório';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _studyTopicController,
                    decoration: const InputDecoration(
                      labelText: 'Tópico de Estudo',
                      hintText: 'Ex: Evangelho de João',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.book),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.description),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encontros',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _meetingDayController,
                    decoration: const InputDecoration(
                      labelText: 'Dia da Reunião',
                      hintText: 'Ex: Quarta-feira',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.calendar),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _meetingTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Horário',
                      hintText: 'Ex: 19:30',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.accessTime),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _meetingLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Local',
                      hintText: 'Ex: Sala 3 - Presencial',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.location),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxParticipantsController,
                    decoration: const InputDecoration(
                      labelText: 'Limite de Participantes',
                      hintText: 'Deixe vazio para sem limite',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.groups),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acesso e status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Turma pública'),
                    subtitle: const Text('Qualquer pessoa pode se inscrever'),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() => _isPublic = value);
                    },
                    secondary: const Icon(AppIcons.public),
                  ),
                  if (widget.groupId != null) ...[
                    const SizedBox(height: 8),
                    DropdownMenu<StudyGroupStatus>(
                      initialSelection: _status,
                      label: const Text('Status'),
                      leadingIcon: const Icon(AppIcons.status),
                      dropdownMenuEntries: StudyGroupStatus.values
                          .map(
                            (status) => DropdownMenuEntry<StudyGroupStatus>(
                              value: status,
                              label: status.displayName,
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            DisabledByPermission(
              permission: widget.groupId == null
                  ? 'study_groups.create'
                  : 'study_groups.edit',
              disabledTooltip: widget.groupId == null
                  ? 'Você não tem permissão para criar turmas'
                  : 'Você não tem permissão para editar turmas',
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _saveGroup,
                icon: const Icon(AppIcons.save),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.groupId == null
                            ? 'Criar turma'
                            : 'Salvar alterações',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
