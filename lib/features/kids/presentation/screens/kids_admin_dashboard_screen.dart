import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/community_design.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../domain/models/kids_child_profile.dart';
import '../providers/kids_providers.dart';
import '../widgets/kids_checkin_panel.dart';
import '../../../../core/layout/readable_width.dart';

/// Painel Administrativo do Módulo Kids
/// Permite gerenciar todas as crianças da igreja, seus vínculos e check-in.
class KidsAdminDashboardScreen extends ConsumerStatefulWidget {
  const KidsAdminDashboardScreen({super.key});

  @override
  ConsumerState<KidsAdminDashboardScreen> createState() => _KidsAdminDashboardScreenState();
}

class _KidsAdminDashboardScreenState extends ConsumerState<KidsAdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: Text('Kids - Gestão', style: CommunityDesign.titleStyle(context)),
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Crianças', icon: Icon(Icons.child_care)),
            Tab(text: 'Check-in', icon: Icon(Icons.qr_code_scanner)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // Navegar para criação de membro pré-setado como criança
              context.push(Uri(path: '/members/new', queryParameters: {'type': 'crianca', 'staff': '1'}).toString());
            },
            tooltip: 'Cadastrar Criança',
          ),
        ],
      ),
      body: ReadableWidth(maxWidth: 1200, child: TabBarView(
        controller: _tabController,
        children: [
          _buildChildrenTab(),
          const KidsCheckinPanel(),
        ],
      )),
    );
  }

  Widget _buildChildrenTab() {
    // Busca todos os membros
    final allMembersAsync = ref.watch(allMembersProvider);
    // Selos de alerta (K2): alergia/intolerância e "sem foto". Se a ficha
    // não carregar, a lista aparece sem selo.
    final profiles = ref
        .watch(kidsChildProfilesProvider)
        .maybeWhen(data: (v) => v, orElse: () => const <String, KidsChildProfile>{});

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar criança',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _query = '';
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: allMembersAsync.when(
            data: (members) {
              // Filtrar crianças (ex: <= 12 anos ou tipo 'crianca')
              // E aplicar filtro de busca
              final children = members.where((m) {
                final isChild = (m.memberType == 'crianca') || ((m.age ?? 99) <= 12);
                if (!isChild) return false;

                if (_query.isEmpty) return true;
                final q = _query.toLowerCase();
                return m.displayName.toLowerCase().contains(q) ||
                       m.email.toLowerCase().contains(q);
              }).toList();

              if (children.isEmpty) {
                return const Center(child: Text('Nenhuma criança encontrada'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  final profile = profiles[child.id];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: child.photoUrl != null ? NetworkImage(child.photoUrl!) : null,
                        child: child.photoUrl == null ? Text(child.initials) : null,
                      ),
                      title: Text(child.displayName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${child.age ?? "?"} anos • Família: ${child.householdId != null ? "Vinculada" : "Sem vínculo"}',
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (profile?.hasFoodAlert ?? false)
                                _alertChip(context, Icons.warning_amber_rounded, 'Alergia'),
                              if (!(profile?.imageConsent ?? false))
                                _alertChip(context, Icons.no_photography, 'Sem foto'),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.family_restroom),
                            tooltip: 'Gerir Família',
                            onPressed: () {
                                context.push('/members/${child.id}');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Editar Dados',
                            onPressed: () {
                              context.push('/members/${child.id}/edit');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings),
                            tooltip: 'Check-in e Responsáveis',
                            onPressed: () {
                              context.push(
                                '/kids/${child.id}/registration?name=${Uri.encodeComponent(child.displayName)}',
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        context.push('/members/${child.id}');
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Erro: $e')),
          ),
        ),
      ],
    );
  }

  Widget _alertChip(BuildContext context, IconData icon, String label) {
    final error = Theme.of(context).colorScheme.error;
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 16, color: error),
      label: Text(label, style: TextStyle(color: error, fontSize: 12)),
      side: BorderSide(color: error.withValues(alpha: 0.4)),
    );
  }
}
