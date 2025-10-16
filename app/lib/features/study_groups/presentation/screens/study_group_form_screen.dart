import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/study_group_provider.dart';
import '../../domain/models/study_group.dart';

class StudyGroupFormScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const StudyGroupFormScreen({super.key, this.groupId});

  @override
  ConsumerState<StudyGroupFormScreen> createState() => _StudyGroupFormScreenState();
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

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isPublic = true;
  StudyGroupStatus _status = StudyGroupStatus.active;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    final group = await ref.read(studyGroupByIdProvider(widget.groupId!).future);
    if (group != null && mounted) {
      setState(() {
        _nameController.text = group.name;
        _descriptionController.text = group.description ?? '';
        _studyTopicController.text = group.studyTopic ?? '';
        _meetingDayController.text = group.meetingDay ?? '';
        _meetingTimeController.text = group.meetingTime ?? '';
        _meetingLocationController.text = group.meetingLocation ?? '';
        _maxParticipantsController.text = group.maxParticipants?.toString() ?? '';
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

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(studyGroupActionsProvider);

      if (widget.groupId == null) {
        // Criar novo grupo
        await actions.createGroup(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          studyTopic: _studyTopicController.text.trim().isEmpty ? null : _studyTopicController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          meetingDay: _meetingDayController.text.trim().isEmpty ? null : _meetingDayController.text.trim(),
          meetingTime: _meetingTimeController.text.trim().isEmpty ? null : _meetingTimeController.text.trim(),
          meetingLocation: _meetingLocationController.text.trim().isEmpty ? null : _meetingLocationController.text.trim(),
          maxParticipants: _maxParticipantsController.text.trim().isEmpty ? null : int.tryParse(_maxParticipantsController.text.trim()),
          isPublic: _isPublic,
        );
      } else {
        // Atualizar grupo existente
        await actions.updateGroup(
          widget.groupId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          studyTopic: _studyTopicController.text.trim().isEmpty ? null : _studyTopicController.text.trim(),
          status: _status,
          startDate: _startDate,
          endDate: _endDate,
          meetingDay: _meetingDayController.text.trim().isEmpty ? null : _meetingDayController.text.trim(),
          meetingTime: _meetingTimeController.text.trim().isEmpty ? null : _meetingTimeController.text.trim(),
          meetingLocation: _meetingLocationController.text.trim().isEmpty ? null : _meetingLocationController.text.trim(),
          maxParticipants: _maxParticipantsController.text.trim().isEmpty ? null : int.tryParse(_maxParticipantsController.text.trim()),
          isPublic: _isPublic,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.groupId == null ? 'Grupo criado com sucesso!' : 'Grupo atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar grupo: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId == null ? 'Novo Grupo' : 'Editar Grupo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Grupo *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Tópico de Estudo
            TextFormField(
              controller: _studyTopicController,
              decoration: const InputDecoration(
                labelText: 'Tópico de Estudo',
                hintText: 'Ex: Evangelho de João',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Dia da Reunião
            TextFormField(
              controller: _meetingDayController,
              decoration: const InputDecoration(
                labelText: 'Dia da Reunião',
                hintText: 'Ex: Quarta-feira',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Horário
            TextFormField(
              controller: _meetingTimeController,
              decoration: const InputDecoration(
                labelText: 'Horário',
                hintText: 'Ex: 19:30',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Local
            TextFormField(
              controller: _meetingLocationController,
              decoration: const InputDecoration(
                labelText: 'Local',
                hintText: 'Ex: Sala 3 - Presencial',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Limite de Participantes
            TextFormField(
              controller: _maxParticipantsController,
              decoration: const InputDecoration(
                labelText: 'Limite de Participantes',
                hintText: 'Deixe vazio para sem limite',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),
            
            // Público/Privado
            SwitchListTile(
              title: const Text('Grupo Público'),
              subtitle: const Text('Qualquer pessoa pode se inscrever'),
              value: _isPublic,
              onChanged: (value) {
                setState(() => _isPublic = value);
              },
            ),
            
            const SizedBox(height: 16),
            
            // Status (apenas ao editar)
            if (widget.groupId != null) ...[
              DropdownButtonFormField<StudyGroupStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                items: StudyGroupStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 24),
            
            // Botão Salvar
            FilledButton(
              onPressed: _isLoading ? null : _saveGroup,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.groupId == null ? 'Criar Grupo' : 'Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}

