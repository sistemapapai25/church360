import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';

class BibleSearchScreen extends ConsumerStatefulWidget {
  const BibleSearchScreen({super.key});

  @override
  ConsumerState<BibleSearchScreen> createState() => _BibleSearchScreenState();
}

class _BibleSearchScreenState extends ConsumerState<BibleSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = _query.length >= 2;
    final resultsAsync = canSearch
        ? ref.watch(
            bibleSearchProvider((query: _query, bookId: null, testament: null)),
          )
        : null;

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Buscar na Bíblia',
          style: CommunityDesign.titleStyle(context),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Digite palavra ou trecho',
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(AppIcons.clear),
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: !canSearch
                ? const Center(
                    child: Text('Digite pelo menos 2 caracteres para buscar.'),
                  )
                : resultsAsync!.when(
                    data: (verses) {
                      if (verses.isEmpty) {
                        return const Center(
                          child: Text('Nenhum versículo encontrado.'),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: verses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final verse = verses[index];
                          return GlassCard(
                            onTap: () {
                              context.push(
                                '/bible/book/${verse.bookId}/chapter/${verse.chapter}',
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(AppIcons.book),
                              title: Text(
                                verse.reference,
                                style: CommunityDesign.titleStyle(context),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  verse.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: CommunityDesign.contentStyle(context),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Erro ao buscar: $error'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
