import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../permissions/providers/permissions_providers.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

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

  /// Até quando a notícia fica em cartaz. Guardada em `event.end_date` — a
  /// coluna já existia e a notícia a gravava como nula. Nula aqui significa
  /// "sem prazo": só sai quando alguém despublicar. Notícia nova nasce com 30
  /// dias sugeridos, que a pessoa muda ou limpa antes de salvar.
  DateTime? _expiraEm = DateTime.now().add(const Duration(days: 30));
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
          _expiraEm = event.endDate;
          _isPublished = event.status == 'published';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar notícia: $e')));
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

  Future<void> _pickExpiraEm() async {
    final base = _expiraEm ?? _publishedAt.add(const Duration(days: 30));

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _publishedAt,
      lastDate: DateTime(2100),
      helpText: 'Até quando a notícia fica no ar',
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Hora em que ela sai do ar',
    );
    if (time == null) return;

    setState(() {
      _expiraEm = DateTime(
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

    final prazo = _expiraEm;
    if (prazo != null && !prazo.isAfter(_publishedAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O prazo tem que ser depois da data de publicação.'),
        ),
      );
      return;
    }

    final requiredPermission = _isEditing ? 'news.edit' : 'news.create';
    final hasPermission = await ref.read(
      currentUserHasPermissionProvider(requiredPermission).future,
    );
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para esta ação'),
          ),
        );
      }
      return;
    }

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
        'end_date': _expiraEm?.toIso8601String(),
        'location': null,
        'max_capacity': null,
        'requires_registration': false,
        // `price` e `is_mandatory` NÃO existem em public.event (VEREDITO A1 da
        // migration 20260830000100) — são campos fantasma do model Dart. Mandar
        // qualquer um dos dois faz o PostgREST recusar o insert inteiro com
        // PGRST204, que era o erro ao salvar uma notícia.
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
      ref.invalidate(recentNewsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Notícia atualizada!' : 'Notícia criada!',
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
    final dateLabel = DateFormat(
      'dd/MM/yyyy • HH:mm',
      'pt_BR',
    ).format(_publishedAt);
    final prazo = _expiraEm;
    final prazoLabel = prazo == null
        ? 'Sem prazo — fica no ar até você despublicar'
        : DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR').format(prazo);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Notícia' : 'Nova Notícia',
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
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
            DisabledByPermission(
              permission: _isEditing ? 'news.edit' : 'news.create',
              disabledTooltip: _isEditing
                  ? 'Você não tem permissão para editar notícias'
                  : 'Você não tem permissão para criar notícias',
              child: IconButton(
                icon: const Icon(AppIcons.save),
                onPressed: _save,
                tooltip: 'Salvar',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/home/banners'),
                        icon: const Icon(AppIcons.image),
                        label: const Text('Gerenciar Banners'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(AppIcons.article),
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
                          prefixIcon: Icon(AppIcons.description),
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
                      GlassCard(
                        child: ListTile(
                          leading: const Icon(AppIcons.schedule),
                          title: const Text('Data/Hora'),
                          subtitle: Text(dateLabel),
                          trailing: const Icon(AppIcons.calendar),
                          onTap: _pickDateTime,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: ListTile(
                          leading: const Icon(AppIcons.accessTime),
                          title: const Text('Sai do ar em'),
                          subtitle: Text(prazoLabel),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (prazo != null)
                                IconButton(
                                  icon: const Icon(AppIcons.clear),
                                  tooltip: 'Deixar sem prazo',
                                  onPressed: () =>
                                      setState(() => _expiraEm = null),
                                ),
                              const Icon(AppIcons.calendar),
                            ],
                          ),
                          onTap: _pickExpiraEm,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
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
                      DisabledByPermission(
                        permission: _isEditing ? 'news.edit' : 'news.create',
                        disabledTooltip: _isEditing
                            ? 'Você não tem permissão para editar notícias'
                            : 'Você não tem permissão para criar notícias',
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(AppIcons.save),
                          label: Text(
                            _isEditing ? 'Salvar alterações' : 'Criar notícia',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
