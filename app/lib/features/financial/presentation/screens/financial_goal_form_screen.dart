import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/contribution.dart';
import '../providers/financial_provider.dart';

/// Tela de formulário de meta financeira
class FinancialGoalFormScreen extends ConsumerStatefulWidget {
  final String? goalId;

  const FinancialGoalFormScreen({
    super.key,
    this.goalId,
  });

  @override
  ConsumerState<FinancialGoalFormScreen> createState() =>
      _FinancialGoalFormScreenState();
}

class _FinancialGoalFormScreenState
    extends ConsumerState<FinancialGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.goalId != null) {
      _loadGoal();
    }
  }

  Future<void> _loadGoal() async {
    final goal = await ref.read(goalByIdProvider(widget.goalId!).future);

    if (goal != null && mounted) {
      setState(() {
        _nameController.text = goal.name;
        _descriptionController.text = goal.description ?? '';
        _targetAmountController.text = goal.targetAmount.toStringAsFixed(2);
        _currentAmountController.text = goal.currentAmount.toStringAsFixed(2);
        _startDate = goal.startDate;
        _endDate = goal.endDate;
        _isActive = goal.isActive;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Se a data final for antes da data inicial, ajusta
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
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
      final targetAmount =
          double.parse(_targetAmountController.text.replaceAll(',', '.'));
      final currentAmount =
          double.parse(_currentAmountController.text.replaceAll(',', '.'));

      final data = {
        'name': _nameController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'start_date': _startDate.toIso8601String().split('T')[0],
        'end_date': _endDate.toIso8601String().split('T')[0],
        'is_active': _isActive,
      };

      if (widget.goalId == null) {
        await repository.createGoal(data);
      } else {
        await repository.updateGoal(widget.goalId!, data);
      }

      // Invalidar providers
      ref.invalidate(allGoalsProvider);
      ref.invalidate(activeGoalsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.goalId == null
                  ? 'Meta criada com sucesso!'
                  : 'Meta atualizada com sucesso!',
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
            content: Text('Erro ao salvar meta: $e'),
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
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.goalId == null ? 'Nova Meta Financeira' : 'Editar Meta',
        ),
        actions: [
          if (widget.goalId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteGoal,
            ),
        ],
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
                labelText: 'Nome da Meta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
                hintText: 'Ex: Reforma do Templo',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o nome da meta';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Descreva os detalhes da meta',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Valor Alvo
            TextFormField(
              controller: _targetAmountController,
              decoration: const InputDecoration(
                labelText: 'Valor Alvo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: 'R\$ ',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o valor alvo';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Valor Atual
            TextFormField(
              controller: _currentAmountController,
              decoration: const InputDecoration(
                labelText: 'Valor Arrecadado Atual',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.savings),
                prefixText: 'R\$ ',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o valor atual';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount < 0) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Data de Início
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data de Início'),
              subtitle: Text(
                dateFormatter.format(_startDate),
                style: const TextStyle(fontSize: 16),
              ),
              leading: const Icon(Icons.calendar_today),
              trailing: const Icon(Icons.edit),
              onTap: _selectStartDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),

            // Data Final
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Final'),
              subtitle: Text(
                dateFormatter.format(_endDate),
                style: const TextStyle(fontSize: 16),
              ),
              leading: const Icon(Icons.event),
              trailing: const Icon(Icons.edit),
              onTap: _selectEndDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),

            // Status Ativo/Inativo
            SwitchListTile(
              title: const Text('Meta Ativa'),
              subtitle: Text(
                _isActive
                    ? 'A meta está ativa e visível'
                    : 'A meta está inativa',
              ),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              secondary: Icon(
                _isActive ? Icons.check_circle : Icons.cancel,
                color: _isActive ? Colors.green : Colors.grey,
              ),
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
                widget.goalId == null ? 'Criar Meta' : 'Salvar Alterações',
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

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente excluir esta meta financeira?'),
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
      await repository.deleteGoal(widget.goalId!);

      ref.invalidate(allGoalsProvider);
      ref.invalidate(activeGoalsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meta excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir meta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

