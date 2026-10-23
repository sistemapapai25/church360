import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error_handler.dart';
import '../support_chat/presentation/widgets/audio_message_bubble.dart';

/// K9 — Mensagens internas (supabase 20261008009600).
///
/// Tudo passa pelas RPCs `msg_*` (security definer); as regras de quem fala
/// com quem ficam no banco:
/// - conversa avulsa só entre líderes pra cima (cargo nível >= 3 ou owner);
/// - cada ministério tem "Liderança – X" e "Voluntários – X", automáticos;
///   o líder do ministério tira e devolve pessoas;
/// - chamar um 3º num direct cria um grupo novo (como no Insta).
/// Sem tempo real: a conversa aberta consulta a cada 5 s, como o suporte.
///
/// Cache no celular (supabase 20261023000100): a lista e cada conversa ficam
/// guardadas por usuário; a conversa abre do cache e só pede ao banco o que
/// chegou depois da última mensagem. Áudio no bucket msg-audio, baixado uma
/// vez só por aparelho.
SupabaseClient get _db => Supabase.instance.client;

const _pageSize = 200;

String _cacheKey(String what) => 'msg:${_db.auth.currentUser?.id}:$what';

Future<dynamic> _readCache(String what) async {
  try {
    final raw = (await SharedPreferences.getInstance()).getString(
      _cacheKey(what),
    );
    return raw == null ? null : jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

Future<void> _writeCache(String what, Object? value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    value == null
        ? await prefs.remove(_cacheKey(what))
        : await prefs.setString(_cacheKey(what), jsonEncode(value));
  } catch (_) {}
}

/// App em segundo plano não consulta o banco.
bool get _appVisible {
  final s = WidgetsBinding.instance.lifecycleState;
  return s == null ||
      s == AppLifecycleState.resumed ||
      s == AppLifecycleState.inactive;
}

/// Mostra "Mensagens" na aba Mais: líder pra cima ou quem já está em algum
/// grupo de ministério.
final msgCanUseProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await _db.rpc('msg_can_use') == true;
  } catch (_) {
    return false;
  }
});

List<Map<String, dynamic>> _list(dynamic v) => (v as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

void _showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppErrorHandler.userMessage(e, feature: 'messages')),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

String _when(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return DateFormat('HH:mm').format(d);
  }
  return DateFormat('dd/MM').format(d);
}

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  List<Map<String, dynamic>>? _items;
  bool _isLeader = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _readCache('list').then((cached) {
      if (cached is List && mounted && _items == null) {
        setState(() => _items = _list(cached));
      }
    });
    _load();
    // Líder pra cima: msg_leaders responde; os outros recebem 42501.
    _db.rpc('msg_leaders').then((_) {
      if (mounted) setState(() => _isLeader = true);
    }, onError: (_) {});
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_appVisible) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = _list(await _db.rpc('msg_list'));
      if (mounted) setState(() => _items = r);
      _writeCache('list', r);
    } catch (e) {
      if (mounted && _items == null) {
        setState(() => _items = const []);
        _showError(context, e);
      }
    }
  }

  Future<void> _newConversation() async {
    final List<Map<String, dynamic>> leaders;
    try {
      leaders = _list(await _db.rpc('msg_leaders'));
    } catch (e) {
      if (mounted) _showError(context, e);
      return;
    }
    if (!mounted) return;
    final picked = await pickPeople(
      context,
      leaders,
      title: 'Nova conversa',
      askTitle: true,
    );
    if (picked == null || !mounted) return;
    try {
      final id = await _db.rpc(
        'msg_start',
        params: {'p_users': picked.ids, 'p_title': picked.title},
      );
      if (!mounted) return;
      await context.push('/messages/$id');
      _load();
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      floatingActionButton: _isLeader
          ? FloatingActionButton.extended(
              onPressed: _newConversation,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Nova conversa'),
            )
          : null,
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma conversa ainda.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = items[i];
                  final kind = c['kind'] as String? ?? '';
                  final unread = c['unread'] == true;
                  final last = c['last_text'] as String?;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        kind == 'direct'
                            ? Icons.person_outline
                            : kind.startsWith('ministry')
                            ? Icons.groups_outlined
                            : Icons.forum_outlined,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      c['title'] as String? ?? 'Conversa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.bold : null,
                      ),
                    ),
                    subtitle: Text(
                      last == null
                          ? 'Sem mensagens'
                          : kind == 'direct'
                          ? last
                          : '${c['last_author'] ?? ''}: $last',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _when(c['last_message_at'] as String?),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (unread)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: CircleAvatar(
                              radius: 5,
                              backgroundColor: cs.primary,
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      await context.push('/messages/${c['id']}');
                      _load();
                    },
                  );
                },
              ),
            ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _conv;
  Object? _loadError;
  bool _sending = false;
  Timer? _poll;
  int _lastCount = 0;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _recLevels = <double>[];
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _recStartedAt;
  bool _recording = false;
  String? _playing;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  /// Web não tem pasta temporária: o áudio baixado fica na memória da aba.
  static final _webAudio = <String, Uint8List>{};

  String get _convKey => 'conv:${widget.conversationId}';

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    _start();
  }

  Future<void> _start() async {
    final cached = await _readCache(_convKey);
    if (cached is Map && mounted && _conv == null) {
      _show(Map<String, dynamic>.from(cached));
    }
    await _load();
    if (!mounted) return;
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_appVisible) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _show(Map<String, dynamic> conv) {
    setState(() {
      _conv = conv;
      _loadError = null;
    });
    final count = _list(conv['messages']).length;
    if (count != _lastCount) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  /// Com mensagens na tela, pede só as novas e junta pelo id. Vindo uma
  /// página cheia, pode ter buraco no meio: fica só a resposta do banco.
  Future<void> _load() async {
    final have = _conv == null ? null : _list(_conv!['messages']);
    final after = (have == null || have.isEmpty)
        ? null
        : have.last['created_at'];
    try {
      final r = Map<String, dynamic>.from(
        await _db.rpc(
              'msg_open',
              params: {
                'p_conversation': widget.conversationId,
                if (after != null) 'p_after': after,
              },
            )
            as Map,
      );
      if (!mounted) return;
      final fresh = _list(r['messages']);
      if (after != null && fresh.length < _pageSize) {
        final seen = have!.map((m) => m['id']).toSet();
        final all = [...have, ...fresh.where((m) => !seen.contains(m['id']))]
          ..sort(
            (a, b) => DateTime.parse(
              '${a['created_at']}',
            ).compareTo(DateTime.parse('${b['created_at']}')),
          );
        r['messages'] = all.length > _pageSize
            ? all.sublist(all.length - _pageSize)
            : all;
      }
      _show(r);
      _writeCache(_convKey, r);
    } catch (e) {
      if (!mounted) return;
      // Saiu ou foi tirado da conversa: o cache some do aparelho.
      if (e is PostgrestException && e.code == 'P0002') {
        _writeCache(_convKey, null);
        setState(() {
          _conv = null;
          _loadError = e;
        });
      } else if (_conv == null) {
        setState(() => _loadError = e);
      }
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _db.rpc(
        'msg_send',
        params: {'p_conversation': widget.conversationId, 'p_content': text},
      );
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  File _audioFile(String path) => File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'msg-audio-${path.replaceAll('/', '_')}',
  );

  Future<void> _keepAudio(String path, Uint8List bytes) async {
    if (kIsWeb) {
      _webAudio[path] = bytes;
    } else {
      await _audioFile(path).writeAsBytes(bytes, flush: true);
    }
  }

  /// Baixa do bucket uma vez só; depois toca do aparelho.
  Future<Source> _audioSource(String path) async {
    if (!kIsWeb && await _audioFile(path).exists()) {
      return DeviceFileSource(_audioFile(path).path);
    }
    final bytes =
        _webAudio[path] ?? await _db.storage.from('msg-audio').download(path);
    await _keepAudio(path, bytes);
    if (!kIsWeb) return DeviceFileSource(_audioFile(path).path);
    // audioplayers_web não toca BytesSource: vira data URI.
    final mime = path.endsWith('.wav') ? 'audio/wav' : 'audio/mp4';
    return UrlSource(Uri.dataFromBytes(bytes, mimeType: mime).toString());
  }

  Future<void> _togglePlay(String path) async {
    try {
      await _player.stop();
      if (_playing == path) {
        setState(() => _playing = null);
        return;
      }
      setState(() {
        _playing = path;
        _pos = Duration.zero;
        _dur = Duration.zero;
      });
      await _player.play(await _audioSource(path));
    } catch (e) {
      if (!mounted) return;
      setState(() => _playing = null);
      _showError(context, e);
    }
  }

  Future<void> _startRecording() async {
    if (_sending) return;
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de microfone negada.')),
      );
      return;
    }
    try {
      await _player.stop();
      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '',
        );
      } else {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path:
              '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'msg_rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
      }
      _recLevels.clear();
      _recStartedAt = DateTime.now();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            _recLevels.add(a.current);
            if (mounted) setState(() {});
          }, onError: (_) {});
      if (mounted) setState(() => _recording = true);
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  /// [send] falso = descarta a gravação.
  Future<void> _stopRecording({required bool send}) async {
    await _ampSub?.cancel();
    _ampSub = null;
    final ms = DateTime.now()
        .difference(_recStartedAt ?? DateTime.now())
        .inMilliseconds;
    String? recorded;
    try {
      recorded = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _recording = false);
    // Menos de 1 s é toque sem querer.
    if (!send || recorded == null || recorded.isEmpty || ms < 1000) return;

    setState(() => _sending = true);
    try {
      final Uint8List bytes;
      if (kIsWeb) {
        bytes = (await http.get(Uri.parse(recorded))).bodyBytes;
      } else {
        final f = File(recorded);
        bytes = await f.readAsBytes();
        unawaited(f.delete().then((_) {}, onError: (_) {}));
      }
      final path =
          '${widget.conversationId}/${DateTime.now().microsecondsSinceEpoch}'
          '.${kIsWeb ? 'wav' : 'm4a'}';
      await _db.storage
          .from('msg-audio')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: kIsWeb ? 'audio/wav' : 'audio/mp4',
            ),
          );
      await _keepAudio(path, bytes);
      await _db.rpc(
        'msg_send',
        params: {
          'p_conversation': widget.conversationId,
          'p_content': '',
          'p_audio_path': path,
          'p_audio_ms': ms,
          'p_audio_levels': waveformBars(_recLevels),
        },
      );
      await _load();
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _audioMessage(Map<String, dynamic> m, bool mine, bool showAuthor) {
    final cs = Theme.of(context).colorScheme;
    final path = '${m['audio_path']}';
    final levels = (m['audio_levels'] as List?)
        ?.map((v) => (v as num).toDouble())
        .toList();
    final playing = _playing == path;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showAuthor && !mine)
            Text(
              '${m['author_name']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: cs.primary,
              ),
            ),
          AudioMessageBubble(
            isUser: mine,
            accent: cs.primary,
            bars: levels == null || levels.isEmpty
                ? List.filled(32, 0.4)
                : levels,
            durationMs: (m['audio_ms'] as num?)?.toInt() ?? 0,
            progress: playing && _dur.inMilliseconds > 0
                ? _pos.inMilliseconds / _dur.inMilliseconds
                : 0,
            isPlaying: playing,
            avatar: ColoredBox(
              color: cs.primaryContainer,
              child: Icon(Icons.person, size: 20, color: cs.onPrimaryContainer),
            ),
            onToggle: () => _togglePlay(path),
          ),
          Text(
            _when(m['created_at'] as String?),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final conv = _conv!;
    final isMinistry = conv['ministry_id'] != null;
    final List<Map<String, dynamic>> people;
    try {
      people = isMinistry
          ? _list(
              await _db.rpc(
                'msg_ministry_candidates',
                params: {'p_conversation': widget.conversationId},
              ),
            )
          : _list(await _db.rpc('msg_leaders'));
    } catch (e) {
      if (mounted) _showError(context, e);
      return;
    }
    final inside = _list(conv['members']).map((m) => m['id']).toSet();
    final candidates = people.where((p) => !inside.contains(p['id'])).toList();
    if (!mounted) return;
    final picked = await pickPeople(
      context,
      candidates,
      title: 'Adicionar pessoas',
      hint: conv['kind'] == 'direct'
          ? 'Uma conversa nova em grupo vai ser criada com vocês e quem você escolher.'
          : null,
    );
    if (picked == null || !mounted) return;
    try {
      final id = await _db.rpc(
        'msg_add',
        params: {
          'p_conversation': widget.conversationId,
          'p_users': picked.ids,
        },
      );
      if (!mounted) return;
      if (id != widget.conversationId) {
        context.pushReplacement('/messages/$id');
      } else {
        _load();
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _remove(Map<String, dynamic> person) async {
    final me = person['me'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(me ? 'Sair da conversa?' : 'Tirar ${person['name']}?'),
        content: Text(
          me
              ? 'Você deixa de ver e de receber as mensagens desta conversa.'
              : '${person['name']} deixa de ver e de receber as mensagens desta conversa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(me ? 'Sair' : 'Tirar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.rpc(
        'msg_remove',
        params: {
          'p_conversation': widget.conversationId,
          'p_user': person['id'],
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // fecha a folha de participantes
      if (me) {
        context.pop();
      } else {
        _load();
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  void _showMembers() {
    final conv = _conv!;
    final canRemove = conv['can_remove_others'] == true;
    final members = _list(conv['members']);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  'Participantes (${members.length})',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                trailing: conv['can_add'] == true
                    ? TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _add();
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Adicionar'),
                      )
                    : null,
              ),
              for (final m in members)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    m['me'] == true ? '${m['name']} (você)' : '${m['name']}',
                  ),
                  trailing: m['me'] == true
                      ? TextButton(
                          onPressed: () => _remove(m),
                          child: const Text('Sair'),
                        )
                      : canRemove
                      ? IconButton(
                          tooltip: 'Tirar da conversa',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () => _remove(m),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final conv = _conv;
    if (conv == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversa')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppErrorHandler.userMessage(
                      _loadError!,
                      feature: 'messages',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }
    final messages = _list(conv['messages']);
    final showAuthor = conv['kind'] != 'direct';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          conv['title'] as String? ?? 'Conversa',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Participantes',
            icon: const Icon(Icons.group_outlined),
            onPressed: _showMembers,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text('Nenhuma mensagem ainda. Diga olá!'),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        final mine = m['mine'] == true;
                        if (m['audio_path'] != null) {
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: _audioMessage(m, mine, showAuthor),
                          );
                        }
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showAuthor && !mine)
                                  Text(
                                    '${m['author_name']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: cs.primary,
                                    ),
                                  ),
                                SelectableText('${m['content']}'),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    _when(m['created_at'] as String?),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: _recording
                  ? Row(
                      children: [
                        IconButton(
                          tooltip: 'Descartar áudio',
                          onPressed: () => _stopRecording(send: false),
                          icon: const Icon(Icons.delete_outline),
                        ),
                        Icon(Icons.fiber_manual_record, color: cs.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gravando ${formatAudioDuration(DateTime.now().difference(_recStartedAt ?? DateTime.now()).inMilliseconds)}',
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Enviar áudio',
                          onPressed: () => _stopRecording(send: true),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 4000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Escreva uma mensagem',
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Campo vazio: microfone, como no chat do Moisés.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _text,
                          builder: (context, value, _) =>
                              value.text.trim().isEmpty
                              ? IconButton.filled(
                                  tooltip: 'Gravar áudio',
                                  onPressed: _sending ? null : _startRecording,
                                  icon: const Icon(Icons.mic),
                                )
                              : IconButton.filled(
                                  tooltip: 'Enviar',
                                  onPressed: _sending ? null : _send,
                                  icon: const Icon(Icons.send),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PickedPeople {
  const PickedPeople(this.ids, this.title);
  final List<String> ids;
  final String? title;
}

/// Escolhe uma ou mais pessoas (com busca). Com [askTitle] e mais de uma
/// pessoa, pede um nome opcional para o grupo.
Future<PickedPeople?> pickPeople(
  BuildContext context,
  List<Map<String, dynamic>> people, {
  required String title,
  String? hint,
  bool askTitle = false,
}) {
  return showDialog<PickedPeople>(
    context: context,
    builder: (ctx) => _PickPeopleDialog(
      people: people,
      title: title,
      hint: hint,
      askTitle: askTitle,
    ),
  );
}

class _PickPeopleDialog extends StatefulWidget {
  const _PickPeopleDialog({
    required this.people,
    required this.title,
    this.hint,
    required this.askTitle,
  });

  final List<Map<String, dynamic>> people;
  final String title;
  final String? hint;
  final bool askTitle;

  @override
  State<_PickPeopleDialog> createState() => _PickPeopleDialogState();
}

class _PickPeopleDialogState extends State<_PickPeopleDialog> {
  final _selected = <String>{};
  final _groupName = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.people
        .where((p) => '${p['name']}'.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            if (widget.hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(widget.hint!),
              ),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar pelo nome',
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            if (widget.askTitle && _selected.length > 1)
              TextField(
                controller: _groupName,
                decoration: const InputDecoration(
                  labelText: 'Nome do grupo (opcional)',
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.people.isEmpty
                  ? const Center(
                      child: Text('Ninguém disponível para adicionar.'),
                    )
                  : ListView(
                      children: [
                        for (final p in shown)
                          CheckboxListTile(
                            value: _selected.contains(p['id']),
                            title: Text('${p['name']}'),
                            onChanged: (v) => setState(() {
                              v == true
                                  ? _selected.add('${p['id']}')
                                  : _selected.remove('${p['id']}');
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  PickedPeople(
                    _selected.toList(),
                    _groupName.text.trim().isEmpty
                        ? null
                        : _groupName.text.trim(),
                  ),
                ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
