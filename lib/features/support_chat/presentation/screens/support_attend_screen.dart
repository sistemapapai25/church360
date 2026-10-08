import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menu de Gestão > Atendimentos: conversas em que o membro pediu uma pessoa
/// (o Moisés chamou o atendente). Assumir, responder, devolver ao Moisés,
/// encerrar. Acesso e escrita garantidos pelo banco (support.attend + RLS);
/// atualiza por polling (Realtime não é ligado nessas tabelas).
class SupportAttendScreen extends StatefulWidget {
  const SupportAttendScreen({super.key, this.initialSessionId});

  final String? initialSessionId;

  @override
  State<SupportAttendScreen> createState() => _SupportAttendScreenState();
}

class _SupportAttendScreenState extends State<SupportAttendScreen> {
  final _client = Supabase.instance.client;
  final _reply = TextEditingController();
  Timer? _poll;

  List<Map<String, dynamic>> _sessions = [];
  Map<String, String> _names = {};
  List<Map<String, dynamic>> _messages = [];
  String? _openId;
  bool _loading = true;
  bool _busy = false;

  static const _statusLabel = {
    'aguardando_humano': 'Aguardando atendente',
    'humano': 'Em atendimento',
    'bot': 'Com o Moisés',
    'encerrada': 'Encerrada',
  };

  @override
  void initState() {
    super.initState();
    _openId = widget.initialSessionId;
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reply.dispose();
    super.dispose();
  }

  String? get _me => _client.auth.currentUser?.id;

  Map<String, dynamic>? get _open {
    for (final s in _sessions) {
      if (s['id'] == _openId) return s;
    }
    return null;
  }

  Future<void> _refresh() async {
    try {
      final rows = await _client
          .from('support_session')
          .select('id,user_id,status,assigned_to,last_message_at')
          .or('status.in.(aguardando_humano,humano)${_openId != null ? ',id.eq.$_openId' : ''}')
          .order('last_message_at', ascending: false);
      final sessions = List<Map<String, dynamic>>.from(rows);
      final ids = sessions.map((s) => s['user_id'].toString()).toSet().toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        final people = await _client
            .from('user_account')
            .select('auth_user_id,full_name')
            .inFilter('auth_user_id', ids);
        for (final p in people) {
          names[p['auth_user_id'].toString()] = (p['full_name'] ?? 'Membro').toString();
        }
      }
      List<Map<String, dynamic>> messages = _messages;
      if (_openId != null) {
        messages = List<Map<String, dynamic>>.from(await _client
            .from('support_message')
            .select('role,content,created_at')
            .eq('session_id', _openId!)
            .order('created_at'));
      }
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _names = names;
        _messages = messages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _rpc(String fn) =>
      _run(() async => await _client.rpc(fn, params: {'p_session_id': _openId}));

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await _client
          .from('support_message')
          .insert({'session_id': _openId, 'role': 'humano', 'content': text});
      _reply.clear();
    });
  }

  String _time(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return Scaffold(
      appBar: AppBar(
        title: Text(open == null ? 'Atendimentos' : (_names[open['user_id']] ?? 'Membro')),
        leading: _openId == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar para a fila',
                onPressed: () => setState(() {
                  _openId = null;
                  _messages = [];
                }),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _openId == null
              ? _buildQueue()
              : _buildConversation(open),
    );
  }

  Widget _buildQueue() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ninguém esperando atendimento agora.\nQuando o Moisés chamar um atendente, a conversa aparece aqui.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = _sessions[i];
        final waiting = s['status'] == 'aguardando_humano';
        final mine = s['assigned_to'] == _me;
        return ListTile(
          leading: Icon(
            waiting ? Icons.notifications_active : Icons.support_agent,
            color: waiting ? Colors.orange : null,
          ),
          title: Text(_names[s['user_id']] ?? 'Membro'),
          subtitle: Text(
            '${_statusLabel[s['status']] ?? s['status']}${mine ? ' (você)' : ''} · ${_time(s['last_message_at'])}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() => _openId = s['id'].toString());
            _refresh();
          },
        );
      },
    );
  }

  Widget _buildConversation(Map<String, dynamic>? open) {
    final status = open?['status']?.toString() ?? 'encerrada';
    final mine = open?['assigned_to'] == _me;
    final canReply = status == 'humano' && mine;
    final canTake = status == 'aguardando_humano' || (status == 'humano' && !mine);
    final active = status == 'aguardando_humano' || status == 'humano';
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_statusLabel[status] ?? status}${mine && status == 'humano' ? ' (você)' : ''}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
        if (active)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canTake)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _rpc('support_take_session'),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Assumir'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _rpc('support_return_to_bot'),
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Devolver ao Moisés'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _rpc('support_close_session'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Encerrar'),
                ),
              ],
            ),
          ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final role = m['role'];
              final fromMember = role == 'user';
              final who = fromMember
                  ? (_names[open?['user_id']] ?? 'Membro')
                  : (role == 'humano' ? 'Atendente' : 'Moisés');
              return Align(
                alignment: fromMember ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fromMember
                        ? theme.colorScheme.surfaceContainerHighest
                        : (role == 'humano'
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$who · ${_time(m['created_at'])}', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      SelectableText(m['content']?.toString() ?? ''),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (canReply)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Responder ao membro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Enviar',
                  ),
                ],
              ),
            ),
          )
        else if (status == 'aguardando_humano' || (status == 'humano' && !mine))
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Toque em Assumir para responder. O Moisés para de responder a partir daí.'),
          ),
      ],
    );
  }
}
