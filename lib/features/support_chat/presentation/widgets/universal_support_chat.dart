import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../data/support_agents_data.dart';
import '../../domain/models/support_agent.dart';
import '../providers/agents_providers.dart';
import 'agent_avatar.dart';
import '../../../members/presentation/providers/members_provider.dart';

/// Componente para o Chat de Suporte Universal
/// Conecta com a Edge Function 'support-chat' via OpenAI Assistants.
class UniversalSupportChat extends ConsumerStatefulWidget {
  final String agentKey; // 'default', 'kids', 'media', etc.
  final Map<String, dynamic>? initialContext;
  final Color accentColor;
  final bool showAppBar;
  final String? title;
  final ValueChanged<ResolvedAgent>? onAgentChanged;

  const UniversalSupportChat({
    super.key,
    this.agentKey = 'default',
    this.initialContext,
    this.accentColor = const Color(0xFF2563EB),
    this.showAppBar = false,
    this.title,
    this.onAgentChanged,
  });

  @override
  ConsumerState<UniversalSupportChat> createState() => _UniversalSupportChatState();
}

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

Future<void> clearLocalChat(String agentKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final rawKey = agentKey.trim();
    final normalizedKey = rawKey.toLowerCase();
    await prefs.remove('chat_history_$rawKey');
    await prefs.remove('chat_history_$normalizedKey');
    await prefs.remove('support_thread_$rawKey');
    await prefs.remove('support_thread_$normalizedKey');
  } catch (_) {}
}

class _UniversalSupportChatState extends ConsumerState<UniversalSupportChat> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _textFocusNode;
  bool _hasFocus = false;
  
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _threadId;
  final List<PlatformFile> _attachments = [];
  late String _activeAgentKey;
  late Color _accentColor;
  late String _localHistoryKey;
  List<Map<String, dynamic>> _pendingTransferCandidates = const [];
  bool _hasText = false;
  bool _showQuickActions = false;

  late SupportAgent _baseAgent;
  late ResolvedAgent _agent;
  ProviderSubscription<AsyncValue<List<ResolvedAgent>>>? _resolvedAgentsSub;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  late final AudioPlayer _audioPlayer;
  PlayerState _audioPlayerState = PlayerState.stopped;
  String? _playingAudioId;

  Color _chatBackgroundColor = const Color(0xFFF9FAFB);
  String? _chatWallpaperUrl;
  bool _isUploadingWallpaper = false;
  String? _userMemberId;
  Map<String, dynamic> _remoteChatPreferences = const {};
  bool _remoteChatPreferencesLoaded = false;

  static const int _maxLocalMessagesPerAgent = 50;

  void _handleTextChanged() {
    final next = _textController.text.trim().isNotEmpty;
    if (!mounted) return;
    if (next != _hasText) {
      setState(() {
        _hasText = next;
        if (_hasText) _showQuickActions = false;
      });
      return;
    }
    if (_hasText && _showQuickActions) {
      setState(() {
        _showQuickActions = false;
      });
    }
  }

  ResolvedAgent _resolveFromResolvedList(List<ResolvedAgent> list) {
    final normalizedKey = _activeAgentKey.toLowerCase();
    return list.cast<ResolvedAgent?>().firstWhere(
          (a) => a?.key.toLowerCase() == normalizedKey,
          orElse: () => null,
        ) ??
        resolveAgent(_baseAgent, null);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textFocusNode = FocusNode();
    _textFocusNode.addListener(() {
      setState(() {
        _hasFocus = _textFocusNode.hasFocus;
      });
    });
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlayerState = state;
        if (state == PlayerState.stopped) _playingAudioId = null;
      });
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingAudioId = null;
        _audioPlayerState = PlayerState.stopped;
      });
    });
    _hasText = _textController.text.trim().isNotEmpty;
    _textController.addListener(_handleTextChanged);
    _activeAgentKey = widget.agentKey;
    _accentColor = widget.accentColor;
    _localHistoryKey = 'chat_history_${_activeAgentKey.toLowerCase()}';
    _baseAgent = kSupportAgents[_activeAgentKey.toLowerCase()] ?? kSupportAgents['default']!;
    _agent = resolveAgent(_baseAgent, null);
    final current = ref.read(resolvedAgentsProvider);
    final immediate = current.maybeWhen(
      data: (list) => _resolveFromResolvedList(list),
      orElse: () => null,
    );
    if (immediate != null) {
      _agent = immediate;
    }
    widget.onAgentChanged?.call(_agent);
    _resolvedAgentsSub = ref.listenManual<AsyncValue<List<ResolvedAgent>>>(resolvedAgentsProvider, (previous, next) {
      next.whenData((list) {
        final match = _resolveFromResolvedList(list);

        final changed = match.name != _agent.name ||
            match.avatarUrl != _agent.avatarUrl ||
            match.themeColor != _agent.themeColor;
        if (!changed) return;
        if (!mounted) return;
        setState(() {
          _agent = match;
        });
        widget.onAgentChanged?.call(match);
      });
    });
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textFocusNode.dispose();
    _resolvedAgentsSub?.close();
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      // Se o teclado abriu, garante que estamos no final (0.0 na lista reversa)
      _scrollToBottom();
    }
  }

  @override
  void didUpdateWidget(covariant UniversalSupportChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentKey.toLowerCase() == widget.agentKey.toLowerCase() &&
        oldWidget.accentColor == widget.accentColor) {
      return;
    }
    _activeAgentKey = widget.agentKey;
    _accentColor = widget.accentColor;
    _localHistoryKey = 'chat_history_${_activeAgentKey.toLowerCase()}';
    _showQuickActions = false;
    _remoteChatPreferencesLoaded = false;
    _baseAgent = kSupportAgents[_activeAgentKey.toLowerCase()] ?? kSupportAgents['default']!;
    _agent = resolveAgent(_baseAgent, null);
    final current = ref.read(resolvedAgentsProvider);
    final immediate = current.maybeWhen(
      data: (list) => _resolveFromResolvedList(list),
      orElse: () => null,
    );
    if (immediate != null) {
      _agent = immediate;
    }
    widget.onAgentChanged?.call(_agent);
    _loadChatBackgroundSafely();
    _loadChatWallpaperSafely();
    _loadRemoteChatPreferencesSafely();
    _loadThreadSafely();
  }

  String get _threadStorageKey => 'support_thread_$_activeAgentKey';

  Future<void> _initializeChat() async {
    try {
      final member = await ref.read(currentMemberProvider.future);
      _userMemberId = member?.id;
    } catch (_) {}
    await _loadChatBackgroundSafely();
    await _loadChatWallpaperSafely();
    await _loadRemoteChatPreferencesSafely();
    await _loadThreadSafely();
    await _loadLocalHistorySafely();

    if (!mounted) return;
    if (_messages.isEmpty) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': _agent.welcomeMessage ??
              'Olá! Como posso ajudar com ${_agent.role}?',
          'time': DateTime.now(),
        });
      });
    }
    _scrollToBottom();
  }

  String get _chatBackgroundStorageKey => 'support_chat_bg_${_activeAgentKey.toLowerCase()}';
  String get _chatWallpaperStorageKey {
    final uid = (_userMemberId ?? 'anon').toLowerCase();
    return 'support_chat_wallpaper_${uid}_${_activeAgentKey.toLowerCase()}';
  }

  Map<String, dynamic>? _asJsonMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic> _agentPrefsFromRoot(Map<String, dynamic> root) {
    final key = _activeAgentKey.toLowerCase();
    final v = root[key];
    final map = _asJsonMap(v);
    return map ?? <String, dynamic>{};
  }

  Future<void> _loadRemoteChatPreferencesSafely() async {
    if (_remoteChatPreferencesLoaded) return;
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      Map<String, dynamic>? row;
      try {
        row = await supabase
            .from('user_account')
            .select('support_chat_preferences')
            .eq('tenant_id', SupabaseConstants.currentTenantId)
            .eq('auth_user_id', uid)
            .maybeSingle();
      } catch (_) {}

      row ??= await supabase
          .from('user_account')
          .select('support_chat_preferences')
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('id', uid)
          .maybeSingle();

      final root = _asJsonMap(row?['support_chat_preferences']) ?? <String, dynamic>{};
      _remoteChatPreferences = root;
      _remoteChatPreferencesLoaded = true;

      final agentPrefs = _agentPrefsFromRoot(root);
      final bgRaw = agentPrefs['bgColor']?.toString().trim();
      final wpRaw = agentPrefs['wallpaperUrl']?.toString().trim();
      Color? parsedBg;
      String? parsedWp;

      if (bgRaw != null && bgRaw.isNotEmpty) {
        final v = int.tryParse(bgRaw, radix: 16);
        if (v != null) parsedBg = Color(v);
      }
      if (wpRaw != null && wpRaw.isNotEmpty) {
        parsedWp = wpRaw;
      }

      if (parsedBg != null) {
        await _saveChatBackgroundSafely(parsedBg);
      }
      if (parsedWp != null && parsedWp.isNotEmpty) {
        await _saveChatWallpaperUrlSafely(parsedWp);
      }

      if (mounted) {
        setState(() {
          if (parsedBg != null) _chatBackgroundColor = parsedBg;
          if (parsedWp != null && parsedWp.isNotEmpty) _chatWallpaperUrl = parsedWp;
        });
      }
    } catch (_) {
      _remoteChatPreferencesLoaded = true;
    }
  }

  Future<void> _saveRemoteChatPreferencesSafely({
    Color? chatBackgroundColor,
    String? chatWallpaperUrl,
  }) async {
    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      if (!_remoteChatPreferencesLoaded) {
        await _loadRemoteChatPreferencesSafely();
      }

      final root = Map<String, dynamic>.from(_remoteChatPreferences);
      final agentKey = _activeAgentKey.toLowerCase();
      final currentAgent = _agentPrefsFromRoot(root);
      final nextAgent = Map<String, dynamic>.from(currentAgent);
      if (chatBackgroundColor != null) {
        nextAgent['bgColor'] = chatBackgroundColor.toARGB32().toRadixString(16);
      }
      if (chatWallpaperUrl != null) {
        nextAgent['wallpaperUrl'] = chatWallpaperUrl.trim();
      }
      root[agentKey] = nextAgent;

      await supabase
          .from('user_account')
          .update({'support_chat_preferences': root})
          .eq('tenant_id', SupabaseConstants.currentTenantId)
          .eq('auth_user_id', uid);

      _remoteChatPreferences = root;
      _remoteChatPreferencesLoaded = true;
    } catch (_) {}
  }

  Future<void> _loadChatBackgroundSafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatBackgroundStorageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final v = int.tryParse(raw, radix: 16);
      if (v == null) return;
      if (!mounted) return;
      setState(() {
        _chatBackgroundColor = Color(v);
      });
    } catch (_) {}
  }

  Future<void> _loadChatWallpaperSafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatWallpaperStorageKey);
      if (raw == null || raw.trim().isEmpty) return;
      if (!mounted) return;
      setState(() {
        _chatWallpaperUrl = raw.trim();
      });
    } catch (_) {}
  }

  Future<void> _saveChatBackgroundSafely(Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatBackgroundStorageKey, color.toARGB32().toRadixString(16));
    } catch (_) {}
  }

  Future<void> _saveChatWallpaperUrlSafely(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatWallpaperStorageKey, url);
    } catch (_) {}
  }

  Future<void> _cycleChatBackground() async {
    const presets = <Color>[
      Color(0xFFF9FAFB),
      Colors.white,
      Color(0xFFEFEAE2),
    ];
    final idx = presets.indexWhere((c) => c.toARGB32() == _chatBackgroundColor.toARGB32());
    final next = presets[(idx < 0 ? 0 : (idx + 1) % presets.length)];
    if (!mounted) return;
    setState(() {
      _chatBackgroundColor = next;
    });
    await _saveRemoteChatPreferencesSafely(chatBackgroundColor: next);
    await _saveChatBackgroundSafely(next);
  }

  String _wallpaperContentTypeFromName(String name) {
    final ext = name.trim().toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickAndUploadWallpaper() async {
    final supabase = Supabase.instance.client;
    String? memberId = _userMemberId;
    if (memberId == null) {
      try {
        final member = await ref.read(currentMemberProvider.future);
        memberId = member?.id;
        _userMemberId = memberId;
      } catch (_) {}
    }
    if (memberId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado')),
        );
      }
      return;
    }

    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (mounted) {
      setState(() {
        _showQuickActions = false;
      });
    }

    Uint8List? bytes = file.bytes;
    if (!kIsWeb && bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler a imagem selecionada')),
        );
      }
      return;
    }

    final filePath = 'support-chat-wallpapers/${memberId}_${_activeAgentKey.toLowerCase()}_wallpaper';
    final contentType = _wallpaperContentTypeFromName(file.name);
    const buckets = <String>[
      'chat-wallpapers',
      'church-assets',
    ];

    if (mounted) {
      setState(() {
        _isUploadingWallpaper = true;
      });
    }

    String? usedBucket;
    try {
      for (final bucket in buckets) {
        try {
          await supabase.storage.from(bucket).uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: true,
                ),
              );
          usedBucket = bucket;
          break;
        } on StorageException catch (e) {
          final msg = e.message.toString();
          final sc = e.statusCode.toString();
          final bucketMissing = sc == '404' || msg.toLowerCase().contains('bucket not found');
          if (!bucketMissing) rethrow;
        }
      }

      if (usedBucket == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bucket de wallpaper não encontrado')),
          );
        }
        return;
      }

      final publicUrl = supabase.storage.from(usedBucket).getPublicUrl(filePath);
      final cacheBustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await _saveRemoteChatPreferencesSafely(chatWallpaperUrl: cacheBustedUrl);
      await _saveChatWallpaperUrlSafely(cacheBustedUrl);
      if (!mounted) return;
      setState(() {
        _chatWallpaperUrl = cacheBustedUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fundo atualizado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer upload do fundo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingWallpaper = false;
        });
      }
    }
  }

  void _toggleQuickActions() {
    if (!mounted) return;
    if (_isLoading || _isUploadingWallpaper) return;
    setState(() {
      _showQuickActions = !_showQuickActions;
    });
  }

  Widget _buildQuickActionsBar() {
    final canAttach = _agent.allowAttachments;
    final actions = <Widget>[
      _buildQuickActionButton(
        icon: Icons.wallpaper,
        label: 'Fundo',
        onPressed: _pickAndUploadWallpaper,
      ),
      _buildQuickActionButton(
        icon: Icons.palette_outlined,
        label: 'Cor',
        onPressed: _cycleChatBackground,
      ),
    ];
    if (canAttach) {
      actions.insert(
        0,
        _buildQuickActionButton(
          icon: Icons.attach_file,
          label: 'Anexo',
          onPressed: _pickFiles,
        ),
      );
    }

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 180),
      crossFadeState: _showQuickActions ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: actions,
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Future<void> Function() onPressed,
  }) {
    final disabled = _isLoading || _isUploadingWallpaper;
    return InkWell(
      onTap: disabled
          ? null
          : () async {
              if (mounted) {
                setState(() {
                  _showQuickActions = false;
                });
              }
              await onPressed();
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF3F4F6),
              child: Icon(icon, size: 18, color: disabled ? const Color(0xFF9CA3AF) : const Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: disabled ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadThreadSafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _threadId = prefs.getString(_threadStorageKey);
      });
    } catch (_) {}
  }

  Future<void> _saveThread(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_threadStorageKey, id);
      if (!mounted) return;
      setState(() {
        _threadId = id;
      });
    } catch (_) {}
  }

  Future<void> _loadLocalHistorySafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localHistoryKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final loaded = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;

        final sender = item['sender']?.toString();
        final text = item['text']?.toString();
        if (sender == null || text == null) continue;

        final role = sender == 'user' ? 'user' : (sender == 'agent' ? 'assistant' : null);
        if (role == null) continue;

        final tsRaw = item['timestamp'];
        final ts = tsRaw is int ? tsRaw : int.tryParse(tsRaw?.toString() ?? '');
        final time = DateTime.fromMillisecondsSinceEpoch(
          ts ?? DateTime.now().millisecondsSinceEpoch,
        );

        loaded.add({
          'role': role,
          'content': text,
          'time': time,
        });
      }

      if (loaded.length > _maxLocalMessagesPerAgent) {
        loaded.removeRange(0, loaded.length - _maxLocalMessagesPerAgent);
      }

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {}
  }

  Future<void> _saveLocalHistorySafely() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializable = <Map<String, dynamic>>[];

      for (final msg in _messages) {
        final role = msg['role']?.toString();
        if (role != 'user' && role != 'assistant') continue;

        final content = msg['content']?.toString() ?? '';
        final time = msg['time'] is DateTime ? msg['time'] as DateTime : DateTime.now();

        serializable.add({
          'sender': role == 'user' ? 'user' : 'agent',
          'text': content,
          'timestamp': time.millisecondsSinceEpoch,
        });
      }

      if (serializable.length > _maxLocalMessagesPerAgent) {
        serializable.removeRange(0, serializable.length - _maxLocalMessagesPerAgent);
      }

      await prefs.setString(_localHistoryKey, jsonEncode(serializable));
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    if (!_agent.allowAttachments) return;
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true, // Necessário para upload via bytes
      );

      if (result != null) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivos: $e')),
        );
      }
    }
  }

  bool _isAudioFileName(String name) {
    final ext = name.trim().toLowerCase().split('.').last;
    return ext == 'm4a' || ext == 'mp3' || ext == 'wav' || ext == 'ogg' || ext == 'aac';
  }

  Future<void> _toggleRecording() async {
    if (!_agent.allowAttachments) return;

    if (_isRecording) {
      String? path;
      try {
        path = await _audioRecorder.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      if (path == null || path.isEmpty) return;

      try {
        Uint8List bytes;
        String name;
        if (kIsWeb) {
          final res = await http.get(Uri.parse(path));
          bytes = res.bodyBytes;
          name = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        } else {
          bytes = await File(path).readAsBytes();
          name = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        final file = PlatformFile(
          name: name,
          size: bytes.length,
          bytes: bytes,
          path: path,
        );
        if (!mounted) return;
        setState(() {
          _attachments.add(file);
        });
        await _handleSend();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao finalizar gravação: $e')),
        );
      }
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de microfone negada.')),
      );
      return;
    }

    try {
      if (kIsWeb) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '',
        );
      } else {
        final path =
            '${Directory.systemTemp.path}${Platform.pathSeparator}church360_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar gravação: $e')),
      );
    }
  }

  Uint8List? _bytesFromDynamic(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  String _audioItemId(Map<String, dynamic> item, int index) {
    final path = item['path']?.toString().trim();
    if (path != null && path.isNotEmpty) return path;
    final name = item['name']?.toString().trim().isNotEmpty == true ? item['name']!.toString() : 'audio';
    final bytes = _bytesFromDynamic(item['bytes']);
    final len = bytes?.length ?? 0;
    return '$name#$len#$index';
  }

  Future<void> _togglePlayAudioItem({
    required String id,
    String? path,
    Uint8List? bytes,
  }) async {
    try {
      if (_playingAudioId == id && _audioPlayerState == PlayerState.playing) {
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() {
          _playingAudioId = null;
          _audioPlayerState = PlayerState.stopped;
        });
        return;
      }

      await _audioPlayer.stop();
      if (bytes != null) {
        await _audioPlayer.play(BytesSource(bytes));
      } else {
        final p = path?.trim() ?? '';
        if (p.isEmpty) return;
        if (kIsWeb) {
          await _audioPlayer.play(UrlSource(p));
        } else {
          await _audioPlayer.play(DeviceFileSource(p));
        }
      }
      if (!mounted) return;
      setState(() {
        _playingAudioId = id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reproduzir áudio: $e')),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  String _normalize(String s) {
    var out = s.trim().toLowerCase();
    out = out
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  String _cleanTransferQuery(String query) {
    var q = query.trim();
    q = q.replaceAll(RegExp(r'[.!?,;:]+$'), '');
    q = q.replaceAll(RegExp(r'\b(por favor|pfv|por gentileza|por gentileza\.)\b', caseSensitive: false), '');
    q = q.replaceAll(RegExp(r'[.!?,;:]+$'), '');
    q = q.trim();
    q = q.replaceFirst(RegExp(r'^(o|a|os|as|um|uma|uns|umas)\s+', caseSensitive: false), '');
    q = q.replaceFirst(RegExp(r'^(do|da|dos|das|de)\s+', caseSensitive: false), '');
    q = q.trim();
    return q;
  }

  String? _extractTransferQuery(String text) {
    final t = text.trim();
    final m1 = RegExp(r'^/agente\s+(.+)$', caseSensitive: false).firstMatch(t);
    if (m1 != null) return _cleanTransferQuery(m1.group(1)?.trim() ?? '');
    final m2 = RegExp(r'^/agent\s+(.+)$', caseSensitive: false).firstMatch(t);
    if (m2 != null) return _cleanTransferQuery(m2.group(1)?.trim() ?? '');
    final mCmd = RegExp(r'^/(?:transfer|transfere)\s+(.+)$', caseSensitive: false).firstMatch(t);
    if (mCmd != null) return _cleanTransferQuery(mCmd.group(1)?.trim() ?? '');

    final m3 = RegExp(
      r'^(?:me\s+)?(?:transfere|transfira|transferir|transferência|transferencia)\s+(?:para|pra|pro)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(t);
    if (m3 != null) return _cleanTransferQuery(m3.group(1)?.trim() ?? '');
    final m4 = RegExp(r'^(?:quero|quero falar com|falar com)\s+(.+)$', caseSensitive: false).firstMatch(t);
    if (m4 != null) return _cleanTransferQuery(m4.group(1)?.trim() ?? '');

    final fallbackMatches = RegExp(
      r'(?:transfere|transfira|transferir|transferência|transferencia)\s+(?:para|pra|pro)\s+(.+)$',
      caseSensitive: false,
    ).allMatches(t);
    if (fallbackMatches.isNotEmpty) {
      return _cleanTransferQuery(fallbackMatches.last.group(1)?.trim() ?? '');
    }
    return null;
  }

  ResolvedAgent? _resolveAgentByQuery(List<ResolvedAgent> available, String query) {
    final q = _normalize(query);
    if (q.isEmpty) return null;

    final byKey = available.where((a) => a.key.toLowerCase() == q).toList();
    if (byKey.length == 1) return byKey.first;

    final byNameExact = available.where((a) => _normalize(a.name) == q).toList();
    if (byNameExact.length == 1) return byNameExact.first;

    final byNameContains = available.where((a) => _normalize(a.name).contains(q)).toList();
    if (byNameContains.length == 1) return byNameContains.first;

    final byRole = available.where((a) {
      final subtitle = a.subtitle ?? '';
      return _normalize(a.role).contains(q) || _normalize(subtitle).contains(q);
    }).toList();
    if (byRole.length == 1) return byRole.first;

    return null;
  }

  Map<String, dynamic> _parseTransferSuggest(String reply) {
    const marker = '[[TRANSFER_SUGGEST]]';
    final lines = reply.split('\n');
    final idx = lines.lastIndexWhere((l) => l.trimLeft().startsWith(marker));
    if (idx < 0) {
      return {
        'text': reply,
        'candidates': <Map<String, dynamic>>[],
      };
    }

    final line = lines[idx].trim();
    final jsonPart = line.substring(marker.length).trim();
    final cleanText = lines.take(idx).join('\n').trimRight();

    try {
      final decoded = jsonDecode(jsonPart);
      final candidatesRaw = (decoded is Map) ? decoded['candidates'] : null;
      if (candidatesRaw is List) {
        final candidates = candidatesRaw
            .whereType<Map>()
            .map((c) => {
                  'key': c['key']?.toString() ?? '',
                  'name': c['name']?.toString() ?? '',
                  'reason': c['reason']?.toString() ?? '',
                })
            .where((c) => (c['key'] ?? '').toString().trim().isNotEmpty)
            .toList();
        return {
          'text': cleanText,
          'candidates': candidates,
        };
      }
    } catch (_) {}

    return {
      'text': cleanText,
      'candidates': <Map<String, dynamic>>[],
    };
  }

  String _buildTransferSummary() {
    final recent = _messages
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .toList()
        .reversed
        .take(10)
        .toList()
        .reversed;
    final parts = <String>[];
    for (final m in recent) {
      final role = m['role']?.toString() ?? '';
      final content = (m['content']?.toString() ?? '').trim();
      if (content.isEmpty) continue;
      if (role == 'user') {
        parts.add('Usuário: $content');
      } else if (role == 'assistant') {
        final agent = m['agent'];
        final agentName = agent is ResolvedAgent ? agent.name : _agent.name;
        parts.add('$agentName: $content');
      }
    }
    return parts.join('\n');
  }

  Future<List<ResolvedAgent>> _getAvailableAgents() async {
    try {
      return await ref.read(visibleAgentsForCurrentUserProvider.future);
    } catch (_) {
      return <ResolvedAgent>[];
    }
  }

  Future<Map<String, dynamic>> _sendToBackend({
    required String message,
    required List<PlatformFile> files,
    Map<String, dynamic>? extraContext,
  }) async {
    final functionUrl = '${SupabaseConstants.supabaseUrl}/functions/v1/support-chat';
    final request = http.MultipartRequest('POST', Uri.parse(functionUrl));

    final supabase = Supabase.instance.client;
    String? accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      try {
        final refreshed = await supabase.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      } catch (_) {}
    }
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Sessão inválida. Faça login novamente e tente de novo.');
    }

    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'apikey': SupabaseConstants.supabaseAnonKey,
      'x-tenant-id': SupabaseConstants.currentTenantId,
    });

    request.fields['message'] = message;
    request.fields['agentKey'] = _activeAgentKey;
    if (_threadId != null) {
      request.fields['threadId'] = _threadId!;
    }

    final context = <String, dynamic>{
      if (widget.initialContext != null) ...widget.initialContext!,
      'agentKey': _activeAgentKey,
      'agentName': _agent.name,
      'agentRole': _agent.role,
      if (_agent.subtitle != null) 'agentSubtitle': _agent.subtitle,
      if (extraContext != null) ...extraContext,
    };

    final available = await _getAvailableAgents();
    if (available.isNotEmpty) {
      context['agentsAvailable'] = available
          .map((a) => {
                'key': a.key,
                'name': a.name,
                'role': a.role,
                if (a.subtitle != null) 'subtitle': a.subtitle,
              })
          .toList();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      context.putIfAbsent('authUserId', () => user.id);
      context.putIfAbsent('email', () => user.email);
    }
    try {
      final member = await ref.read(currentMemberProvider.future);
      if (member != null) {
        context.putIfAbsent('memberId', () => member.id);
      }
    } catch (_) {}

    request.fields['context'] = jsonEncode(context);

    for (final file in files) {
      if (file.bytes == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file.bytes!,
          filename: file.name,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('Erro ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data as Map<String, dynamic>;
  }

  Future<void> _performTransfer(ResolvedAgent target, {String? reason}) async {
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
    final fromAgent = _agent;
    final subtitle = target.subtitle ?? target.role;
    final now = DateTime.now();

    setState(() {
      _messages.add({
        'role': 'system',
        'content': 'Transferindo você para ${target.name}${subtitle.isNotEmpty ? ' ($subtitle)' : ''}…',
        'time': now,
        'isError': false,
      });
      _pendingTransferCandidates = const [];
    });

    await _saveLocalHistorySafely();
    _scrollToBottom();

    setState(() {
      _activeAgentKey = target.key;
      _localHistoryKey = 'chat_history_${_activeAgentKey.toLowerCase()}';
      _baseAgent = kSupportAgents[_activeAgentKey.toLowerCase()] ?? kSupportAgents['default']!;
      _agent = target;
      _accentColor = target.themeColor;
      _isLoading = true;
    });
    widget.onAgentChanged?.call(target);

    await _loadThreadSafely();

    final summary = _buildTransferSummary();
    try {
      final data = await _sendToBackend(
        message: 'Você agora é ${target.name}. Cumprimente o usuário e continue a partir do resumo abaixo.\n\n$summary',
        files: const [],
        extraContext: {
          'transferFromAgentKey': fromAgent.key,
          'transferFromAgentName': fromAgent.name,
          if (reason != null && reason.trim().isNotEmpty) 'transferReason': reason.trim(),
        },
      );
      final replyRaw = (data['reply'] ?? '').toString();
      final newThreadId = data['threadId']?.toString();
      if (newThreadId != null && newThreadId.isNotEmpty && newThreadId != _threadId) {
        await _saveThread(newThreadId);
      }

      final parsed = _parseTransferSuggest(replyRaw);
      final reply = (parsed['text'] ?? '').toString().trim();
      final candidates = (parsed['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': reply.isEmpty ? 'Olá! Como posso ajudar?' : reply,
            'time': DateTime.now(),
            'agent': target,
            if (candidates.isNotEmpty) 'transferCandidates': candidates,
          });
          _pendingTransferCandidates = candidates;
        });
        await _saveLocalHistorySafely();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'system',
            'content': 'Erro ao transferir: $e',
            'time': DateTime.now(),
            'isError': true,
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSend() async {
    if (mounted && _showQuickActions) {
      setState(() {
        _showQuickActions = false;
      });
    }
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    final availableAgents = await _getAvailableAgents();
    final transferQuery = _extractTransferQuery(text);
    final isCommand = text.trimLeft().startsWith('/');

    ResolvedAgent? transferTarget;
    if (transferQuery != null) {
      transferTarget = _resolveAgentByQuery(availableAgents, transferQuery);
    } else if (_pendingTransferCandidates.isNotEmpty) {
      final match = _pendingTransferCandidates.firstWhere(
        (c) => _normalize(c['key']?.toString() ?? '') == _normalize(text) ||
            _normalize(c['name']?.toString() ?? '') == _normalize(text),
        orElse: () => <String, dynamic>{},
      );
      final key = match['key']?.toString() ?? '';
      if (key.isNotEmpty) {
        transferTarget = availableAgents.firstWhere(
          (a) => a.key.toLowerCase() == key.toLowerCase(),
          orElse: () => _agent,
        );
        if (transferTarget.key.toLowerCase() == _agent.key.toLowerCase()) {
          transferTarget = null;
        }
      }
    }

    if (transferTarget != null && _attachments.isEmpty) {
      if (!isCommand) {
        final userMsg = {
          'role': 'user',
          'content': text,
          'time': DateTime.now(),
        };
        setState(() {
          _messages.add(userMsg);
        });
        await _saveLocalHistorySafely();
      }

      _textController.clear();
      await _performTransfer(transferTarget);
      return;
    }

    final userMsg = {
      'role': 'user',
      'content': text.isEmpty
          ? (_attachments.isNotEmpty && _attachments.every((f) => _isAudioFileName(f.name)) ? '[Áudio]' : '[Arquivo enviado]')
          : text,
      'time': DateTime.now(),
      'attachments': _attachments.map((f) => f.name).toList(),
    };

    final audioItems = <Map<String, dynamic>>[];
    for (final f in _attachments) {
      if (!_isAudioFileName(f.name)) continue;
      audioItems.add({
        'name': f.name,
        if (f.path != null) 'path': f.path,
        if (f.bytes != null) 'bytes': f.bytes,
      });
    }
    if (audioItems.isNotEmpty) {
      userMsg['audioItems'] = audioItems;
    }

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    await _saveLocalHistorySafely();
    
    // O texto é limpo dentro do try para garantir o envio correto
    // final filesToSend = List<PlatformFile>.from(_attachments);
    // setState(() {
    //   _attachments.clear();
    // });
    
    _scrollToBottom();

    try {
      // Limpa o campo ANTES do envio para evitar reenvio
      final textToSend = text;
      _textController.clear();
      final filesToSend = List<PlatformFile>.from(_attachments);
      setState(() {
        _attachments.clear();
      });

      final data = await _sendToBackend(
        message: textToSend.isEmpty ? 'Segue anexo.' : textToSend,
        files: filesToSend,
      );
      final replyRaw = (data['reply'] ?? '').toString();
      final newThreadId = data['threadId']?.toString();

      if (newThreadId != null && newThreadId.isNotEmpty && newThreadId != _threadId) {
        await _saveThread(newThreadId);
      }

      final parsed = _parseTransferSuggest(replyRaw);
      final reply = (parsed['text'] ?? '').toString().trim();
      final candidates = (parsed['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': reply.isEmpty ? 'Ok.' : reply,
            'time': DateTime.now(),
            'agent': _agent,
            if (candidates.isNotEmpty) 'transferCandidates': candidates,
          });
          _pendingTransferCandidates = candidates;
        });
        await _saveLocalHistorySafely();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'system',
            'content': 'Erro ao enviar mensagem: $e',
            'time': DateTime.now(),
            'isError': true,
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _hasText || _attachments.isNotEmpty;
    final canRecord = _agent.allowAttachments;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleQuickActions,
            icon: Icon(_showQuickActions ? Icons.close : Icons.add, color: const Color(0xFF6B7280)),
            tooltip: _showQuickActions ? 'Fechar' : 'Opções',
          ),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: _hasFocus 
                      ? theme.colorScheme.primary.withValues(alpha: 0.8) 
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Shortcuts(
                shortcuts: kIsWeb
                    ? const <ShortcutActivator, Intent>{
                        SingleActivator(LogicalKeyboardKey.enter): _SendMessageIntent(),
                      }
                    : const <ShortcutActivator, Intent>{},
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _SendMessageIntent: CallbackAction<_SendMessageIntent>(
                      onInvoke: (_) {
                        if (!kIsWeb) return null;
                        final shift = HardwareKeyboard.instance.logicalKeysPressed.any(
                          (k) => k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight,
                        );
                        if (shift) return null;
                        if (_isLoading) return null;
                        unawaited(_handleSend());
                        return null;
                      },
                    ),
                  },
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Digite sua mensagem...',
                      hintStyle: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
                    ),
                    style: const TextStyle(fontSize: 15),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _handleSend(),
                    enabled: true,
                    onTap: _scrollToBottom,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading
                  ? null
                  : _isRecording
                      ? _toggleRecording
                      : (_textController.text.trim().isEmpty && _attachments.isEmpty)
                          ? (canRecord ? _toggleRecording : null)
                          : _handleSend,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      canSend ? Icons.send : (_isRecording ? Icons.stop : Icons.mic),
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsArea() {
    if (!_agent.allowAttachments || _attachments.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final file = _attachments[index];
            return Chip(
              label: Text(file.name, style: const TextStyle(fontSize: 10)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _removeAttachment(index),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: _chatBackgroundColor),
        ),
        if (_chatWallpaperUrl != null)
          Positioned.fill(
            child: Image.network(
              _chatWallpaperUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        if (_chatWallpaperUrl != null)
          Positioned.fill(
            child: Container(
              color: _chatBackgroundColor.withValues(alpha: 0.65),
            ),
          ),
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          reverse: true,
          itemBuilder: (context, index) {
            final msg = _messages[_messages.length - 1 - index];
            final isUser = msg['role'] == 'user';
            final isSystem = msg['role'] == 'system';
            if (isSystem) {
              final isError = msg['isError'] == true;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    msg['content'],
                    style: TextStyle(
                      color: isError ? Colors.red : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }
            return _buildMessageBubble(msg, isUser);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(widget.title ?? _agent.name),
              )
            : null,
        backgroundColor: widget.showAppBar ? Colors.white : Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          top: !widget.showAppBar,
          child: Column(
            children: [
              Expanded(
                child: _buildMessageList(),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAttachmentsArea(),
                  _buildQuickActionsBar(),
                  _buildInputArea(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser) {
    final attachments = msg['attachments'] as List<String>?;
    final audioItems = msg['audioItems'] is List
        ? (msg['audioItems'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : const <Map<String, dynamic>>[];
    final bubbleAgent = (!isUser && msg['agent'] is ResolvedAgent) ? msg['agent'] as ResolvedAgent : _agent;
    final transferCandidates = (!isUser && msg['transferCandidates'] is List)
        ? (msg['transferCandidates'] as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAgentAvatar(bubbleAgent),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      bubbleAgent.name,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUser ? _accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      topLeft: isUser ? const Radius.circular(12) : Radius.zero,
                      topRight: !isUser ? const Radius.circular(12) : Radius.zero,
                    ),
                    boxShadow: [
                      if (!isUser)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (audioItems.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: audioItems.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final id = _audioItemId(item, idx);
                              final path = item['path']?.toString();
                              final bytes = _bytesFromDynamic(item['bytes']);
                              final isPlaying = _playingAudioId == id && _audioPlayerState == PlayerState.playing;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUser ? _accentColor.withValues(alpha: 0.15) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                                      onPressed: _isLoading
                                          ? null
                                          : () => _togglePlayAudioItem(id: id, path: path, bytes: bytes),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mensagem de áudio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUser ? _accentColor : const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      if (attachments != null && attachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: attachments.map((a) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attachment, size: 12, color: isUser ? Colors.white70 : Colors.black54),
                                const SizedBox(width: 4),
                                Text(a, style: TextStyle(fontSize: 10, color: isUser ? Colors.white : Colors.black87)),
                              ],
                            )).toList(),
                          ),
                        ),
                      Text(
                        msg['content'] as String,
                        style: TextStyle(
                          color: isUser ? Colors.white : const Color(0xFF1F2937),
                          fontSize: 14,
                        ),
                      ),
                      if (!isUser && transferCandidates.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: transferCandidates.map((c) {
                            final name = (c['name'] ?? '').toString().trim();
                            final key = (c['key'] ?? '').toString().trim();
                            final reason = (c['reason'] ?? '').toString().trim();
                            final label = name.isNotEmpty ? name : key;
                            final subtitle = reason.isNotEmpty ? reason : 'Transferir';
                            return OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      final available = await _getAvailableAgents();
                                      final target = available.firstWhere(
                                        (a) => a.key.toLowerCase() == key.toLowerCase(),
                                        orElse: () => _agent,
                                      );
                                      if (target.key.toLowerCase() == _agent.key.toLowerCase()) return;
                                      await _performTransfer(target, reason: reason);
                                    },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg['time'] as DateTime),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 40), // Espaço para manter alinhamento visual
        ],
      ),
    );
  }

  Widget _buildAgentAvatar(ResolvedAgent agent) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: AgentAvatar(agent: agent, size: 36),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
