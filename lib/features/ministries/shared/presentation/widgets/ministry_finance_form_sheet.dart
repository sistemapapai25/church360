import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/pearl_button.dart';
import '../../../../financeiro/domain/models/lancamento.dart';
import '../../domain/ministry_finance.dart';
import '../providers/ministry_finance_providers.dart';

/// Abre o formulário de lançamento do caixa do ministério numa folha
/// inferior. Devolve `true` quando gravou — quem chamou invalida as listas.
Future<bool> showMinistryFinanceFormSheet({
  required BuildContext context,
  required String ministryId,
  required MinistryFinanceCatalog catalog,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _MinistryFinanceFormSheet(ministryId: ministryId, catalog: catalog),
  );
  return saved ?? false;
}

class _MinistryFinanceFormSheet extends ConsumerStatefulWidget {
  final String ministryId;
  final MinistryFinanceCatalog catalog;

  const _MinistryFinanceFormSheet({
    required this.ministryId,
    required this.catalog,
  });

  @override
  ConsumerState<_MinistryFinanceFormSheet> createState() =>
      _MinistryFinanceFormSheetState();
}

class _MinistryFinanceFormSheetState
    extends ConsumerState<_MinistryFinanceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  TipoLancamento _tipo = TipoLancamento.despesa;
  String? _categoriaId;
  String? _beneficiarioId;
  DateTime _data = DateTime.now();
  bool _efetivado = false;
  bool _saving = false;
  String? _error;

  bool get _isSaida => _tipo == TipoLancamento.despesa;

  List<MinistryFinanceOption> get _categorias =>
      widget.catalog.categoriasDe(_tipo);

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  void _trocarTipo(TipoLancamento tipo) {
    setState(() {
      _tipo = tipo;
      // A rubrica de entrada não serve para saída: limpar evita gravar com
      // a categoria do tipo errado só porque ela já estava escolhida.
      _categoriaId = null;
      if (!_isSaida) {
        _beneficiarioId = null;
      } else {
        // Saída nasce pendente e ninguém paga o que não foi aprovado.
        _efetivado = false;
      }
    });
  }

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked != null) setState(() => _data = picked);
  }

  /// Aceita `1.234,56` e `1234.56`. Quem digita valor no Brasil usa a
  /// vírgula, e `double.parse` só entende o ponto.
  double? _parseValor(String raw) {
    final limpo = raw.trim().replaceAll('R\$', '').trim();
    if (limpo.isEmpty) return null;
    final normalizado = limpo.contains(',')
        ? limpo.replaceAll('.', '').replaceAll(',', '.')
        : limpo;
    return double.tryParse(normalizado);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      setState(() => _error = 'Escolha uma categoria.');
      return;
    }
    if (_isSaida && _beneficiarioId == null) {
      setState(
        () => _error =
            'Toda saída precisa de um beneficiário — é regra do banco, '
            'não desta tela.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(ministryFinanceRepositoryProvider);
      await repo.createLancamento(
        ministryId: widget.ministryId,
        tipo: _tipo,
        categoriaId: _categoriaId!,
        beneficiarioId: _isSaida ? _beneficiarioId : null,
        valor: _parseValor(_valor.text)!,
        vencimento: _data,
        descricao: _descricao.text.trim().isEmpty
            ? null
            : _descricao.text.trim(),
        efetivado: _efetivado,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final semCategoria = _categorias.isEmpty;
    final semBeneficiario = widget.catalog.beneficiarios.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.dialogRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.mutedForeground.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Novo lançamento',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                _TipoSelector(tipo: _tipo, onChanged: _trocarTipo),
                if (_isSaida) ...[
                  const SizedBox(height: 12),
                  const _Aviso(
                    'A saída entra como pendente e só conta no caixa depois '
                    'que alguém com permissão de aprovação confirmar.',
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor *',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                  validator: (v) {
                    final valor = _parseValor(v ?? '');
                    if (valor == null) return 'Informe um valor';
                    if (valor <= 0) return 'O valor tem de ser maior que zero';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (semCategoria)
                  _Aviso(
                    'Nenhuma categoria de ${_isSaida ? 'saída' : 'entrada'} '
                    'cadastrada na igreja. Quem cuida do financeiro precisa '
                    'criar a rubrica antes.',
                    erro: true,
                  )
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _categoriaId,
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                    items: [
                      for (final c in _categorias)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _categoriaId = v),
                  ),
                if (_isSaida) ...[
                  const SizedBox(height: 12),
                  if (semBeneficiario)
                    const _Aviso(
                      'Nenhum beneficiário cadastrado na igreja. Toda saída '
                      'precisa de um, e o cadastro é do financeiro.',
                      erro: true,
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _beneficiarioId,
                      decoration: const InputDecoration(
                        labelText: 'Beneficiário *',
                      ),
                      items: [
                        for (final b in widget.catalog.beneficiarios)
                          DropdownMenuItem(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _beneficiarioId = v),
                    ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      suffixIcon: Icon(AppIcons.calendar, size: 18),
                    ),
                    child: Text(dateFormat.format(_data)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descricao,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    alignLabelWithHint: true,
                  ),
                ),
                if (!_isSaida) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _efetivado,
                    onChanged: (v) => setState(() => _efetivado = v),
                    title: const Text('O dinheiro já entrou'),
                    subtitle: const Text(
                      'Marca como recebido na data escolhida.',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PearlButton(
                        color: AppTheme.primary,
                        width: double.infinity,
                        height: 48,
                        onTap: (_saving || semCategoria) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryForeground,
                                ),
                              )
                            : const Text(
                                'Lançar',
                                style: TextStyle(
                                  color: AppTheme.primaryForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrada ou saída, lado a lado. Duas opções não merecem um dropdown: o
/// tipo muda o resto do formulário e precisa estar visível o tempo todo.
class _TipoSelector extends StatelessWidget {
  final TipoLancamento tipo;
  final ValueChanged<TipoLancamento> onChanged;

  const _TipoSelector({required this.tipo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TipoChip(
            label: 'Entrada',
            icon: AppIcons.trendingUp,
            selected: tipo == TipoLancamento.receita,
            onTap: () => onChanged(TipoLancamento.receita),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TipoChip(
            label: 'Saída',
            icon: AppIcons.trendingDown,
            selected: tipo == TipoLancamento.despesa,
            onTap: () => onChanged(TipoLancamento.despesa),
          ),
        ),
      ],
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TipoChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final color = selected ? accent : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.45 : 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;
  final bool erro;

  const _Aviso(this.texto, {this.erro = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = erro
        ? AppTheme.errorColor
        : (dark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(texto, style: TextStyle(fontSize: 12.5, color: color)),
    );
  }
}
