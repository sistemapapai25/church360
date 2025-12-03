import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/viacep_service.dart';
import '../../domain/models/member.dart';
import '../providers/members_provider.dart';

/// Tela de Edição de Perfil do Usuário
class EditProfileScreen extends ConsumerStatefulWidget {
  final Member member;

  const EditProfileScreen({
    super.key,
    required this.member,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers para os campos de texto
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _cpfController;
  late TextEditingController _professionController;
  late TextEditingController _addressController;
  late TextEditingController _addressComplementController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipCodeController;
  late TextEditingController _notesController;

  // Valores selecionados
  DateTime? _birthdate;
  String? _gender;
  String? _maritalStatus;
  DateTime? _marriageDate;
  String? _status;
  String? _memberType;
  DateTime? _conversionDate;
  DateTime? _baptismDate;
  DateTime? _membershipDate;

  bool _isSaving = false;
  bool _isSearchingCep = false;

  @override
  void initState() {
    super.initState();

    // Inicializar controllers com os valores atuais
    _firstNameController = TextEditingController(text: widget.member.firstName);
    _lastNameController = TextEditingController(text: widget.member.lastName);
    _nicknameController = TextEditingController(text: widget.member.nickname);
    _emailController = TextEditingController(text: widget.member.email);
    _phoneController = TextEditingController(text: widget.member.phone);
    _cpfController = TextEditingController(text: widget.member.cpf);
    _professionController = TextEditingController(text: widget.member.profession);
    _addressController = TextEditingController(text: widget.member.address);
    _addressComplementController = TextEditingController(text: widget.member.addressComplement);
    _neighborhoodController = TextEditingController(text: widget.member.neighborhood);
    _cityController = TextEditingController(text: widget.member.city);
    _stateController = TextEditingController(text: widget.member.state);
    _zipCodeController = TextEditingController(text: widget.member.zipCode);
    _notesController = TextEditingController(text: widget.member.notes);

    // Inicializar valores selecionados
    _birthdate = widget.member.birthdate;
    _gender = widget.member.gender;
    _maritalStatus = widget.member.maritalStatus;
    _marriageDate = widget.member.marriageDate;
    _status = widget.member.status;
    _memberType = widget.member.memberType;
    _conversionDate = widget.member.conversionDate;
    _baptismDate = widget.member.baptismDate;
    _membershipDate = widget.member.membershipDate;

    if (widget.member.profession != null && widget.member.profession!.isNotEmpty) {
      final value = widget.member.profession!;
      Future.microtask(() async {
        final label = await ref.read(membersRepositoryProvider).getProfessionLabelById(value);
        if (label != null && mounted) {
          setState(() {
            _professionController.text = label;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    _addressComplementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, DateTime? initialDate, Function(DateTime) onDateSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  /// Buscar endereço pelo CEP usando a API ViaCEP
  Future<void> _searchCep() async {
    final cep = _zipCodeController.text.trim();

    // Validar se o CEP tem 8 dígitos
    if (!ViaCepService.isValidCep(cep)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CEP inválido. Digite 8 dígitos.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSearchingCep = true;
    });

    try {
      // Buscar endereço na API ViaCEP
      final address = await ViaCepService.fetchAddress(cep);

      // Preencher os campos automaticamente
      setState(() {
        _addressController.text = address.logradouro;
        _neighborhoodController.text = address.bairro;
        _cityController.text = address.localidade;
        _stateController.text = address.uf;

        // Se a API retornar complemento, preencher também
        if (address.complemento.isNotEmpty) {
          _addressComplementController.text = address.complemento;
        }

        // Formatar o CEP
        _zipCodeController.text = ViaCepService.formatCep(cep);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Endereço encontrado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingCep = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Criar membro atualizado
      final updatedMember = Member(
        id: widget.member.id,
        email: _emailController.text.trim(),
        householdId: widget.member.householdId,
        campusId: widget.member.campusId,
        firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        cpf: _cpfController.text.trim().isEmpty ? null : _cpfController.text.trim(),
        birthdate: _birthdate,
        gender: _gender,
        maritalStatus: _maritalStatus,
        marriageDate: _marriageDate,
        profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
        status: _status ?? 'visitor',
        memberType: _memberType,
        membershipDate: _membershipDate,
        conversionDate: _conversionDate,
        baptismDate: _baptismDate,
        photoUrl: widget.member.photoUrl,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        addressComplement: _addressComplementController.text.trim().isEmpty ? null : _addressComplementController.text.trim(),
        neighborhood: _neighborhoodController.text.trim().isEmpty ? null : _neighborhoodController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.member.createdAt,
        updatedAt: DateTime.now(),
      );

      // Atualizar no banco
      await ref.read(membersRepositoryProvider).updateMember(updatedMember);

      // Invalidar o provider para recarregar os dados
      ref.invalidate(currentMemberProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Seção: Dados Pessoais
            _buildSectionTitle('Dados Pessoais'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Primeiro Nome *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Sobrenome *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Apelido
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Apelido',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),

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
              onTap: () => _selectDate(context, _birthdate, (date) {
                setState(() {
                  _birthdate = date;
                });
              }),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                child: Text(
                  _birthdate != null
                      ? DateFormat('dd/MM/yyyy').format(_birthdate!)
                      : 'Selecione a data',
                  style: TextStyle(
                    color: _birthdate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gênero
            DropdownMenu<String>(
              initialSelection: _gender,
              label: const Text('Gênero'),
              leadingIcon: const Icon(Icons.wc),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'male', label: 'Masculino'),
                DropdownMenuEntry(value: 'female', label: 'Feminino'),
                DropdownMenuEntry(value: 'other', label: 'Outro'),
              ],
              onSelected: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // CPF
            TextFormField(
              controller: _cpfController,
              decoration: const InputDecoration(
                labelText: 'CPF',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
                hintText: '000.000.000-00',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Estado Civil
            DropdownMenu<String>(
              initialSelection: _maritalStatus,
              label: const Text('Estado Civil'),
              leadingIcon: const Icon(Icons.favorite),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'single', label: 'Solteiro(a)'),
                DropdownMenuEntry(value: 'married', label: 'Casado(a)'),
                DropdownMenuEntry(value: 'divorced', label: 'Divorciado(a)'),
                DropdownMenuEntry(value: 'widowed', label: 'Viúvo(a)'),
              ],
              onSelected: (value) {
                setState(() {
                  _maritalStatus = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Data de Casamento (só aparece se casado)
            if (_maritalStatus == 'married') ...[
              InkWell(
                onTap: () => _selectDate(context, _marriageDate, (date) {
                  setState(() {
                    _marriageDate = date;
                  });
                }),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Casamento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite_border),
                  ),
                  child: Text(
                    _marriageDate != null
                        ? DateFormat('dd/MM/yyyy').format(_marriageDate!)
                        : 'Selecione a data',
                    style: TextStyle(
                      color: _marriageDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Profissão
            TextFormField(
              controller: _professionController,
              decoration: const InputDecoration(
                labelText: 'Profissão',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
            ),
            const SizedBox(height: 24),

            // Seção: Endereço
            _buildSectionTitle('Endereço'),
            const SizedBox(height: 16),

            // CEP
            TextFormField(
              controller: _zipCodeController,
              decoration: InputDecoration(
                labelText: 'CEP',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.pin_drop),
                hintText: '00000-000',
                suffixIcon: _isSearchingCep
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar CEP',
                        onPressed: _searchCep,
                      ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Auto-buscar quando digitar 8 dígitos
                final cleanCep = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleanCep.length == 8 && !_isSearchingCep) {
                  _searchCep();
                }
              },
            ),
            const SizedBox(height: 16),

            // Complemento
            TextFormField(
              controller: _addressComplementController,
              decoration: const InputDecoration(
                labelText: 'Complemento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.apartment),
                hintText: 'Apto, Bloco, etc',
              ),
            ),
            const SizedBox(height: 16),

            // Endereço
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const SizedBox(height: 16),

            // Bairro
            TextFormField(
              controller: _neighborhoodController,
              decoration: const InputDecoration(
                labelText: 'Bairro',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Cidade
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Cidade',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 16),

            // Estado
            TextFormField(
              controller: _stateController,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
                hintText: 'UF',
                counterText: '',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 2,
            ),
            const SizedBox(height: 24),

            // Seção: Informações Eclesiásticas
            _buildSectionTitle('Informações Eclesiásticas'),
            const SizedBox(height: 16),

            // Status
            DropdownMenu<String>(
              initialSelection: _status,
              label: const Text('Status *'),
              leadingIcon: const Icon(Icons.info),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'visitor', label: 'Visitante'),
                DropdownMenuEntry(value: 'new_convert', label: 'Novo Convertido'),
                DropdownMenuEntry(value: 'member_active', label: 'Membro Ativo'),
                DropdownMenuEntry(value: 'member_inactive', label: 'Membro Inativo'),
                DropdownMenuEntry(value: 'transferred', label: 'Transferido'),
                DropdownMenuEntry(value: 'deceased', label: 'Falecido'),
              ],
              onSelected: (value) {
                setState(() {
                  _status = value ?? _status;
                });
              },
            ),
            const SizedBox(height: 16),

            // Data de Conversão
            InkWell(
              onTap: () => _selectDate(context, _conversionDate, (date) {
                setState(() {
                  _conversionDate = date;
                });
              }),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Conversão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.church),
                ),
                child: Text(
                  _conversionDate != null
                      ? DateFormat('dd/MM/yyyy').format(_conversionDate!)
                      : 'Selecione a data',
                  style: TextStyle(
                    color: _conversionDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Data de Batismo
            InkWell(
              onTap: () => _selectDate(context, _baptismDate, (date) {
                setState(() {
                  _baptismDate = date;
                });
              }),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Batismo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
                child: Text(
                  _baptismDate != null
                      ? DateFormat('dd/MM/yyyy').format(_baptismDate!)
                      : 'Selecione a data',
                  style: TextStyle(
                    color: _baptismDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Data de Membresia
            InkWell(
              onTap: () => _selectDate(context, _membershipDate, (date) {
                setState(() {
                  _membershipDate = date;
                });
              }),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Membresia',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_membership),
                ),
                child: Text(
                  _membershipDate != null
                      ? DateFormat('dd/MM/yyyy').format(_membershipDate!)
                      : 'Selecione a data',
                  style: TextStyle(
                    color: _membershipDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tipo de Membro
            DropdownMenu<String>(
              initialSelection: _memberType,
              label: const Text('Tipo de Membro'),
              leadingIcon: const Icon(Icons.person_outline),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'titular', label: 'Titular'),
                DropdownMenuEntry(value: 'congregado', label: 'Congregado'),
                DropdownMenuEntry(value: 'cooperador', label: 'Cooperador'),
                DropdownMenuEntry(value: 'crianca', label: 'Criança'),
              ],
              onSelected: (value) {
                setState(() {
                  _memberType = value ?? _memberType;
                });
              },
            ),
            const SizedBox(height: 24),

            // Seção: Observações
            _buildSectionTitle('Observações'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Botão Salvar
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
