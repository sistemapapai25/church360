import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/church_info_provider.dart';
import '../../domain/models/church_info.dart';

/// Tela de informações da igreja
class ChurchInfoScreen extends ConsumerWidget {
  const ChurchInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchInfoAsync = ref.watch(churchInfoProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Voltar para a tela Home ao invés de sair do app
        context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('A Igreja'),
          centerTitle: true,
        ),
        body: churchInfoAsync.when(
          data: (churchInfo) {
            if (churchInfo == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.church_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Informações não disponíveis',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'As informações da igreja ainda não foram cadastradas',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(churchInfoProvider);
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo e Nome
                    _buildHeader(context, churchInfo),
                    const SizedBox(height: 24),

                    // Missão
                    if (churchInfo.mission != null) ...[
                      _buildSection(
                        context,
                        icon: Icons.flag_outlined,
                        title: 'Missão',
                        content: churchInfo.mission!,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Visão
                    if (churchInfo.vision != null) ...[
                      _buildSection(
                        context,
                        icon: Icons.visibility_outlined,
                        title: 'Visão',
                        content: churchInfo.vision!,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Valores
                    if (churchInfo.values != null && churchInfo.values!.isNotEmpty) ...[
                      _buildValuesSection(context, churchInfo.values!),
                      const SizedBox(height: 16),
                    ],

                    // História
                    if (churchInfo.history != null) ...[
                      _buildSection(
                        context,
                        icon: Icons.history_outlined,
                        title: 'Nossa História',
                        content: churchInfo.history!,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Horários de Culto
                    if (churchInfo.serviceTimes != null && churchInfo.serviceTimes!.isNotEmpty) ...[
                      _buildServiceTimesSection(context, churchInfo.serviceTimes!),
                      const SizedBox(height: 16),
                    ],

                    // Pastores
                    if (churchInfo.pastors != null && churchInfo.pastors!.isNotEmpty) ...[
                      _buildPastorsSection(context, churchInfo.pastors!),
                      const SizedBox(height: 16),
                    ],

                    // Contato
                    _buildContactSection(context, churchInfo),
                    const SizedBox(height: 16),

                    // Redes Sociais
                    if (churchInfo.socialMedia != null && churchInfo.socialMedia!.isNotEmpty) ...[
                      _buildSocialMediaSection(context, churchInfo.socialMedia!),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
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
                Text('Erro ao carregar informações: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(churchInfoProvider);
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChurchInfo churchInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Logo
            if (churchInfo.logoUrl != null && churchInfo.logoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  churchInfo.logoUrl!,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.church,
                      size: 120,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),
              )
            else
              Icon(
                Icons.church,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(height: 16),

            // Nome
            Text(
              churchInfo.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required IconData icon, required String title, required String content}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValuesSection(BuildContext context, List<String> values) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Nossos Valores',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...values.map((value) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTimesSection(BuildContext context, List<ServiceTime> serviceTimes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Horários de Culto',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...serviceTimes.map((serviceTime) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          serviceTime.day,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceTime.time,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (serviceTime.description != null)
                              Text(
                                serviceTime.description!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPastorsSection(BuildContext context, List<Pastor> pastors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Liderança',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...pastors.map((pastor) => _buildPastorCard(context, pastor)),
          ],
        ),
      ),
    );
  }

  Widget _buildPastorCard(BuildContext context, Pastor pastor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Foto
            CircleAvatar(
              radius: 30,
              backgroundImage: pastor.photoUrl != null && pastor.photoUrl!.isNotEmpty
                  ? NetworkImage(pastor.photoUrl!)
                  : null,
              child: pastor.photoUrl == null || pastor.photoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 12),

            // Informações
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pastor.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (pastor.title != null)
                    Text(
                      pastor.title!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  if (pastor.bio != null)
                    Text(
                      pastor.bio!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context, ChurchInfo churchInfo) {
    final hasContact = churchInfo.address != null ||
        churchInfo.phone != null ||
        churchInfo.email != null ||
        churchInfo.website != null;

    if (!hasContact) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Contato',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Endereço
            if (churchInfo.address != null)
              _buildContactItem(
                context,
                icon: Icons.location_on_outlined,
                text: churchInfo.address!,
                onTap: () => _launchUrl('https://maps.google.com/?q=${Uri.encodeComponent(churchInfo.address!)}'),
              ),

            // Telefone
            if (churchInfo.phone != null)
              _buildContactItem(
                context,
                icon: Icons.phone_outlined,
                text: churchInfo.phone!,
                onTap: () => _launchUrl('tel:${churchInfo.phone}'),
              ),

            // Email
            if (churchInfo.email != null)
              _buildContactItem(
                context,
                icon: Icons.email_outlined,
                text: churchInfo.email!,
                onTap: () => _launchUrl('mailto:${churchInfo.email}'),
              ),

            // Website
            if (churchInfo.website != null)
              _buildContactItem(
                context,
                icon: Icons.language_outlined,
                text: churchInfo.website!,
                onTap: () => _launchUrl(churchInfo.website!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, {required IconData icon, required String text, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaSection(BuildContext context, Map<String, String> socialMedia) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Redes Sociais',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: socialMedia.entries.map((entry) {
                return _buildSocialMediaButton(context, entry.key, entry.value);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialMediaButton(BuildContext context, String platform, String url) {
    IconData icon;
    Color color;

    switch (platform.toLowerCase()) {
      case 'facebook':
        icon = FontAwesomeIcons.facebook;
        color = const Color(0xFF1877F2);
        break;
      case 'instagram':
        icon = FontAwesomeIcons.instagram;
        color = const Color(0xFFE4405F);
        break;
      case 'youtube':
        icon = FontAwesomeIcons.youtube;
        color = const Color(0xFFFF0000);
        break;
      case 'whatsapp':
        icon = FontAwesomeIcons.whatsapp;
        color = const Color(0xFF25D366);
        break;
      case 'twitter':
      case 'x':
        icon = FontAwesomeIcons.xTwitter;
        color = Colors.black;
        break;
      default:
        icon = Icons.link;
        color = Theme.of(context).colorScheme.primary;
    }

    return ElevatedButton.icon(
      onPressed: () => _launchUrl(url),
      icon: FaIcon(icon, size: 20),
      label: Text(platform.toUpperCase()),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
