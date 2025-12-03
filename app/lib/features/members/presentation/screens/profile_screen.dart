import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/members_provider.dart';

/// Tela de Perfil do Usuário
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingPhoto = false;

  /// Mostrar opções de escolha de foto (Câmera ou Galeria)
  Future<void> _showPhotoOptions(BuildContext context, String memberId) async {
    final ImagePicker picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                if (image != null && mounted) {
                  await _uploadPhoto(image, memberId);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1024,
                  maxHeight: 1024,
                  imageQuality: 85,
                );
                if (image != null && mounted) {
                  await _uploadPhoto(image, memberId);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Fazer upload da foto para o Supabase Storage
  Future<void> _uploadPhoto(XFile image, String memberId) async {
    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      // Gerar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = image.path.split('.').last;
      final fileName = 'member_${memberId}_$timestamp.$extension';

      // Upload para Supabase Storage
      final imageFile = File(image.path);
      await supabase.storage
          .from('member-photos')
          .upload(fileName, imageFile);

      // Obter URL pública
      final publicUrl = supabase.storage
          .from('member-photos')
          .getPublicUrl(fileName);

      // Atualizar a foto do membro no banco de dados
      await supabase
          .from('user_account')
          .update({'photo_url': publicUrl})
          .eq('id', memberId);

      // Invalidar o provider para recarregar os dados
      ref.invalidate(currentMemberProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto atualizada com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(currentMemberProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        centerTitle: true,
      ),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return _buildProfileNotFound(context, currentUser?.email);
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header com foto, nome e botão editar
                _buildProfileHeader(context, member),

                const SizedBox(height: 16),

                // Ficha Cadastral
                _buildProfileCard(context, member),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar perfil',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tela quando o perfil não é encontrado
  Widget _buildProfileNotFound(BuildContext context, String? userEmail) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Perfil não encontrado',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Não encontramos um perfil de membro vinculado à sua conta.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (userEmail != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Botão para criar perfil
            ElevatedButton.icon(
              onPressed: () {
                // Navegar para tela de criação de perfil
                context.push('/members/new', extra: {'userEmail': userEmail});
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Criar Meu Perfil'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ou',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Como resolver?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionStep(
                      context,
                      '1',
                      'Entre em contato com a administração da igreja',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '2',
                      'Informe seu email de login: ${userEmail ?? "não disponível"}',
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      context,
                      '3',
                      'Solicite a criação do seu perfil de membro',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                // Voltar para a tela anterior
                context.pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Passo de instrução
  Widget _buildInstructionStep(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Header do perfil com foto, nome e botão editar
  Widget _buildProfileHeader(BuildContext context, dynamic member) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Foto do perfil com botão de edição
          Stack(
            children: [
              // Foto do perfil
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: _isUploadingPhoto
                    ? const CircularProgressIndicator()
                    : member.photoUrl != null && member.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              member.photoUrl!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person, size: 60, color: Colors.grey);
                              },
                            ),
                          )
                        : const Icon(Icons.person, size: 60, color: Colors.grey),
              ),

              // Botão de editar foto (ícone de lápis)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPhoto
                      ? null
                      : () => _showPhotoOptions(context, member.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Nome completo
          Text(
            member.fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getStatusLabel(member.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botão Editar Perfil
          ElevatedButton.icon(
            onPressed: () {
              context.push('/profile/edit', extra: member);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Editar Perfil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Card com a ficha cadastral
  Widget _buildProfileCard(BuildContext context, dynamic member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Icon(
                    Icons.assignment,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ficha Cadastral',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Dados Pessoais
              _buildSectionTitle(context, 'Dados Pessoais'),
              const SizedBox(height: 12),
              _buildInfoRow(context, 'Nome Completo', member.fullName),
              _buildInfoRow(context, 'Email', member.email ?? 'Não informado'),
              _buildInfoRow(context, 'Telefone', member.phone ?? 'Não informado'),
              _buildInfoRow(
                context,
                'Data de Nascimento',
                member.birthdate != null
                    ? DateFormat('dd/MM/yyyy').format(member.birthdate!)
                    : 'Não informado',
              ),
              _buildInfoRow(
                context,
                'Idade',
                member.age != null ? '${member.age} anos' : 'Não informado',
              ),
              _buildInfoRow(context, 'Sexo', _getGenderLabel(member.gender)),
              _buildInfoRow(
                context,
                'Estado Civil',
                _getMaritalStatusLabel(member.maritalStatus),
              ),

              const Divider(height: 24),

              // Endereço
              _buildSectionTitle(context, 'Endereço'),
              const SizedBox(height: 12),
              _buildInfoRow(context, 'Endereço', member.address ?? 'Não informado'),
              _buildInfoRow(context, 'Cidade', member.city ?? 'Não informado'),
              _buildInfoRow(context, 'Estado', member.state ?? 'Não informado'),
              _buildInfoRow(context, 'CEP', member.zipCode ?? 'Não informado'),

              const Divider(height: 24),

              // Informações Eclesiásticas
              _buildSectionTitle(context, 'Informações Eclesiásticas'),
              const SizedBox(height: 12),
              _buildInfoRow(context, 'Status', _getStatusLabel(member.status)),
              _buildInfoRow(
                context,
                'Data de Conversão',
                member.conversionDate != null
                    ? DateFormat('dd/MM/yyyy').format(member.conversionDate!)
                    : 'Não informado',
              ),
              _buildInfoRow(
                context,
                'Data de Batismo',
                member.baptismDate != null
                    ? DateFormat('dd/MM/yyyy').format(member.baptismDate!)
                    : 'Não informado',
              ),
              _buildInfoRow(
                context,
                'Data de Membresia',
                member.membershipDate != null
                    ? DateFormat('dd/MM/yyyy').format(member.membershipDate!)
                    : 'Não informado',
              ),

              if (member.notes != null && member.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                _buildSectionTitle(context, 'Observações'),
                const SizedBox(height: 12),
                Text(
                  member.notes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Título de seção
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  /// Linha de informação
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Converter status para label
  String _getStatusLabel(String status) {
    switch (status) {
      case 'visitor':
        return 'Visitante';
      case 'new_convert':
        return 'Novo Convertido';
      case 'member_active':
        return 'Membro Ativo';
      case 'member_inactive':
        return 'Membro Inativo';
      case 'transferred':
        return 'Transferido';
      case 'deceased':
        return 'Falecido';
      default:
        return status;
    }
  }

  /// Converter gênero para label
  String _getGenderLabel(String? gender) {
    if (gender == null) return 'Não informado';
    switch (gender) {
      case 'male':
        return 'Masculino';
      case 'female':
        return 'Feminino';
      case 'other':
        return 'Outro';
      default:
        return gender;
    }
  }

  /// Converter estado civil para label
  String _getMaritalStatusLabel(String? maritalStatus) {
    if (maritalStatus == null) return 'Não informado';
    switch (maritalStatus) {
      case 'single':
        return 'Solteiro(a)';
      case 'married':
        return 'Casado(a)';
      case 'divorced':
        return 'Divorciado(a)';
      case 'widowed':
        return 'Viúvo(a)';
      default:
        return maritalStatus;
    }
  }
}
