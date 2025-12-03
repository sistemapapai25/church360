import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/contribution_provider.dart';
import '../../domain/models/contribution_info.dart';

/// Tela de gerenciamento de informações de contribuição (para administradores)
class ManageContributionScreen extends ConsumerStatefulWidget {
  const ManageContributionScreen({super.key});

  @override
  ConsumerState<ManageContributionScreen> createState() => _ManageContributionScreenState();
}

class _ManageContributionScreenState extends ConsumerState<ManageContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _churchNameController = TextEditingController();
  final _pixKeyController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankCodeController = TextEditingController();
  final _agencyController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountHolderDocumentController = TextEditingController();
  final _instructionsController = TextEditingController();
  
  String? _pixType;
  String? _accountType;
  bool _isLoading = false;
  String? _contributionInfoId;

  @override
  void dispose() {
    _churchNameController.dispose();
    _pixKeyController.dispose();
    _bankNameController.dispose();
    _bankCodeController.dispose();
    _agencyController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _accountHolderDocumentController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _loadContributionInfo(ContributionInfo? info) {
    if (info != null) {
      _contributionInfoId = info.id;
      _churchNameController.text = info.churchName;
      _pixKeyController.text = info.pixKey ?? '';
      _pixType = info.pixType;
      _bankNameController.text = info.bankName ?? '';
      _bankCodeController.text = info.bankCode ?? '';
      _agencyController.text = info.agency ?? '';
      _accountNumberController.text = info.accountNumber ?? '';
      _accountType = info.accountType;
      _accountHolderController.text = info.accountHolder ?? '';
      _accountHolderDocumentController.text = info.accountHolderDocument ?? '';
      _instructionsController.text = info.instructions ?? '';
    }
  }

  Future<void> _saveContributionInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(contributionRepositoryProvider);
      
      final data = {
        'church_name': _churchNameController.text.trim(),
        'pix_key': _pixKeyController.text.trim().isEmpty ? null : _pixKeyController.text.trim(),
        'pix_type': _pixType,
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        'bank_code': _bankCodeController.text.trim().isEmpty ? null : _bankCodeController.text.trim(),
        'agency': _agencyController.text.trim().isEmpty ? null : _agencyController.text.trim(),
        'account_number': _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
        'account_type': _accountType,
        'account_holder': _accountHolderController.text.trim().isEmpty ? null : _accountHolderController.text.trim(),
        'account_holder_document': _accountHolderDocumentController.text.trim().isEmpty ? null : _accountHolderDocumentController.text.trim(),
        'instructions': _instructionsController.text.trim().isEmpty ? null : _instructionsController.text.trim(),
      };

      if (_contributionInfoId == null) {
        // Criar novo
        await repository.createContributionInfo(data);
      } else {
        // Atualizar existente
        await repository.updateContributionInfo(_contributionInfoId!, data);
      }

      // Invalidar provider
      ref.invalidate(activeContributionInfoProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informações salvas com sucesso!'),
            backgroundColor: Colors.green,
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contributionInfoAsync = ref.watch(activeContributionInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Contribuição'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveContributionInfo,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: contributionInfoAsync.when(
        data: (info) {
          // Carregar dados apenas uma vez
          if (_contributionInfoId == null && info != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadContributionInfo(info);
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Nome da Igreja
                TextFormField(
                  controller: _churchNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Igreja *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.church),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome da igreja é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Seção PIX
                const Text(
                  'Informações PIX',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Tipo de Chave PIX
                DropdownMenu<String>(
                  initialSelection: _pixType,
                  label: const Text('Tipo de Chave PIX'),
                  leadingIcon: const Icon(Icons.pix),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'CPF', label: 'CPF'),
                    DropdownMenuEntry(value: 'CNPJ', label: 'CNPJ'),
                    DropdownMenuEntry(value: 'Email', label: 'Email'),
                    DropdownMenuEntry(value: 'Telefone', label: 'Telefone'),
                    DropdownMenuEntry(value: 'Aleatória', label: 'Chave Aleatória'),
                  ],
                  onSelected: (value) => setState(() => _pixType = value),
                ),
                const SizedBox(height: 16),

                // Chave PIX
                TextFormField(
                  controller: _pixKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Chave PIX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 24),

                // Seção Dados Bancários
                const Text(
                  'Dados Bancários (TED/DOC)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Nome do Banco
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Banco',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                ),
                const SizedBox(height: 16),

                // Código do Banco
                TextFormField(
                  controller: _bankCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Código do Banco',
                    hintText: 'Ex: 001, 237, 341',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Agência
                TextFormField(
                  controller: _agencyController,
                  decoration: const InputDecoration(
                    labelText: 'Agência',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                ),
                const SizedBox(height: 16),

                // Número da Conta
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Número da Conta',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipo de Conta
                DropdownMenu<String>(
                  initialSelection: _accountType,
                  label: const Text('Tipo de Conta'),
                  leadingIcon: const Icon(Icons.account_box),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'Corrente', label: 'Conta Corrente'),
                    DropdownMenuEntry(value: 'Poupança', label: 'Conta Poupança'),
                  ],
                  onSelected: (value) => setState(() => _accountType = value),
                ),
                const SizedBox(height: 16),

                // Titular da Conta
                TextFormField(
                  controller: _accountHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Titular da Conta',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),

                // CPF/CNPJ do Titular
                TextFormField(
                  controller: _accountHolderDocumentController,
                  decoration: const InputDecoration(
                    labelText: 'CPF/CNPJ do Titular',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),

                // Instruções Adicionais
                const Text(
                  'Instruções Adicionais',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instruções',
                    hintText: 'Ex: Favor informar o nome completo ao realizar a contribuição',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 32),

                // Botão Salvar
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveContributionInfo,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Salvando...' : 'Salvar Informações'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
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
}
