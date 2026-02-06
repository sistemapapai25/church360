import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/design/community_design.dart';
import '../../../devotionals/presentation/providers/devotional_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';
import '../../../permissions/presentation/widgets/permission_gate.dart';

import '../providers/members_provider.dart';
import '../../domain/models/member.dart';

const double _pagePadding = 16;
const double _cardPadding = 16;
const double _cardRadius = 16;
const double _sectionGap = 16;
const double _iconBubbleSize = 36;

/// Tela de perfil completo do membro
class MemberProfileScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String? title;

  const MemberProfileScreen({super.key, required this.memberId, this.title});

  @override
  ConsumerState<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  late final ScrollController _scrollController;

  String get _memberId => widget.memberId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberByIdProvider(_memberId));
    final currentMemberAsync = ref.watch(currentMemberProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      body: memberAsync.when(
        data: (member) {
          if (member == null) {
            return const Center(child: Text('Membro não encontrado'));
          }
          final isCurrentMember = currentMemberAsync.maybeWhen(
            data: (currentMember) => currentMember?.id == member.id,
            orElse: () => false,
          );
          return isCurrentMember
              ? _buildMyProfileContent(context, ref, member)
              : _buildLegacyProfileContent(context, ref, member);
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
      await repo.deleteMember(_memberId);

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

  Widget _buildLegacyProfileContent(
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

          const SizedBox(height: _sectionGap),
          // Informações Pessoais
          _buildSection(
            context,
            icon: Icons.person,
            title: 'Informações Pessoais',
            child: _buildPersonalInfo(context, ref, member),
          ),
          const SizedBox(height: _sectionGap),
          // Endereço
          _buildSection(
            context,
            icon: Icons.location_on,
            title: 'Endereço',
            child: _buildAddressInfo(context, member),
          ),
          const SizedBox(height: _sectionGap),
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
          const SizedBox(height: _sectionGap),
          // Liderança (se aplicável)
          if (member.memberType == 'titular') ...[
            _buildSection(
              context,
              icon: Icons.groups,
              title: 'Liderança',
              child: _buildLeadershipInfo(context, member, ref),
            ),
            const SizedBox(height: _sectionGap),
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

  Widget _buildMyProfileContent(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
    final completion = _completionPercentage(member);
    final hasPending = completion < 100;
    final streakAsync = ref.watch(currentUserReadingStreakProvider);
    final totalAsync = ref.watch(currentUserTotalReadingsProvider);
    final readingsAsync = ref.watch(currentUserReadingsWithDevotionalProvider);
    final journeyItems = _buildJourneyItems(readingsAsync.value ?? const <Map<String, dynamic>>[]);
    final canShowLeadership = _shouldShowLeadership(member);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildMyHeader(context, ref, member),
        if (hasPending) ...[
          const SizedBox(height: _sectionGap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
            child: _buildPendingBanner(context, completion),
          ),
        ],
        const SizedBox(height: _sectionGap),
        _buildMyJourneyCard(
          context,
          member,
          streakAsync: streakAsync,
          totalAsync: totalAsync,
          readingsAsync: readingsAsync,
          journeyItems: journeyItems,
        ),
        const SizedBox(height: _sectionGap),
        _buildSection(
          context,
          icon: Icons.person,
          title: 'Informações Pessoais',
          child: _buildPersonalInfoNew(context, ref, member),
        ),
        const SizedBox(height: _sectionGap),
        _buildSection(
          context,
          icon: Icons.location_on,
          title: 'Endereço',
          child: _buildAddressInfoNew(context, member),
        ),
        if (canShowLeadership) ...[
          const SizedBox(height: _sectionGap),
          _buildSection(
            context,
            icon: Icons.groups,
            title: 'Liderança',
            child: _buildLeadershipInfo(context, member, ref),
          ),
        ],
        const SizedBox(height: _sectionGap),
        _buildSection(
          context,
          icon: Icons.qr_code,
          title: 'QR Code do Membro',
          child: _buildQRCode(context, member),
        ),
        const SizedBox(height: _sectionGap),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scrollToTop,
              icon: const Icon(Icons.arrow_upward),
              label: const Text('Subir ao topo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildMyHeader(BuildContext context, WidgetRef ref, Member member) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(_pagePadding, 12, _pagePadding, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    foregroundColor: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                const NotificationBadge(),
                const SizedBox(width: 4),
                PermissionGate(
                  permission: member.status == 'visitor' ? 'visitors.edit' : 'members.edit',
                  showLoading: false,
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/members/$_memberId/edit'),
                    tooltip: 'Editar Informações',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                      foregroundColor: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PermissionGate(
                  permission: member.status == 'visitor' ? 'visitors.delete' : 'members.delete',
                  showLoading: false,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteDialog(context, ref),
                    tooltip: 'Deletar Membro',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildHeaderAvatar(context, member),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: CommunityDesign.titleStyle(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Membro da igreja',
                        style: CommunityDesign.metaStyle(context).copyWith(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(BuildContext context, Member member) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedUrl = _resolvePhotoUrl(member);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: colorScheme.primaryContainer,
        child: resolvedUrl != null
            ? ClipOval(
                child: Image.network(
                  resolvedUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      member.initials,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 18,
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
      ),
    );
  }

  Widget _buildPendingBanner(BuildContext context, int completion) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme).copyWith(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      padding: const EdgeInsets.all(_cardPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber,
              color: Color(0xFFE67E22),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cadastro incompleto • $completion% preenchido',
              style: CommunityDesign.titleStyle(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE67E22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyJourneyCard(
    BuildContext context,
    Member member, {
    required AsyncValue<int> streakAsync,
    required AsyncValue<int> totalAsync,
    required AsyncValue<List<Map<String, dynamic>>> readingsAsync,
    required List<_JourneyItem> journeyItems,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final devotionalCount = readingsAsync.when(
      data: (items) => items.length,
      loading: () => null,
      error: (_, __) => null,
    );
    final timelineSection = readingsAsync.when(
      data: (_) => _buildJourneyTimeline(context, journeyItems),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Text(
        'Não foi possível carregar sua caminhada agora.',
        style: CommunityDesign.metaStyle(context).copyWith(
          color: colorScheme.error,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _pagePadding),
      decoration: CommunityDesign.overlayDecoration(colorScheme).copyWith(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      padding: const EdgeInsets.all(_cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _iconBubbleSize,
                height: _iconBubbleSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.timeline_outlined, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'Minha Caminhada',
                style: CommunityDesign.titleStyle(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: _sectionGap),
          Row(
            children: [
              Expanded(
                child: _JourneyMiniStat(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Sequência',
                  value: streakAsync.when(
                    data: (value) => '$value',
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
              const SizedBox(width: _sectionGap),
              Expanded(
                child: _JourneyMiniStat(
                  icon: Icons.check_circle_outline,
                  label: 'Leituras',
                  value: totalAsync.when(
                    data: (value) => '$value',
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
              const SizedBox(width: _sectionGap),
              Expanded(
                child: _JourneyMiniStat(
                  icon: Icons.menu_book_outlined,
                  label: 'Devocionais',
                  value: devotionalCount?.toString() ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: _sectionGap),
          timelineSection,
          const SizedBox(height: _sectionGap),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/my-journey'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
                side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Ver toda minha jornada',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline(BuildContext context, List<_JourneyItem> items) {
    final colorScheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Text(
        'Nenhuma atividade registrada ainda.',
        style: CommunityDesign.metaStyle(context),
      );
    }

    final children = <Widget>[];
    DateTime? currentGroup;
    for (final item in items) {
      final group = DateTime(item.when.year, item.when.month);
      final lastGroup = currentGroup;
      final isNewGroup = lastGroup == null ||
          lastGroup.year != group.year ||
          lastGroup.month != group.month;

      if (isNewGroup) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              _formatMonthYear(item.when),
              style: CommunityDesign.metaStyle(context).copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
        currentGroup = group;
      }

      children.add(_buildJourneyItem(context, item));
      children.add(const SizedBox(height: 8));
    }

    if (children.isNotEmpty) {
      children.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildJourneyItem(BuildContext context, _JourneyItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 16, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: CommunityDesign.titleStyle(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatShortDate(item.when),
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoNew(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) {
    final items = <Widget>[];
    if (_hasValue(member.email)) {
      items.add(_buildInfoRow(Icons.email, 'Email', member.email));
    }
    if (_hasValue(member.phone)) {
      items.add(_buildInfoRow(Icons.phone, 'Telefone', member.phone!));
    }
    if (member.birthdate != null) {
      final date = _formatShortDate(member.birthdate!);
      final age = member.age != null ? ' (${member.age} anos)' : '';
      items.add(_buildInfoRow(Icons.cake, 'Data de Nascimento', '$date$age'));
    }
    final genderLabel = _genderLabel(member.gender);
    if (genderLabel != null) {
      items.add(_buildInfoRow(Icons.person, 'Gênero', genderLabel));
    }
    if (_hasValue(member.profession)) {
      items.add(
        Builder(
          builder: (_) {
            final labelAsync = ref.watch(professionLabelProvider(member.profession!));
            return labelAsync.when(
              data: (label) => _buildInfoRow(Icons.work, 'Profissão', label ?? member.profession!),
              loading: () => _buildInfoRow(Icons.work, 'Profissão', member.profession!),
              error: (_, __) => _buildInfoRow(Icons.work, 'Profissão', member.profession!),
            );
          },
        ),
      );
    }
    final maritalLabel = _maritalStatusLabelOrNull(member.maritalStatus);
    if (maritalLabel != null) {
      items.add(_buildInfoRow(Icons.favorite, 'Estado Civil', maritalLabel));
    }
    if (member.credentialDate != null) {
      items.add(_buildCredentialRow(context, member.credentialDate!));
    }

    if (items.isEmpty) {
      return Text(
        'Nenhuma informação disponível.',
        style: CommunityDesign.metaStyle(context),
      );
    }

    return Column(children: items);
  }

  Widget _buildAddressInfoNew(BuildContext context, Member member) {
    final items = <Widget>[];
    if (_hasValue(member.zipCode)) {
      items.add(_buildInfoRow(Icons.pin_drop, 'CEP', member.zipCode!));
    }
    if (_hasValue(member.address)) {
      items.add(_buildInfoRow(Icons.location_on, 'Endereço', member.address!));
    }
    if (_hasValue(member.addressComplement)) {
      items.add(_buildInfoRow(Icons.home, 'Complemento', member.addressComplement!));
    }
    if (_hasValue(member.neighborhood)) {
      items.add(_buildInfoRow(Icons.map, 'Bairro', member.neighborhood!));
    }
    if (_hasValue(member.city) || _hasValue(member.state)) {
      final cityState = [
        if (_hasValue(member.city)) member.city!,
        if (_hasValue(member.state)) member.state!,
      ].join(' - ');
      items.add(_buildInfoRow(Icons.location_city, 'Cidade / Estado', cityState));
    }

    final hasFullAddress = _hasValue(member.address) && _hasValue(member.city) && _hasValue(member.state);
    if (hasFullAddress) {
      items.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
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
            icon: Icon(
              Icons.map_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              'Ver no Google Maps',
              style: CommunityDesign.metaStyle(context).copyWith(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: const StadiumBorder(),
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Text(
        'Nenhum endereço cadastrado.',
        style: CommunityDesign.metaStyle(context),
      );
    }

    return Column(children: items);
  }

  bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  String? _genderLabel(String? gender) {
    if (!_hasValue(gender)) return null;
    switch (gender!.toLowerCase()) {
      case 'male':
        return 'Masculino';
      case 'female':
        return 'Feminino';
      default:
        return gender;
    }
  }

  String? _maritalStatusLabelOrNull(String? status) {
    if (!_hasValue(status)) return null;
    return _getMaritalStatusLabel(status);
  }

  Widget _buildCredentialRow(BuildContext context, DateTime credentialDate) {
    final today = DateTime.now();
    final reference = DateTime(today.year, today.month, today.day);
    final expiry = DateTime(
      credentialDate.year,
      credentialDate.month,
      credentialDate.day,
    );
    final isValid = !expiry.isBefore(reference);
    final label = isValid ? 'Válida até' : 'Vencida em';
    final valueColor = isValid ? Colors.green : Colors.red;

    return _buildInfoRow(
      Icons.badge,
      'Credencial',
      '$label ${_formatShortDate(credentialDate)}',
      valueColor: valueColor,
    );
  }

  int _completionPercentage(Member member) {
    int totalFields = 23;
    int filledFields = 0;

    if (_hasValue(member.firstName)) filledFields++;
    if (_hasValue(member.lastName)) filledFields++;
    if (_hasValue(member.nickname)) filledFields++;
    if (_hasValue(member.email)) filledFields++;
    if (_hasValue(member.phone)) filledFields++;
    if (_hasValue(member.cpf)) filledFields++;
    if (member.birthdate != null) filledFields++;
    if (_hasValue(member.gender)) filledFields++;
    if (_hasValue(member.maritalStatus)) filledFields++;
    if (_hasValue(member.profession)) filledFields++;
    if (_hasValue(member.address)) filledFields++;
    if (_hasValue(member.addressComplement)) filledFields++;
    if (_hasValue(member.neighborhood)) filledFields++;
    if (_hasValue(member.city)) filledFields++;
    if (_hasValue(member.state)) filledFields++;
    if (_hasValue(member.zipCode)) filledFields++;
    if (member.memberType != null) filledFields++;
    if (member.membershipDate != null) filledFields++;
    if (member.conversionDate != null) filledFields++;
    if (member.baptismDate != null) filledFields++;
    if (_hasValue(member.photoUrl)) filledFields++;
    if (_hasValue(member.notes)) filledFields++;
    if (member.marriageDate != null && member.maritalStatus == 'married') {
      filledFields++;
    }

    return ((filledFields / totalFields) * 100).round();
  }

  bool _shouldShowLeadership(Member member) {
    final type = member.memberType?.toLowerCase().trim();
    return type == 'lider' || type == 'coordenador' || type == 'admin';
  }

  List<_JourneyItem> _buildJourneyItems(List<Map<String, dynamic>> readings) {
    final items = readings.map((row) {
      final readAt = _parseDateTime(row['read_at']) ??
          _parseDateTime(row['created_at']) ??
          DateTime.now();
      final devotional = row['devotionals'];
      final devotionalTitle = devotional is Map
          ? (devotional['title']?.toString().trim() ?? '')
          : '';
      final title = devotionalTitle.isNotEmpty ? devotionalTitle : 'Devocional';
      return _JourneyItem(
        when: readAt,
        title: 'Leu devocional',
        subtitle: title,
        icon: Icons.menu_book_outlined,
      );
    }).toList();

    items.sort((a, b) => b.when.compareTo(a.when));
    return items;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static const List<String> _ptMonths = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  String _formatMonthYear(DateTime date) {
    final month = _ptMonths[(date.month - 1).clamp(0, 11)];
    return '$month ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String? _resolvePhotoUrl(Member member) {
    final rawUrl = member.photoUrl;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme) {
      return rawUrl;
    }
    return Supabase.instance.client.storage
        .from('member-photos')
        .getPublicUrl(rawUrl);
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, Member member) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(_pagePadding, 12, _pagePadding, 24),
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
      child: SafeArea(
        bottom: false,
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
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    foregroundColor: colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    PermissionGate(
                      permission: member.status == 'visitor' ? 'visitors.edit' : 'members.edit',
                      showLoading: false,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.push('/members/$_memberId/edit'),
                        tooltip: 'Editar Informações',
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PermissionGate(
                      permission: member.status == 'visitor' ? 'visitors.delete' : 'members.delete',
                      showLoading: false,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _showDeleteDialog(context, ref),
                        tooltip: 'Deletar Membro',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar Integrado Centrado
            _buildAvatar(context, member),

            const SizedBox(height: 16),

            // Nome e Meta
            Text(
              member.displayName,
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            if (member.nickname != null && member.nickname!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '"${member.nickname}"',
                style: CommunityDesign.metaStyle(
                  context,
                ).copyWith(fontSize: 14, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'membro da igreja',
              style: CommunityDesign.metaStyle(context).copyWith(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 16),

            // Badges Centralizadas
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildHeaderBadge(
                  context,
                  _getStatusLabel(member.status),
                  _getStatusColor(member.status),
                ),
                if (member.memberType != null)
                  _buildHeaderBadge(
                    context,
                    _getMemberTypeLabel(member.memberType!),
                    Colors.orange,
                  ),
              ],
            ),
          ],
        ),
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
        radius: 56,
        backgroundColor: colorScheme.primaryContainer,
        child: resolvedUrl != null
            ? ClipOval(
                child: Image.network(
                  resolvedUrl,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      member.initials,
                      style: CommunityDesign.titleStyle(context).copyWith(
                        fontSize: 36,
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
                  fontSize: 36,
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
      margin: const EdgeInsets.symmetric(horizontal: _pagePadding),
      padding: const EdgeInsets.all(_cardPadding),
      decoration: CommunityDesign.overlayDecoration(colorScheme).copyWith(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _iconBubbleSize,
                height: _iconBubbleSize,
                decoration: BoxDecoration(
                  color:
                      iconBackgroundColor ??
                      colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
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
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
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
              icon: Icon(
                Icons.map_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Ver no Google Maps',
                style: CommunityDesign.metaStyle(context).copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: const StadiumBorder(),
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionStatus(BuildContext context, Member member) {
    final percentage = _completionPercentage(member);
    final isComplete = percentage == 100;

    return Column(
      children: [
        if (!isComplete) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: const Color(0xFFE67E22).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: Color(0xFFE67E22), // Laranja forte
                  size: 20,
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
          const SizedBox(height: 16),
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
          borderRadius: BorderRadius.circular(999),
          minHeight: 8,
        ),
        const SizedBox(height: 12),
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
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.groups, color: colorScheme.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ministry.name,
                          style: CommunityDesign.titleStyle(context).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            QrImageView(
              data: member.id,
              version: QrVersions.auto,
              size: 180.0,
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _iconBubbleSize,
                height: _iconBubbleSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: colorScheme.primary,
                ),
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
                        fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _iconBubbleSize,
                height: _iconBubbleSize,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: colorScheme.primary),
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
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.28)),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
      },
    );
  }

  Widget _buildHeaderBadge(
    BuildContext context,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
      case 'membro':
        return 'Membro';
      case 'visitante':
        return 'Visitante';
      case 'lider':
        return 'Líder';
      case 'voluntario':
        return 'Voluntário';
      case 'titular':
        return 'Liderança';
      case 'congregado':
        return 'Congregado';
      case 'cooperador':
        return 'Cooperador';
      case 'crianca':
        return 'Criança';
      default:
        final v = type.trim();
        var s = v.replaceAll(RegExp(r'[_-]+'), ' ').trim();
        if (s.isEmpty) return v;
        final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final normalized = words
            .map((w) => w.length == 1
                ? w.toUpperCase()
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
        return normalized.isNotEmpty ? normalized : v;
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

class _JourneyMiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _JourneyMiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _JourneyItem {
  final DateTime when;
  final String title;
  final String subtitle;
  final IconData icon;

  const _JourneyItem({
    required this.when,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
