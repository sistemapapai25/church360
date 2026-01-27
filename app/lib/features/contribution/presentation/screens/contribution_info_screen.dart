import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contribution_provider.dart';
import '../../domain/models/contribution_info.dart';
import '../../../../core/design/community_design.dart';

/// Tela de visualização de informações de contribuição (para usuários)
class ContributionInfoScreen extends ConsumerWidget {
  const ContributionInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionInfoAsync = ref.watch(activeContributionInfoProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        titleSpacing: 0,
        toolbarHeight: 64,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.volunteer_activism,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contribua', style: CommunityDesign.titleStyle(context)),
                Text(
                  'Informações para doar',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
      ),
      body: contributionInfoAsync.when(
        data: (info) {
          if (info == null) {
            final cs = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: CommunityDesign.overlayDecoration(cs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 56,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Informações de contribuição\nnão disponíveis no momento',
                        textAlign: TextAlign.center,
                        style: CommunityDesign.contentStyle(
                          context,
                        ).copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeContributionInfoProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                // Header
                Container(
                  decoration: CommunityDesign.overlayDecoration(
                    Theme.of(context).colorScheme,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 52,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          info.churchName,
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sua contribuição faz a diferença!',
                          style: CommunityDesign.metaStyle(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PIX Section
                if (info.pixKey != null && info.pixKey!.isNotEmpty) ...[
                  _buildSectionTitle(context, 'PIX', Icons.pix),
                  const SizedBox(height: 12),
                  _buildPixCard(context, info),
                  const SizedBox(height: 24),
                ],

                // Bank Transfer Section
                if (_hasBankInfo(info)) ...[
                  _buildSectionTitle(
                    context,
                    'Transferência Bancária (TED/DOC)',
                    Icons.account_balance,
                  ),
                  const SizedBox(height: 12),
                  _buildBankInfoCard(context, info),
                  const SizedBox(height: 24),
                ],

                // Instructions Section
                if (info.instructions != null &&
                    info.instructions!.isNotEmpty) ...[
                  _buildSectionTitle(context, 'Instruções', Icons.info_outline),
                  const SizedBox(height: 12),
                  Container(
                    decoration: CommunityDesign.overlayDecoration(
                      Theme.of(context).colorScheme,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        info.instructions!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(activeContributionInfoProvider),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildPixCard(BuildContext context, ContributionInfo info) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(cs),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.pixType != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.label,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tipo de chave',
                    style: CommunityDesign.metaStyle(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    info.pixType!,
                    style: CommunityDesign.contentStyle(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.key,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.06),
                      ),
                    ),
                    child: SelectableText(
                      info.pixKey!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: info.pixKey!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave PIX copiada!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  tooltip: 'Copiar chave PIX',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoCard(BuildContext context, ContributionInfo info) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(cs),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.bankName != null) ...[
              _buildInfoRow(context, 'Banco', info.bankName!, info.bankCode),
              Divider(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ],
            if (info.agency != null) ...[
              _buildInfoRow(context, 'Agência', info.agency!, null),
              Divider(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ],
            if (info.accountNumber != null) ...[
              _buildInfoRow(
                context,
                'Conta',
                info.accountNumber!,
                info.accountType,
              ),
              Divider(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ],
            if (info.accountHolder != null) ...[
              _buildInfoRow(context, 'Titular', info.accountHolder!, null),
              if (info.accountHolderDocument != null)
                Divider(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
            ],
            if (info.accountHolderDocument != null)
              _buildInfoRow(
                context,
                'CPF/CNPJ',
                info.accountHolderDocument!,
                null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    String? extra,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: CommunityDesign.authorStyle(context).copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  value,
                  style: CommunityDesign.contentStyle(
                    context,
                  ).copyWith(color: cs.onSurface),
                ),
                if (extra != null)
                  Text(
                    extra,
                    style: CommunityDesign.metaStyle(context).copyWith(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasBankInfo(ContributionInfo info) {
    return (info.bankName != null && info.bankName!.isNotEmpty) ||
        (info.agency != null && info.agency!.isNotEmpty) ||
        (info.accountNumber != null && info.accountNumber!.isNotEmpty);
  }
}
