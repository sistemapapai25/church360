import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget reutilizável para upload de imagens
class ImageUploadWidget extends StatefulWidget {
  final String? initialImageUrl;
  final Function(String?) onImageUrlChanged;
  final String storageBucket;
  final String label;

  const ImageUploadWidget({
    super.key,
    this.initialImageUrl,
    required this.onImageUrlChanged,
    required this.storageBucket,
    this.label = 'Imagem',
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  File? _imageFile;
  Uint8List? _webImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // Para Web, ler os bytes da imagem
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
          });
        } else {
          // Para Mobile/Desktop, usar File
          setState(() {
            _imageFile = File(pickedFile.path);
          });
        }
        await _uploadImage(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage(XFile pickedFile) async {
    if (!kIsWeb && _imageFile == null) return;
    if (kIsWeb && _webImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      // Gerar nome único para o arquivo
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = pickedFile.name.split('.').last;
      final fileName = '${userId}_$timestamp.$extension';

      // Upload para Supabase Storage
      if (kIsWeb) {
        // Upload dos bytes para Web
        await supabase.storage
            .from(widget.storageBucket)
            .uploadBinary(fileName, _webImage!);
      } else {
        // Upload do arquivo para Mobile/Desktop
        await supabase.storage
            .from(widget.storageBucket)
            .upload(fileName, _imageFile!);
      }

      // Obter URL pública
      final publicUrl = supabase.storage
          .from(widget.storageBucket)
          .getPublicUrl(fileName);

      setState(() {
        _imageUrl = publicUrl;
        _isUploading = false;
      });

      // Notificar mudança
      widget.onImageUrlChanged(publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagem enviada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar imagem: $e')),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _imageUrl = null;
      _imageFile = null;
      _webImage = null;
    });
    widget.onImageUrlChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preview da imagem
            if (_webImage != null || _imageFile != null || _imageUrl != null) ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _webImage != null
                      ? Image.memory(
                          _webImage!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : _imageUrl != null
                              ? Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
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
                                    return const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botões
            Row(
              children: [
                // Botão selecionar/alterar
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_imageUrl == null ? Icons.add_photo_alternate : Icons.edit),
                    label: Text(_imageUrl == null ? 'Selecionar Imagem' : 'Alterar Imagem'),
                  ),
                ),

                // Botão remover (se houver imagem)
                if (_imageUrl != null || _imageFile != null || _webImage != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isUploading ? null : _removeImage,
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Remover imagem',
                  ),
                ],
              ],
            ),

            // Dica
            if (_imageUrl == null && _imageFile == null && _webImage == null) ...[
              const SizedBox(height: 8),
              Text(
                'Selecione uma imagem para o ${widget.label.toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

