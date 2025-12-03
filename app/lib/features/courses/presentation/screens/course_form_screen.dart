import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/course.dart';
import '../providers/courses_provider.dart';
import '../../../../core/widgets/image_upload_widget.dart';

/// Tela de formulário de curso (criar/editar)
class CourseFormScreen extends ConsumerStatefulWidget {
  final String? courseId; // null = criar, não-null = editar

  const CourseFormScreen({
    super.key,
    this.courseId,
  });

  @override
  ConsumerState<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends ConsumerState<CourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructorController = TextEditingController();
  final _categoryController = TextEditingController();
  final _durationController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  final _meetingLinkController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _paymentInfoController = TextEditingController();

  // State
  String _level = 'Básico';
  String _status = 'active';
  CourseType _courseType = CourseType.presencial;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _imageUrl;
  bool _isPaid = false;

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.courseId != null;
    if (_isEditMode) {
      _loadCourse();
    }
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final course = await ref.read(courseByIdProvider(widget.courseId!).future);
      if (course != null && mounted) {
        setState(() {
          _titleController.text = course.title;
          _descriptionController.text = course.description ?? '';
          _instructorController.text = course.instructor ?? '';
          _categoryController.text = course.category ?? '';
          _durationController.text = course.duration?.toString() ?? '';
          _maxStudentsController.text = course.maxStudents?.toString() ?? '';
          _meetingLinkController.text = course.meetingLink ?? '';
          _addressController.text = course.address ?? '';
          _priceController.text = course.price?.toString() ?? '';
          _paymentInfoController.text = course.paymentInfo ?? '';
          _level = course.level;
          _status = course.status;
          _courseType = course.courseType;
          _startDate = course.startDate;
          _endDate = course.endDate;
          _imageUrl = course.imageUrl;
          _isPaid = course.isPaid;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar curso: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actions = ref.read(coursesActionsProvider);
      
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'instructor': _instructorController.text.trim().isEmpty ? null : _instructorController.text.trim(),
        'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        'duration': _durationController.text.trim().isEmpty ? null : int.tryParse(_durationController.text.trim()),
        'max_students': _maxStudentsController.text.trim().isEmpty ? null : int.tryParse(_maxStudentsController.text.trim()),
        'level': _level,
        'status': _status,
        'course_type': _courseType.value,
        'meeting_link': _courseType == CourseType.onlineLive && _meetingLinkController.text.trim().isNotEmpty
            ? _meetingLinkController.text.trim()
            : null,
        'address': _courseType == CourseType.presencial && _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'is_paid': _isPaid,
        'price': _isPaid && _priceController.text.trim().isNotEmpty
            ? double.tryParse(_priceController.text.trim())
            : null,
        'payment_info': _isPaid && _paymentInfoController.text.trim().isNotEmpty
            ? _paymentInfoController.text.trim()
            : null,
        'start_date': _startDate?.toIso8601String(),
        'end_date': _endDate?.toIso8601String(),
        'image_url': _imageUrl,
      };

      if (_isEditMode) {
        await actions.updateCourse(widget.courseId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Curso atualizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        final newCourse = await actions.createCourse(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Curso criado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          // Se for curso online gravado, redirecionar para gerenciar aulas
          if (_courseType == CourseType.onlineRecorded) {
            context.push('/courses/${newCourse.id}/lessons');
          } else {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar curso: $e'),
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: isStartDate ? DateTime(2020) : (_startDate ?? DateTime(2020)),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      // Validação: data de término deve ser depois da data de início
      if (!isStartDate && _startDate != null && picked.isBefore(_startDate!)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A data de término deve ser posterior à data de início'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Se a data de término for anterior à nova data de início, limpa
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructorController.dispose();
    _categoryController.dispose();
    _durationController.dispose();
    _maxStudentsController.dispose();
    _meetingLinkController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _paymentInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _isEditMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Carregando...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Curso' : 'Novo Curso'),
        actions: [
          if (_isEditMode && widget.courseId != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Imagem
            ImageUploadWidget(
              initialImageUrl: _imageUrl,
              onImageUrlChanged: (url) {
                setState(() => _imageUrl = url);
              },
              storageBucket: 'course-images',
              label: 'Imagem do Curso',
            ),
            const SizedBox(height: 24),

            // Título
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título *',
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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              enableInteractiveSelection: true,
            ),
            const SizedBox(height: 16),

            // Instrutor
            TextFormField(
              controller: _instructorController,
              decoration: const InputDecoration(
                labelText: 'Instrutor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              enableInteractiveSelection: true,
            ),
            const SizedBox(height: 16),

            // Categoria
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                hintText: 'Ex: Teologia, Música, Liderança',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              enableInteractiveSelection: true,
            ),
            const SizedBox(height: 16),

            // Tipo de Curso
            DropdownMenu<CourseType>(
              initialSelection: _courseType,
              label: const Text('Tipo de Curso *'),
              leadingIcon: const Icon(Icons.school),
              dropdownMenuEntries: CourseType.values
                  .map((type) => DropdownMenuEntry<CourseType>(value: type, label: type.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) {
                  setState(() => _courseType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Link da Reunião (apenas para Online ao Vivo)
            if (_courseType == CourseType.onlineLive) ...[
              TextFormField(
                controller: _meetingLinkController,
                decoration: const InputDecoration(
                  labelText: 'Link da Sala *',
                  hintText: 'Ex: https://meet.google.com/...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (_courseType == CourseType.onlineLive && (value == null || value.trim().isEmpty)) {
                    return 'Link da sala é obrigatório para cursos online ao vivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Endereço (apenas para Presencial)
            if (_courseType == CourseType.presencial) ...[
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  hintText: 'Ex: Rua ABC, 123 - Bairro - Cidade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
            ],

            // Curso Pago
            SwitchListTile(
              title: const Text('Curso Pago'),
              subtitle: const Text('Este curso requer pagamento para inscrição'),
              value: _isPaid,
              onChanged: (value) {
                setState(() => _isPaid = value);
              },
            ),
            const SizedBox(height: 16),

            // Preço (apenas se pago)
            if (_isPaid) ...[
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Preço *',
                  hintText: 'Ex: 50.00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (_isPaid && (value == null || value.trim().isEmpty)) {
                    return 'Preço é obrigatório para cursos pagos';
                  }
                  if (_isPaid && double.tryParse(value!) == null) {
                    return 'Digite um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Informações de Pagamento
              TextFormField(
                controller: _paymentInfoController,
                decoration: const InputDecoration(
                  labelText: 'Informações de Pagamento',
                  hintText: 'Ex: PIX, Transferência, Dados bancários...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
            ],

            // Botão/Mensagem para gerenciar aulas (apenas para Online Gravado)
            if (_courseType == CourseType.onlineRecorded) ...[
              if (_isEditMode && widget.courseId != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.video_library),
                    title: const Text('Gerenciar Aulas'),
                    subtitle: const Text('Adicionar e organizar aulas do curso'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      context.push('/courses/${widget.courseId}/lessons');
                    },
                  ),
                )
              else
                Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Após criar o curso, você será redirecionado para adicionar as aulas (vídeos, arquivos, transcrições).',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Nível
            DropdownMenu<String>(
              initialSelection: _level,
              label: const Text('Nível'),
              leadingIcon: const Icon(Icons.signal_cellular_alt),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'Básico', label: 'Básico'),
                DropdownMenuEntry(value: 'Intermediário', label: 'Intermediário'),
                DropdownMenuEntry(value: 'Avançado', label: 'Avançado'),
              ],
              onSelected: (value) {
                if (value != null) {
                  setState(() => _level = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Status
            DropdownMenu<String>(
              initialSelection: _status,
              label: const Text('Status'),
              leadingIcon: const Icon(Icons.info),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'active', label: 'Ativo'),
                DropdownMenuEntry(value: 'upcoming', label: 'Em breve'),
                DropdownMenuEntry(value: 'completed', label: 'Concluído'),
              ],
              onSelected: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Duração (em horas)
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duração (horas)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.access_time),
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

            // Máximo de Alunos
            TextFormField(
              controller: _maxStudentsController,
              decoration: const InputDecoration(
                labelText: 'Máximo de Alunos',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
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

            // Data de Início
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Data de Início'),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('dd/MM/yyyy').format(_startDate!)
                    : 'Não definida',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context, true),
            ),
            const Divider(),

            // Data de Término
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Data de Término'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('dd/MM/yyyy').format(_endDate!)
                    : 'Não definida',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context, false),
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveCourse,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditMode ? 'Atualizar Curso' : 'Criar Curso'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Curso'),
        content: const Text('Tem certeza que deseja excluir este curso? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        setState(() => _isLoading = true);
        final actions = ref.read(coursesActionsProvider);
        await actions.deleteCourse(widget.courseId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Curso excluído com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir curso: $e'),
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
  }
}
