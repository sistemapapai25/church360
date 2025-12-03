import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Tela de formulário de visitante (criar/editar)
/// Unificada para visitantes da igreja e de grupos
class VisitorFormScreen extends ConsumerStatefulWidget {
  final String? visitorId;
  final String? meetingId; // Para visitantes de reuniões de grupos

  const VisitorFormScreen({
    super.key,
    this.visitorId,
    this.meetingId,
  });

  @override
  ConsumerState<VisitorFormScreen> createState() => _VisitorFormScreenState();
}

class _VisitorFormScreenState extends ConsumerState<VisitorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers básicos
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _ageController = TextEditingController();
  
  // Controllers adicionais
  final _prayerRequestController = TextEditingController();
  final _interestsController = TextEditingController();
  final _notesController = TextEditingController();
  final _howFoundUsController = TextEditingController();
  final _testimonyController = TextEditingController();

  // Datas
  DateTime _firstVisitDate = DateTime.now();
  DateTime? _birthDate;
  DateTime? _salvationDate;
  DateTime? _lastContactDate;
  
  // Enums e seleções
  VisitorStatus _status = VisitorStatus.firstVisit;
  HowFoundChurch? _howFound;
  VisitorSource _visitorSource = VisitorSource.church;
  String? _gender;
  String _followUpStatus = 'pending';
  String? _assignedMentorId;
  
  // Booleans
  bool _wantsContact = true;
  bool _wantsToReturn = false;
  bool _isSalvation = false;
  bool _wantsBaptism = false;
  bool _wantsDiscipleship = false;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.visitorId != null;
    
    // Se veio de uma reunião, definir source como 'house'
    if (widget.meetingId != null) {
      _visitorSource = VisitorSource.house;
    }
    
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
        _ageController.text = visitor.age?.toString() ?? '';
        _prayerRequestController.text = visitor.prayerRequest ?? '';
        _interestsController.text = visitor.interests ?? '';
        _notesController.text = visitor.notes ?? '';
        _howFoundUsController.text = visitor.howFoundUs ?? '';
        _testimonyController.text = visitor.testimony ?? '';

        _firstVisitDate = visitor.firstVisitDate ?? DateTime.now();
        _birthDate = visitor.birthDate;
        _salvationDate = visitor.salvationDate;
        _lastContactDate = visitor.lastContactDate;
        
        _status = visitor.status;
        _howFound = visitor.howFound;
        _visitorSource = visitor.visitorSource;
        _gender = visitor.gender;
        _followUpStatus = visitor.followUpStatus;
        _assignedMentorId = visitor.assignedMentorId;
        
        _wantsContact = visitor.wantsContact;
        _wantsToReturn = visitor.wantsToReturn;
        _isSalvation = visitor.isSalvation;
        _wantsBaptism = visitor.wantsBaptism;
        _wantsDiscipleship = visitor.wantsDiscipleship;
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
    _ageController.dispose();
    _prayerRequestController.dispose();
    _interestsController.dispose();
    _notesController.dispose();
    _howFoundUsController.dispose();
    _testimonyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    DateTime? initialDate;
    DateTime firstDate;
    DateTime lastDate = DateTime.now();
    
    switch (type) {
      case 'birth':
        initialDate = _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 30));
        firstDate = DateTime(1900);
        break;
      case 'visit':
        initialDate = _firstVisitDate;
        firstDate = DateTime(2020);
        break;
      case 'salvation':
        initialDate = _salvationDate ?? DateTime.now();
        firstDate = DateTime(2000);
        break;
      case 'contact':
        initialDate = _lastContactDate ?? DateTime.now();
        firstDate = DateTime(2020);
        break;
      default:
        return;
    }
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    
    if (picked != null && mounted) {
      setState(() {
        switch (type) {
          case 'birth':
            _birthDate = picked;
            break;
          case 'visit':
            _firstVisitDate = picked;
            break;
          case 'salvation':
            _salvationDate = picked;
            break;
          case 'contact':
            _lastContactDate = picked;
            break;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveVisitor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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
        'age': _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
        'gender': _gender,
        'first_visit_date': _firstVisitDate.toIso8601String().split('T')[0],
        'status': _status.value,
        'how_found': _howFound?.value,
        'how_found_us': _howFoundUsController.text.trim().isEmpty ? null : _howFoundUsController.text.trim(),
        'prayer_request': _prayerRequestController.text.trim().isEmpty ? null : _prayerRequestController.text.trim(),
        'interests': _interestsController.text.trim().isEmpty ? null : _interestsController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'visitor_source': _visitorSource.value,
        'meeting_id': widget.meetingId,
        'wants_contact': _wantsContact,
        'wants_to_return': _wantsToReturn,
        'is_salvation': _isSalvation,
        'salvation_date': _isSalvation && _salvationDate != null ? _salvationDate!.toIso8601String().split('T')[0] : null,
        'testimony': _isSalvation && _testimonyController.text.trim().isNotEmpty ? _testimonyController.text.trim() : null,
        'wants_baptism': _isSalvation && _wantsBaptism,
        'wants_discipleship': _isSalvation && _wantsDiscipleship,
        'assigned_mentor_id': _isSalvation ? _assignedMentorId : null,
        'follow_up_status': _isSalvation ? _followUpStatus : 'pending',
        'last_contact_date': _isSalvation && _lastContactDate != null ? _lastContactDate!.toIso8601String().split('T')[0] : null,
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
        context.pop(true);
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(allMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Visitante' : 'Novo Visitante'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== INFORMAÇÕES BÁSICAS =====
            Text('Informações Básicas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Nome e Sobrenome
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Nome é obrigatório' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Sobrenome *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Sobrenome é obrigatório' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email e Telefone
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Idade e Gênero
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: 'Idade', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownMenu<String?>(
                    initialSelection: _gender,
                    label: const Text('Gênero'),
                    leadingIcon: const Icon(Icons.wc),
                    dropdownMenuEntries: const <DropdownMenuEntry<String?>>[
                      DropdownMenuEntry<String?>(value: 'male', label: 'Masculino'),
                      DropdownMenuEntry<String?>(value: 'female', label: 'Feminino'),
                      DropdownMenuEntry<String?>(value: 'other', label: 'Outro'),
                      DropdownMenuEntry<String?>(value: null, label: 'Não informado'),
                    ],
                    onSelected: (value) => setState(() => _gender = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Data de Nascimento
            InkWell(
              onTap: () => _selectDate(context, 'birth'),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data de Nascimento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                child: Text(_birthDate != null ? _formatDate(_birthDate!) : 'Selecione a data', style: TextStyle(color: _birthDate != null ? null : Colors.grey)),
              ),
            ),
            const SizedBox(height: 24),

            // ===== ENDEREÇO =====
            Text('Endereço', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _zipCodeController,
              decoration: const InputDecoration(labelText: 'CEP', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // ===== INFORMAÇÕES DA VISITA =====
            Text('Informações da Visita', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Tipo de Membro (Origem do Visitante)
            DropdownMenu<VisitorSource>(
              initialSelection: _visitorSource,
              label: const Text('Tipo de Membro (Origem) *'),
              leadingIcon: const Icon(Icons.source),
              dropdownMenuEntries: VisitorSource.values
                  .map((source) => DropdownMenuEntry<VisitorSource>(value: source, label: source.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) setState(() => _visitorSource = value);
              },
            ),
            const SizedBox(height: 16),

            // Data da Primeira Visita
            InkWell(
              onTap: () => _selectDate(context, 'visit'),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data da Primeira Visita *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                child: Text(_formatDate(_firstVisitDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            DropdownMenu<VisitorStatus>(
              initialSelection: _status,
              label: const Text('Status *'),
              leadingIcon: const Icon(Icons.info),
              dropdownMenuEntries: VisitorStatus.values
                  .map((status) => DropdownMenuEntry<VisitorStatus>(value: status, label: status.label))
                  .toList(),
              onSelected: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 16),

            // Como conheceu a igreja
            DropdownMenu<HowFoundChurch?>(
              initialSelection: _howFound,
              label: const Text('Como conheceu a igreja?'),
              leadingIcon: const Icon(Icons.question_mark),
              dropdownMenuEntries: [
                const DropdownMenuEntry<HowFoundChurch?>(value: null, label: 'Não informado'),
                ...HowFoundChurch.values.map((how) => DropdownMenuEntry<HowFoundChurch?>(value: how, label: how.label)),
              ],
              onSelected: (value) => setState(() => _howFound = value),
            ),
            const SizedBox(height: 16),

            // Como conheceu (texto livre)
            TextFormField(
              controller: _howFoundUsController,
              decoration: const InputDecoration(labelText: 'Como conheceu? (Detalhes)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.info)),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Checkboxes
            CheckboxListTile(
              title: const Text('Deseja ser contatado'),
              value: _wantsContact,
              onChanged: (value) => setState(() => _wantsContact = value ?? true),
            ),
            CheckboxListTile(
              title: const Text('Demonstrou interesse em retornar'),
              value: _wantsToReturn,
              onChanged: (value) => setState(() => _wantsToReturn = value ?? false),
            ),

            const Divider(height: 32),

            // ===== É UMA SALVAÇÃO? =====
            CheckboxListTile(
              title: Text('É uma salvação? 🎉', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
              subtitle: const Text('Marque se esta pessoa aceitou Jesus'),
              value: _isSalvation,
              onChanged: (value) {
                setState(() {
                  _isSalvation = value ?? false;
                  if (_isSalvation && _salvationDate == null) {
                    _salvationDate = DateTime.now();
                  }
                });
              },
            ),

            // Campos de salvação (mostrar apenas se _isSalvation = true)
            if (_isSalvation) ...[
              const SizedBox(height: 16),
              Text('Informações da Salvação', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Data da salvação
              InkWell(
                onTap: () => _selectDate(context, 'salvation'),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data da Salvação', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(_salvationDate != null ? _formatDate(_salvationDate!) : 'Não informada', style: TextStyle(color: _salvationDate != null ? null : Colors.grey)),
                ),
              ),
              const SizedBox(height: 16),

              // Testemunho
              TextFormField(
                controller: _testimonyController,
                decoration: const InputDecoration(labelText: 'Testemunho', border: OutlineInputBorder(), prefixIcon: Icon(Icons.message), hintText: 'Breve testemunho da salvação...'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Deseja batismo
              CheckboxListTile(
                title: const Text('Deseja ser batizado'),
                subtitle: const Text('Será inscrito no curso e evento de batismo'),
                value: _wantsBaptism,
                onChanged: (value) => setState(() => _wantsBaptism = value ?? false),
              ),

              // Deseja discipulado
              CheckboxListTile(
                title: const Text('Deseja fazer discipulado'),
                subtitle: const Text('Será inscrito no curso de discipulado'),
                value: _wantsDiscipleship,
                onChanged: (value) => setState(() => _wantsDiscipleship = value ?? false),
              ),
              const SizedBox(height: 16),

              // Mentor/Discipulador
              membersAsync.when(
                data: (members) {
                  return DropdownMenu<String?>(
                    initialSelection: _assignedMentorId,
                    label: const Text('Mentor/Discipulador'),
                    leadingIcon: const Icon(Icons.person_pin),
                    dropdownMenuEntries: [
                      const DropdownMenuEntry<String?>(value: null, label: 'Nenhum'),
                      ...members.map((member) => DropdownMenuEntry<String?>(value: member.id, label: member.displayName)),
                    ],
                    onSelected: (value) => setState(() => _assignedMentorId = value),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Erro ao carregar membros'),
              ),
              const SizedBox(height: 16),

              // Status de acompanhamento
            DropdownMenu<String>(
              initialSelection: _followUpStatus,
              label: const Text('Status de Acompanhamento'),
              leadingIcon: const Icon(Icons.track_changes),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'pending', label: 'Pendente'),
                DropdownMenuEntry(value: 'in_progress', label: 'Em Andamento'),
                DropdownMenuEntry(value: 'completed', label: 'Concluído'),
              ],
              onSelected: (value) {
                if (value != null) setState(() => _followUpStatus = value);
              },
            ),
            ],

            const SizedBox(height: 24),

            // ===== OBSERVAÇÕES =====
            Text('Observações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _prayerRequestController,
              decoration: const InputDecoration(labelText: 'Pedido de Oração', border: OutlineInputBorder(), prefixIcon: Icon(Icons.favorite)),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _interestsController,
              decoration: const InputDecoration(labelText: 'Interesses', border: OutlineInputBorder(), prefixIcon: Icon(Icons.star)),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note)),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveVisitor,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSalvation ? 'Registrar Salvação' : (_isEditMode ? 'Atualizar Visitante' : 'Cadastrar Visitante')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: _isSalvation ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
