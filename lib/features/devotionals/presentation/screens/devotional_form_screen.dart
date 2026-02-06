import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/devotional_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';

/// Tela de formulário para criar/editar devocional
class DevotionalFormScreen extends ConsumerStatefulWidget {
  final String? devotionalId;

  const DevotionalFormScreen({
    super.key,
    this.devotionalId,
  });

  @override
  ConsumerState<DevotionalFormScreen> createState() => _DevotionalFormScreenState();
}

class _DevotionalFormScreenState extends ConsumerState<DevotionalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _scriptureController = TextEditingController();
  final _preacherController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isPublished = false;
  bool _isLoading = false;
  String? _imageUrl;
  String? _category;

  bool get _isEditing => widget.devotionalId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadDevotional();
    } else {
      _isPublished = true;
    }
  }

  Future<void> _loadDevotional() async {
    setState(() => _isLoading = true);

    try {
      final devotional = await ref.read(devotionalByIdProvider(widget.devotionalId!).future);

      if (devotional != null) {
        _titleController.text = devotional.title;
        _contentController.text = devotional.content;
        _scriptureController.text = devotional.scriptureReference ?? '';
        _preacherController.text = devotional.preacher ?? '';
        _youtubeUrlController.text = devotional.youtubeUrl ?? '';
        _selectedDate = devotional.devotionalDate;
        _isPublished = devotional.isPublished;
        _imageUrl = devotional.imageUrl;
        _category = devotional.category;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar devocional: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scriptureController.dispose();
    _preacherController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final actions = ref.read(devotionalActionsProvider);

      if (_isEditing) {
        await actions.updateDevotional(
          id: widget.devotionalId!,
          title: _titleController.text,
          content: _contentController.text,
          scriptureReference: _scriptureController.text.isEmpty
              ? null
              : _scriptureController.text,
          devotionalDate: _selectedDate,
          isPublished: _isPublished,
          imageUrl: _imageUrl,
          category: _category,
          preacher: _preacherController.text.isEmpty
              ? null
              : _preacherController.text,
          youtubeUrl: _youtubeUrlController.text.isEmpty
              ? null
              : _youtubeUrlController.text,
        );
      } else {
        await actions.createDevotional(
          title: _titleController.text,
          content: _contentController.text,
          scriptureReference: _scriptureController.text.isEmpty
              ? null
              : _scriptureController.text,
          devotionalDate: _selectedDate,
          isPublished: _isPublished,
          imageUrl: _imageUrl,
          category: _category,
          preacher: _preacherController.text.isEmpty
              ? null
              : _preacherController.text,
          youtubeUrl: _youtubeUrlController.text.isEmpty
              ? null
              : _youtubeUrlController.text,
        );
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Devocional atualizado com sucesso!'
                  : 'Devocional criado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se estiver editando, carregar dados
    if (_isEditing) {
      final devotionalAsync = ref.watch(devotionalByIdProvider(widget.devotionalId!));
      
      devotionalAsync.whenData((devotional) {
        if (devotional != null && _titleController.text.isEmpty) {
          _titleController.text = devotional.title;
          _contentController.text = devotional.content;
          _scriptureController.text = devotional.scriptureReference ?? '';
          _selectedDate = devotional.devotionalDate;
          _isPublished = devotional.isPublished;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Devocional' : 'Novo Devocional'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Data do Devocional'),
                subtitle: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year}',
                ),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),
            ),
            const SizedBox(height: 16),

            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Ex: A Fé que Move Montanhas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira um título';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Referência Bíblica
            TextFormField(
              controller: _scriptureController,
              decoration: const InputDecoration(
                labelText: 'Referência Bíblica',
                hintText: 'Ex: João 3:16-17',
                helperText: "Use ':' entre capítulo e versículo e '-' para intervalo de versículos. Ex: 3:16 ou 3:16-18",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Categoria
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Categoria',
                hintText: 'Selecione a categoria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Nenhuma')),
                DropdownMenuItem(value: 'domingo', child: Text('Culto de Domingo')),
                DropdownMenuItem(value: 'quarta', child: Text('Culto de Quarta-feira')),
                DropdownMenuItem(value: 'especial', child: Text('Culto Especial')),
              ],
              onChanged: (value) {
                setState(() {
                  _category = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Pregador
            TextFormField(
              controller: _preacherController,
              decoration: const InputDecoration(
                labelText: 'Pregador',
                hintText: 'Ex: Pastor João Silva',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Link do YouTube
            TextFormField(
              controller: _youtubeUrlController,
              decoration: const InputDecoration(
                labelText: 'Link do YouTube',
                hintText: 'Ex: https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.video_library),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Conteúdo
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Conteúdo *',
                hintText: 'Escreva o devocional aqui...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira o conteúdo';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Upload de Imagem
            ImageUploadWidget(
              initialImageUrl: _imageUrl,
              onImageUrlChanged: (url) {
                setState(() {
                  _imageUrl = url;
                });
              },
              storageBucket: 'devotional-images',
              label: 'Imagem do Devocional',
            ),
            const SizedBox(height: 16),

            // Publicar
            Card(
              child: SwitchListTile(
                title: const Text('Publicar'),
                subtitle: const Text(
                  'Se marcado, o devocional ficará visível para todos',
                ),
                value: _isPublished,
                onChanged: (value) {
                  setState(() {
                    _isPublished = value;
                  });
                },
                secondary: Icon(
                  _isPublished ? Icons.visibility : Icons.visibility_off,
                  color: _isPublished ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botão de salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _save,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Atualizar' : 'Criar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
