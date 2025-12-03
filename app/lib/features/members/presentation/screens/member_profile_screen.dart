import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';

/// Tela de perfil completo do membro
class MemberProfileScreen extends ConsumerWidget {
  final String memberId;

  const MemberProfileScreen({
    super.key,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberByIdProvider(memberId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Perfil do Membro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/members/$memberId/edit');
            },
            tooltip: 'Editar Informações',
          ),
        ],
      ),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(
              child: Text('Membro não encontrado'),
            );
          }
          return _buildProfileContent(context, ref, member);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar perfil',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, Member member) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com foto, nome e badges
          _buildHeader(context, member),
          
          const SizedBox(height: 24),
          
          // Informações Pessoais
          _buildSection(
            context,
            icon: Icons.person,
            title: 'Informações Pessoais',
            child: _buildPersonalInfo(context, ref, member),
          ),
          
          const SizedBox(height: 24),
          
          // Endereço
          _buildSection(
            context,
            icon: Icons.location_on,
            title: 'Endereço',
            child: _buildAddressInfo(context, member),
          ),
          
          const SizedBox(height: 24),
          
          // Pendências do Cadastro
          _buildSection(
            context,
            icon: Icons.warning_amber,
            title: 'Pendências do Cadastro',
            child: _buildCompletionStatus(context, member),
          ),
          
          const SizedBox(height: 24),
          
          // Liderança (se aplicável)
          if (member.memberType == 'titular') ...[
            _buildSection(
              context,
              icon: Icons.stars,
              title: 'Liderança',
              child: _buildLeadershipInfo(context, member, ref),
            ),
            const SizedBox(height: 24),
          ],
          
          // QR Code do Membro
          _buildSection(
            context,
            icon: Icons.qr_code,
            title: 'QR Code do Membro',
            child: _buildQRCode(context, member),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Member member) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Builder(builder: (context) {
            final rawUrl = member.photoUrl;
            String? resolvedUrl;
            if (rawUrl != null && rawUrl.isNotEmpty) {
              final parsed = Uri.tryParse(rawUrl);
              if (parsed != null && parsed.hasScheme) {
                resolvedUrl = rawUrl;
              } else {
                resolvedUrl = Supabase.instance.client.storage
                    .from('member-photos')
                    .getPublicUrl(rawUrl);
              }
            }

            return CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              child: resolvedUrl != null
                  ? ClipOval(
                      child: Image.network(
                        resolvedUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            member.initials,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          );
                        },
                      ),
                    )
                  : Text(
                      member.initials,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
            );
          }),
          const SizedBox(width: 20),
          // Nome e badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (member.nickname != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${member.nickname}"',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Badge de Status
                    _buildBadge(
                      _getStatusLabel(member.status),
                      _getStatusColor(member.status),
                    ),
                    // Badge de Tipo
                    if (member.memberType != null)
                      _buildBadge(
                        _getMemberTypeLabel(member.memberType!),
                        Colors.orange,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(BuildContext context, WidgetRef ref, Member member) {
    return Column(
      children: [
        _buildInfoRow(Icons.email, 'Email', member.email),
        _buildInfoRow(Icons.phone, 'Telefone', member.phone ?? 'Não informado'),
        _buildInfoRow(
          Icons.cake,
          'Data de Nascimento',
          member.birthdate != null
              ? '${member.birthdate!.day.toString().padLeft(2, '0')}/${member.birthdate!.month.toString().padLeft(2, '0')}/${member.birthdate!.year}${member.age != null ? ' (${member.age} anos)' : ''}'
              : 'Não informado',
        ),
        _buildInfoRow(
          Icons.person,
          'Gênero',
          member.gender == 'male'
              ? 'Masculino'
              : member.gender == 'female'
                  ? 'Feminino'
                  : 'Não informado',
        ),
        Builder(
          builder: (_) {
            if (member.profession == null) {
              return _buildInfoRow(Icons.work, 'Profissão', 'Não informado');
            }
            final labelAsync = ref.watch(professionLabelProvider(member.profession!));
            return labelAsync.when(
              data: (label) => _buildInfoRow(Icons.work, 'Profissão', label ?? member.profession!),
              loading: () => _buildInfoRow(Icons.work, 'Profissão', 'Carregando...'),
              error: (_, __) => _buildInfoRow(Icons.work, 'Profissão', member.profession!),
            );
          },
        ),
        _buildInfoRow(
          Icons.favorite,
          'Estado Civil',
          _getMaritalStatusLabel(member.maritalStatus),
        ),
        if (member.maritalStatus == 'married' && member.marriageDate != null)
          _buildInfoRow(
            Icons.calendar_today,
            'Data de Casamento',
            '${member.marriageDate!.day.toString().padLeft(2, '0')}/${member.marriageDate!.month.toString().padLeft(2, '0')}/${member.marriageDate!.year}',
          ),
        // Credencial Ativa (placeholder - implementar depois)
        _buildInfoRow(
          Icons.badge,
          'Credencial Ativa',
          'Válida até 17/10/2030',
          valueColor: Colors.green,
        ),
        // Consentimento LGPD (placeholder - implementar depois)
          _buildInfoRowWithAction(
            Icons.check_circle,
            'Consentimento LGPD',
            'Concedido',
            'Ver Política',
            () {
            final url = Uri.parse('https://www.gov.br/anpd/pt-br');
            launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
      ],
    );
  }

  Widget _buildAddressInfo(BuildContext context, Member member) {
    return Column(
      children: [
        _buildInfoRow(Icons.pin_drop, 'CEP', member.zipCode ?? 'Não informado'),
        _buildInfoRow(Icons.location_on, 'Endereço', member.address ?? 'Não informado'),
        _buildInfoRow(Icons.home, 'Complemento', member.addressComplement ?? 'Não informado'),
        _buildInfoRow(Icons.map, 'Bairro', member.neighborhood ?? 'Não informado'),
        _buildInfoRow(
          Icons.location_city,
          'Cidade',
          member.city != null && member.state != null
              ? '${member.city} - ${member.state}'
              : member.state ?? 'Não informado',
        ),
        if (member.address != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final address = Uri.encodeComponent(
                '${member.address}, ${member.city ?? ''}, ${member.state ?? ''}',
              );
              final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                Icon(Icons.map, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Ver no Google Maps',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionStatus(BuildContext context, Member member) {
    // Calcular completude do cadastro
    int totalFields = 23;
    int filledFields = 0;

    if (member.firstName != null && member.firstName!.isNotEmpty) filledFields++;
    if (member.lastName != null && member.lastName!.isNotEmpty) filledFields++;
    if (member.nickname != null && member.nickname!.isNotEmpty) filledFields++;
    if (member.email.isNotEmpty) filledFields++;
    if (member.phone != null && member.phone!.isNotEmpty) filledFields++;
    if (member.cpf != null && member.cpf!.isNotEmpty) filledFields++;
    if (member.birthdate != null) filledFields++;
    if (member.gender != null) filledFields++;
    if (member.maritalStatus != null) filledFields++;
    if (member.profession != null && member.profession!.isNotEmpty) filledFields++;
    if (member.address != null && member.address!.isNotEmpty) filledFields++;
    if (member.addressComplement != null && member.addressComplement!.isNotEmpty) filledFields++;
    if (member.neighborhood != null && member.neighborhood!.isNotEmpty) filledFields++;
    if (member.city != null && member.city!.isNotEmpty) filledFields++;
    if (member.state != null && member.state!.isNotEmpty) filledFields++;
    if (member.zipCode != null && member.zipCode!.isNotEmpty) filledFields++;
    if (member.memberType != null) filledFields++;
    if (member.membershipDate != null) filledFields++;
    if (member.conversionDate != null) filledFields++;
    if (member.baptismDate != null) filledFields++;
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) filledFields++;
    if (member.notes != null && member.notes!.isNotEmpty) filledFields++;
    if (member.marriageDate != null && member.maritalStatus == 'married') filledFields++;

    int percentage = ((filledFields / totalFields) * 100).round();
    bool isComplete = percentage == 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isComplete ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isComplete ? Icons.check_circle : Icons.warning_amber,
                    color: isComplete ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isComplete ? 'Cadastro Completo!' : 'Cadastro Incompleto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percentage% Completo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isComplete
                ? 'Todas as informações obrigatórias foram preenchidas.'
                : 'Algumas informações ainda precisam ser preenchidas.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadershipInfo(BuildContext context, Member member, WidgetRef ref) {
    final ministriesAsync = ref.watch(memberMinistriesProvider(member.id));

    return ministriesAsync.when(
      data: (ministries) {
        if (ministries.isEmpty) {
          return Text(
            'Não lidera nenhum departamento',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          );
        }

        return Column(
          children: ministries.map((ministry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.book, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ministry.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ministry.description ?? 'Líder do departamento',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Text(
        'Erro ao carregar departamentos: $error',
        style: TextStyle(
          fontSize: 14,
          color: Colors.red,
        ),
      ),
    );
  }

  Widget _buildQRCode(BuildContext context, Member member) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: QrImageView(
              data: member.id,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ID: ${member.id}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithAction(
    IconData icon,
    String label,
    String value,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'visitor':
        return 'Visitante';
      case 'new_convert':
        return 'Novo Convertido';
      case 'member_active':
        return 'Ativo';
      case 'member_inactive':
        return 'Inativo';
      case 'transferred':
        return 'Transferido';
      case 'deceased':
        return 'Falecido';
      default:
        return 'Desconhecido';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'visitor':
        return Colors.blue;
      case 'new_convert':
        return Colors.purple;
      case 'member_active':
        return Colors.green;
      case 'member_inactive':
        return Colors.grey;
      case 'transferred':
        return Colors.orange;
      case 'deceased':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  String _getMemberTypeLabel(String type) {
    switch (type) {
      case 'titular':
        return 'Liderança';
      case 'congregado':
        return 'Congregado';
      case 'cooperador':
        return 'Cooperador';
      case 'crianca':
        return 'Criança';
      default:
        return type;
    }
  }

  String _getMaritalStatusLabel(String? status) {
    switch (status) {
      case 'single':
        return 'Solteiro(a)';
      case 'married':
        return 'Casado(a)';
      case 'divorced':
        return 'Divorciado(a)';
      case 'widowed':
        return 'Viúvo(a)';
      default:
        return 'Não informado';
    }
  }
}
