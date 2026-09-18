import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/duplicates_repository.dart';
import '../../domain/models/dismissed_pair.dart';
import '../../domain/models/duplicate_group.dart';
import '../providers/duplicates_provider.dart';

/// Tela de vincular cadastros.
///
/// Duas abas: o que a deteccao ainda considera candidato, e o que alguem ja
/// marcou como pessoas diferentes. A tela inteira e' de owner — as RPCs por
/// tras dela recusam qualquer outro chamador, entao a rota carrega
/// OwnerOnlyRoute para o usuario ver "acesso negado" em vez de uma lista que
/// estoura.
class DuplicateAccountsScreen extends StatelessWidget {
  const DuplicateAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vincular cadastros'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Possíveis duplicados'),
              Tab(text: 'Dispensados'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_GroupsTab(), _DismissedTab()],
        ),
      ),
    );
  }
}

// =====================================================================
// Aba 1 — candidatos
// =====================================================================

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruposAsync = ref.watch(duplicateGroupsProvider);

    return gruposAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => _ErrorState(
        mensagem: erro is DuplicatesFailure ? erro.mensagem : erro.toString(),
        onRetry: () => ref.invalidate(duplicateGroupsProvider),
      ),
      data: (grupos) {
        if (grupos.isEmpty) {
          return _EmptyState(
            icone: Icons.verified_user_outlined,
            titulo: 'Nenhum cadastro repetido',
            detalhe:
                'Ninguém no cadastro divide login, CPF, telefone ou e-mail — '
                'fora os pares que você já marcou como pessoas diferentes.',
            onRefresh: () => ref.invalidate(duplicateGroupsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(duplicateGroupsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grupos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return const _CandidatosAviso();
              return _GroupCard(grupo: grupos[index - 1]);
            },
          ),
        );
      },
    );
  }
}

/// Chave repetida nao prova pessoa repetida. Sem este aviso a lista parece um
/// veredito, e a pessoa funde o que nao devia.
class _CandidatosAviso extends StatelessWidget {
  const _CandidatosAviso();

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      color: cores.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: cores.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estes são candidatos, não duplicatas confirmadas. Marido e '
                'esposa dividem um telefone; mãe cadastra o filho com o '
                'próprio e-mail. Confira antes de fundir — a fusão não tem '
                'volta.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerStatefulWidget {
  final DuplicateGroup grupo;
  const _GroupCard({required this.grupo});

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  final Set<String> _selecionados = {};
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    // Grupo de dois nao tem o que escolher: ja vem com o par pronto. Com tres
    // ou mais, a pessoa marca duas — a decisao e' sempre por par.
    if (widget.grupo.fichas.length == 2) {
      _selecionados.addAll(widget.grupo.fichas.map((f) => f.id));
    }
  }

  List<DuplicateAccount> get _selecionadas =>
      widget.grupo.fichas.where((f) => _selecionados.contains(f.id)).toList();

  bool get _parCompleto => _selecionados.length == 2;

  /// Duas fichas com login nao fundem — mas so quando os logins sao
  /// DIFERENTES. A guarda da RPC (20260917000700, passo 3) e
  /// `count(DISTINCT auth_user_id) > 1`, nao "as duas tem login": apagar um
  /// auth.users exige a Admin API, e isso so e problema quando ha dois.
  ///
  /// Quando o grupo veio pelo motivo 'login', as fichas compartilham o MESMO
  /// auth_user_id — ele e a propria chave do grupo. Bloquear ai era negar o
  /// merge justamente no caso em que a RPC aceita, e com a mensagem dizendo o
  /// contrario do titulo do grupo ("Mesmo login: …"). Foi o que travou a
  /// ultima linha da fila de duplicados (CHU-369).
  bool get _doisLogins =>
      _parCompleto &&
      widget.grupo.motivo != 'login' &&
      _selecionadas.every((f) => f.temLogin);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconeDoMotivo(widget.grupo.motivo),
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.grupo.motivoLabel}: ${widget.grupo.chave}',
                    style: tema.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(widget.grupo.confiancaLabel),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.grupo.fichas.length > 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Marque duas fichas para comparar.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
            ...widget.grupo.fichas.map(_ficha),
            if (_doisLogins)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'As duas fichas têm logins diferentes. Resolva o login antes '
                  'de fundir — ou marque como pessoas diferentes.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: (_parCompleto && !_ocupado) ? _dispensar : null,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Não é a mesma pessoa'),
                ),
                FilledButton.icon(
                  onPressed:
                      (_parCompleto && !_doisLogins && !_ocupado) ? _fundir : null,
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Fundir…'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ficha(DuplicateAccount ficha) {
    final marcada = _selecionados.contains(ficha.id);
    return CheckboxListTile(
      value: marcada,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: _ocupado
          ? null
          : (valor) {
              setState(() {
                if (valor == true) {
                  // Nunca mais de duas: a unidade de decisao e' o par.
                  if (_selecionados.length >= 2) {
                    _selecionados.remove(_selecionados.first);
                  }
                  _selecionados.add(ficha.id);
                } else {
                  _selecionados.remove(ficha.id);
                }
              });
            },
      title: Row(
        children: [
          Flexible(
            child: Text(
              ficha.nome,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (ficha.temLogin)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.key, size: 16),
            ),
        ],
      ),
      subtitle: Text(_resumoFicha(ficha)),
    );
  }

  Future<void> _dispensar() async {
    final par = _selecionadas;
    final controller = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Não é a mesma pessoa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${par[0].nome} e ${par[1].nome} são pessoas diferentes.'),
            const SizedBox(height: 8),
            const Text(
              'O par some da lista e as duas fichas continuam separadas. '
              'Dá para reabrir depois, na aba "Dispensados".',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'ex.: mãe e filha, mesmo telefone de casa',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final motivo = controller.text.trim();
    setState(() => _ocupado = true);
    try {
      await ref.read(duplicatesRepositoryProvider).dismissPair(
            userAId: par[0].id,
            userBId: par[1].id,
            motivo: motivo.isEmpty ? null : motivo,
          );
      _recarregar();
      _aviso('Par marcado como pessoas diferentes.');
    } on DuplicatesFailure catch (e) {
      _aviso(e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _fundir() async {
    final par = _selecionadas;

    // 1. Quem fica. A escolha importa: a ficha que fica herda o historico e
    // preenche com a outra o que estiver vazio; a outra deixa de existir.
    final keepId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var escolhido = par.first.id;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Qual ficha fica?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A ficha escolhida recebe todo o histórico da outra e '
                  'preenche com ela os campos que estiverem vazios.',
                ),
                const SizedBox(height: 8),
                ...par.map(
                  (ficha) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      escolhido == ficha.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(ficha.nome),
                    subtitle: Text(_resumoFicha(ficha)),
                    onTap: () => setStateDialog(() => escolhido = ficha.id),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, escolhido),
                child: const Text('Simular fusão'),
              ),
            ],
          ),
        );
      },
    );

    if (keepId == null || !mounted) return;

    final keep = par.firstWhere((f) => f.id == keepId);
    final drop = par.firstWhere((f) => f.id != keepId);

    // 2. Ensaio. A RPC executa a fusao inteira e desfaz, devolvendo o mesmo
    // relatorio da fusao real. Nada e' aplicado antes de a pessoa ver isto.
    setState(() => _ocupado = true);
    final Map<String, dynamic> relatorio;
    try {
      relatorio = await ref.read(duplicatesRepositoryProvider).mergeAccounts(
            keepId: keep.id,
            dropIds: [drop.id],
          );
    } on DuplicatesFailure catch (e) {
      if (mounted) setState(() => _ocupado = false);
      _aviso(e.mensagem, erro: true);
      return;
    }
    if (!mounted) return;
    setState(() => _ocupado = false);

    // 3. Confirmacao com o relatorio do ensaio na mao.
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar fusão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fica: ${keep.nome}\nSai: ${drop.nome}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 24),
              ..._resumoDoEnsaio(dialogContext, relatorio),
              const Divider(height: 24),
              Text(
                'Esta ação não tem volta.',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fundir de verdade'),
          ),
        ],
      ),
    );

    if (aplicar != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ref.read(duplicatesRepositoryProvider).mergeAccounts(
            keepId: keep.id,
            dropIds: [drop.id],
            apply: true,
          );
      _recarregar();
      _aviso('Cadastros fundidos.');
    } on DuplicatesFailure catch (e) {
      _aviso(e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Sem Realtime nesta tabela: quem grava invalida na mao, senao a lista
  /// continua mostrando o que acabou de sair dela.
  void _recarregar() {
    ref.invalidate(duplicateGroupsProvider);
    ref.invalidate(dismissedPairsProvider);
  }

  void _aviso(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}

// =====================================================================
// Aba 2 — dispensados
// =====================================================================

class _DismissedTab extends ConsumerWidget {
  const _DismissedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paresAsync = ref.watch(dismissedPairsProvider);

    return paresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => _ErrorState(
        mensagem: erro is DuplicatesFailure ? erro.mensagem : erro.toString(),
        onRetry: () => ref.invalidate(dismissedPairsProvider),
      ),
      data: (pares) {
        if (pares.isEmpty) {
          return _EmptyState(
            icone: Icons.inbox_outlined,
            titulo: 'Nada dispensado ainda',
            detalhe: 'Quando você marcar um par como pessoas diferentes, ele '
                'aparece aqui e pode ser reaberto.',
            onRefresh: () => ref.invalidate(dismissedPairsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(dismissedPairsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pares.length,
            itemBuilder: (context, index) => _DismissedCard(par: pares[index]),
          ),
        );
      },
    );
  }
}

class _DismissedCard extends ConsumerStatefulWidget {
  final DismissedPair par;
  const _DismissedCard({required this.par});

  @override
  ConsumerState<_DismissedCard> createState() => _DismissedCardState();
}

class _DismissedCardState extends ConsumerState<_DismissedCard> {
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final par = widget.par;
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${par.nomeA}  ×  ${par.nomeB}',
              style: tema.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (par.motivo != null) ...[
              const SizedBox(height: 6),
              Text(par.motivo!, style: tema.textTheme.bodyMedium),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if (par.dispensadoEm != null) _data(par.dispensadoEm!),
                par.dispensadoPor ?? 'pelo painel administrativo',
              ].join(' · '),
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _ocupado ? null : _reabrir,
                icon: const Icon(Icons.undo),
                label: const Text('Reabrir'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reabrir() async {
    setState(() => _ocupado = true);
    try {
      await ref.read(duplicatesRepositoryProvider).restorePair(
            userAId: widget.par.userAId,
            userBId: widget.par.userBId,
          );
      ref.invalidate(dismissedPairsProvider);
      ref.invalidate(duplicateGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Par reaberto: volta para a lista de candidatos.'),
          ),
        );
      }
    } on DuplicatesFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.mensagem),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }
}

// =====================================================================
// Pecas compartilhadas
// =====================================================================

class _EmptyState extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String detalhe;
  final VoidCallback onRefresh;

  const _EmptyState({
    required this.icone,
    required this.titulo,
    required this.detalhe,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detalhe,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensagem;
  final VoidCallback onRetry;

  const _ErrorState({required this.mensagem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconeDoMotivo(String motivo) => switch (motivo) {
      'login' => Icons.key,
      'cpf' => Icons.badge_outlined,
      'telefone' => Icons.phone,
      'email' => Icons.mail_outline,
      _ => Icons.people_outline,
    };

String _resumoFicha(DuplicateAccount ficha) {
  final partes = <String>[
    if (ficha.telefone != null) ficha.telefone!,
    if (ficha.email != null) ficha.email!,
    if (ficha.cpf != null) 'CPF ${ficha.cpf}',
    if (ficha.status != null) ficha.status!,
    if (ficha.criadoEm != null) 'desde ${_data(ficha.criadoEm!)}',
  ];
  return partes.isEmpty ? 'Sem dados de contato' : partes.join(' · ');
}

String _data(DateTime valor) {
  final local = valor.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

/// Traduz o relatorio da RPC para linhas que dizem o que vai acontecer.
List<Widget> _resumoDoEnsaio(
  BuildContext context,
  Map<String, dynamic> relatorio,
) {
  final tema = Theme.of(context);
  final linhas = <Widget>[];

  Widget item(IconData icone, String texto, {Color? cor}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: tema.textTheme.bodyMedium?.copyWith(color: cor),
              ),
            ),
          ],
        ),
      );

  final movidas = relatorio['referencias_movidas'] as List? ?? const [];
  final totalMovidas = movidas.fold<int>(
    0,
    (soma, linha) =>
        soma + (((linha as Map)['linhas_movidas'] as num?) ?? 0).toInt(),
  );
  linhas.add(
    item(
      Icons.swap_horiz,
      totalMovidas == 0
          ? 'Nenhum registro para transferir.'
          : '$totalMovidas registro(s) passam para a ficha que fica, em '
              '${movidas.length} tabela(s).',
    ),
  );

  final campos = relatorio['campos_preenchidos'] as List? ?? const [];
  if (campos.isNotEmpty) {
    linhas.add(
      item(Icons.edit_outlined, 'Campos preenchidos: ${campos.join(', ')}.'),
    );
  }

  if (relatorio['login_transferido'] != null) {
    linhas.add(item(Icons.key, 'O login passa para a ficha que fica.'));
  }

  // Conflito de UNIQUE nao e' detalhe: sao linhas descartadas de vez.
  final conflitos = relatorio['conflitos_unique'] as List? ?? const [];
  if (conflitos.isNotEmpty) {
    final descartadas = conflitos.fold<int>(
      0,
      (soma, linha) =>
          soma + (((linha as Map)['linhas_descartadas'] as num?) ?? 0).toInt(),
    );
    linhas.add(
      item(
        Icons.warning_amber_outlined,
        '$descartadas registro(s) repetidos serão descartados '
        '(${conflitos.map((c) => (c as Map)['tabela']).join(', ')}).',
        cor: tema.colorScheme.error,
      ),
    );
  }

  final compostas = relatorio['fks_compostas_ignoradas'] as List? ?? const [];
  if (compostas.isNotEmpty) {
    linhas.add(
      item(
        Icons.report_gmailerrorred_outlined,
        'Atenção: ${compostas.length} vínculo(s) de chave composta não são '
        'tratados automaticamente e precisam de conferência manual.',
        cor: tema.colorScheme.error,
      ),
    );
  }

  final pares = (relatorio['pares_nao_duplicata_apagados'] as num? ?? 0).toInt();
  if (pares > 0) {
    linhas.add(
      item(
        Icons.person_off_outlined,
        '$pares marcação(ões) de "não é a mesma pessoa" da ficha que sai '
        'serão apagadas.',
      ),
    );
  }

  return linhas;
}
