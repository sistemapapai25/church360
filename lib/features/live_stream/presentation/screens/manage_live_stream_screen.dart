import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../courses/presentation/turma/lesson_media.dart';
import '../../../courses/presentation/turma/tabs/turma_aulas_tab.dart'
    show blankToNull, lessonUrlError, openLessonLink;
import '../providers/live_stream_provider.dart';
import '../../domain/models/live_stream.dart';

/// Pasta dos PDFs de slides no bucket (policy `culto_slides_*`, 007400).
const String cultoSlidesFolder = 'culto';

/// Tela de gerenciamento do culto ao vivo (link e status)
class ManageLiveStreamScreen extends ConsumerStatefulWidget {
  const ManageLiveStreamScreen({super.key});

  @override
  ConsumerState<ManageLiveStreamScreen> createState() =>
      _ManageLiveStreamScreenState();
}

class _ManageLiveStreamScreenState
    extends ConsumerState<ManageLiveStreamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isActive = false;
  bool _isSaving = false;
  bool _loaded = false;
  bool _wasActive = false;
  String? _slidesUrl;

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
      _slidesUrl = blankToNull(config.slidesUrl);
    }
  }

  // ---- Slides do culto (A3): grava na hora, sem passar pelo Salvar. ----

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  /// Chama a RPC e conta o que aconteceu: vinculou ao culto de hoje ou não.
  Future<void> _setSlides(String? url) async {
    setState(() => _isSaving = true);
    try {
      final old = _slidesUrl;
      final r = await ref
          .read(liveStreamRepositoryProvider)
          .cultoSetSlides(url);
      _slidesUrl = url;
      ref.invalidate(liveStreamConfigProvider);
      ref.invalidate(currentCultoProvider);
      final title = r['title'] as String?;
      if (url == null) {
        _snack('Slides removidos.');
      } else if (r['event_id'] != null) {
        _snack(
          'Slides vinculados ao culto de hoje: $title (${r['start_hhmm']}).',
        );
      } else {
        _snack(
          'Sem culto na Agenda hoje: os slides aparecem com a chave ligada.',
        );
      }
      // Arquivo antigo da pasta culto/ não serve mais.
      if (old != null && old != url) {
        try {
          await ref
              .read(lessonMediaServiceProvider)
              .removeIfLessonFile(
                kind: LessonMediaKind.pdf,
                lessonId: _lessonIdOf(old),
                url: old,
                folder: cultoSlidesFolder,
              );
        } catch (_) {}
      }
    } catch (e) {
      _snack('Não foi possível salvar os slides: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Pasta do dia: `tenant/uid/culto/AAAAMMDD/arquivo`.
  static String _today() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// Dia (4º segmento) de uma URL da pasta culto/, para apagar o antigo.
  static String _lessonIdOf(String url) {
    final segs = Uri.tryParse(url)?.pathSegments ?? const [];
    final i = segs.indexOf(cultoSlidesFolder);
    return i >= 0 && i + 1 < segs.length ? segs[i + 1] : _today();
  }

  Future<void> _uploadSlides() async {
    final media = ref.read(lessonMediaServiceProvider);
    try {
      final file = await media.pick(LessonMediaKind.slides);
      if (file == null || !mounted) return;
      if (file.size > lessonMediaMaxBytes) {
        _snack('O arquivo passa de 50 MB.', error: true);
        return;
      }
      setState(() => _isSaving = true);
      final url = await media.upload(
        kind: LessonMediaKind.slides,
        lessonId: _today(),
        file: file,
        folder: cultoSlidesFolder,
      );
      await _setSlides(url);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      _snack('Não foi possível enviar: $e', error: true);
    }
  }

  Future<void> _pasteSlides() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link dos slides'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://docs.google.com/presentation/...',
            ),
            validator: (v) =>
                blankToNull(v) == null ? 'Informe o link' : lessonUrlError(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url != null) await _setSlides(url);
  }

  Widget _slidesSection(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final url = _slidesUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Slides do culto', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (url == null)
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('culto-upload-slides'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _isSaving ? null : _uploadSlides,
                icon: const Icon(AppIcons.upload, size: 18),
                label: const Text('Enviar PPTX ou PDF'),
              ),
              TextButton.icon(
                key: const ValueKey('culto-link-slides'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: _isSaving ? null : _pasteSlides,
                icon: const Icon(AppIcons.link, size: 18),
                label: const Text('Colar link'),
              ),
            ],
          )
        else
          ListTile(
            key: const ValueKey('culto-slides'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('Slides do culto'),
            subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => openLessonLink(context, url),
            trailing: PopupMenuButton<String>(
              tooltip: 'Mais opções',
              enabled: !_isSaving,
              onSelected: (v) => switch (v) {
                'arquivo' => _uploadSlides(),
                'link' => _pasteSlides(),
                _ => _setSlides(null),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'arquivo', child: Text('Trocar por arquivo')),
                PopupMenuItem(value: 'link', child: Text('Trocar por link')),
                PopupMenuItem(value: 'remover', child: Text('Remover slides')),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'PDF ou Google Slides (Arquivo > Compartilhar > Publicar na web). '
          'Grava na hora: se há culto na Agenda hoje, os slides ficam '
          'vinculados a ele; senão aparecem enquanto a chave estiver ligada. '
          'A pessoa vê e passa os slides no card Slides da Home e na tela do '
          'culto.',
          style: meta,
        ),
      ],
    );
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
      ref.invalidate(currentCultoProvider);

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

  /// D16: a Home também entra em modo culto pela Agenda. Um culto cadastrado
  /// errado não pode prender a Home: este botão desliga a chave e marca o
  /// culto aberto como encerrado (RPC `culto_mode_off`, 006500).
  Future<void> _modeOff() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(liveStreamRepositoryProvider).cultoModeOff();
      _isActive = false;
      _wasActive = false;
      ref.invalidate(liveStreamConfigProvider);
      ref.invalidate(activeLiveStreamProvider);
      ref.invalidate(currentCultoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo culto encerrado na Home.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encerrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontSize: 20, fontWeight: FontWeight.bold),
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
              if (mounted) setState(() => _loadConfig(config));
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                _slidesSection(context),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _modeOff,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Encerrar modo culto agora'),
                ),
                const SizedBox(height: 8),
                Text(
                  'A Home entra em modo culto quando esta chave está ligada '
                  'ou quando há culto na Agenda neste horário. Se a Agenda '
                  'está errada, este botão desliga a chave e tira a Home do '
                  'modo culto até o próximo culto.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
