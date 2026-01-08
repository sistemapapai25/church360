import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/permission_widget.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';

/// Tela de perfil completo do membro
class MemberProfileScreen extends ConsumerWidget {
  final String memberId;
  final String? title;

  const MemberProfileScreen({super.key, required this.memberId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberByIdProvider(memberId));

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(child: Text('Membro não encontrado'));
          }
          return _buildProfileContent(context, ref, member);
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
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: CommunityDesign.contentStyle(context).copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Membro'),
        content: const Text(
          'Tem certeza que deseja deletar este membro?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMember(context, ref);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMember(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(membersRepositoryProvider);
      await repo.deleteMember(memberId);

      if (context.mounted) {
        // Invalida a lista de membros para atualizar
        ref.invalidate(allMembersProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro deletado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // Se estiver na tela de lista, volta. Se estiver na tela de perfil (meu perfil), talvez logout?
        // Assumindo que essa tela é acessada via lista de membros.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/members');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar membro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com foto, nome e badges
          _buildHeader(context, ref, member),

          const SizedBox(height: 16),
          // Informações Pessoais
          _buildSection(
            context,
            icon: Icons.person,
            title: 'Informações Pessoais',
            child: _buildPersonalInfo(context, ref, member),
          ),
          const SizedBox(height: 16),
          // Endereço
          _buildSection(
            context,
            icon: Icons.location_on,
            title: 'Endereço',
            child: _buildAddressInfo(context, member),
          ),
          const SizedBox(height: 16),
          // Pendências do Cadastro
          _buildSection(
            context,
            icon: Icons.warning_amber,
            title: 'Pendências do Cadastro',
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            iconBackgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
            titleColor: Theme.of(context).colorScheme.onSurface,
            child: _buildCompletionStatus(context, member),
          ),
          const SizedBox(height: 16),
          // Liderança (se aplicável)
          if (member.memberType == 'titular') ...[
            _buildSection(
              context,
              icon: Icons.stars,
              title: 'Liderança',
              child: _buildLeadershipInfo(context, member, ref),
            ),
            const SizedBox(height: 16),
          ],
          // QR Code do Membro
          _buildSection(
            context,
            icon: Icons.qr_code,
            title: 'QR Code do Membro',
            child: _buildQRCode(context, member),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, Member member) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ações do Topo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/members/$memberId/edit'),
                    tooltip: 'Editar Informações',
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                  CoordinatorOnlyWidget(
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteDialog(context, ref),
                      tooltip: 'Deletar Membro',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar Integrado Centrado
          _buildAvatar(context, member),

          const SizedBox(height: 16),

          // Nome e Meta
          Text(
            member.displayName,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (member.nickname != null && member.nickname!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"${member.nickname}"',
              style: CommunityDesign.metaStyle(
                context,
              ).copyWith(fontSize: 16, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // Badges Centralizadas
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              CommunityDesign.badge(
                context,
                _getStatusLabel(member.status),
                _getStatusColor(member.status),
              ),
              if (member.memberType != null)
                CommunityDesign.badge(
                  context,
                  _getMemberTypeLabel(member.memberType!),
                  Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, Member member) {
    final colorScheme = Theme.of(context).colorScheme;
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.1),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: colorScheme.primaryContainer,
        child: resolvedUrl != null
            ? ClipOval(
                child: Image.network(
                  resolvedUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      member.initials,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    );
                  },
                ),
              )
            : Text(
                member.initials,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    Color? iconColor,
    Color? iconBackgroundColor,
    Color? titleColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      iconBackgroundColor ??
                      colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
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
            final labelAsync = ref.watch(
              professionLabelProvider(member.profession!),
            );
            return labelAsync.when(
              data: (label) => _buildInfoRow(
                Icons.work,
                'Profissão',
                label ?? member.profession!,
              ),
              loading: () =>
                  _buildInfoRow(Icons.work, 'Profissão', 'Carregando...'),
              error: (_, __) =>
                  _buildInfoRow(Icons.work, 'Profissão', member.profession!),
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
        _buildInfoRow(
          Icons.location_on,
          'Endereço',
          member.address ?? 'Não informado',
        ),
        _buildInfoRow(
          Icons.home,
          'Complemento',
          member.addressComplement ?? 'Não informado',
        ),
        _buildInfoRow(
          Icons.map,
          'Bairro',
          member.neighborhood ?? 'Não informado',
        ),
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
              final url = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=$address',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ver no Google Maps',
                  style: CommunityDesign.metaStyle(context).copyWith(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
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

    if (member.firstName != null && member.firstName!.isNotEmpty) {
      filledFields++;
    }
    if (member.lastName != null && member.lastName!.isNotEmpty) {
      filledFields++;
    }
    if (member.nickname != null && member.nickname!.isNotEmpty) {
      filledFields++;
    }
    if (member.email.isNotEmpty) {
      filledFields++;
    }
    if (member.phone != null && member.phone!.isNotEmpty) {
      filledFields++;
    }
    if (member.cpf != null && member.cpf!.isNotEmpty) {
      filledFields++;
    }
    if (member.birthdate != null) {
      filledFields++;
    }
    if (member.gender != null) {
      filledFields++;
    }
    if (member.maritalStatus != null) {
      filledFields++;
    }
    if (member.profession != null && member.profession!.isNotEmpty) {
      filledFields++;
    }
    if (member.address != null && member.address!.isNotEmpty) {
      filledFields++;
    }
    if (member.addressComplement != null &&
        member.addressComplement!.isNotEmpty) {
      filledFields++;
    }
    if (member.neighborhood != null && member.neighborhood!.isNotEmpty) {
      filledFields++;
    }
    if (member.city != null && member.city!.isNotEmpty) {
      filledFields++;
    }
    if (member.state != null && member.state!.isNotEmpty) {
      filledFields++;
    }
    if (member.zipCode != null && member.zipCode!.isNotEmpty) {
      filledFields++;
    }
    if (member.memberType != null) {
      filledFields++;
    }
    if (member.membershipDate != null) {
      filledFields++;
    }
    if (member.conversionDate != null) {
      filledFields++;
    }
    if (member.baptismDate != null) {
      filledFields++;
    }
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      filledFields++;
    }
    if (member.notes != null && member.notes!.isNotEmpty) {
      filledFields++;
    }
    if (member.marriageDate != null && member.maritalStatus == 'married') {
      filledFields++;
    }

    int percentage = ((filledFields / totalFields) * 100).round();
    bool isComplete = percentage == 100;

    return Column(
      children: [
        if (!isComplete) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5), // Laranja pastel muito claro
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE1C2)), // Borda suave
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: Color(0xFFE67E22), // Laranja forte
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cadastro Incompleto',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      color: const Color(0xFFE67E22),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24), // Espaço maior entre card e barra
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentage% Preenchido',
              style: CommunityDesign.metaStyle(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            if (isComplete)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: const Color(0xFFE6E6E6), // Cinza claro
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFFF39C12), // Laranja vibrante
          ),
          borderRadius: BorderRadius.circular(4),
          minHeight: 8,
        ),
        const SizedBox(height: 12), // Espaço para a legenda inferior
        Center(
          child: Text(
            isComplete
                ? 'Todas as informações obrigatórias foram preenchidas.'
                : 'Algumas informações ainda precisam ser preenchidas.',
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLeadershipInfo(
    BuildContext context,
    Member member,
    WidgetRef ref,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final ministriesAsync = ref.watch(memberMinistriesProvider(member.id));

    return ministriesAsync.when(
      data: (ministries) {
        if (ministries.isEmpty) {
          return Text(
            'Não lidera nenhum departamento',
            style: CommunityDesign.contentStyle(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          );
        }

        return Column(
          children: ministries.map((ministry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(CommunityDesign.radius),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommunityDesign.badge(
                          context,
                          ministry.name,
                          colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ministry.description ?? 'Líder do departamento',
                          style: CommunityDesign.metaStyle(context),
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
      error:
          (error, stack) => Text(
            'Erro ao carregar departamentos: $error',
            style: CommunityDesign.contentStyle(
              context,
            ).copyWith(color: Theme.of(context).colorScheme.error),
          ),
    );
  }

  Widget _buildQRCode(BuildContext context, Member member) {
    return Center(
      child: Column(
        children: [
          QrImageView(
            data: member.id,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.transparent,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${member.id}',
            style: CommunityDesign.metaStyle(
              context,
            ).copyWith(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: CommunityDesign.metaStyle(
                        context,
                      ).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRowWithAction(
    IconData icon,
    String label,
    String value,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: CommunityDesign.metaStyle(
                        context,
                      ).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          value,
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: onAction,
                          child: CommunityDesign.badge(
                            context,
                            actionLabel,
                            Colors.blue,
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
      },
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
        return Colors.red;
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
