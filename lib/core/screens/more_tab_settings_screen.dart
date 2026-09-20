import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/more_menu_item.dart';
import '../providers/more_menu_layout_provider.dart';
import '../design/app_icons.dart';

/// Tela de configuração da aba "Mais" (F6).
///
/// É o par da `UserDashboardSettingsScreen` ("Meu Dashboard"), que foi o
/// "igual ao da tela de dashboard" pedido no feedback — mesma premissa
/// (preferência pessoal, aberta a qualquer usuário, aviso de escopo no topo)
/// e uma diferença: aqui a pessoa escolhe **visibilidade e ordem**, com
/// arrastar-e-soltar, como já se faz em `DashboardSettingsScreen`.
///
/// Lista apenas os itens que a pessoa realmente vê ([moreMenuSettingsProvider]
/// já aplica os gates). Oferecer "Liderança" a quem não tem acesso ao
/// Dashboard seria porta dos fundos.
///
/// O que **não** aparece aqui, de propósito: o seletor de tema, "Ver tour de
/// novo", a entrada desta própria tela e "Sair do aplicativo". Se a entrada da
/// configuração pudesse ser escondida, a pessoa se trancaria fora dela sem
/// caminho de volta.
class MoreTabSettingsScreen extends ConsumerStatefulWidget {
  const MoreTabSettingsScreen({super.key});

  @override
  ConsumerState<MoreTabSettingsScreen> createState() =>
      _MoreTabSettingsScreenState();
}

class _MoreTabSettingsScreenState extends ConsumerState<MoreTabSettingsScreen> {
  /// Edição em curso. `null` = ainda espelhando o provider.
  List<(MoreMenuItem, bool)>? _edicao;
  bool _salvando = false;

  bool get _temMudanca => _edicao != null;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(moreMenuSettingsProvider);
    final itens = _edicao ?? settingsAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar tela Mais'),
        actions: [
          if (itens != null && itens.isNotEmpty)
            TextButton(
              onPressed: _salvando ? null : _restaurarPadrao,
              child: const Text('Restaurar padrão'),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => itens == null
            ? const Center(child: CircularProgressIndicator())
            : _corpo(itens),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível carregar suas preferências: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (_) => _corpo(itens ?? const []),
      ),
      bottomNavigationBar: _temMudanca ? _barraSalvar() : null,
    );
  }

  Widget _corpo(List<(MoreMenuItem, bool)> itens) {
    if (itens.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum item configurável disponível para o seu perfil no momento.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(AppIcons.info, color: cs.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Escolha quais itens aparecem na sua tela "Mais" e em que '
                    'ordem. Vale só para você.',
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: itens.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                final lista = List.of(itens);
                if (newIndex > oldIndex) newIndex -= 1;
                final movido = lista.removeAt(oldIndex);
                lista.insert(newIndex, movido);
                _edicao = lista;
              });
            },
            itemBuilder: (context, index) {
              final (item, isVisible) = itens[index];
              return Card(
                key: ValueKey(item.key),
                margin: const EdgeInsets.only(bottom: 12),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: item.color.withValues(alpha: 0.1),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: isVisible,
                  onChanged: _salvando
                      ? null
                      : (value) {
                          setState(() {
                            final lista = List.of(itens);
                            lista[index] = (item, value);
                            _edicao = lista;
                          });
                        },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _barraSalvar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _salvando
                    ? null
                    : () => setState(() => _edicao = null),
                child: const Text('Descartar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    final edicao = _edicao;
    if (edicao == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _salvando = true);
    try {
      await ref.read(saveMoreMenuLayoutProvider)(edicao);
      if (!mounted) return;
      // Volta a espelhar o provider, que acabou de ser invalidado.
      setState(() {
        _edicao = null;
        _salvando = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Tela "Mais" atualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restaurarPadrao() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar padrão'),
        content: const Text(
          'Isso devolve a ordem original e volta a mostrar todos os itens. '
          'Suas escolhas atuais serão perdidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _salvando = true);
    try {
      await ref.read(resetMoreMenuLayoutProvider)();
      if (!mounted) return;
      setState(() {
        _edicao = null;
        _salvando = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Tela "Mais" restaurada ao padrão.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao restaurar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
