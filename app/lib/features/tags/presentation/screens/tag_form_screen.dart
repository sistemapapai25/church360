import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tags_repository.dart';
import '../providers/tags_provider.dart';

/// Tela de formulário de tag (criar/editar)
class TagFormScreen extends ConsumerStatefulWidget {
  final String? tagId; // null = criar, não-null = editar

  const TagFormScreen({
    super.key,
    this.tagId,
  });

  @override
  ConsumerState<TagFormScreen> createState() => _TagFormScreenState();
}

class _TagFormScreenState extends ConsumerState<TagFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  
  // State
  String _selectedColor = '#2196F3'; // Azul padrão
  bool _isLoading = false;
  bool _isEditMode = false;

  // Cores predefinidas
  final List<String> _predefinedColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#9E9E9E', // Grey
    '#607D8B', // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.tagId != null;
    if (_isEditMode) {
      _loadTag();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadTag() async {
    setState(() => _isLoading = true);
    
    try {
      final tag = await ref.read(tagsRepositoryProvider).getTagById(widget.tagId!);
      
      if (tag != null) {
        _nameController.text = tag.name;
        _categoryController.text = tag.category ?? '';
        _selectedColor = tag.color ?? '#2196F3';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar tag: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Tag' : 'Nova Tag'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nome
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Tag *',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nome é obrigatório';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                        hintText: 'Ex: Ministério, Cargo, Espiritual',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seletor de cor
                    Text(
                      'Cor da Tag',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    
                    // Preview da cor selecionada
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hexToColor(_selectedColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.label, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _nameController.text.isEmpty 
                                  ? 'Preview da Tag' 
                                  : _nameController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid de cores
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _predefinedColors.map((color) {
                        final isSelected = color == _selectedColor;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedColor = color);
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _hexToColor(color),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Botão salvar
                    FilledButton.icon(
                      onPressed: _saveTag,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditMode ? 'Salvar Alterações' : 'Criar Tag'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _hexToColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  Future<void> _saveTag() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'category': _categoryController.text.trim().isEmpty 
            ? null 
            : _categoryController.text.trim(),
        'color': _selectedColor,
      };

      if (_isEditMode) {
        // Atualizar tag existente
        await ref.read(tagsRepositoryProvider).updateTag(widget.tagId!, data);
      } else {
        // Criar nova tag
        await ref.read(tagsRepositoryProvider).createTag(data);
      }

      // Invalidar providers
      ref.invalidate(allTagsProvider);
      if (_isEditMode) {
        ref.invalidate(tagByIdProvider(widget.tagId!));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode 
                ? 'Tag atualizada com sucesso!' 
                : 'Tag criada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar tag: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

