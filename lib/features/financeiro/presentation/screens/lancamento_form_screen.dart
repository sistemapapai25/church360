// =====================================================
// CHURCH 360 - LANÇAMENTO FORM SCREEN
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/financeiro_providers.dart';
import '../../domain/models/lancamento.dart';
import '../../domain/models/categoria.dart';
import '../../domain/models/financial_attachment.dart';
import '../widgets/comprovante_upload_widget.dart';
import '../widgets/financeiro_quick_create.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

class LancamentoFormScreen extends ConsumerStatefulWidget {
  final String? lancamentoId;

  const LancamentoFormScreen({super.key, this.lancamentoId});

  @override
  ConsumerState<LancamentoFormScreen> createState() => _LancamentoFormScreenState();
}

class _LancamentoFormScreenState extends ConsumerState<LancamentoFormScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // Controllers
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacoesController = TextEditingController();

  // Form values
  TipoLancamento _tipo = TipoLancamento.despesa;
  String? _categoriaId;
  String? _beneficiarioId;
  String? _contaId;
  DateTime _vencimento = DateTime.now();
  FormaPagamento _formaPagamento = FormaPagamento.pix;
  bool _isLoading = false;
  FinancialAttachment? _attachment;
  bool _isRecurring = false;
  String _recurrenceFrequency = 'MONTHLY';
  int _recurrenceInterval = 1;
  int? _recurrenceDayOfMonth;
  DateTime? _recurrenceEndDate;
  List<int> _notifyDaysBefore = const [1, 0];
  String? _responsibleUserId;

  bool get _isEditMode => widget.lancamentoId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadLancamento();
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _loadLancamento() async {
    setState(() => _isLoading = true);
    try {
      final lancamento = await ref.read(lancamentoByIdProvider(widget.lancamentoId!).future);
      if (lancamento != null && mounted) {
        setState(() {
          _descricaoController.text = lancamento.descricao ?? '';
          _valorController.text = lancamento.valor.toStringAsFixed(2);
          _observacoesController.text = lancamento.observacoes ?? '';
          _tipo = lancamento.tipo;
          _categoriaId = lancamento.categoriaId;
          _beneficiarioId = lancamento.beneficiarioId;
          _contaId = lancamento.contaId;
          _vencimento = lancamento.vencimento;
          _formaPagamento = lancamento.formaPagamento ?? FormaPagamento.pix;
          _isRecurring = lancamento.isRecurring;
          _recurrenceFrequency =
              (lancamento.recurrenceFrequency ?? 'MONTHLY').toUpperCase();
          _recurrenceInterval = lancamento.recurrenceInterval;
          _recurrenceDayOfMonth = lancamento.recurrenceDayOfMonth;
          _recurrenceEndDate = lancamento.recurrenceEndDate;
          _notifyDaysBefore = lancamento.notifyDaysBefore;
          _responsibleUserId = lancamento.responsibleUserId;
        });
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.transaction_form.load',
          fallbackMessage:
              'Nao foi possivel carregar o lancamento. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/financial/lancamentos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: Text(_isEditMode ? 'Editar Lançamento' : 'Novo Lançamento'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTipoSelector(),
                          const SizedBox(height: 16),
                          _buildDescricaoField(),
                          const SizedBox(height: 16),
                          _buildValorField(),
                          const SizedBox(height: 16),
                          _buildCategoriaDropdown(),
                          const SizedBox(height: 16),
                          _buildBeneficiarioDropdown(),
                          const SizedBox(height: 16),
                          _buildContaDropdown(),
                          const SizedBox(height: 16),
                          _buildVencimentoField(),
                          const SizedBox(height: 16),
                          _buildFormaPagamentoDropdown(),
                          const SizedBox(height: 16),
                          _buildRecurringSection(),
                          const SizedBox(height: 16),
                          _buildObservacoesField(),
                          const SizedBox(height: 16),
                          ComprovanteUploadWidget(
                            existingAttachment: _attachment,
                            onUploadComplete: (attachment) {
                              setState(() => _attachment = attachment);
                            },
                            onRemove: () {
                              setState(() => _attachment = null);
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTipoOption(TipoLancamento.despesa, 'Despesa', Icons.arrow_downward, Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTipoOption(TipoLancamento.receita, 'Receita', Icons.arrow_upward, Colors.green),
        ),
      ],
    );
  }

  Widget _buildTipoOption(TipoLancamento tipo, String label, IconData icon, Color color) {
    final isSelected = _tipo == tipo;

    return InkWell(
      onTap: () => setState(() => _tipo = tipo),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescricaoField() {
    return TextFormField(
      controller: _descricaoController,
      decoration: const InputDecoration(
        labelText: 'Descrição',
        hintText: 'Ex: Conta de luz',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Campo obrigatório';
        }
        return null;
      },
    );
  }

  Widget _buildValorField() {
    return TextFormField(
      controller: _valorController,
      decoration: const InputDecoration(
        labelText: 'Valor',
        hintText: '0,00',
        prefixText: 'R\$ ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Campo obrigatório';
        }
        final valor = double.tryParse(value);
        if (valor == null || valor <= 0) {
          return 'Valor inválido';
        }
        return null;
      },
    );
  }

  Widget _buildCategoriaDropdown() {
    final categoriasAsync = ref.watch(categoriasByTipoProvider(_tipo == TipoLancamento.despesa
        ? TipoCategoria.despesa
        : TipoCategoria.receita));

    return categoriasAsync.when(
      data: (categorias) {
        final tipoCategoria =
            _tipo == TipoLancamento.despesa ? TipoCategoria.despesa : TipoCategoria.receita;
        final selectedCategoriaId = (categorias.any((c) => c.id == _categoriaId))
            ? _categoriaId
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedCategoriaId,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                    ),
                    items: categorias.map((categoria) {
                      return DropdownMenuItem(
                        value: categoria.id,
                        child: Text(categoria.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _categoriaId = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Campo obrigatório';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Criar categoria',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final created = await FinanceiroQuickCreate.createCategoria(
                      context,
                      ref,
                      tipo: tipoCategoria,
                    );
                    if (created == null || !mounted) return;
                    setState(() {
                      _categoriaId = created.id;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Editar categorias',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: selectedCategoriaId == null
                      ? null
                      : () async {
                          final current =
                              categorias.firstWhere((c) => c.id == selectedCategoriaId);
                          final updated =
                              await FinanceiroQuickCreate.editCategoria(
                            context,
                            ref,
                            categoria: current,
                            fixedTipo: tipoCategoria,
                          );
                          if (updated == null || !mounted) return;
                          setState(() => _categoriaId = updated.id);
                        },
                ),
              ],
            ),
            if (categorias.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nenhuma categoria cadastrada. Clique em + para criar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar categorias: $e'),
    );
  }

  Widget _buildBeneficiarioDropdown() {
    final beneficiariosAsync = ref.watch(allBeneficiariosProvider);

    return beneficiariosAsync.when(
      data: (beneficiarios) {
        final selectedBeneficiarioId =
            (beneficiarios.any((b) => b.id == _beneficiarioId))
                ? _beneficiarioId
                : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedBeneficiarioId,
                    decoration: const InputDecoration(
                      labelText: 'Beneficiário',
                    ),
                    items: beneficiarios.map((beneficiario) {
                      return DropdownMenuItem(
                        value: beneficiario.id,
                        child: Text(beneficiario.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _beneficiarioId = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Criar beneficiário',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final created = await FinanceiroQuickCreate.createBeneficiario(
                      context,
                      ref,
                    );
                    if (created == null || !mounted) return;
                    setState(() {
                      _beneficiarioId = created.id;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Editar beneficiário',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: selectedBeneficiarioId == null
                      ? null
                      : () async {
                          final current = beneficiarios.firstWhere(
                            (b) => b.id == selectedBeneficiarioId,
                          );
                          final updated =
                              await FinanceiroQuickCreate.editBeneficiario(
                            context,
                            ref,
                            beneficiario: current,
                          );
                          if (updated == null || !mounted) return;
                          setState(() => _beneficiarioId = updated.id);
                        },
                ),
              ],
            ),
            if (beneficiarios.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nenhum beneficiário cadastrado. Clique em + para criar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar beneficiários: $e'),
    );
  }

  Widget _buildContaDropdown() {
    final contasAsync = ref.watch(allContasProvider);

    return contasAsync.when(
      data: (contas) {
        final selectedContaId =
            (contas.any((c) => c.id == _contaId)) ? _contaId : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedContaId,
                    decoration: const InputDecoration(
                      labelText: 'Conta',
                    ),
                    items: contas.map((conta) {
                      return DropdownMenuItem(
                        value: conta.id,
                        child: Text(conta.nome),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _contaId = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Criar conta',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final created = await FinanceiroQuickCreate.createConta(
                      context,
                      ref,
                    );
                    if (created == null || !mounted) return;
                    setState(() {
                      _contaId = created.id;
                    });
                  },
                ),
                IconButton(
                  tooltip: 'Editar conta',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: selectedContaId == null
                      ? null
                      : () async {
                          final current =
                              contas.firstWhere((c) => c.id == selectedContaId);
                          final updated =
                              await FinanceiroQuickCreate.editConta(
                            context,
                            ref,
                            conta: current,
                          );
                          if (updated == null || !mounted) return;
                          setState(() => _contaId = updated.id);
                        },
                ),
              ],
            ),
            if (contas.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nenhuma conta cadastrada. Clique em + para criar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar contas: $e'),
    );
  }

  Widget _buildVencimentoField() {
    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Vencimento',
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateFormat.format(_vencimento)),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFormaPagamentoDropdown() {
    return DropdownButtonFormField<FormaPagamento>(
      initialValue: _formaPagamento,
      decoration: const InputDecoration(
        labelText: 'Forma de Pagamento',
      ),
      items: FormaPagamento.values.map((forma) {
        return DropdownMenuItem(
          value: forma,
          child: Text(forma.label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _formaPagamento = value);
        }
      },
    );
  }

  Widget _buildRecurringSection() {
    final membersAsync = ref.watch(activeMembersProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lançamento fixo (recorrente)'),
            subtitle: const Text('Habilita lembretes e recorrência mensal/semanal/anual.'),
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
          ),
          if (!_isRecurring) const SizedBox.shrink() else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _recurrenceFrequency,
                    decoration: const InputDecoration(labelText: 'Frequência'),
                    items: const [
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Mensal')),
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Semanal')),
                      DropdownMenuItem(value: 'YEARLY', child: Text('Anual')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _recurrenceFrequency = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: _recurrenceInterval.toString(),
                    decoration: const InputDecoration(labelText: 'Intervalo'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null || parsed < 1) return;
                      _recurrenceInterval = parsed;
                    },
                  ),
                ),
              ],
            ),
            if (_recurrenceFrequency == 'MONTHLY') ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: (_recurrenceDayOfMonth ?? _vencimento.day).toString(),
                decoration: const InputDecoration(
                  labelText: 'Dia do mês',
                  helperText: 'Ex: 10 (se o mês não tiver o dia, cai no último dia do mês)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null) return;
                  _recurrenceDayOfMonth = parsed.clamp(1, 31);
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Lembretes:'),
                const SizedBox(width: 8),
                _buildNotifyChip(7, '7d'),
                const SizedBox(width: 6),
                _buildNotifyChip(3, '3d'),
                const SizedBox(width: 6),
                _buildNotifyChip(1, '1d'),
                const SizedBox(width: 6),
                _buildNotifyChip(0, 'no dia'),
              ],
            ),
            const SizedBox(height: 12),
            membersAsync.when(
              data: (members) {
                final items = members
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.displayName),
                      ),
                    )
                    .toList();
                final initial = items.any((i) => i.value == _responsibleUserId)
                    ? _responsibleUserId
                    : null;
                return DropdownButtonFormField<String>(
                  initialValue: initial,
                  decoration: const InputDecoration(
                    labelText: 'Responsável',
                    helperText: 'Quem recebe os lembretes/notificações',
                  ),
                  items: items,
                  onChanged: (v) => setState(() => _responsibleUserId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar responsáveis: $e'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotifyChip(int day, String label) {
    final selected = _notifyDaysBefore.contains(day);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          final next = [..._notifyDaysBefore];
          if (v) {
            if (!next.contains(day)) next.add(day);
          } else {
            next.remove(day);
          }
          next.sort((a, b) => b.compareTo(a));
          _notifyDaysBefore = next.isEmpty ? [1, 0] : next;
        });
      },
    );
  }

  Widget _buildObservacoesField() {
    return TextFormField(
      controller: _observacoesController,
      decoration: const InputDecoration(
        labelText: 'Observações',
        hintText: 'Informações adicionais (opcional)',
      ),
      maxLines: 3,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveLancamento,
      style: ElevatedButton.styleFrom(
        backgroundColor: _financialGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(_isEditMode ? 'Salvar Alterações' : 'Criar Lançamento'),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && mounted) {
      setState(() => _vencimento = picked);
    }
  }

  Future<void> _saveLancamento() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_categoriaId == null || _categoriaId!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ou cadastre uma categoria para continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_tipo == TipoLancamento.despesa &&
        (_beneficiarioId == null || _beneficiarioId!.trim().isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ou cadastre um beneficiário para a despesa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(lancamentosRepositoryProvider);
      final valor = double.parse(_valorController.text);

      final lancamentoData = {
        'tipo': _tipo.value,
        'descricao': _descricaoController.text,
        'valor': valor,
        'categoria_id': _categoriaId,
        'beneficiario_id': _beneficiarioId,
        'conta_id': _contaId,
        'vencimento': _vencimento.toIso8601String(),
        'forma_pagamento': _formaPagamento.value,
        'observacoes': _observacoesController.text.isEmpty ? null : _observacoesController.text,
        'status': StatusLancamento.emAberto.value,
        'is_recurring': _isRecurring,
        'recurrence_frequency': _isRecurring ? _recurrenceFrequency : null,
        'recurrence_interval': _isRecurring ? _recurrenceInterval : 1,
        'recurrence_day_of_month':
            _isRecurring && _recurrenceFrequency == 'MONTHLY'
                ? (_recurrenceDayOfMonth ?? _vencimento.day)
                : null,
        'recurrence_end_date': _recurrenceEndDate?.toIso8601String(),
        'notify_days_before': _isRecurring ? _notifyDaysBefore : null,
        'responsible_user_id': _isRecurring ? _responsibleUserId : null,
      };

      if (_isEditMode) {
        await repo.updateLancamento(widget.lancamentoId!, lancamentoData);
      } else {
        await repo.createLancamento(lancamentoData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Lançamento atualizado com sucesso!'
                : 'Lançamento criado com sucesso!'),
          ),
        );
        ref.invalidate(allLancamentosProvider);
        ref.invalidate(dashboardDataProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(
          context,
          e,
          feature: 'finance.transaction_form.save',
          fallbackMessage:
              'Nao foi possivel salvar o lancamento. Revise e tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
