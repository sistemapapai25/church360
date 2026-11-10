import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/layout/readable_width.dart';
import '../widgets/admin_action_card.dart';

/// Solicitações: pedidos de ação administrativa que o Moisés encaminhou.
/// "Para você aprovar" e "Meus pedidos". Qualquer usuário logado abre: a RPC
/// admin_action_inbox já filtra pelo usuário e o banco confere cada decisão.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _paraAprovar = [];
  List<Map<String, dynamic>> _meusPedidos = [];
  bool _loading = true;
  bool _busy = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  List<Map<String, dynamic>> _lista(dynamic v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : [];

  Future<void> _carregar() async {
    try {
      final r = await _client.rpc('admin_action_inbox');
      final m = r is Map ? r : const {};
      if (!mounted) return;
      setState(() {
        _paraAprovar = _lista(m['para_aprovar']);
        _meusPedidos = _lista(m['meus_pedidos']);
        _erro = null;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não consegui carregar. Puxe para tentar de novo.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _decidir(String rpc, Map<String, dynamic> params) async {
    setState(() => _busy = true);
    try {
      await _client.rpc(rpc, params: params);
    } on PostgrestException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('Não consegui falar com o servidor. Tente de novo.');
    }
    await _carregar();
    if (mounted) setState(() => _busy = false);
  }

  void _aviso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _recusar(String id) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar pedido'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Recusar')),
        ],
      ),
    );
    final motivo = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    await _decidir('admin_action_reject',
        {'p_id': id, 'p_reason': motivo.isEmpty ? null : motivo});
  }

  String _status(Map<String, dynamic> p) {
    final resultado = p['resultado']?.toString() ?? '';
    switch (p['status']) {
      case 'awaiting_approval':
        return 'Aguardando ${p['aprovador'] ?? 'o aprovador'}';
      case 'executed':
        return 'Feito';
      case 'rejected':
        return 'Recusado';
      case 'cancelled':
        return 'Cancelado';
      case 'expired':
        return 'Expirado';
      case 'failed':
        return 'Não executado: $resultado';
      default:
        return p['status']?.toString() ?? '';
    }
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _card(Map<String, dynamic> p, {required bool aprovar}) {
    final nota = p['nota']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['resumo']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (aprovar) ...[
              Text('Pedido por ${p['pedido_por'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (nota.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 4), child: Text(nota)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                AdminPillButton(
                  label: 'Aprovar',
                  onTap: _busy
                      ? null
                      : () => _decidir('admin_action_confirm', {'p_id': p['id']}),
                ),
                AdminPillButton(
                  label: 'Recusar',
                  color: const Color(0xFF6B7280),
                  onTap: _busy ? null : () => _recusar(p['id'].toString()),
                ),
              ]),
            ] else
              Text(_status(p),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vazio = _paraAprovar.isEmpty && _meusPedidos.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações')),
      body: ReadableWidth(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _carregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_erro != null)
                      Text(_erro!,
                          style: const TextStyle(color: Color(0xFFB91C1C))),
                    if (vazio && _erro == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: Text('Nenhuma solicitação.')),
                      ),
                    if (_paraAprovar.isNotEmpty) ...[
                      _titulo('Para você aprovar'),
                      for (final p in _paraAprovar) _card(p, aprovar: true),
                    ],
                    if (_meusPedidos.isNotEmpty) ...[
                      _titulo('Meus pedidos'),
                      for (final p in _meusPedidos) _card(p, aprovar: false),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
