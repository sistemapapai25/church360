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
import '../../../../core/design/community_design.dart';

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
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar lançamento: $e')),
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
        return DropdownButtonFormField<String>(
          initialValue: _categoriaId,
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
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Erro ao carregar categorias'),
    );
  }

  Widget _buildBeneficiarioDropdown() {
    final beneficiariosAsync = ref.watch(allBeneficiariosProvider);

    return beneficiariosAsync.when(
      data: (beneficiarios) {
        return DropdownButtonFormField<String>(
          initialValue: _beneficiarioId,
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
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Erro ao carregar beneficiários'),
    );
  }

  Widget _buildContaDropdown() {
    final contasAsync = ref.watch(allContasProvider);

    return contasAsync.when(
      data: (contas) {
        return DropdownButtonFormField<String>(
          initialValue: _contaId,
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
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Erro ao carregar contas'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar lançamento: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
