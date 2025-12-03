import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contribution_provider.dart';
import '../../domain/models/contribution_info.dart';

/// Tela de visualização de informações de contribuição (para usuários)
class ContributionInfoScreen extends ConsumerWidget {
  const ContributionInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributionInfoAsync = ref.watch(activeContributionInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contribua'),
        centerTitle: true,
      ),
      body: contributionInfoAsync.when(
        data: (info) {
          if (info == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Informações de contribuição\nnão disponíveis no momento',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeContributionInfoProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          info.churchName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sua contribuição faz a diferença!',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // PIX Section
                if (info.pixKey != null && info.pixKey!.isNotEmpty) ...[
                  _buildSectionTitle(context, 'PIX', Icons.pix),
                  const SizedBox(height: 12),
                  _buildPixCard(context, info),
                  const SizedBox(height: 24),
                ],

                // Bank Transfer Section
                if (_hasBankInfo(info)) ...[
                  _buildSectionTitle(context, 'Transferência Bancária (TED/DOC)', Icons.account_balance),
                  const SizedBox(height: 12),
                  _buildBankInfoCard(context, info),
                  const SizedBox(height: 24),
                ],

                // Instructions Section
                if (info.instructions != null && info.instructions!.isNotEmpty) ...[
                  _buildSectionTitle(context, 'Instruções', Icons.info_outline),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPixCard(BuildContext context, ContributionInfo info) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.pixType != null) ...[
              Row(
                children: [
                  const Icon(Icons.label, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Tipo de Chave:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(info.pixType!),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(Icons.key, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Chave PIX:', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      info.pixKey!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: info.pixKey!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave PIX copiada!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copiar chave PIX',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoCard(BuildContext context, ContributionInfo info) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.bankName != null) ...[
              _buildInfoRow('Banco', info.bankName!, info.bankCode),
              const Divider(),
            ],
            if (info.agency != null) ...[
              _buildInfoRow('Agência', info.agency!, null),
              const Divider(),
            ],
            if (info.accountNumber != null) ...[
              _buildInfoRow('Conta', info.accountNumber!, info.accountType),
              const Divider(),
            ],
            if (info.accountHolder != null) ...[
              _buildInfoRow('Titular', info.accountHolder!, null),
              if (info.accountHolderDocument != null) const Divider(),
            ],
            if (info.accountHolderDocument != null)
              _buildInfoRow('CPF/CNPJ', info.accountHolderDocument!, null),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String? extra) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
                if (extra != null)
                  Text(
                    extra,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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

