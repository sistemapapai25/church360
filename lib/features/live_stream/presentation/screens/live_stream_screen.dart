import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    show YoutubePlayer;
import '../../../../core/widgets/media/inline_video.dart';
import '../providers/live_stream_provider.dart';

/// Tela publica do culto ao vivo
class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  /// Link do culto ligado (culto desligado não expõe o link antigo, nem no
  /// "Abrir no navegador").
  String? _currentUrl;

  String _normalizeUrl(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return v;
    }
    return 'https://$v';
  }

  Future<void> _openInApp() async {
    final url = _currentUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(_normalizeUrl(url));
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(liveStreamConfigProvider);
    final live = configAsync.valueOrNull;
    final liveUrl = live?.isActive == true ? (live?.streamUrl ?? '').trim() : '';
    _currentUrl = liveUrl.isEmpty ? null : liveUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Culto ao vivo'),
        actions: [
          IconButton(
            tooltip: 'Abrir no navegador',
            icon: const Icon(Icons.open_in_new),
            onPressed: _currentUrl == null ? null : _openInApp,
          ),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          final isActive = config?.isActive ?? false;
          final url = (config?.streamUrl ?? '').trim();
          final message = (config?.message ?? '').trim();

          if (!isActive || url.isEmpty) {
            return _InactiveLiveStream(message: message);
          }

          final showPlayer = YoutubePlayer.convertUrlToId(url) != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Player único do app: controles do próprio YouTube.
              showPlayer
                  ? InlineVideo(key: ValueKey(url), url: url, autoStart: true)
                  : Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _LinkOnlyPlaceholder(onOpen: _openInApp),
                    ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          'AO VIVO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _currentUrl == null ? null : _openInApp,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir'),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveLiveStream extends StatelessWidget {
  final String message;

  const _InactiveLiveStream({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma transmissao ao vivo no momento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkOnlyPlaceholder extends StatelessWidget {
  final VoidCallback onOpen;

  const _LinkOnlyPlaceholder({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Assistir no navegador'),
        ),
      ),
    );
  }
}
