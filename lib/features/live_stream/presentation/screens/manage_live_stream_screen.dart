import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/community_design.dart';
import '../providers/live_stream_provider.dart';
import '../../domain/models/live_stream.dart';

/// Tela de gerenciamento do culto ao vivo (link e status)
class ManageLiveStreamScreen extends ConsumerStatefulWidget {
  const ManageLiveStreamScreen({super.key});

  @override
  ConsumerState<ManageLiveStreamScreen> createState() =>
      _ManageLiveStreamScreenState();
}

class _ManageLiveStreamScreenState extends ConsumerState<ManageLiveStreamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isActive = false;
  bool _isSaving = false;
  bool _loaded = false;
  bool _wasActive = false;

  @override
  void dispose() {
    _urlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadConfig(LiveStreamConfig? config) {
    if (_loaded) return;
    _loaded = true;

    if (config != null) {
      _urlController.text = config.streamUrl ?? '';
      _messageController.text = config.message ?? '';
      _isActive = config.isActive;
      _wasActive = config.isActive;
    }
  }

  String _normalizeUrl(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return v;
    }
    return 'https://$v';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rawUrl = _urlController.text.trim();
    final normalizedUrl = _normalizeUrl(rawUrl);
    if (_isActive && normalizedUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o link do culto ao vivo para ativar.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(liveStreamRepositoryProvider);
      final shouldNotify = !_wasActive && _isActive;

      await repo.upsertLiveStreamConfig({
        'stream_url': normalizedUrl.isEmpty ? null : normalizedUrl,
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _wasActive = _isActive;

      ref.invalidate(liveStreamConfigProvider);
      ref.invalidate(activeLiveStreamProvider);

      if (shouldNotify) {
        try {
          await repo.notifyLiveStreamActive(
            title: 'Culto ao vivo',
            body: 'Estamos ao vivo agora. Toque para assistir.',
            route: '/live-stream',
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuracao salva com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(liveStreamConfigProvider);

    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Culto ao vivo',
          style: CommunityDesign.titleStyle(context).copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: CommunityDesign.headerColor(context),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: 'Salvar',
            ),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadConfig(config);
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Link do YouTube *',
                    hintText: 'https://www.youtube.com/watch?v=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (value) {
                    if (_isActive && (value == null || value.trim().isEmpty)) {
                      return 'Link obrigatorio quando ativo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem opcional',
                    hintText: 'Ex: Em instantes, aguarde...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Culto ao vivo ativo'),
                  subtitle: const Text(
                    'Ativar exibe o link no app e envia notificacao para todos',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() => _isActive = value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Quem desativou notificacoes gerais nao sera avisado.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar configuracao: $error'),
            ],
          ),
        ),
      ),
    );
  }
}
