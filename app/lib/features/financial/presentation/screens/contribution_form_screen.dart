import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/contribution.dart';
import '../providers/financial_provider.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Tela de formulário de contribuição
class ContributionFormScreen extends ConsumerStatefulWidget {
  final String? contributionId;

  const ContributionFormScreen({
    super.key,
    this.contributionId,
  });

  @override
  ConsumerState<ContributionFormScreen> createState() =>
      _ContributionFormScreenState();
}

class _ContributionFormScreenState
    extends ConsumerState<ContributionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedMemberId;
  ContributionType _selectedType = ContributionType.tithe;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contributionId != null) {
      _loadContribution();
    }
  }

  Future<void> _loadContribution() async {
    final contribution = await ref.read(
      contributionByIdProvider(widget.contributionId!).future,
    );

    if (contribution != null && mounted) {
      setState(() {
        _selectedMemberId = contribution.memberId;
        _selectedType = contribution.type;
        _selectedPaymentMethod = contribution.paymentMethod;
        _selectedDate = contribution.date;
        _amountController.text = contribution.amount.toStringAsFixed(2);
        _descriptionController.text = contribution.description ?? '';
        _notesController.text = contribution.notes ?? '';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(financialRepositoryProvider);
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));

      final data = {
        'member_id': _selectedMemberId,
        'type': _selectedType.value,
        'amount': amount,
        'payment_method': _selectedPaymentMethod.value,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      if (widget.contributionId == null) {
        await repository.createContribution(data);
      } else {
        await repository.updateContribution(widget.contributionId!, data);
      }

      // Invalidar providers
      ref.invalidate(allContributionsProvider);
      ref.invalidate(totalContributionsProvider);
      ref.invalidate(balanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.contributionId == null
                  ? 'Contribuição criada com sucesso!'
                  : 'Contribuição atualizada com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar contribuição: $e'),
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
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contributionId == null
              ? 'Nova Contribuição'
              : 'Editar Contribuição',
        ),
        actions: [
          if (widget.contributionId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteContribution,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Membro
            membersAsync.when(
              data: (members) {
                final activeMembers = members
                    .where((m) => m.status == 'active')
                    .toList();

                return DropdownButtonFormField<String>(
                  initialValue: _selectedMemberId,
                  decoration: const InputDecoration(
                    labelText: 'Membro (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Anônimo'),
                    ),
                    ...activeMembers.map((member) {
                      return DropdownMenuItem(
                        value: member.id,
                        child: Text(member.fullName),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMemberId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),

            // Tipo
            DropdownButtonFormField<ContributionType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: ContributionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Valor
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o valor';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Método de Pagamento
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Método de Pagamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: PaymentMethod.values.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Data
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: const TextStyle(fontSize: 16),
              ),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.edit),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Notas
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                widget.contributionId == null ? 'Criar' : 'Salvar',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContribution() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente excluir esta contribuição?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(financialRepositoryProvider);
      await repository.deleteContribution(widget.contributionId!);

      ref.invalidate(allContributionsProvider);
      ref.invalidate(totalContributionsProvider);
      ref.invalidate(balanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contribuição excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir contribuição: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

