import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/contribution.dart';
import '../providers/financial_provider.dart';

/// Tela de formulário de despesa
class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? expenseId;

  const ExpenseFormScreen({
    super.key,
    this.expenseId,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Categorias sugeridas
  final List<String> _suggestedCategories = [
    'Aluguel',
    'Água',
    'Luz',
    'Internet',
    'Telefone',
    'Material de Limpeza',
    'Material de Escritório',
    'Manutenção',
    'Salários',
    'Impostos',
    'Equipamentos',
    'Transporte',
    'Alimentação',
    'Eventos',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExpense();
    }
  }

  Future<void> _loadExpense() async {
    final expenses = await ref.read(allExpensesProvider.future);
    final expense = expenses.firstWhere((e) => e.id == widget.expenseId);

    if (mounted) {
      setState(() {
        _categoryController.text = expense.category;
        _amountController.text = expense.amount.toStringAsFixed(2);
        _descriptionController.text = expense.description;
        _notesController.text = expense.notes ?? '';
        _selectedPaymentMethod = expense.paymentMethod;
        _selectedDate = expense.date;
      });
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
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
        'category': _categoryController.text,
        'amount': amount,
        'payment_method': _selectedPaymentMethod.value,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'description': _descriptionController.text,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      if (widget.expenseId == null) {
        await repository.createExpense(data);
      } else {
        await repository.updateExpense(widget.expenseId!, data);
      }

      // Invalidar providers
      ref.invalidate(allExpensesProvider);
      ref.invalidate(totalExpensesProvider);
      ref.invalidate(balanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expenseId == null
                  ? 'Despesa criada com sucesso!'
                  : 'Despesa atualizada com sucesso!',
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
            content: Text('Erro ao salvar despesa: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expenseId == null ? 'Nova Despesa' : 'Editar Despesa',
        ),
        actions: [
          if (widget.expenseId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteExpense,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Categoria
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _categoryController.text),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _suggestedCategories;
                }
                return _suggestedCategories.where((category) {
                  return category
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (value) {
                _categoryController.text = value;
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                _categoryController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                    hintText: 'Digite ou selecione uma categoria',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a categoria';
                    }
                    return null;
                  },
                );
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
              value: _selectedPaymentMethod,
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
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe a descrição';
                }
                return null;
              },
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
                widget.expenseId == null ? 'Criar' : 'Salvar',
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

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja realmente excluir esta despesa?'),
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
      await repository.deleteExpense(widget.expenseId!);

      ref.invalidate(allExpensesProvider);
      ref.invalidate(totalExpensesProvider);
      ref.invalidate(balanceProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Despesa excluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir despesa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

