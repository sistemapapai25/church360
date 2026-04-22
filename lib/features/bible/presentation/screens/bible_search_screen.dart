import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/bible_provider.dart';

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
            bibleSearchProvider(
              (query: _query, bookId: null, testament: null),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar na Bíblia'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Digite palavra ou trecho',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
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
                        itemCount: verses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final verse = verses[index];
                          return ListTile(
                            title: Text(
                              verse.reference,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              verse.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              context.push(
                                '/bible/book/${verse.bookId}/chapter/${verse.chapter}',
                              );
                            },
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
