import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget reutilizável para upload de vídeos ou link do YouTube
class VideoUploadWidget extends StatefulWidget {
  final String? initialVideoUrl;
  final Function(String?) onVideoUrlChanged;
  final String storageBucket;
  final String label;
  final bool allowYouTubeLink;

  const VideoUploadWidget({
    super.key,
    this.initialVideoUrl,
    required this.onVideoUrlChanged,
    required this.storageBucket,
    this.label = 'Vídeo',
    this.allowYouTubeLink = true,
  });

  @override
  State<VideoUploadWidget> createState() => _VideoUploadWidgetState();
}

class _VideoUploadWidgetState extends State<VideoUploadWidget> {
  final TextEditingController _youtubeLinkController = TextEditingController();
  String? _videoUrl;
  String? _fileName;
  File? _file;
  Uint8List? _webFile;
  bool _isUploading = false;
  bool _useYouTubeLink = true;

  @override
  void initState() {
    super.initState();
    _videoUrl = widget.initialVideoUrl;
    if (_videoUrl != null) {
      if (_videoUrl!.contains('youtube.com') || _videoUrl!.contains('youtu.be')) {
        _useYouTubeLink = true;
        _youtubeLinkController.text = _videoUrl!;
      } else {
        _useYouTubeLink = false;
        _fileName = _videoUrl!.split('/').last;
      }
    }
  }

  @override
  void dispose() {
    _youtubeLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        
        if (kIsWeb) {
          // Para Web, usar bytes
          setState(() {
            _webFile = pickedFile.bytes;
            _fileName = pickedFile.name;
          });
        } else {
          // Para Mobile/Desktop, usar File
          if (pickedFile.path != null) {
            setState(() {
              _file = File(pickedFile.path!);
              _fileName = pickedFile.name;
            });
          }
        }
        
        await _uploadVideo(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar vídeo: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo(PlatformFile pickedFile) async {
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
            .uploadBinary(fileName, _webFile!);
      } else {
        // Upload do arquivo para Mobile/Desktop
        await supabase.storage
            .from(widget.storageBucket)
            .upload(fileName, _file!);
      }

      // Obter URL pública
      final publicUrl = supabase.storage
          .from(widget.storageBucket)
          .getPublicUrl(fileName);

      setState(() {
        _videoUrl = publicUrl;
        _isUploading = false;
      });

      widget.onVideoUrlChanged(publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vídeo enviado com sucesso!'),
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
          SnackBar(
            content: Text('Erro ao fazer upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveYouTubeLink() {
    final link = _youtubeLinkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira um link do YouTube'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _videoUrl = link;
    });
    widget.onVideoUrlChanged(link);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link do YouTube salvo!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeVideo() {
    setState(() {
      _videoUrl = null;
      _fileName = null;
      _file = null;
      _webFile = null;
      _youtubeLinkController.clear();
    });
    widget.onVideoUrlChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Opção de escolha: YouTube ou Upload
            if (widget.allowYouTubeLink)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Link YouTube'),
                    icon: Icon(Icons.link),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Upload Vídeo'),
                    icon: Icon(Icons.upload_file),
                  ),
                ],
                selected: {_useYouTubeLink},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _useYouTubeLink = newSelection.first;
                    _removeVideo();
                  });
                },
              ),
            const SizedBox(height: 16),
            
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_useYouTubeLink)
              // Campo para link do YouTube
              Column(
                children: [
                  TextFormField(
                    controller: _youtubeLinkController,
                    decoration: const InputDecoration(
                      labelText: 'Link do YouTube',
                      hintText: 'https://www.youtube.com/watch?v=...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saveYouTubeLink,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar Link'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  if (_videoUrl != null && _videoUrl!.contains('youtube'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Link do YouTube salvo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _removeVideo,
                              tooltip: 'Remover link',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              // Upload de arquivo de vídeo
              Column(
                children: [
                  if (_videoUrl != null && !_videoUrl!.contains('youtube'))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Vídeo enviado',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (_fileName != null)
                                  Text(
                                    _fileName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _removeVideo,
                            tooltip: 'Remover vídeo',
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Selecionar Vídeo'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Formatos aceitos: MP4, MOV, AVI, MKV',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

