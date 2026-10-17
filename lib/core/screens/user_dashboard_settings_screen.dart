import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/dashboard_widget.dart';
import '../providers/dashboard_widget_provider.dart';
import '../design/app_icons.dart';
import '../layout/readable_width.dart';

/// Tela de gerenciamento pessoal do Dashboard (CHU-308, B1).
///
/// Diferente de [DashboardSettingsScreen] (`/dashboard-settings`), que é
/// restrita a quem tem `dashboard.configure` e liga/desliga widgets pro
/// tenant inteiro, esta tela é aberta pra qualquer usuário com acesso ao
/// Dashboard e só afeta a preferência pessoal dele — nunca lista um widget
/// que ele não tem permissão de ver ([myDashboardWidgetSettingsProvider]).
///
/// Mesmo desenho da `MoreTabSettingsScreen`: a pessoa escolhe visibilidade
/// **e ordem** (arrastar), salva de uma vez; "Restaurar padrão da igreja"
/// apaga as escolhas pessoais.
class UserDashboardSettingsScreen extends ConsumerStatefulWidget {
  const UserDashboardSettingsScreen({super.key});

  @override
  ConsumerState<UserDashboardSettingsScreen> createState() =>
      _UserDashboardSettingsScreenState();
}

class _UserDashboardSettingsScreenState
    extends ConsumerState<UserDashboardSettingsScreen> {
  /// Edição em curso. `null` = ainda espelhando o provider.
  List<(DashboardWidget, bool)>? _edicao;
  bool _salvando = false;

  bool get _temMudanca => _edicao != null;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(myDashboardWidgetSettingsProvider);
    final itens = _edicao ?? settingsAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Dashboard'),
        actions: [
          if (itens != null && itens.isNotEmpty)
            TextButton(
              onPressed: _salvando ? null : _restaurarPadrao,
              child: const Text('Restaurar padrão'),
            ),
        ],
      ),
      body: ReadableWidth(child: settingsAsync.when(
        loading: () => itens == null
            ? const Center(child: CircularProgressIndicator())
            : _corpo(itens),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $error', textAlign: TextAlign.center),
          ),
        ),
        data: (_) => _corpo(itens ?? const []),
      )),
      bottomNavigationBar: _temMudanca ? _barraSalvar() : null,
    );
  }

  Widget _corpo(List<(DashboardWidget, bool)> itens) {
    if (itens.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum card disponível para o seu perfil no momento.',
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
                    'Escolha quais cards aparecem no seu Dashboard e em que '
                    'ordem, dentre os que você tem permissão de ver. Vale só '
                    'para você.',
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
              final (widget, isVisible) = itens[index];
              return Card(
                key: ValueKey(widget.widgetKey),
                margin: const EdgeInsets.only(bottom: 12),
                child: SwitchListTile(
                  secondary: const Icon(AppIcons.dragHandle),
                  title: Text(
                    widget.widgetName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: widget.description != null
                      ? Text(widget.description!)
                      : null,
                  value: isVisible,
                  onChanged: _salvando
                      ? null
                      : (value) {
                          setState(() {
                            final lista = List.of(itens);
                            lista[index] = (widget, value);
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
      await ref.read(saveMyDashboardLayoutProvider)(edicao);
      if (!mounted) return;
      setState(() {
        _edicao = null;
        _salvando = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Dashboard atualizado.')),
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
        title: const Text('Restaurar padrão da igreja'),
        content: const Text(
          'Isso apaga suas escolhas: todos os cards que você pode ver voltam '
          'a aparecer, na ordem definida pela igreja.',
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
      await ref.read(resetMyDashboardLayoutProvider)();
      if (!mounted) return;
      setState(() {
        _edicao = null;
        _salvando = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Dashboard restaurado ao padrão da igreja.')),
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
