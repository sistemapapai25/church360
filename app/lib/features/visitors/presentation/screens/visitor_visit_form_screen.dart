import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../../../core/design/community_design.dart';

/// Tela de formulário para registrar visita
class VisitorVisitFormScreen extends ConsumerStatefulWidget {
  final String visitorId;

  const VisitorVisitFormScreen({super.key, required this.visitorId});

  @override
  ConsumerState<VisitorVisitFormScreen> createState() => _VisitorVisitFormScreenState();
}

class _VisitorVisitFormScreenState extends ConsumerState<VisitorVisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  DateTime _visitDate = DateTime.now();
  bool _wasContacted = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveVisit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'visitor_id': widget.visitorId,
        'visit_date': _visitDate.toIso8601String().split('T')[0],
        'was_contacted': _wasContacted,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await ref.read(visitorsRepositoryProvider).createVisit(data);

      // Invalidar providers para atualizar a lista
      ref.invalidate(visitorVisitsProvider(widget.visitorId));
      ref.invalidate(visitorByIdProvider(widget.visitorId));
      ref.invalidate(allVisitorsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita registrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registrar visita: $e'),
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
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          'Registrar Visita',
          style: CommunityDesign.titleStyle(context),
        ),
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

                // Data da Visita
                InkWell(
                  onTap: _selectVisitDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data da Visita *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(_formatDate(_visitDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // Foi Contatado
                SwitchListTile(
                  title: const Text('Foi contatado após a visita?'),
                  subtitle: const Text('Marque se já houve contato com o visitante'),
                  value: _wasContacted,
                  onChanged: (value) {
                    setState(() {
                      _wasContacted = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),

                // Observações
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Adicione observações sobre esta visita...',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),

                // Botão Salvar
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveVisit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Registrar Visita'),
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

