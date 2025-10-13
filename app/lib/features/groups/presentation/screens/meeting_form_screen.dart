import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/group_meetings_repository.dart';
import '../providers/meetings_provider.dart';
import '../providers/groups_provider.dart';

/// Tela de formulário de reunião
class MeetingFormScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? meetingId;

  const MeetingFormScreen({
    super.key,
    required this.groupId,
    this.meetingId,
  });

  @override
  ConsumerState<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends ConsumerState<MeetingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.meetingId != null) {
      _loadMeeting();
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMeeting() async {
    final meeting = await ref.read(meetingByIdProvider(widget.meetingId!).future);
    if (meeting != null && mounted) {
      setState(() {
        _topicController.text = meeting.topic ?? '';
        _notesController.text = meeting.notes ?? '';
        _selectedDate = meeting.meetingDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.meetingId != null;
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Reunião' : 'Nova Reunião'),
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Grupo não encontrado'));
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Nome do grupo
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(group.name),
                    subtitle: const Text('Grupo'),
                  ),
                ),
                const SizedBox(height: 24),

                // Data da reunião
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Data da Reunião'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    trailing: const Icon(Icons.edit),
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(height: 16),

                // Tópico
                TextFormField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'Tópico/Tema',
                    hintText: 'Ex: Estudo sobre Fé',
                    prefixIcon: Icon(Icons.topic),
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: 16),

                // Notas
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas/Observações',
                    hintText: 'Anotações sobre a reunião...',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  maxLength: 1000,
                ),
                const SizedBox(height: 24),

                // Botão de salvar
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveMeeting,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(isEditing ? 'Salvar Alterações' : 'Criar Reunião'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(groupMeetingsRepositoryProvider);
      final data = {
        'group_id': widget.groupId,
        'meeting_date': _selectedDate.toIso8601String().split('T')[0],
        if (_topicController.text.isNotEmpty) 'topic': _topicController.text.trim(),
        if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
      };

      if (widget.meetingId != null) {
        // Atualizar
        await repository.updateMeeting(widget.meetingId!, data);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reunião atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Criar
        final meeting = await repository.createMeeting(data);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reunião criada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navegar para tela de registrar presença
          context.go('/groups/${widget.groupId}/meetings/${meeting.id}');
          return;
        }
      }

      // Invalidar providers
      ref.invalidate(meetingsListProvider(widget.groupId));
      if (widget.meetingId != null) {
        ref.invalidate(meetingByIdProvider(widget.meetingId!));
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar reunião: $e'),
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
}

