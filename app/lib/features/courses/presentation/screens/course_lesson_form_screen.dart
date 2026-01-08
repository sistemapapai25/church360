import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../members/presentation/providers/members_provider.dart';

import '../providers/courses_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';
import '../../../../core/widgets/video_upload_widget.dart';
import '../../../../core/widgets/file_upload_widget.dart';

/// Tela de formulário para criar/editar aula de curso
class CourseLessonFormScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String? lessonId;

  const CourseLessonFormScreen({
    super.key,
    required this.courseId,
    this.lessonId,
  });

  @override
  ConsumerState<CourseLessonFormScreen> createState() => _CourseLessonFormScreenState();
}

class _CourseLessonFormScreenState extends ConsumerState<CourseLessonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _videoDurationController = TextEditingController();

  bool _isLoading = false;
  String? _coverImageUrl;
  String? _videoUrl;
  String? _fileUrl;
  String? _fileName;

  bool get _isEditMode => widget.lessonId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadLesson();
    }
  }

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);

    try {
      final lesson = await ref.read(courseLessonByIdProvider(widget.lessonId!).future);

      if (lesson != null && mounted) {
        _titleController.text = lesson.title;
        _descriptionController.text = lesson.description ?? '';
        _contentController.text = lesson.content ?? '';
        _videoDurationController.text = lesson.videoDuration?.toString() ?? '';
        
        setState(() {
          _coverImageUrl = lesson.coverImageUrl;
          _videoUrl = lesson.videoUrl;
          _fileUrl = lesson.fileUrl;
          _fileName = lesson.fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar aula: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _videoDurationController.dispose();
    super.dispose();
  }

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final member = await ref.read(currentMemberProvider.future);
      if (member == null) throw Exception('Usuário não autenticado');

      final actions = ref.read(courseLessonsActionsProvider);

      // Obter o próximo order_index se for criação
      int orderIndex = 0;
      if (!_isEditMode) {
        final lessons = await ref.read(courseLessonsProvider(widget.courseId).future);
        orderIndex = lessons.length;
      }

      final data = {
        'course_id': widget.courseId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'content': _contentController.text.trim().isEmpty ? null : _contentController.text.trim(),
        'video_url': _videoUrl,
        'video_duration': _videoDurationController.text.isEmpty ? null : int.tryParse(_videoDurationController.text),
        'file_url': _fileUrl,
        'file_name': _fileName,
        'cover_image_url': _coverImageUrl,
        if (!_isEditMode) 'order_index': orderIndex,
        if (!_isEditMode) 'created_by': member.id,
        'updated_by': member.id,
      };

      if (_isEditMode) {
        await actions.updateLesson(widget.courseId, widget.lessonId!, data);
      } else {
        await actions.createLesson(widget.courseId, data);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Aula atualizada com sucesso!' : 'Aula criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar aula: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Aula' : 'Nova Aula'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Título
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título da Aula *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    enableInteractiveSelection: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Título é obrigatório';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Descrição
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Breve descrição da aula',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    enableInteractiveSelection: true,
                  ),
                  const SizedBox(height: 16),

                  // Imagem de Capa
                  ImageUploadWidget(
                    initialImageUrl: _coverImageUrl,
                    onImageUrlChanged: (url) {
                      setState(() => _coverImageUrl = url);
                    },
                    storageBucket: 'course-lesson-covers',
                    label: 'Imagem de Capa da Aula',
                  ),
                  const SizedBox(height: 16),

                  // Vídeo
                  VideoUploadWidget(
                    initialVideoUrl: _videoUrl,
                    onVideoUrlChanged: (url) {
                      setState(() => _videoUrl = url);
                    },
                    storageBucket: 'course-lesson-videos',
                    label: 'Vídeo da Aula',
                    allowYouTubeLink: true,
                  ),
                  const SizedBox(height: 16),

                  // Duração do Vídeo (em segundos)
                  TextFormField(
                    controller: _videoDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Duração do Vídeo (segundos)',
                      hintText: 'Ex: 1800 (30 minutos)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
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
                  const SizedBox(height: 16),

                  // Arquivo Anexo
                  FileUploadWidget(
                    initialFileUrl: _fileUrl,
                    initialFileName: _fileName,
                    onFileUrlChanged: (url, name) {
                      setState(() {
                        _fileUrl = url;
                        _fileName = name;
                      });
                    },
                    storageBucket: 'course-lesson-files',
                    label: 'Arquivo Anexo (PDF, DOC, etc.)',
                  ),
                  const SizedBox(height: 16),

                  // Conteúdo/Transcrição
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Conteúdo/Transcrição',
                      hintText: 'Transcrição da aula ou conteúdo adicional...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                    enableInteractiveSelection: true,
                  ),
                  const SizedBox(height: 24),

                  // Botão Salvar
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveLesson,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isEditMode ? 'Atualizar Aula' : 'Criar Aula'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
