import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../data/visitors_repository.dart';

/// Tela de formulário para follow-up
class VisitorFollowupFormScreen extends ConsumerStatefulWidget {
  final String visitorId;
  final String? followupId;

  const VisitorFollowupFormScreen({
    super.key,
    required this.visitorId,
    this.followupId,
  });

  @override
  ConsumerState<VisitorFollowupFormScreen> createState() => _VisitorFollowupFormScreenState();
}

class _VisitorFollowupFormScreenState extends ConsumerState<VisitorFollowupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _followupTypeController = TextEditingController();

  DateTime _followupDate = DateTime.now();
  bool _completed = false;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.followupId != null;
    if (_isEditMode) {
      _loadFollowup();
    }
  }

  Future<void> _loadFollowup() async {
    final followups = await ref.read(visitorFollowupsProvider(widget.visitorId).future);
    final followup = followups.firstWhere((f) => f.id == widget.followupId);
    
    if (mounted) {
      setState(() {
        _followupDate = followup.followupDate;
        _followupTypeController.text = followup.followupType ?? '';
        _descriptionController.text = followup.description ?? '';
        _completed = followup.completed;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _followupTypeController.dispose();
    super.dispose();
  }

  Future<void> _selectFollowupDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followupDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _followupDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveFollowup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'visitor_id': widget.visitorId,
        'followup_date': _followupDate.toIso8601String().split('T')[0],
        'followup_type': _followupTypeController.text.trim().isEmpty ? null : _followupTypeController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'completed': _completed,
      };

      if (_isEditMode) {
        await ref.read(visitorsRepositoryProvider).updateFollowup(widget.followupId!, data);
      } else {
        await ref.read(visitorsRepositoryProvider).createFollowup(data);
      }

      // Invalidar providers para atualizar a lista
      ref.invalidate(visitorFollowupsProvider(widget.visitorId));
      ref.invalidate(allVisitorsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Follow-up atualizado com sucesso!' : 'Follow-up criado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar follow-up: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorAsync = ref.watch(visitorByIdProvider(widget.visitorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Follow-up' : 'Novo Follow-up'),
      ),
      body: visitorAsync.when(
        data: (visitor) {
          if (visitor == null) {
            return const Center(
              child: Text('Visitante não encontrado'),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Visitante Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visitante',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          visitor.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (visitor.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            visitor.phone!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Data do Follow-up
                InkWell(
                  onTap: _selectFollowupDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do Follow-up *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_formatDate(_followupDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipo de Follow-up
                TextFormField(
                  controller: _followupTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Follow-up',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                    hintText: 'Ex: Ligação, Visita, WhatsApp...',
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
                    hintText: 'Descreva o que será feito neste follow-up...',
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Descrição é obrigatória';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Completado
                SwitchListTile(
                  title: const Text('Follow-up completado?'),
                  subtitle: const Text('Marque se o follow-up já foi realizado'),
                  value: _completed,
                  onChanged: (value) {
                    setState(() {
                      _completed = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Botão Salvar
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveFollowup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEditMode ? 'Atualizar Follow-up' : 'Criar Follow-up'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erro ao carregar visitante: $error'),
        ),
      ),
    );
  }
}

