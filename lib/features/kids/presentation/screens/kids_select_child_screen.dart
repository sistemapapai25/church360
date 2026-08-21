import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/kids_providers.dart';
import '../../../members/presentation/providers/members_provider.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/errors/app_error_handler.dart';

/// Tela para selecionar qual criança gerenciar
/// Acessada via /kids-registration (botão do menu principal)
class KidsSelectChildScreen extends ConsumerWidget {
  const KidsSelectChildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(managedChildrenProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.child_care_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inscrição Kids',
                  style: CommunityDesign.titleStyle(context),
                ),
                Text('Seus filhos', style: CommunityDesign.metaStyle(context)),
              ],
            ),
          ],
        ),
        centerTitle: false,
        toolbarHeight: 64,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Cadastrar Filho',
            onPressed: () => context.push('/members/new?type=crianca'),
          ),
        ],
      ),
      body: childrenAsync.when(
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.child_care, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma criança encontrada.',
                    style: CommunityDesign.titleStyle(context).copyWith(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Se você já tem filhos cadastrados, verifique se estão vinculados à sua família. Caso contrário, cadastre-os agora.',
                      textAlign: TextAlign.center,
                      style: CommunityDesign.contentStyle(context).copyWith(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/members/new?type=crianca'),
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar Meu Filho'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              final name =
                  child['full_name'] ?? child['first_name'] ?? 'Sem Nome';
              final photoUrl = child['avatar_url'] ?? child['photo_url'];
              final initials = name.isNotEmpty
                  ? name.substring(0, 1).toUpperCase()
                  : '?';

              // Calcular idade se possível
              String subtitle = 'Criança';
              if (child['birthdate'] != null) {
                try {
                  final birth = DateTime.parse(child['birthdate']);
                  final now = DateTime.now();
                  int age = now.year - birth.year;
                  if (now.month < birth.month ||
                      (now.month == birth.month && now.day < birth.day)) {
                    age--;
                  }
                  subtitle = '$age anos';
                } catch (_) {}
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: CommunityDesign.overlayDecoration(
                  Theme.of(context).colorScheme,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null ? Text(initials) : null,
                  ),
                  title: Text(name, style: CommunityDesign.titleStyle(context)),
                  subtitle: Text(
                    subtitle,
                    style: CommunityDesign.contentStyle(context),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar Dados',
                        onPressed: () =>
                            context.push('/members/${child['id']}/edit'),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Excluir',
                        onPressed: () =>
                            _confirmDelete(context, ref, child['id'] as String, name),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                  onTap: () {
                    context.push(
                      '/kids/${child['id']}/registration?name=${Uri.encodeComponent(name)}',
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Text(
            AppErrorHandler.userMessage(
              e,
              feature: 'kids.list_children',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String childId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Criança'),
        content: Text(
          'Tem certeza que deseja excluir o cadastro de "$name"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteChild(context, ref, childId);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChild(
    BuildContext context,
    WidgetRef ref,
    String childId,
  ) async {
    try {
      final repo = ref.read(membersRepositoryProvider);
      await repo.deleteMember(childId);

      ref.invalidate(managedChildrenProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Criança excluída com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorHandler.userMessage(e, feature: 'kids.delete_child'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
