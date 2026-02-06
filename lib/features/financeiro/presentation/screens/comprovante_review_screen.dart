import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/beneficiario.dart';
import '../../domain/models/categoria.dart';
import '../../domain/models/conta_financeira.dart';
import '../../domain/models/financial_attachment.dart';
import '../../domain/models/lancamento.dart';
import '../providers/financial_attachments_providers.dart';
import '../providers/financeiro_providers.dart';
import '../widgets/comprovante_preview_widget.dart';
import '../widgets/confidence_badge_widget.dart';
import '../widgets/financeiro_quick_create.dart';

/// Tela de revisão de comprovante com dados extraídos pela IA
class ComprovanteReviewScreen extends ConsumerStatefulWidget {
  final String attachmentId;

  const ComprovanteReviewScreen({
    super.key,
    required this.attachmentId,
  });

  @override
  ConsumerState<ComprovanteReviewScreen> createState() =>
      _ComprovanteReviewScreenState();
}

class _ComprovanteReviewScreenState
    extends ConsumerState<ComprovanteReviewScreen> {
  static const _financialGreen = Color(0xFF1D6E45);
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Form fields
  String _tipo = 'despesa';
  DateTime? _vencimento;
  String? _beneficiarioId;
  String? _categoriaId;
  String? _contaId;
  String? _formaPagamento;

  bool _isSaving = false;
  bool _hasPrefilled = false;
  int _refreshCount = 0;

  TipoCategoria get _categoriaTipo =>
      _tipo == 'receita' ? TipoCategoria.receita : TipoCategoria.despesa;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _observacoesController.dispose();
    super.dispose();
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
    final attachmentAsync =
        ref.watch(attachmentByIdProvider(widget.attachmentId));

    return Theme(
      data: CommunityDesign.getTheme(context),
      child: Scaffold(
        backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Revisar Comprovante'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            // Botão de debug para forçar refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recarregar dados',
              onPressed: () {
                setState(() {
                  _hasPrefilled = false;
                  _refreshCount = 0;
                });
                ref.invalidate(attachmentByIdProvider(widget.attachmentId));
              },
            ),
          ],
        ),
        body: attachmentAsync.when(
          data: (attachment) {
            if (attachment == null) {
              return const Center(child: Text('Comprovante não encontrado'));
            }

            // Auto-refresh if still processing and haven't refreshed too many times
            if (attachment.status == AttachmentStatus.processing && _refreshCount < 10) {
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() => _refreshCount++);
                  ref.invalidate(attachmentByIdProvider(widget.attachmentId));
                }
              });
            }

            // Preencher campos quando tiver dados (suggested OU extracted)
            final hasData = attachment.suggestedTransactionJson != null ||
                           attachment.extractedJson != null;

            if (!_hasPrefilled && hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _initializeFormFromSuggestion(attachment);
              });
            }

            return _buildContent(attachment);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Erro: $error'),
          ),
        ),
      ),
    );
  }

  void _initializeFormFromSuggestion(FinancialAttachment attachment) {
    if (_hasPrefilled) return;
    _hasPrefilled = true;

    final suggested = attachment.suggestedTransactionJson ?? {};
    final extracted = attachment.extractedJson ?? {};

    // Debug logs
    debugPrint('[ComprovanteReview] Initializing form from suggestion');
    debugPrint('[ComprovanteReview] Suggested: $suggested');
    debugPrint('[ComprovanteReview] Extracted: $extracted');

    final descricao = _stringOrEmpty(
      suggested['descricao'] ?? extracted['recebedor_nome'],
    );
    _descricaoController.text = descricao;
    debugPrint('[ComprovanteReview] Descrição: $descricao');

    final valor = _parseValor(suggested['valor'] ?? extracted['valor']);
    if (valor != null) {
      _valorController.text = valor.toStringAsFixed(2);
      debugPrint('[ComprovanteReview] Valor: $valor');
    }

    final vencimento = _parseDate(
      suggested['vencimento'] ?? extracted['data'],
    );
    debugPrint('[ComprovanteReview] Vencimento: $vencimento');

    setState(() {
      _tipo = _normalizeTipo(suggested['tipo']);
      _vencimento = vencimento ?? _vencimento;
      _beneficiarioId = suggested['beneficiario_id'];
      _categoriaId = suggested['categoria_id'];
      _contaId = suggested['conta_id'];
      _formaPagamento = _normalizeFormaPagamento(
        suggested['forma_pagamento'] ?? extracted['tipo_pagamento'],
      );
    });

    debugPrint('[ComprovanteReview] Form initialized successfully');
  }

  String _stringOrEmpty(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  double? _parseValor(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final normalized = raw
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsedIso = DateTime.tryParse(raw);
    if (parsedIso != null) return parsedIso;
    final parts = raw.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  String _normalizeTipo(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return 'despesa';
    final upper = raw.toUpperCase();
    if (upper == 'RECEITA') return 'receita';
    if (upper == 'DESPESA') return 'despesa';
    final lower = raw.toLowerCase();
    if (lower.contains('receita')) return 'receita';
    if (lower.contains('despesa')) return 'despesa';
    return 'despesa';
  }

  String? _normalizeFormaPagamento(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final upper = raw.toUpperCase();
    if (upper.contains('PIX')) return 'PIX';
    if (upper.contains('BOLETO')) return 'BOLETO';
    if (upper.contains('DINHEIRO')) return 'DINHEIRO';
    if (upper.contains('CART')) return 'CARTAO';
    if (upper == 'TED') return 'TRANSFERENCIA';
    if (upper.contains('TRANSF')) return 'TRANSFERENCIA';
    return upper;
  }

  String _tipoToDbValue() {
    return _tipo == 'receita' ? 'RECEITA' : 'DESPESA';
  }

  Widget _buildContent(FinancialAttachment attachment) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 980;

        return Column(
          children: [
            if (attachment.hasMatch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: DuplicateWarningWidget(
                  onViewDuplicate: () {
                    final id = attachment.matchedLancamentoId;
                    if (id == null || id.isEmpty) return;
                    context.push('/financial/lancamentos/$id');
                  },
                ),
              ),
            if (attachment.isProcessing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildProcessingBanner(),
              ),
            if (attachment.hasFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildFailedBanner(attachment),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isDesktop
                      ? _buildDesktopLayout(attachment)
                      : _buildMobileLayout(attachment),
                ),
              ),
            ),
            _buildBottomActions(attachment),
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout(FinancialAttachment attachment) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ComprovantePreviewWidget(attachment: attachment),
                ),
                const SizedBox(height: 16),
                _buildAttachmentMetaCard(attachment),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _buildForm(attachment, allowScroll: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(FinancialAttachment attachment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: ComprovantePreviewWidget(attachment: attachment),
          ),
          const SizedBox(height: 16),
          _buildAttachmentMetaCard(attachment),
          const SizedBox(height: 16),
          _buildForm(attachment, allowScroll: false),
        ],
      ),
    );
  }

  Widget _buildAttachmentMetaCard(FinancialAttachment attachment) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeLabel = _formatMimeType(attachment.mimeType);
    final createdAt = _dateTimeFormat.format(attachment.createdAt.toLocal());
    final statusLabel = _formatStatus(attachment.status);

    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: CommunityDesign.overlayPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Text('Informações do Arquivo',
                  style: CommunityDesign.titleStyle(context)),
            ],
          ),
          const SizedBox(height: 12),
          if (attachment.confidenceScore != null) ...[
            Row(
              children: [
                Text('Confiança geral',
                    style: CommunityDesign.metaStyle(context)),
                const SizedBox(width: 8),
                ConfidenceBadgeWidget(
                  level: attachment.confidenceLevel,
                  score: attachment.confidenceScore,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildMetaRow('Tipo', typeLabel),
          _buildMetaRow('Tamanho', attachment.formattedFileSize),
          _buildMetaRow('Enviado', createdAt),
          _buildMetaRow('Status', statusLabel),
        ],
      ),
    );
  }

  String _formatMimeType(String mimeType) {
    if (mimeType.contains('pdf')) return 'PDF';
    if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
      return 'Imagem JPEG';
    }
    if (mimeType.contains('png')) return 'Imagem PNG';
    return 'Arquivo';
  }

  String _formatStatus(AttachmentStatus status) {
    switch (status) {
      case AttachmentStatus.uploaded:
        return 'Enviado';
      case AttachmentStatus.processing:
        return 'Processando';
      case AttachmentStatus.ready:
        return 'Pronto';
      case AttachmentStatus.failed:
        return 'Falha';
    }
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: CommunityDesign.metaStyle(context),
            ),
          ),
          Text(
            value,
            style: CommunityDesign.contentStyle(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: CommunityDesign.overlayPadding,
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Processando comprovante com IA...',
              style: CommunityDesign.contentStyle(context),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.invalidate(attachmentByIdProvider(widget.attachmentId)),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedBanner(FinancialAttachment attachment) {
    final colorScheme = Theme.of(context).colorScheme;
    final msg = attachment.errorMessage?.trim();
    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: CommunityDesign.overlayPadding,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg?.isNotEmpty == true
                  ? 'Falha ao processar: $msg'
                  : 'Falha ao processar comprovante.',
              style: CommunityDesign.contentStyle(context).copyWith(
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    FinancialAttachment attachment, {
    required bool allowScroll,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final extracted = attachment.extractedJson ?? {};
    final suggested = attachment.suggestedTransactionJson ?? {};

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormHeader(attachment),
          const SizedBox(height: 4),
          Text(
            'Revise e edite os dados antes de confirmar.',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 16),
          _buildExtractedSummary(extracted),
          const SizedBox(height: 16),
          // DEBUG: Mostrar dados brutos
          if (extracted.isNotEmpty || suggested.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔍 DEBUG - Dados Recebidos:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (extracted.isNotEmpty) ...[
                    Text('Extracted JSON:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(extracted.toString(), style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 4),
                  ],
                  if (suggested.isNotEmpty) ...[
                    Text('Suggested JSON:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(suggested.toString(), style: const TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
          _buildFieldLabel(
            'Tipo',
            hasAiSuggestion: suggested['tipo'] != null,
            required: true,
          ),
          _buildTipoSelector(),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Descrição',
            hasAiSuggestion: extracted['recebedor_nome'] != null ||
                suggested['descricao'] != null,
            required: true,
          ),
          TextFormField(
            controller: _descricaoController,
            decoration: const InputDecoration(
              hintText: 'Descrição do lançamento',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Valor',
            hasAiSuggestion:
                extracted['valor'] != null || suggested['valor'] != null,
            required: true,
          ),
          TextFormField(
            controller: _valorController,
            decoration: const InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Campo obrigatório';
              }
              final parsed = _parseValor(value);
              if (parsed == null || parsed <= 0) {
                return 'Valor inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Data de Vencimento',
            hasAiSuggestion:
                extracted['data'] != null || suggested['vencimento'] != null,
            required: true,
          ),
          InkWell(
            onTap: () => _selectDate(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _vencimento != null
                    ? _dateFormat.format(_vencimento!)
                    : 'Selecione a data',
                style: TextStyle(
                  color: _vencimento != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Forma de Pagamento',
            hasAiSuggestion: extracted['tipo_pagamento'] != null ||
                suggested['forma_pagamento'] != null,
          ),
          DropdownButtonFormField<String?>(
            key: ValueKey('forma_${_formaPagamento ?? 'none'}'),
            initialValue: _formaPagamento,
            decoration: const InputDecoration(),
            hint: const Text('Selecione'),
            items: const [
              DropdownMenuItem(value: 'PIX', child: Text('PIX')),
              DropdownMenuItem(
                  value: 'TRANSFERENCIA', child: Text('Transferência')),
              DropdownMenuItem(value: 'BOLETO', child: Text('Boleto')),
              DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'CARTAO', child: Text('Cartão')),
            ],
            onChanged: (value) {
              setState(() {
                _formaPagamento = value;
              });
            },
          ),
          const SizedBox(height: 24),
          _buildFieldLabel(
            'Beneficiário',
            hasAiSuggestion: suggested['beneficiario_id'] != null ||
                extracted['recebedor_nome'] != null,
            required: _tipo == 'despesa',
            onAdd: () async {
              final created = await FinanceiroQuickCreate.createBeneficiario(
                context,
                ref,
                initialName: _stringOrEmpty(extracted['recebedor_nome']),
              );
              if (created != null && mounted) {
                setState(() => _beneficiarioId = created.id);
              }
            },
            addLabel: 'Novo',
          ),
          _buildBeneficiarioDropdown(),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Categoria',
            hasAiSuggestion: suggested['categoria_id'] != null,
            required: true,
            onAdd: () async {
              final created = await FinanceiroQuickCreate.createCategoria(
                context,
                ref,
                tipo: _categoriaTipo,
              );
              if (created != null && mounted) {
                setState(() {
                  _categoriaId = created.id;
                  _tipo =
                      created.tipo == TipoCategoria.receita ? 'receita' : 'despesa';
                });
              }
            },
            addLabel: 'Nova',
          ),
          _buildCategoriaDropdown(),
          const SizedBox(height: 16),
          _buildFieldLabel(
            'Conta Financeira',
            hasAiSuggestion: suggested['conta_id'] != null ||
                extracted['conta'] != null,
            onAdd: () async {
              final banco = _stringOrEmpty(extracted['banco']);
              final nomeSugestao = banco.isNotEmpty ? 'Conta $banco' : '';
              final created = await FinanceiroQuickCreate.createConta(
                context,
                ref,
                initialName: nomeSugestao,
                initialInstituicao: banco,
              );
              if (created != null && mounted) {
                setState(() => _contaId = created.id);
              }
            },
            addLabel: 'Nova',
          ),
          _buildContaDropdown(),
          const SizedBox(height: 16),
          _buildFieldLabel('Observações'),
          TextFormField(
            controller: _observacoesController,
            decoration: const InputDecoration(
              hintText: 'Informações adicionais (opcional)',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );

    final body = allowScroll
        ? SingleChildScrollView(child: formContent)
        : formContent;

    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(24),
      child: body,
    );
  }

  Widget _buildFormHeader(FinancialAttachment attachment) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Dados Extraidos',
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
          ),
        ),
        if (attachment.confidenceScore != null)
          ConfidenceBadgeWidget(
            level: attachment.confidenceLevel,
            score: attachment.confidenceScore,
          ),
      ],
    );
  }

  Widget _buildExtractedSummary(Map<String, dynamic> extracted) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <_ExtractedItem>[
      _ExtractedItem(
        label: 'Valor',
        value: _stringOrEmpty(extracted['valor']),
        icon: Icons.payments_outlined,
      ),
      _ExtractedItem(
        label: 'Data',
        value: _stringOrEmpty(extracted['data']),
        icon: Icons.calendar_today_outlined,
      ),
      _ExtractedItem(
        label: 'Favorecido',
        value: _stringOrEmpty(extracted['recebedor_nome']),
        icon: Icons.person_outline,
      ),
      _ExtractedItem(
        label: 'Banco',
        value: _stringOrEmpty(extracted['banco']),
        icon: Icons.account_balance_outlined,
      ),
      _ExtractedItem(
        label: 'Conta',
        value: _stringOrEmpty(extracted['conta']),
        icon: Icons.credit_card,
      ),
      _ExtractedItem(
        label: 'Pagamento',
        value: _stringOrEmpty(extracted['tipo_pagamento']),
        icon: Icons.qr_code_2,
      ),
    ].where((item) => item.value.isNotEmpty).toList();

    // Só mostra o card se tiver dados extraídos
    if (items.isEmpty && extracted.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: Color(0xFF2196F3)),
                const SizedBox(width: 8),
                Text(
                  'IA detectou automaticamente',
                  style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
                ),
                const SizedBox(width: 8),
                const AiSuggestedBadge(),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Text(
              'Processando comprovante...',
              style: CommunityDesign.metaStyle(context),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: 18, color: const Color(0xFF1D6E45)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: CommunityDesign.metaStyle(context),
                      ),
                    ),
                    Text(
                      item.value,
                      style: CommunityDesign.contentStyle(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(
    String label, {
    bool hasAiSuggestion = false,
    bool required = false,
    VoidCallback? onAdd,
    String? addLabel,
  }) {
    final textLabel = required ? '$label *' : label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            textLabel,
            style: CommunityDesign.metaStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (hasAiSuggestion) ...[
            const SizedBox(width: 8),
            const AiSuggestedBadge(),
          ],
          if (onAdd != null) ...[
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: Text(addLabel ?? 'Novo'),
              style: CommunityDesign.pillButtonStyle(
                context,
                Theme.of(context).colorScheme.primary,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTipoOption(
            'Despesa',
            'despesa',
            Icons.arrow_downward,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTipoOption(
            'Receita',
            'receita',
            Icons.arrow_upward,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildTipoOption(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isSelected = _tipo == value;
    return InkWell(
      onTap: () {
        if (_tipo == value) return;
        setState(() {
          _tipo = value;
          _categoriaId = null;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiarioDropdown() {
    final beneficiariosAsync = ref.watch(allBeneficiariosProvider);
    return beneficiariosAsync.when(
      data: (beneficiarios) {
        final sorted = [...beneficiarios]
          ..sort((a, b) => a.name.compareTo(b.name));
        return DropdownButtonFormField<String?>(
          key: ValueKey('beneficiario_${_beneficiarioId ?? 'none'}'),
          initialValue: _beneficiarioId,
          decoration: const InputDecoration(),
          hint: const Text('Selecione'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('-'),
            ),
            ...sorted.map(
              (Beneficiario b) => DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _beneficiarioId = value),
          validator: (value) {
            if (_tipo == 'despesa' && (value == null || value.isEmpty)) {
              return 'Campo obrigatório';
            }
            return null;
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar beneficiários: $e'),
    );
  }

  Widget _buildCategoriaDropdown() {
    final categoriasAsync = ref.watch(categoriasByTipoProvider(_categoriaTipo));
    return categoriasAsync.when(
      data: (categorias) {
        final sorted = [...categorias]
          ..sort((a, b) => a.name.compareTo(b.name));
        return DropdownButtonFormField<String?>(
          key: ValueKey('categoria_${_categoriaId ?? 'none'}'),
          initialValue: _categoriaId,
          decoration: const InputDecoration(),
          hint: const Text('Selecione'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('-'),
            ),
            ...sorted.map(
              (Categoria c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name),
              ),
            ),
          ],
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
      error: (e, _) => Text('Erro ao carregar categorias: $e'),
    );
  }

  Widget _buildContaDropdown() {
    final contasAsync = ref.watch(allContasProvider);
    return contasAsync.when(
      data: (contas) {
        final sorted = [...contas]
          ..sort((a, b) => a.nome.compareTo(b.nome));
        return DropdownButtonFormField<String?>(
          key: ValueKey('conta_${_contaId ?? 'none'}'),
          initialValue: _contaId,
          decoration: const InputDecoration(),
          hint: const Text('Selecione'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('-'),
            ),
            ...sorted.map(
              (ContaFinanceira conta) => DropdownMenuItem<String?>(
                value: conta.id,
                child: Text(conta.nome),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _contaId = value),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro ao carregar contas: $e'),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vencimento ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _vencimento = picked;
      });
    }
  }

  Widget _buildBottomActions(FinancialAttachment attachment) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                    _isSaving ? null : () => _saveAndCreateLancamento(attachment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _financialGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirmar e Salvar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndCreateLancamento(FinancialAttachment attachment) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data de vencimento')),
      );
      return;
    }

    final valor = _parseValor(_valorController.text);
    if (valor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor')),
      );
      return;
    }

    if (_tipo == 'despesa' &&
        (_beneficiarioId == null || _beneficiarioId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ou cadastre um beneficiário'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(lancamentosRepositoryProvider);
      final attachmentsRepo =
          ref.read(financialAttachmentsRepositoryProvider);

      final descricao = _descricaoController.text.trim();
      final observacoes = _observacoesController.text.trim();

      final lancamentoData = {
        'tipo': _tipoToDbValue(),
        'descricao': descricao,
        'valor': valor,
        'vencimento': _vencimento!.toIso8601String().split('T')[0],
        if (_beneficiarioId != null) 'beneficiario_id': _beneficiarioId,
        if (_categoriaId != null) 'categoria_id': _categoriaId,
        if (_contaId != null) 'conta_id': _contaId,
        if (_formaPagamento != null) 'forma_pagamento': _formaPagamento,
        if (observacoes.isNotEmpty) 'observacoes': observacoes,
        'status': StatusLancamento.emAberto.value,
      };

      final lancamento = await repository.createLancamento(lancamentoData);

      await attachmentsRepo.linkToLancamento(
        attachmentId: attachment.id,
        lancamentoId: lancamento.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento criado com sucesso!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _ExtractedItem {
  final String label;
  final String value;
  final IconData icon;

  _ExtractedItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}
