import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ministries_provider.dart';
import '../../shared/domain/ministry_type_catalog.dart';
import '../../shared/presentation/providers/ministry_type_catalog_providers.dart';
import '../../shared/presentation/widgets/ministry_tabs_settings_card.dart';
import '../../../../core/design/community_design.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/glass_card.dart';

/// Tela de formulário de ministério (criar/editar)
class MinistryFormScreen extends ConsumerStatefulWidget {
  final String? ministryId;

  const MinistryFormScreen({super.key, this.ministryId});

  @override
  ConsumerState<MinistryFormScreen> createState() => _MinistryFormScreenState();
}

class _MinistryFormScreenState extends ConsumerState<MinistryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// A cor saiu do formulário (01/10): fica a do cadastro, e ministério novo
  /// nasce azul.
  String _selectedColor = '0xFF2196F3';

  /// Só vale na criação. Editar o tipo de um ministério que já existe trocaria
  /// as abas debaixo de quem está usando — é assunto da Fase 2, com migração.
  String _ministryType = MinistryTypeCodes.generic;
  bool _isLoading = false;
  final _newFunctionController = TextEditingController();
  Map<String, int> _functionRequirements = {};
  bool _isLoadingFunctions = false;

  @override
  void initState() {
    super.initState();
    if (widget.ministryId != null) {
      _loadMinistry();
      _loadFunctionRequirements();
    }
  }

  Future<void> _loadMinistry() async {
    final ministry = await ref.read(
      ministryByIdProvider(widget.ministryId!).future,
    );
    if (ministry != null && mounted) {
      setState(() {
        _nameController.text = ministry.name;
        _descriptionController.text = ministry.description ?? '';
        _selectedColor = ministry.color;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _newFunctionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ministryId != null;
    // A engrenagem abre para quem é do ministério (ordem das abas). Dados,
    // funções e exclusão continuam de quem edita ministérios.
    final canEdit =
        !isEditing ||
        (ref
                .watch(currentUserHasPermissionProvider('ministries.edit'))
                .valueOrNull ??
            false);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          isEditing ? 'Configurar ministério' : 'Novo Ministério',
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!canEdit)
            const SizedBox.shrink()
          else if (_isLoading)
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
            PermissionGate(
              permission: isEditing ? 'ministries.edit' : 'ministries.create',
              showLoading: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _saveMinistry,
                    icon: const Icon(AppIcons.check, size: 18),
                    label: const Text('Salvar'),
                    style: CommunityDesign.pillButtonStyle(
                      context,
                      Colors.green,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: CommunityDesign.overlayPadding,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (isEditing) ...[
                  MinistryTabsSettingsCard(ministryId: widget.ministryId!),
                  const SizedBox(height: 16),
                ],
                if (canEdit) ...[
                // Dados Básicos
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dados Básicos',
                        style: CommunityDesign.titleStyle(
                          context,
                        ).copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome do Ministério *',
                          hintText: 'Ex: Louvor, Infantil, Jovens',
                          prefixIcon: Icon(AppIcons.church),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nome é obrigatório';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição (opcional)',
                          hintText: 'Descreva o propósito do ministério',
                          prefixIcon: Icon(AppIcons.description),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tipo — só na criação. Ver _ministryType.
                if (widget.ministryId == null) ...[
                  _buildTypeCard(context),
                  const SizedBox(height: 16),
                ],

                if (widget.ministryId != null) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Funções e Quantidades',
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingFunctions)
                          const LinearProgressIndicator()
                        else ...[
                          ..._functionRequirements.entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(child: Text(e.key)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: e.value.toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Qtd',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        final n = int.tryParse(v);
                                        setState(
                                          () => _functionRequirements[e.key] =
                                              (n ?? e.value).clamp(0, 99),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newFunctionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nova função',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () {
                                  final name = _newFunctionController.text
                                      .trim();
                                  if (name.isEmpty) return;
                                  setState(() {
                                    _functionRequirements.putIfAbsent(
                                      name,
                                      () => 1,
                                    );
                                    _newFunctionController.clear();
                                  });
                                },
                                icon: const Icon(AppIcons.add),
                                label: const Text('Adicionar'),
                                style: CommunityDesign.pillButtonStyle(
                                  context,
                                  Theme.of(context).colorScheme.primary,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Preview
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preview',
                        style: CommunityDesign.metaStyle(
                          context,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(_selectedColor),
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              AppIcons.church,
                              color: Color(int.parse(_selectedColor)),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Nome do Ministério'
                                      : _nameController.text,
                                  style: CommunityDesign.titleStyle(
                                    context,
                                  ).copyWith(fontSize: 18),
                                ),
                                if (_descriptionController.text.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _descriptionController.text,
                                    style: CommunityDesign.metaStyle(context),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(height: 24),
                  PermissionGate(
                    permission: 'ministries.delete',
                    showLoading: false,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _deleteMinistry,
                      icon: const Icon(AppIcons.delete),
                      label: const Text('Excluir ministério'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seletor de tipo mais a prévia das abas.
  ///
  /// A prévia existe porque o tipo é a única escolha do formulário que não dá
  /// para desfazer pela tela: ela decide quais abas o ministério abre, e
  /// trocar depois é migração (Fase 2). Mostrar antes evita criar um Batismo
  /// achando que é comum.
  Widget _buildTypeCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final catalog = ref.watch(ministryTypeCatalogSyncProvider);
    final tabs = catalog.tabLabelsFor(_ministryType);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipo do Ministério',
            style: CommunityDesign.titleStyle(context).copyWith(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Define quais abas ele abre. Só dá para escolher agora.',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 12),
          ...catalog.offeredOnCreate.map((type) {
            final isSelected = _ministryType == type.code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _ministryType = type.code),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.label,
                              style: CommunityDesign.contentStyle(context)
                                  .copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type.description,
                              style: CommunityDesign.metaStyle(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Vai abrir com ${tabs.length} abas:',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tabs
                .map(
                  (tab) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tab, style: CommunityDesign.metaStyle(context)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMinistry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(ministriesRepositoryProvider);
      final data = {
        'name': _nameController.text.trim(),
        if (_descriptionController.text.isNotEmpty)
          'description': _descriptionController.text.trim(),
      };

      if (widget.ministryId != null) {
        // Editar
        await repository.updateMinistry(widget.ministryId!, data);
        await _saveFunctionRequirements();
      } else {
        // Criar — pela RPC, para o ministério e o vínculo do líder nascerem
        // juntos. Sem o vínculo, um ministério novo some da lista de quem não
        // tem visão global, inclusive de quem acabou de criá-lo.
        await repository.createMinistryWithLeader(
          name: _nameController.text.trim(),
          ministryType: _ministryType,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          color: _selectedColor,
        );

        // Nasce ativo: a RPC sempre cria assim, e "Ministério ativo" saiu do
        // formulário em 01/10.
      }

      ref.invalidate(allMinistriesProvider);
      ref.invalidate(activeMinistriesProvider);
      // O criador virou líder: a lista dele mudou. Realtime não é habilitado
      // por migration neste banco — invalidar é o que faz a tela ver.
      ref.invalidate(currentMemberMinistriesProvider);
      ref.invalidate(visibleMinistriesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.ministryId != null
                  ? 'Ministério atualizado com sucesso!'
                  : 'Ministério criado com sucesso!',
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
            content: Text('Erro ao salvar ministério: $e'),
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

  /// Excluir é irreversível: pede o nome do ministério digitado antes.
  Future<void> _deleteMinistry() async {
    final name = _nameController.text.trim();
    final typed = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Excluir ministério?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Isto não pode ser desfeito. Saem junto a equipe, as escalas, '
                'os cargos e funções do ministério e tudo o que é só dele. '
                'Cursos continuam, sem o vínculo; lançamentos financeiros '
                'ficam no caixa geral.',
              ),
              const SizedBox(height: 16),
              Text('Digite "$name" para confirmar:'),
              const SizedBox(height: 8),
              TextField(
                controller: typed,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: typed.text.trim() == name
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(ministriesRepositoryProvider)
          .deleteMinistry(widget.ministryId!);
      ref.invalidate(allMinistriesProvider);
      ref.invalidate(activeMinistriesProvider);
      ref.invalidate(currentMemberMinistriesProvider);
      ref.invalidate(visibleMinistriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ministério excluído.'),
          backgroundColor: Colors.green,
        ),
      );
      // O workspace do ministério apagado está na pilha: voltar cairia nele.
      context.go('/ministries');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir ministério: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadFunctionRequirements() async {
    setState(() => _isLoadingFunctions = true);
    try {
      final contexts = await ref
          .read(roleContextsRepositoryProvider)
          .getContextsByMinistry(widget.ministryId!);
      final Map<String, int> merged = {};
      for (final c in contexts) {
        final meta = c.metadata ?? {};
        final req = meta['function_requirements'];
        if (req is Map) {
          req.forEach((k, v) {
            final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
            if (n > 0) merged[k.toString()] = n;
          });
        }
        final funcs = meta['functions'];
        if (funcs is List) {
          for (final f in funcs) {
            merged.putIfAbsent(f.toString(), () => 1);
          }
        }
      }
      setState(() => _functionRequirements = merged);
    } catch (_) {
      setState(() => _functionRequirements = {});
    } finally {
      setState(() => _isLoadingFunctions = false);
    }
  }

  Future<void> _saveFunctionRequirements() async {
    try {
      final contexts = await ref
          .read(roleContextsRepositoryProvider)
          .getContextsByMinistry(widget.ministryId!);
      for (final c in contexts) {
        final meta = Map<String, dynamic>.from(c.metadata ?? {});
        final funcs = Set<String>.from(
          (meta['functions'] as List?)?.map((e) => e.toString()) ?? const [],
        );
        funcs.addAll(_functionRequirements.keys);
        meta['functions'] = funcs.toList();
        meta['function_requirements'] = _functionRequirements;
        await ref
            .read(roleContextsRepositoryProvider)
            .updateContext(contextId: c.id, metadata: meta);
      }
    } catch (e) {
      debugPrint('Falha ao salvar requisitos de função: $e');
    }
  }
}
