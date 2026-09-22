import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../core/widgets/glass_card.dart';
import '../../../../financeiro/domain/models/lancamento.dart';
import '../../domain/ministry_finance.dart';
import '../providers/ministry_finance_providers.dart';
import 'ministry_finance_form_sheet.dart';

/// Aba Financeiro do workspace: o caixa do departamento.
///
/// Nasce em `shared/` porque é universal — o Batismo é só o primeiro
/// ministério a mostrá-la, e nada aqui conhece batismo.
///
/// O que ela mostra é o recorte `ministry_id = <este ministério>` de
/// `lancamentos`. O livro-caixa da igreja continua nas telas do módulo
/// Financeiro e não aparece aqui, nem o contrário: desde 22/09 as leituras
/// da igreja filtram lançamento de ministério não aprovado
/// (`kLancamentosIgrejaScope`).
class MinistryFinanceTab extends ConsumerWidget {
  final String ministryId;

  const MinistryFinanceTab({super.key, required this.ministryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessAsync = ref.watch(ministryFinanceAccessProvider(ministryId));

    return accessAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _MessagePanel(
        icon: AppIcons.finance,
        title: 'Não deu para verificar suas permissões',
        message: '$error',
        onRetry: () =>
            ref.invalidate(ministryFinanceAccessProvider(ministryId)),
      ),
      data: (access) {
        if (!access.canView) {
          // Estado honesto em vez de lista vazia: sem a permissão em um
          // cargo, ou sem vínculo no ministério, o banco não devolve linha
          // nenhuma e a tela ficaria muda sem dizer por quê.
          return const _MessagePanel(
            icon: AppIcons.finance,
            title: 'Caixa do ministério fechado para você',
            message:
                'Para ver o caixa deste departamento é preciso ter a '
                'permissão "Ver caixa do ministério" em um cargo e estar '
                'vinculado a este ministério. Quem administra o financeiro '
                'da igreja também enxerga.',
          );
        }
        return _MinistryFinanceBody(ministryId: ministryId, access: access);
      },
    );
  }
}

class _MinistryFinanceBody extends ConsumerStatefulWidget {
  final String ministryId;
  final MinistryFinanceAccess access;

  const _MinistryFinanceBody({required this.ministryId, required this.access});

  @override
  ConsumerState<_MinistryFinanceBody> createState() =>
      _MinistryFinanceBodyState();
}

class _MinistryFinanceBodyState extends ConsumerState<_MinistryFinanceBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Lancamento> _apply(List<Lancamento> lancamentos) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return lancamentos;
    return lancamentos.where((l) {
      final campos = [
        l.descricao ?? '',
        l.categoriaNome ?? '',
        l.beneficiarioNome ?? '',
      ];
      return campos.any((c) => c.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _novoLancamento() async {
    final catalog = await ref.read(
      ministryFinanceCatalogProvider(widget.ministryId).future,
    );
    if (!mounted) return;

    final saved = await showMinistryFinanceFormSheet(
      context: context,
      ministryId: widget.ministryId,
      catalog: catalog,
    );
    // Realtime não é habilitado por migration neste banco: sem invalidar na
    // mão, o lançamento recém-criado não apareceria.
    if (saved && mounted) invalidateMinistryFinance(ref, widget.ministryId);
  }

  Future<void> _decidir(Lancamento lancamento, bool aprovado) async {
    try {
      final repo = ref.read(ministryFinanceRepositoryProvider);
      await repo.setApproval(id: lancamento.id, aprovado: aprovado);
      if (!mounted) return;
      invalidateMinistryFinance(ref, widget.ministryId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aprovado ? 'Saída aprovada.' : 'Saída rejeitada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lancamentosAsync = ref.watch(
      ministryFinanceLancamentosProvider(widget.ministryId),
    );

    return lancamentosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _MessagePanel(
        icon: AppIcons.finance,
        title: 'Não deu para carregar o caixa',
        message: '$error',
        onRetry: () => invalidateMinistryFinance(ref, widget.ministryId),
      ),
      data: (todos) {
        // O resumo é de tudo, não do que a busca deixou na tela: saldo que
        // muda quando alguém digita no campo de busca seria mentira.
        final summary = MinistryFinanceSummary.from(todos);
        final visiveis = _apply(todos);
        final pendentes = visiveis.where((l) => l.isPendenteAprovacao).toList();
        final demais = visiveis
            .where((l) => !l.isPendenteAprovacao)
            .toList(growable: false);

        return RefreshIndicator(
          onRefresh: () async {
            invalidateMinistryFinance(ref, widget.ministryId);
            await ref.read(
              ministryFinanceLancamentosProvider(widget.ministryId).future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 14),
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por descrição, rubrica ou beneficiário...',
                onSearchChanged: (v) => setState(() => _query = v),
                primaryAction: widget.access.canCreate
                    ? AppFilterAction(
                        label: 'Novo lançamento',
                        icon: AppIcons.add,
                        onPressed: _novoLancamento,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              if (todos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    widget.access.canCreate
                        ? 'O caixa deste ministério ainda não tem lançamento '
                              'nenhum. Comece por "Novo lançamento".'
                        : 'O caixa deste ministério ainda não tem lançamento '
                              'nenhum.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                )
              else if (visiveis.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nenhum lançamento bate com essa busca.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ),
              if (pendentes.isNotEmpty) ...[
                _SectionLabel('Aguardando aprovação (${pendentes.length})'),
                for (final l in pendentes)
                  _LancamentoTile(
                    lancamento: l,
                    onAprovar: widget.access.canApprove
                        ? () => _decidir(l, true)
                        : null,
                    onRejeitar: widget.access.canApprove
                        ? () => _decidir(l, false)
                        : null,
                  ),
                const SizedBox(height: 20),
              ],
              if (demais.isNotEmpty) ...[
                _SectionLabel('Movimentação (${demais.length})'),
                for (final l in demais) _LancamentoTile(lancamento: l),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Saldo, entradas e saídas do departamento, mais a fila pendente.
class _SummaryCard extends StatelessWidget {
  final MinistryFinanceSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final negativo = summary.saldo < 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo do departamento',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 4),
          Text(
            money.format(summary.saldo),
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: negativo ? AppTheme.errorColor : null,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _SummaryItem(
                icon: AppIcons.trendingUp,
                label: 'entradas',
                value: money.format(summary.entradas),
              ),
              _SummaryItem(
                icon: AppIcons.trendingDown,
                label: 'saídas',
                value: money.format(summary.saidas),
              ),
            ],
          ),
          if (summary.pendentesCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: muted.withValues(alpha: 0.22)),
              ),
              child: Text(
                '${summary.pendentesCount} '
                '${summary.pendentesCount == 1 ? 'saída espera' : 'saídas esperam'} '
                'aprovação — ${money.format(summary.pendentesTotal)} fora do saldo.',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 6),
        Text(
          value,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        Text(label, style: CommunityDesign.metaStyle(context)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }
}

class _LancamentoTile extends StatelessWidget {
  final Lancamento lancamento;
  final VoidCallback? onAprovar;
  final VoidCallback? onRejeitar;

  const _LancamentoTile({
    required this.lancamento,
    this.onAprovar,
    this.onRejeitar,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final date = DateFormat('dd/MM/yyyy');
    final entrada = lancamento.isReceita;
    final cor = entrada ? AppTheme.successColor : AppTheme.errorColor;

    final titulo = lancamento.descricao?.trim().isNotEmpty == true
        ? lancamento.descricao!.trim()
        : (lancamento.categoriaNome ?? 'Lançamento');

    final legenda = [
      date.format(lancamento.vencimento),
      if (lancamento.categoriaNome != null) lancamento.categoriaNome!,
      if (lancamento.beneficiarioNome != null) lancamento.beneficiarioNome!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entrada ? AppIcons.trendingUp : AppIcons.trendingDown,
                  size: 18,
                  color: cor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(legenda, style: CommunityDesign.metaStyle(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${entrada ? '+' : '−'} ${money.format(lancamento.valor)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(
                  label: lancamento.approvalStatus.label,
                  color: switch (lancamento.approvalStatus) {
                    AprovacaoLancamento.aprovado => muted,
                    AprovacaoLancamento.pendente => AppTheme.warningColor,
                    AprovacaoLancamento.rejeitado => AppTheme.errorColor,
                  },
                ),
                _StatusChip(label: lancamento.status.label, color: muted),
              ],
            ),
            if (onAprovar != null || onRejeitar != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onRejeitar != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRejeitar,
                        child: const Text('Rejeitar'),
                      ),
                    ),
                  if (onRejeitar != null && onAprovar != null)
                    const SizedBox(width: 10),
                  if (onAprovar != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: onAprovar,
                        child: const Text('Aprovar'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Painel de estado — sem acesso, erro ou falha de carregamento.
class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
