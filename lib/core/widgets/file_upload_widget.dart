import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';

/// Widget reutilizável para upload de arquivos (PDF, PowerPoint, etc.)
class FileUploadWidget extends StatefulWidget {
  final String? initialFileUrl;
  final String? initialFileName;
  final Function(String?, String?) onFileUrlChanged; // (url, fileName)
  final String storageBucket;
  final String label;
  final List<String> allowedExtensions;
  final IconData icon;

  const FileUploadWidget({
    super.key,
    this.initialFileUrl,
    this.initialFileName,
    required this.onFileUrlChanged,
    required this.storageBucket,
    this.label = 'Arquivo',
    this.allowedExtensions = const ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
    this.icon = Icons.attach_file,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  String? _fileUrl;
  String? _fileName;
  File? _file;
  Uint8List? _webFile;
  bool _isUploading = false;
  Future<String?> _effectiveUserId() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      try {
        final nickname = email.trim().split('@').first;
        await supabase.rpc('ensure_my_account', params: {
          '_tenant_id': SupabaseConstants.currentTenantId,
          '_email': email,
          '_nickname': nickname,
        });
      } catch (_) {}
    }
    return user.id;
  }

  @override
  void initState() {
    super.initState();
    _fileUrl = widget.initialFileUrl;
    _fileName = widget.initialFileName;
    if (_fileName == null && _fileUrl != null) {
      _fileName = _fileUrl!.split('/').last;
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
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
        
        await _uploadFile(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  Future<void> _uploadFile(PlatformFile pickedFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = await _effectiveUserId();
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
        _fileUrl = publicUrl;
        _isUploading = false;
      });

      widget.onFileUrlChanged(publicUrl, _fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo enviado com sucesso!'),
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

  void _removeFile() {
    setState(() {
      _fileUrl = null;
      _fileName = null;
      _file = null;
      _webFile = null;
    });
    widget.onFileUrlChanged(null, null);
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
                Icon(widget.icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_fileUrl != null)
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
                            'Arquivo enviado',
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
                      onPressed: _removeFile,
                      tooltip: 'Remover arquivo',
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Selecionar Arquivo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            
            const SizedBox(height: 8),
            Text(
              'Formatos aceitos: ${widget.allowedExtensions.join(", ").toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
