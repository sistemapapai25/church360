import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/financial_attachment.dart';
import '../providers/financial_attachments_providers.dart';
import '../../../../core/design/community_design.dart';

/// Widget que exibe preview de imagem ou PDF do comprovante
class ComprovantePreviewWidget extends ConsumerStatefulWidget {
  final FinancialAttachment attachment;

  const ComprovantePreviewWidget({
    super.key,
    required this.attachment,
  });

  @override
  ConsumerState<ComprovantePreviewWidget> createState() =>
      _ComprovantePreviewWidgetState();
}

class _ComprovantePreviewWidgetState
    extends ConsumerState<ComprovantePreviewWidget> {
  double _scale = 1.0;
  double _rotation = 0.0;
  static const _financialGreen = Color(0xFF1D6E45);

  @override
  Widget build(BuildContext context) {
    final signedUrlAsync = ref.watch(signedUrlProvider(widget.attachment.objectPath));
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: CommunityDesign.overlayDecoration(colorScheme),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header com controles
          _buildHeader(context, colorScheme),
          
          // Preview area
          Expanded(
            child: signedUrlAsync.when(
              data: (signedUrl) => _buildPreview(signedUrl),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.attachment.isImage ? Icons.image : Icons.picture_as_pdf,
            size: 20,
            color: _financialGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.attachment.fileName,
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          
          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: () {
              setState(() {
                _scale = (_scale - 0.2).clamp(0.5, 3.0);
              });
            },
            tooltip: 'Diminuir zoom',
          ),
          Text(
            '${(_scale * 100).toInt()}%',
            style: CommunityDesign.metaStyle(context),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: () {
              setState(() {
                _scale = (_scale + 0.2).clamp(0.5, 3.0);
              });
            },
            tooltip: 'Aumentar zoom',
          ),
          
          // Rotation control
          IconButton(
            icon: const Icon(Icons.rotate_right, size: 20),
            onPressed: () {
              setState(() {
                _rotation = (_rotation + 90) % 360;
              });
            },
            tooltip: 'Girar',
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(String signedUrl) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        child: Transform.rotate(
          angle: _rotation * 3.14159 / 180,
          child: Transform.scale(
            scale: _scale,
            child: widget.attachment.isImage
                ? Image.network(
                    signedUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildError('Erro ao carregar imagem');
                    },
                  )
                : _buildPdfPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'PDF Preview',
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.attachment.fileName,
            style: CommunityDesign.metaStyle(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar preview',
            style: CommunityDesign.titleStyle(context).copyWith(
              fontSize: 16,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: CommunityDesign.metaStyle(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
