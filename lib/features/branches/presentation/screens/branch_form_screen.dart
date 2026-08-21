import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../../members/domain/models/member.dart';
import '../../../permissions/presentation/widgets/user_search_dialog.dart';
import '../providers/branches_provider.dart';

/// Tela de criação de filial (CHU-289). Só criação — ver/alterar pastor
/// responsável de uma filial já existente ficou fora de escopo desta v1
/// (sem RPC/RLS pra isso hoje).
class BranchFormScreen extends ConsumerStatefulWidget {
  const BranchFormScreen({super.key});

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Member? _selectedPastor;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreateAsync = ref.watch(isMatrizAdminProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Nova Filial',
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            canCreateAsync.maybeWhen(
              data: (canCreate) => canCreate
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _saveFilial,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Salvar'),
                          style: CommunityDesign.pillButtonStyle(
                            context,
                            Colors.green,
                            compact: true,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: ListView(
        padding: CommunityDesign.overlayPadding,
        children: [
          Form(
            key: _formKey,
            child: Container(
              decoration: CommunityDesign.overlayDecoration(
                Theme.of(context).colorScheme,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dados da Filial',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Filial *',
                      hintText: 'Ex: Aparecida de Goiânia (Jd. Tiradentes)',
                      prefixIcon: Icon(Icons.store),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome da filial';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: TextEditingController(
                      text: _selectedPastor == null
                          ? ''
                          : '${_selectedPastor!.firstName} ${_selectedPastor!.lastName}',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Pastor Responsável *',
                      hintText: 'Clique para buscar um usuário',
                      prefixIcon: const Icon(Icons.person_search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _selectedPastor != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _selectedPastor = null);
                              },
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (_selectedPastor == null) {
                        return 'Selecione o pastor responsável';
                      }
                      return null;
                    },
                    readOnly: true,
                    onTap: _showPastorSearchDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPastorSearchDialog() async {
    final selected = await showDialog<Member>(
      context: context,
      builder: (context) => const UserSearchDialog(),
    );

    if (selected != null && mounted) {
      setState(() => _selectedPastor = selected);
    }
  }

  Future<void> _saveFilial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(branchesRepositoryProvider);
      final authUserId = await repo.resolveAuthUserId(_selectedPastor!.id);

      if (authUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Este membro ainda não possui conta criada no Auth. Peça para ele se cadastrar.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      await repo.criarFilial(
        nome: _nameController.text.trim(),
        pastorResponsavelId: authUserId,
      );

      ref.invalidate(myNetworkUnitsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filial criada com sucesso!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar filial: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
