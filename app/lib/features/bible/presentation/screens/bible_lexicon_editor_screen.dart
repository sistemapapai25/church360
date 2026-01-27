import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/bible_lexeme.dart';
import '../providers/bible_provider.dart';

class BibleLexiconEditorScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const BibleLexiconEditorScreen({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<BibleLexiconEditorScreen> createState() => _BibleLexiconEditorScreenState();
}

class _BibleLexiconEditorScreenState extends ConsumerState<BibleLexiconEditorScreen> {
  final _searchController = TextEditingController();
  var _holdingInitialQuery = false;
  var _initialQuery = '';

  @override
  void initState() {
    super.initState();
    _initialQuery = widget.initialQuery?.trim() ?? '';
    if (_initialQuery.isNotEmpty) {
      _holdingInitialQuery = true;
      _searchController.text = _initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(bibleLexemeSearchQueryProvider.notifier).state = _initialQuery;
        _holdingInitialQuery = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _editLexeme(BibleLexeme lexeme) async {
    final rootContext = context;
    final glossController = TextEditingController(text: lexeme.ptGloss ?? '');
    final definitionController = TextEditingController(text: lexeme.ptDefinition ?? '');
    var saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(lexeme.strongCode),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: glossController,
                          decoration: const InputDecoration(
                            labelText: 'Gloss (PT)',
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          enabled: !saving,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: definitionController,
                          decoration: const InputDecoration(
                            labelText: 'Definição (PT)',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 4,
                          maxLines: 10,
                          enabled: !saving,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setState(() => saving = true);
                            try {
                              final repo = ref.read(bibleRepositoryProvider);
                              await repo.updateLexemePt(
                                lexeme.id,
                                ptGloss: glossController.text,
                                ptDefinition: definitionController.text,
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.of(dialogContext).pop();
                              ref.invalidate(bibleLexemeSearchProvider);
                              if (!rootContext.mounted) return;
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(content: Text('Léxico atualizado.')),
                              );
                            } catch (e) {
                              setState(() => saving = false);
                              if (!rootContext.mounted) return;
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                SnackBar(content: Text('Erro ao salvar: $e')),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      glossController.dispose();
      definitionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(bibleLexemeSearchQueryProvider);
    final lexemesAsync = ref.watch(bibleLexemeSearchProvider);

    if (!_holdingInitialQuery && _searchController.text != query) {
      _searchController.text = query;
      _searchController.selection = TextSelection.collapsed(offset: _searchController.text.length);
    }

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        backgroundColor: CommunityDesign.headerColor(context),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            tooltip: 'Voltar',
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
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
                Icons.translate_rounded,
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
                  'Léxico (Strong)',
                  style: CommunityDesign.titleStyle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  'Editar gloss/definição em PT',
                  style: CommunityDesign.metaStyle(context),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar Strong (ex: H7225) ou termo...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.trim().isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(bibleLexemeSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => ref.read(bibleLexemeSearchQueryProvider.notifier).state = value,
            ),
          ),
          Expanded(
            child: lexemesAsync.when(
              data: (lexemes) {
                if (lexemes.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhum resultado encontrado.',
                      style: CommunityDesign.metaStyle(context),
                    ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(bibleLexemeSearchProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: lexemes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lexeme = lexemes[index];
                    final title = lexeme.ptGloss?.trim().isNotEmpty == true
                        ? lexeme.ptGloss!.trim()
                        : (lexeme.lemma?.trim().isNotEmpty == true ? lexeme.lemma!.trim() : '—');

                      final subtitleParts = <String>[
                        lexeme.strongCode,
                        lexeme.language,
                        if ((lexeme.ptDefinition ?? '').trim().isNotEmpty) lexeme.ptDefinition!.trim(),
                      ];

                    return Container(
                        decoration: CommunityDesign.overlayDecoration(
                          Theme.of(context).colorScheme,
                          hovered: true,
                        ),
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text(
                            subtitleParts.join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => _editLexeme(lexeme),
                        ),
                      );
                  },
                ),
              );
            },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erro ao carregar léxicos: $error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
