import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/community_providers.dart';
import '../../../domain/models/community_post.dart';
import '../../../domain/models/classified.dart';
import '../../../../../core/design/community_design.dart';

class CommunityAdminScreen extends ConsumerStatefulWidget {
  const CommunityAdminScreen({super.key});

  @override
  ConsumerState<CommunityAdminScreen> createState() => _CommunityAdminScreenState();
}

class _CommunityAdminScreenState extends ConsumerState<CommunityAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text('Gestão da Comunidade', style: CommunityDesign.titleStyle(context)),
        backgroundColor: CommunityDesign.headerColor(context),
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Posts Pendentes', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Classificados Pendentes', icon: Icon(Icons.storefront)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingPostsList(),
          _PendingClassifiedsList(),
        ],
      ),
    );
  }
}

class _PendingPostsList extends ConsumerWidget {
  const _PendingPostsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingPostsAsync = ref.watch(pendingPostsProvider);

    return pendingPostsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('Nenhum post pendente de aprovação!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final CommunityPost post = posts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: post.authorAvatarUrl != null
                              ? NetworkImage(post.authorAvatarUrl!)
                              : null,
                          child: post.authorAvatarUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName ?? 'Anônimo',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(post.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Spacer(),
                        _buildTypeChip(context, post.type),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(post.content),
                    const SizedBox(height: 16),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejectPost(context, ref, post.id),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Rejeitar', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _approvePost(context, ref, post.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Aprovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  Widget _buildTypeChip(BuildContext context, String type) {
    String label;
    Color color;
    switch (type) {
      case 'prayer_request':
        label = 'Oração';
        color = Colors.purple;
        break;
      case 'testimony':
        label = 'Testemunho';
        color = Colors.orange;
        break;
      default:
        label = 'Geral';
        color = Colors.blue;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _approvePost(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(communityRepositoryProvider).updatePostStatus(id, 'approved');
      ref.invalidate(pendingPostsProvider);
      ref.invalidate(communityPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post aprovado com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar: $e')),
        );
      }
    }
  }

  Future<void> _rejectPost(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(communityRepositoryProvider).updatePostStatus(id, 'rejected');
      ref.invalidate(pendingPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post rejeitado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao rejeitar: $e')),
        );
      }
    }
  }
}

class _PendingClassifiedsList extends ConsumerWidget {
  const _PendingClassifiedsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingClassifiedsAsync = ref.watch(pendingClassifiedsProvider);

    return pendingClassifiedsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('Nenhum classificado pendente!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final Classified item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: item.authorAvatarUrl != null
                              ? NetworkImage(item.authorAvatarUrl!)
                              : null,
                          child: item.authorAvatarUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.authorName ?? 'Anônimo',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (item.price != null)
                          Chip(
                            label: Text(
                              'R\$ ${item.price!.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.green.shade100,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(item.description),
                    const SizedBox(height: 16),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejectClassified(context, ref, item.id),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Rejeitar', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _approveClassified(context, ref, item.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Aprovar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
    );
  }

  Future<void> _approveClassified(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(communityRepositoryProvider).updateClassifiedStatus(id, 'approved');
      ref.invalidate(pendingClassifiedsProvider);
      ref.invalidate(classifiedsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classificado aprovado com sucesso!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aprovar: $e')),
        );
      }
    }
  }

  Future<void> _rejectClassified(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(communityRepositoryProvider).updateClassifiedStatus(id, 'rejected');
      ref.invalidate(pendingClassifiedsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classificado rejeitado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao rejeitar: $e')),
        );
      }
    }
  }
}
