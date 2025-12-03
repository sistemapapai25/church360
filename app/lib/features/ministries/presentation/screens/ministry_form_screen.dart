import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/ministries_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';

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
  
  bool _isActive = true;
  String _selectedColor = '0xFF2196F3'; // Azul padrão
  bool _isLoading = false;
  final _newFunctionController = TextEditingController();
  Map<String, int> _functionRequirements = {};
  bool _isLoadingFunctions = false;

  // Cores disponíveis
  final List<Map<String, dynamic>> _colors = [
    {'name': 'Azul', 'value': '0xFF2196F3'},
    {'name': 'Rosa', 'value': '0xFFE91E63'},
    {'name': 'Roxo', 'value': '0xFF9C27B0'},
    {'name': 'Verde', 'value': '0xFF4CAF50'},
    {'name': 'Laranja', 'value': '0xFFFF9800'},
    {'name': 'Vermelho', 'value': '0xFFFF5722'},
    {'name': 'Ciano', 'value': '0xFF00BCD4'},
    {'name': 'Amarelo', 'value': '0xFFFFC107'},
    {'name': 'Índigo', 'value': '0xFF3F51B5'},
    {'name': 'Teal', 'value': '0xFF009688'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.ministryId != null) {
      _loadMinistry();
      _loadFunctionRequirements();
    }
  }

  Future<void> _loadMinistry() async {
    final ministry = await ref.read(ministryByIdProvider(widget.ministryId!).future);
    if (ministry != null && mounted) {
      setState(() {
        _nameController.text = ministry.name;
        _descriptionController.text = ministry.description ?? '';
        _selectedColor = ministry.color;
        _isActive = ministry.isActive;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Ministério' : 'Novo Ministério'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do Ministério *',
                hintText: 'Ex: Louvor, Infantil, Jovens',
                prefixIcon: Icon(Icons.church),
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

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Descreva o propósito do ministério',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Seletor de cor
            const Text(
              'Cor do Ministério',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((colorData) {
                final colorValue = int.parse(colorData['value'] as String);
                final color = Color(colorValue);
                final isSelected = _selectedColor == colorData['value'];

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorData['value'] as String;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 32,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (widget.ministryId != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Funções e Quantidades',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingFunctions)
                        const LinearProgressIndicator()
                      else ...[
                        ..._functionRequirements.entries.map((e) => Padding(
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
                                        setState(() => _functionRequirements[e.key] = (n ?? e.value).clamp(0, 99));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )),
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
                                final name = _newFunctionController.text.trim();
                                if (name.isEmpty) return;
                                setState(() {
                                  _functionRequirements.putIfAbsent(name, () => 1);
                                  _newFunctionController.clear();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar Função'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Status ativo/inativo
            SwitchListTile(
              title: const Text('Ministério Ativo'),
              subtitle: Text(
                _isActive
                    ? 'Ministério está ativo e visível'
                    : 'Ministério está inativo',
              ),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(int.parse(_selectedColor)).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.church,
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
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_descriptionController.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _descriptionController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
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
            ),
            const SizedBox(height: 32),

            // Botão de salvar
            FilledButton(
              onPressed: _isLoading ? null : _saveMinistry,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEditing ? 'Salvar Alterações' : 'Criar Ministério'),
            ),
          ],
        ),
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
        'color': _selectedColor,
        'is_active': _isActive,
      };

      if (widget.ministryId != null) {
        // Editar
        await repository.updateMinistry(widget.ministryId!, data);
        await _saveFunctionRequirements();
      } else {
        // Criar
        await repository.createMinistry(data);
      }

      ref.invalidate(allMinistriesProvider);
      ref.invalidate(activeMinistriesProvider);

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

  Future<void> _loadFunctionRequirements() async {
    setState(() => _isLoadingFunctions = true);
    try {
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(widget.ministryId!);
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
      final contexts = await ref.read(roleContextsRepositoryProvider).getContextsByMinistry(widget.ministryId!);
      for (final c in contexts) {
        final meta = Map<String, dynamic>.from(c.metadata ?? {});
        final funcs = Set<String>.from((meta['functions'] as List?)?.map((e) => e.toString()) ?? const []);
        funcs.addAll(_functionRequirements.keys);
        meta['functions'] = funcs.toList();
        meta['function_requirements'] = _functionRequirements;
        await ref.read(roleContextsRepositoryProvider).updateContext(
          contextId: c.id,
          metadata: meta,
        );
      }
    } catch (e) {
      debugPrint('Falha ao salvar requisitos de função: $e');
    }
  }
}
