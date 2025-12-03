import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/support_material_link.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../courses/presentation/providers/courses_provider.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../ministries/presentation/providers/ministries_provider.dart';
import '../../../study_groups/presentation/providers/study_group_provider.dart';

/// Dialog para selecionar entidades específicas para vincular ao material
class EntitySelectorDialog extends ConsumerStatefulWidget {
  final MaterialLinkType linkType;
  final List<String> initialSelectedIds;

  const EntitySelectorDialog({
    super.key,
    required this.linkType,
    this.initialSelectedIds = const [],
  });

  @override
  ConsumerState<EntitySelectorDialog> createState() => _EntitySelectorDialogState();
}

class _EntitySelectorDialogState extends ConsumerState<EntitySelectorDialog> {
  final Set<String> _selectedIds = {};
  final Map<String, String> _entityNames = {}; // id -> name

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(_getIconForLinkType(widget.linkType), color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selecionar ${widget.linkType.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body - Lista de entidades
            Expanded(
              child: _buildEntityList(),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedIds.length} selecionado(s)',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, {
                            'ids': _selectedIds.toList(),
                            'names': _entityNames,
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityList() {
    switch (widget.linkType) {
      case MaterialLinkType.communionGroup:
        return _buildGroupsList();
      case MaterialLinkType.course:
        return _buildCoursesList();
      case MaterialLinkType.event:
        return _buildEventsList();
      case MaterialLinkType.ministry:
        return _buildMinistriesList();
      case MaterialLinkType.studyGroup:
        return _buildStudyGroupsList();
      case MaterialLinkType.general:
        return const Center(
          child: Text('Tipo "Geral" não requer seleção de entidades'),
        );
    }
  }

  Widget _buildGroupsList() {
    final groupsAsync = ref.watch(allGroupsProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return const Center(
            child: Text('Nenhum grupo de comunhão cadastrado'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final isSelected = _selectedIds.contains(group.id);

            return CheckboxListTile(
              title: Text(group.name),
              subtitle: group.description != null
                  ? Text(group.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(group.id);
                    _entityNames[group.id] = group.name;
                  } else {
                    _selectedIds.remove(group.id);
                    _entityNames.remove(group.id);
                  }
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar grupos: $error'),
      ),
    );
  }

  Widget _buildCoursesList() {
    final coursesAsync = ref.watch(allCoursesProvider);

    return coursesAsync.when(
      data: (courses) {
        if (courses.isEmpty) {
          return const Center(
            child: Text('Nenhum curso cadastrado'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            final isSelected = _selectedIds.contains(course.id);

            return CheckboxListTile(
              title: Text(course.title),
              subtitle: course.description != null
                  ? Text(course.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(course.id);
                    _entityNames[course.id] = course.title;
                  } else {
                    _selectedIds.remove(course.id);
                    _entityNames.remove(course.id);
                  }
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar cursos: $error'),
      ),
    );
  }

  Widget _buildEventsList() {
    final eventsAsync = ref.watch(allEventsProvider);

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(
            child: Text('Nenhum evento cadastrado'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isSelected = _selectedIds.contains(event.id);

            return CheckboxListTile(
              title: Text(event.name),
              subtitle: event.description != null
                  ? Text(event.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(event.id);
                    _entityNames[event.id] = event.name;
                  } else {
                    _selectedIds.remove(event.id);
                    _entityNames.remove(event.id);
                  }
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar eventos: $error'),
      ),
    );
  }

  Widget _buildMinistriesList() {
    final ministriesAsync = ref.watch(allMinistriesProvider);

    return ministriesAsync.when(
      data: (ministries) {
        if (ministries.isEmpty) {
          return const Center(
            child: Text('Nenhum ministério cadastrado'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ministries.length,
          itemBuilder: (context, index) {
            final ministry = ministries[index];
            final isSelected = _selectedIds.contains(ministry.id);

            return CheckboxListTile(
              title: Text(ministry.name),
              subtitle: ministry.description != null
                  ? Text(ministry.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(ministry.id);
                    _entityNames[ministry.id] = ministry.name;
                  } else {
                    _selectedIds.remove(ministry.id);
                    _entityNames.remove(ministry.id);
                  }
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar ministérios: $error'),
      ),
    );
  }

  Widget _buildStudyGroupsList() {
    final studyGroupsAsync = ref.watch(allStudyGroupsProvider);

    return studyGroupsAsync.when(
      data: (studyGroups) {
        if (studyGroups.isEmpty) {
          return const Center(
            child: Text('Nenhum grupo de estudo cadastrado'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: studyGroups.length,
          itemBuilder: (context, index) {
            final studyGroup = studyGroups[index];
            final isSelected = _selectedIds.contains(studyGroup.id);

            return CheckboxListTile(
              title: Text(studyGroup.name),
              subtitle: studyGroup.description != null
                  ? Text(studyGroup.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(studyGroup.id);
                    _entityNames[studyGroup.id] = studyGroup.name;
                  } else {
                    _selectedIds.remove(studyGroup.id);
                    _entityNames.remove(studyGroup.id);
                  }
                });
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erro ao carregar grupos de estudo: $error'),
      ),
    );
  }

  IconData _getIconForLinkType(MaterialLinkType linkType) {
    switch (linkType) {
      case MaterialLinkType.communionGroup:
        return Icons.group;
      case MaterialLinkType.course:
        return Icons.school;
      case MaterialLinkType.event:
        return Icons.event;
      case MaterialLinkType.ministry:
        return Icons.volunteer_activism;
      case MaterialLinkType.studyGroup:
        return Icons.menu_book;
      case MaterialLinkType.general:
        return Icons.public;
    }
  }
}

