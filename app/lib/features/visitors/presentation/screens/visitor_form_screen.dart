import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../data/visitors_repository.dart';

/// Tela de formulário de visitante (criar/editar)
class VisitorFormScreen extends ConsumerStatefulWidget {
  final String? visitorId;

  const VisitorFormScreen({super.key, this.visitorId});

  @override
  ConsumerState<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends ConsumerState<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _prayerRequestController = TextEditingController();
  final _interestsController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _firstVisitDate = DateTime.now();
  DateTime? _birthDate;
  VisitorStatus _status = VisitorStatus.firstVisit;
  HowFoundChurch? _howFound;

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.visitorId != null;
    if (_isEditMode) {
      _loadVisitor();
    }
  }

  Future<void> _loadVisitor() async {
    final visitor = await ref.read(visitorByIdProvider(widget.visitorId!).future);
    if (visitor != null && mounted) {
      setState(() {
        _firstNameController.text = visitor.firstName;
        _lastNameController.text = visitor.lastName;
        _emailController.text = visitor.email ?? '';
        _phoneController.text = visitor.phone ?? '';
        _addressController.text = visitor.address ?? '';
        _cityController.text = visitor.city ?? '';
        _stateController.text = visitor.state ?? '';
        _zipCodeController.text = visitor.zipCode ?? '';
        _prayerRequestController.text = visitor.prayerRequest ?? '';
        _interestsController.text = visitor.interests ?? '';
        _notesController.text = visitor.notes ?? '';
        _firstVisitDate = visitor.firstVisitDate;
        _birthDate = visitor.birthDate;
        _status = visitor.status;
        _howFound = visitor.howFound;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _prayerRequestController.dispose();
    _interestsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectFirstVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstVisitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _firstVisitDate = picked;
      });
    }
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveVisitor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        'zip_code': _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
        'first_visit_date': _firstVisitDate.toIso8601String().split('T')[0],
        'status': _status.value,
        'how_found': _howFound?.value,
        'prayer_request': _prayerRequestController.text.trim().isEmpty ? null : _prayerRequestController.text.trim(),
        'interests': _interestsController.text.trim().isEmpty ? null : _interestsController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      if (_isEditMode) {
        await ref.read(visitorsRepositoryProvider).updateVisitor(widget.visitorId!, data);
      } else {
        await ref.read(visitorsRepositoryProvider).createVisitor(data);
      }

      ref.invalidate(allVisitorsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Visitante atualizado com sucesso!' : 'Visitante cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar visitante: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Visitante' : 'Novo Visitante'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Informações Pessoais
            Text(
              'Informações Pessoais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Nome
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nome é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Sobrenome
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Sobrenome *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Sobrenome é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Telefone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Data de Nascimento
            InkWell(
              onTap: _selectBirthDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                child: Text(
                  _birthDate != null ? _formatDate(_birthDate!) : 'Selecione a data',
                  style: TextStyle(
                    color: _birthDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Endereço
            Text(
              'Endereço',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _zipCodeController,
              decoration: const InputDecoration(
                labelText: 'CEP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Informações da Visita
            Text(
              'Informações da Visita',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Data da Primeira Visita
            InkWell(
              onTap: _selectFirstVisitDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da Primeira Visita *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatDate(_firstVisitDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<VisitorStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              items: VisitorStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Como conheceu a igreja
            DropdownButtonFormField<HowFoundChurch>(
              initialValue: _howFound,
              decoration: const InputDecoration(
                labelText: 'Como conheceu a igreja?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.question_mark),
              ),
              items: HowFoundChurch.values.map((how) {
                return DropdownMenuItem(
                  value: how,
                  child: Text(how.label),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _howFound = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Observações
            Text(
              'Observações',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _prayerRequestController,
              decoration: const InputDecoration(
                labelText: 'Pedido de Oração',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _interestsController,
              decoration: const InputDecoration(
                labelText: 'Interesses',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveVisitor,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditMode ? 'Atualizar Visitante' : 'Cadastrar Visitante'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

