import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/financial_attachment.dart';
import '../providers/financial_attachments_providers.dart';
import '../../../../core/constants/supabase_constants.dart';

/// Widget para upload de comprovantes financeiros
class ComprovanteUploadWidget extends ConsumerStatefulWidget {
  final Function(FinancialAttachment)? onUploadComplete;
  final FinancialAttachment? existingAttachment;
  final VoidCallback? onRemove;

  const ComprovanteUploadWidget({
    super.key,
    this.onUploadComplete,
    this.existingAttachment,
    this.onRemove,
  });

  @override
  ConsumerState<ComprovanteUploadWidget> createState() =>
      _ComprovanteUploadWidgetState();
}

class _ComprovanteUploadWidgetState
    extends ConsumerState<ComprovanteUploadWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _removedExisting = false;

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        await _uploadFileBytes(
          bytes: bytes,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
    } catch (e) {
      _showError('Erro ao tirar foto: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        await _uploadFileBytes(
          bytes: bytes,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
    } catch (e) {
      _showError('Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          _showError('Erro ao ler arquivo');
          return;
        }

        final mimeType = _getMimeType(file.extension ?? '');
        await _uploadFileBytes(
          bytes: bytes,
          fileName: file.name,
          mimeType: mimeType,
        );
      }
    } catch (e) {
      _showError('Erro ao selecionar arquivo: $e');
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _uploadFileBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    // Validar tamanho (max 10MB)
    if (bytes.length > 10 * 1024 * 1024) {
      _showError('Arquivo muito grande. Máximo: 10MB');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final repo = ref.read(financialAttachmentsRepositoryProvider);
      final supabase = Supabase.instance.client;

      // 1. Upload file and create attachment record
      setState(() => _uploadProgress = 0.3);
      final attachment = await repo.createAttachmentFromBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (mounted) {
        widget.onUploadComplete?.call(attachment);
      }

      // 2. Call Edge Function to process with AI
      setState(() => _uploadProgress = 0.6);
      final userId = supabase.auth.currentUser?.id;
      final tenantId = SupabaseConstants.currentTenantId;

      await supabase.functions.invoke(
        'processar-comprovante',
        body: {
          'attachment_id': attachment.id,
          'tenant_id': tenantId,
          'user_id': userId,
        },
      );

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        // 3. Navigate to review screen
        context.push('/financial/comprovantes/${attachment.id}/review');
      }
    } catch (e) {
      _showError('Erro ao enviar arquivo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return _buildUploadingState();
    }

    if (!_removedExisting && widget.existingAttachment != null) {
      return _buildExistingAttachment();
    }

    return _buildUploadButtons();
  }

  Widget _buildUploadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Enviando comprovante... ${(_uploadProgress * 100).toInt()}%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _uploadProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingAttachment() {
    final attachment = widget.existingAttachment!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.attach_file),
        title: Text(attachment.fileName),
        subtitle: Text(attachment.formattedFileSize),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: _previewExistingAttachment,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _removeExistingAttachment,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewExistingAttachment() async {
    final attachment = widget.existingAttachment;
    if (attachment == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final repo = ref.read(financialAttachmentsRepositoryProvider);
      final signedUrl = await repo.generateSignedUrl(attachment.objectPath);

      if (!mounted) return;

      if (attachment.isImage) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });

        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
              child: InteractiveViewer(
                child: Image.network(
                  signedUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Não foi possível carregar a imagem.'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        return;
      }

      final uri = Uri.parse(signedUrl);
      final ok = await canLaunchUrl(uri);
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      if (!ok) {
        _showError('Não foi possível abrir o anexo');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      _showError('Erro ao abrir anexo: $e');
    }
  }

  Future<void> _removeExistingAttachment() async {
    final attachment = widget.existingAttachment;
    if (attachment == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover comprovante'),
        content: const Text('Deseja remover este comprovante?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final repo = ref.read(financialAttachmentsRepositoryProvider);
      await repo.deleteAttachment(attachment.id);

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _removedExisting = true;
      });

      widget.onRemove?.call();
      _showSuccess('Comprovante removido com sucesso!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      _showError('Erro ao remover comprovante: $e');
    }
  }

  Widget _buildUploadButtons() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Adicionar Comprovante',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Câmera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Selecionar Arquivo (PDF/Imagem)'),
            ),
          ],
        ),
      ),
    );
  }
}
