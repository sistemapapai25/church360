import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../events/presentation/providers/events_provider.dart';

class NewsFormScreen extends ConsumerStatefulWidget {
  final String? newsId;

  const NewsFormScreen({super.key, this.newsId});

  @override
  ConsumerState<NewsFormScreen> createState() => _NewsFormScreenState();
}

class _NewsFormScreenState extends ConsumerState<NewsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _imageUrl;
  DateTime _publishedAt = DateTime.now();
  bool _isPublished = true;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEditing => widget.newsId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _load();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final event = await ref.read(eventByIdProvider(widget.newsId!).future);
      if (event != null && mounted) {
        setState(() {
          _titleController.text = event.name;
          _contentController.text = event.description ?? '';
          _imageUrl = event.imageUrl;
          _publishedAt = event.startDate;
          _isPublished = event.status == 'published';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar notícia: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _publishedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishedAt),
    );
    if (time == null) return;

    setState(() {
      _publishedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);

      final data = {
        'name': _titleController.text.trim(),
        'description': _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        'event_type': 'news',
        'start_date': _publishedAt.toIso8601String(),
        'end_date': null,
        'location': null,
        'max_capacity': null,
        'requires_registration': false,
        'price': null,
        'is_mandatory': false,
        'status': _isPublished ? 'published' : 'draft',
        'image_url': _imageUrl?.trim().isEmpty == true ? null : _imageUrl,
      };

      if (_isEditing) {
        await repo.updateEvent(widget.newsId!, data);
        ref.invalidate(eventByIdProvider(widget.newsId!));
      } else {
        await repo.createEventFromJson(data);
      }

      ref.invalidate(allEventsProvider);
      ref.invalidate(activeEventsProvider);
      ref.invalidate(upcomingEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Notícia atualizada!' : 'Notícia criada!'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR').format(
      _publishedAt,
    );

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Notícia' : 'Nova Notícia',
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
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
              onPressed: _save,
              tooltip: 'Salvar',
            ),
        ],
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
                    OutlinedButton.icon(
                      onPressed: () => context.push('/home/banners'),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Gerenciar Banners'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, insira um título';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Conteúdo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.article_outlined),
                      ),
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    ImageUploadWidget(
                      initialImageUrl: _imageUrl,
                      onImageUrlChanged: (url) {
                        setState(() {
                          _imageUrl = url;
                        });
                      },
                      storageBucket: 'event-images',
                      label: 'Imagem (Opcional)',
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Data/Hora'),
                        subtitle: Text(dateLabel),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: _pickDateTime,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: SwitchListTile(
                        title: const Text('Publicar'),
                        subtitle: Text(
                          _isPublished
                              ? 'Visível no app'
                              : 'Não aparece no app',
                        ),
                        value: _isPublished,
                        onChanged: (v) => setState(() => _isPublished = v),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditing ? 'Salvar alterações' : 'Criar notícia'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
