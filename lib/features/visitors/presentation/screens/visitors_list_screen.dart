import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/visitors_provider.dart';
import '../../domain/models/visitor.dart';
import '../../../../core/widgets/permission_widget.dart';

/// Tela de listagem de visitantes
class VisitorsListScreen extends ConsumerStatefulWidget {
  const VisitorsListScreen({super.key});

  @override
  ConsumerState<VisitorsListScreen> createState() => _VisitorsListScreenState();
}

class _VisitorsListScreenState extends ConsumerState<VisitorsListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Buscar todos os visitantes
    final visitorsAsync = ref.watch(allVisitorsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header com título
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Gestão de Visitantes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Campo de busca
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou apelido...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Lista de visitantes
          Expanded(
            child: visitorsAsync.when(
              data: (visitors) {
                // Filtrar por pesquisa
                var filteredVisitors = visitors;
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredVisitors = visitors.where((visitor) {
                    return visitor.displayName.toLowerCase().contains(query) ||
                        (visitor.nickname?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                return _buildVisitorsList(context, filteredVisitors);
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
                      'Erro ao carregar visitantes',
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
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(allVisitorsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: LeaderOnlyWidget(
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/visitors/new'),
          icon: const Icon(Icons.add),
          label: const Text('Novo Visitante'),
        ),
      ),
    );
  }

  Widget _buildVisitorsList(BuildContext context, List<Visitor> filteredVisitors) {
    if (filteredVisitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum visitante encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredVisitors.length,
      itemBuilder: (context, index) {
        final visitor = filteredVisitors[index];
        return _VisitorCard(visitor: visitor);
      },
    );
  }

}

/// Widget de card de visitante com design rico
class _VisitorCard extends ConsumerWidget {
  final Visitor visitor;

  const _VisitorCard({required this.visitor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Foto, Nome, Apelido e Status
            Row(
              children: [
                // Foto do visitante
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  backgroundImage: visitor.photoUrl != null
                      ? NetworkImage(visitor.photoUrl!)
                      : null,
                  child: visitor.photoUrl == null
                      ? Text(
                          visitor.initials,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Nome e apelido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (visitor.nickname != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '"${visitor.nickname}"',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Visitante',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Visitante',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Informações do visitante
            _buildInfoRow(Icons.phone, visitor.phone ?? 'Sem telefone'),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.person,
              visitor.gender == 'male'
                  ? 'Masculino'
                  : visitor.gender == 'female'
                      ? 'Feminino'
                      : 'Não informado',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.cake,
              visitor.age != null ? '${visitor.age} anos' : 'Idade não informada',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              visitor.state ?? 'GO',
            ),
            const SizedBox(height: 16),
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showVisitorDialog(context, ref, visitor);
                    },
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('Ver Perfil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/visitors/${visitor.id}/edit');
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _showVisitorDialog(BuildContext context, WidgetRef ref, Visitor visitor) {
    showDialog(
      context: context,
      builder: (context) => _VisitorDetailDialog(visitor: visitor),
    );
  }
}

/// Dialog de detalhes do visitante
class _VisitorDetailDialog extends ConsumerWidget {
  final Visitor visitor;

  const _VisitorDetailDialog({required this.visitor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com foto, nome e status
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  // Foto
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: visitor.photoUrl != null
                        ? NetworkImage(visitor.photoUrl!)
                        : null,
                    child: visitor.photoUrl == null
                        ? Text(
                            visitor.initials,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Nome
                  Text(
                    visitor.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Apelido
                  if (visitor.nickname != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${visitor.nickname}"',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Visitante',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Conteúdo
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações Pessoais
                    _buildSectionTitle('Informações Pessoais'),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.phone,
                      'Telefone',
                      visitor.phone ?? 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.cake,
                      'Data de Nascimento',
                      visitor.birthDate != null
                          ? '${visitor.birthDate!.day.toString().padLeft(2, '0')}/${visitor.birthDate!.month.toString().padLeft(2, '0')}/${visitor.birthDate!.year}${visitor.age != null ? ' (${visitor.age} anos)' : ''}'
                          : 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.person,
                      'Gênero',
                      visitor.gender == 'male'
                          ? 'Masculino'
                          : visitor.gender == 'female'
                              ? 'Feminino'
                              : 'Não informado',
                    ),
                    const SizedBox(height: 24),
                    // Endereço
                    _buildSectionTitle('Endereço'),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      Icons.pin_drop,
                      'CEP',
                      visitor.zipCode ?? 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.location_on,
                      'Endereço',
                      visitor.address ?? 'Não informado',
                    ),
                    _buildInfoItem(
                      Icons.location_city,
                      'Cidade/UF',
                      visitor.city != null && visitor.state != null
                          ? '${visitor.city} - ${visitor.state}'
                          : visitor.state ?? 'Não informado',
                    ),
                    // Link Google Maps
                    if (visitor.address != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final address = Uri.encodeComponent(
                            '${visitor.address}, ${visitor.city ?? ''}, ${visitor.state ?? ''}',
                          );
                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$address');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Row(
                          children: [
                            const SizedBox(width: 32),
                            Icon(Icons.map, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Ver no Google Maps',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Botões de ação
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/members/${visitor.id}/profile');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Perfil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Fechar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


