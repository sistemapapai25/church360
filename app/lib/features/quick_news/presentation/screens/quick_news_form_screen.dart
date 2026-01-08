import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import '../../../../core/design/community_design.dart';
import '../providers/quick_news_provider.dart';

/// Tela de formulário para criar/editar avisos rápidos
class QuickNewsFormScreen extends ConsumerStatefulWidget {
  final String? newsId;

  const QuickNewsFormScreen({super.key, this.newsId});

  @override
  ConsumerState<QuickNewsFormScreen> createState() => _QuickNewsFormScreenState();
}

class _QuickNewsFormScreenState extends ConsumerState<QuickNewsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkUrlController = TextEditingController();
  final _priorityController = TextEditingController(text: '0');

  bool _isActive = true;
  bool _hasExpiration = false;
  DateTime? _expiresAt;
  String? _imageUrl;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.newsId != null) {
      _loadNews();
    }
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    try {
      final news = await ref.read(quickNewsByIdProvider(widget.newsId!).future);
      if (news != null && mounted) {
        _titleController.text = news.title;
        _descriptionController.text = news.description;
        _linkUrlController.text = news.linkUrl ?? '';
        _priorityController.text = news.priority.toString();
        _isActive = news.isActive;
        _imageUrl = news.imageUrl;
        _hasExpiration = news.expiresAt != null;
        _expiresAt = news.expiresAt;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar aviso: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _imageUrl;

    setState(() => _isUploading = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'quick-news/$fileName';

      await Supabase.instance.client.storage
          .from('church-assets')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('church-assets')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer upload da imagem: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload da imagem se houver
      final uploadedImageUrl = await _uploadImage();

      final repo = ref.read(quickNewsRepositoryProvider);
      final priority = int.tryParse(_priorityController.text) ?? 0;

      if (widget.newsId == null) {
        // Criar novo
        await repo.createNews(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: uploadedImageUrl,
          linkUrl: _linkUrlController.text.trim().isEmpty
              ? null
              : _linkUrlController.text.trim(),
          priority: priority,
          isActive: _isActive,
          expiresAt: _hasExpiration ? _expiresAt : null,
        );
      } else {
        // Atualizar existente
        await repo.updateNews(
          id: widget.newsId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageUrl: uploadedImageUrl,
          linkUrl: _linkUrlController.text.trim().isEmpty
              ? null
              : _linkUrlController.text.trim(),
          priority: priority,
          isActive: _isActive,
          expiresAt: _hasExpiration ? _expiresAt : null,
        );
      }

      ref.invalidate(allQuickNewsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.newsId == null
                  ? 'Aviso criado com sucesso!'
                  : 'Aviso atualizado com sucesso!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkUrlController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.newsId != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Carregando...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text(
          widget.newsId == null ? 'Novo Aviso' : 'Editar Aviso',
          style: CommunityDesign.titleStyle(context),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading || _isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check),
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O título é obrigatório';
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // Descrição
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'A descrição é obrigatória';
                }
                return null;
              },
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // Link URL (opcional)
            TextFormField(
              controller: _linkUrlController,
              decoration: const InputDecoration(
                labelText: 'Link (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Prioridade
            TextFormField(
              controller: _priorityController,
              decoration: const InputDecoration(
                labelText: 'Prioridade',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.priority_high),
                helperText: 'Maior número = maior prioridade',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (int.tryParse(value) == null) {
                    return 'Digite um número válido';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Imagem
            _buildImageSection(),
            const SizedBox(height: 24),

            // Status Ativo
            SwitchListTile(
              title: const Text('Aviso Ativo'),
              subtitle: const Text('Desative para ocultar o aviso temporariamente'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const Divider(),

            // Expiração
            SwitchListTile(
              title: const Text('Definir Data de Expiração'),
              subtitle: const Text('O aviso será ocultado após esta data'),
              value: _hasExpiration,
              onChanged: (value) => setState(() => _hasExpiration = value),
            ),

            if (_hasExpiration) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(
                  _expiresAt == null
                      ? 'Selecionar data de expiração'
                      : 'Expira em: ${_formatDateTime(_expiresAt!)}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selectExpirationDate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: CommunityDesign.overlayDecoration(Theme.of(context).colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Imagem (opcional)',
                  style: CommunityDesign.contentStyle(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_selectedImage != null || _imageUrl != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : NetworkImage(_imageUrl!) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(_selectedImage != null || _imageUrl != null
                        ? 'Trocar Imagem'
                        : 'Selecionar Imagem'),
                  ),
                ),
                if (_selectedImage != null || _imageUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _imageUrl = null;
                      });
                    },
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectExpirationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiresAt ?? DateTime.now()),
      );

      if (time != null && mounted) {
        setState(() {
          _expiresAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} às ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
