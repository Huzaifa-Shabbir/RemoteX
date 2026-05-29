import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/theme_controller.dart';

// Model representing a shared file (mapped from API)
class SharedFile {
  SharedFile({
    required this.id,
    required this.name,
    required this.filePath,
    required this.uploadedBy,
    required this.uploadedAt,
    this.size = 0,
  });

  final String id;
  final String name;
  final String filePath;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int size;

  factory SharedFile.fromListJson(Map<String, dynamic> json) {
    return SharedFile(
      id: json['_id']?.toString() ?? json['fileId']?.toString() ?? '',
      name: json['fileName'] ?? json['fileName'] ?? json['name'] ?? '',
      filePath: json['filePath'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      uploadedAt: DateTime.tryParse(json['createdAt'] ?? json['updatedAt'] ?? '') ?? DateTime.now(),
      size: json['size'] is int ? json['size'] : 0,
    );
  }
}

// ---------------- FileService (API layer) ----------------
class FileService {
  FileService();

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _baseUrl => (dotenv.env['FILES_BASE_URL'] ?? '').trim();

  Map<String, String> _authHeader() {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<SharedFile>> fetchFiles() async {
    final url = Uri.parse(_baseUrl);
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      ..._authHeader(),
    });

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => SharedFile.fromListJson(e as Map<String, dynamic>)).toList();
    }

    _throwForStatus(res.statusCode, res.body);
  }

  // Changed return to Never so analyzer knows this always throws.
  Never _throwForStatus(int status, String body) {
    debugPrint('FileService HTTP $status: $body');
    throw HttpException('HTTP $status: $body', uri: Uri.parse(_baseUrl));
  }

  // New: upload from a PlatformFile (supports bytes for web or path for mobile)
  Future<SharedFile> uploadFile(PlatformFile picked) async {
    final url = Uri.parse('$_baseUrl/upload');
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw HttpException('HTTP 401: Missing token', uri: url);

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    if (picked.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', picked.bytes!, filename: picked.name),
      );
    } else if (picked.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', picked.path!, filename: picked.name),
      );
    } else {
      throw Exception('Selected file has no data');
    }

    final streamed = await request.send();
    final respStr = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final json = jsonDecode(respStr) as Map<String, dynamic>;
      return SharedFile.fromListJson(json);
    }

    _throwForStatus(streamed.statusCode, respStr);
  }

  Future<String> getDownloadUrl(String fileId) async {
    final url = Uri.parse('$_baseUrl/$fileId');
    final res = await http.get(url, headers: {
      'Accept': 'application/json',
      ..._authHeader(),
    });

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final signed = json['signedUrl'] ?? json['signed_url'] ?? json['signedurl'];
      if (signed is String && signed.isNotEmpty) return signed;
      throw Exception('Signed URL missing in response');
    }

    _throwForStatus(res.statusCode, res.body);
  }

  Future<void> deleteFile(String fileId) async {
    final url = Uri.parse('$_baseUrl/$fileId');
    final res = await http.delete(url, headers: {
      'Accept': 'application/json',
      ..._authHeader(),
    });

    if (res.statusCode == 200 || res.statusCode == 204) return;

    _throwForStatus(res.statusCode, res.body);
  }
}

// ---------------- UI (uses FileService) ----------------
class SharedFolderLightScreen extends StatefulWidget {
  const SharedFolderLightScreen({super.key});

  @override
  State<SharedFolderLightScreen> createState() =>
      _SharedFolderLightScreenState();
}

class _SharedFolderLightScreenState extends State<SharedFolderLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _SharedFolderScaffold(isDarkPreview: false);
  }
}

class SharedFolderDarkScreen extends StatefulWidget {
  const SharedFolderDarkScreen({super.key});

  @override
  State<SharedFolderDarkScreen> createState() =>
      _SharedFolderDarkScreenState();
}

class _SharedFolderDarkScreenState extends State<SharedFolderDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _SharedFolderScaffold(isDarkPreview: true);
  }
}

class _SharedFolderScaffold extends StatefulWidget {
  const _SharedFolderScaffold({required this.isDarkPreview});

  final bool isDarkPreview;

  @override
  State<_SharedFolderScaffold> createState() => _SharedFolderScaffoldState();
}

class _SharedFolderScaffoldState extends State<_SharedFolderScaffold> {
  final List<SharedFile> _files = [];
  bool _loading = false;
  final FileService _service = FileService();

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() => _loading = true);
    try {
      final files = await _service.fetchFiles();
      if (mounted) {
        setState(() {
          _files
            ..clear()
            ..addAll(files);
        });
      }
    } on HttpException catch (e) {
      _handleHttpException(e);
    } catch (e, st) {
      debugPrint('Fetch files error: $e\n$st');
      _showMessage('Failed to load files.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Replaced fallback dialog with native FilePicker usage (browses mobile files/photos)
  Future<void> _pickAndUpload() async {
    try {
      final selectedType = await _showFileTypeSelector();
      if (selectedType == null) {
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true, // keep bytes available as fallback
        type: selectedType,
        allowedExtensions: selectedType == FileType.custom
            ? ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx']
            : null,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('File picker: user cancelled');
        return;
      }

      final picked = result.files.single;
      debugPrint('File picker selected: path=${picked.path} name=${picked.name} size=${picked.size} bytesAvailable=${picked.bytes != null}');

      if (picked.path == null && picked.bytes == null) {
        _showMessage('Selected file has no data');
        return;
      }

      setState(() => _loading = true);
      try {
        await _service.uploadFile(picked);
        await _fetchFiles();
        _showMessage('Upload successful');
      } on HttpException catch (e) {
        _handleHttpException(e);
      } catch (e, st) {
        debugPrint('Upload error: $e\n$st');
        _showMessage('Upload failed.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e, st) {
      debugPrint('File picker error: $e\n$st');
      _showMessage('Failed to pick file.');
    }
  }

  Future<FileType?> _showFileTypeSelector() async {
    return showModalBottomSheet<FileType>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // Drag Handle
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Choose file type',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),

                _buildTypeOption(
                  sheetContext,
                  'Images',
                  FileType.image,
                ),

                _buildTypeOption(
                  sheetContext,
                  'Videos',
                  FileType.video,
                ),

                _buildTypeOption(
                  sheetContext,
                  'Audio',
                  FileType.audio,
                ),

                _buildTypeOption(
                  sheetContext,
                  'Documents',
                  FileType.custom,
                ),

                const SizedBox(height: 8),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(BuildContext sheetContext, String label, FileType type) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: Colors.black),
      ),
      onTap: () {
        Navigator.of(sheetContext).pop(type);
      },
    );
  }

  Future<void> _openFile(SharedFile file) async {
    setState(() => _loading = true);
    try {
      final url = await _service.getDownloadUrl(file.id);
      debugPrint('Signed URL received: $url');

      // Build a valid Uri safely. Try parsing, fall back to encoded parse.
      Uri? uri;
      try {
        uri = Uri.parse(url);
        if (!uri.hasScheme) {
          // If no scheme, assume https
          uri = Uri.parse('https://$url');
        }
      } catch (e) {
        debugPrint('Initial Uri.parse failed: $e');
        try {
          uri = Uri.parse(Uri.encodeFull(url));
        } catch (e2) {
          debugPrint('Encoded Uri.parse also failed: $e2');
          uri = null;
        }
      }

      var launched = false;

      if (uri != null) {
        // Primary attempt: open in external application (browser)
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('launchUrl externalApplication returned: $launched');
        } catch (e) {
          debugPrint('launchUrl externalApplication threw: $e');
          launched = false;
        }

        // Fallback: try platformDefault mode if previous attempt failed
        if (!launched) {
          try {
            if (await canLaunchUrl(uri)) {
              launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
              debugPrint('launchUrl platformDefault returned: $launched');
            } else {
              debugPrint('canLaunchUrl returned false for $uri');
            }
          } catch (e) {
            debugPrint('Fallback launchUrl platformDefault threw: $e');
            launched = false;
          }
        }
      } else {
        debugPrint('URI was null, cannot attempt to launch.');
      }

      if (!launched) {
        _showMessage('Cannot open file URL.');
      }
    } on HttpException catch (e) {
      _handleHttpException(e);
    } catch (e, st) {
      debugPrint('Open file error: $e\n$st');
      _showMessage('Failed to open file.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(SharedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Delete file'),
          content: Text('Delete "${file.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await _service.deleteFile(file.id);
        await _fetchFiles();
        _showMessage('File deleted');
      } on HttpException catch (e) {
        _handleHttpException(e);
      } catch (e, st) {
        debugPrint('Delete error: $e\n$st');
        _showMessage('Failed to delete file.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _handleHttpException(HttpException e) {
    final msg = e.message;
    debugPrint('HTTP error: $msg');
    if (msg.contains('HTTP 401')) {
      // Unauthorized — redirect to login
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (r) => false);
      }
      return;
    }
    if (msg.contains('HTTP 403')) {
      _showMessage('Forbidden: you do not have access to this file.');
      return;
    }
    if (msg.contains('HTTP 404')) {
      _showMessage('File not found.');
      return;
    }
    _showMessage('Server error. Please try again later.');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _readableSize(int bytes) {
    if (bytes <= 0) return '-';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 ? 2 : 0)} ${suffixes[i]}';
  }

  // New helper: choose icon based on extension and wrap in avatar
  Widget _fileIcon(SharedFile f, ThemeData theme) {
    final ext = (f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '');
    IconData icon;
    Color bg = theme.colorScheme.primary.withOpacity(0.12);
    Color fg = theme.colorScheme.primary;

    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'].contains(ext)) {
      icon = Icons.image_outlined;
      bg = Colors.green.withOpacity(0.12);
      fg = Colors.green;
    } else if (['mp4', 'mkv', 'mov', 'avi', 'webm'].contains(ext)) {
      icon = Icons.movie_outlined;
      bg = Colors.purple.withOpacity(0.12);
      fg = Colors.purple;
    } else if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) {
      icon = Icons.audiotrack_outlined;
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange;
    } else if (ext == 'pdf') {
      icon = Icons.picture_as_pdf_outlined;
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red;
    } else if (['doc', 'docx', 'txt', 'rtf', 'odt'].contains(ext)) {
      icon = Icons.article_outlined;
      bg = Colors.blue.withOpacity(0.12);
      fg = Colors.blue;
    } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
      icon = Icons.grid_on_outlined;
      bg = Colors.teal.withOpacity(0.12);
      fg = Colors.teal;
    } else {
      icon = Icons.insert_drive_file_outlined;
      bg = theme.colorScheme.onSurface.withOpacity(0.04);
      fg = theme.colorScheme.onSurface.withOpacity(0.9);
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: bg,
      child: Icon(icon, size: 20, color: fg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeControllerScope.of(context);
    final homeRoute = controller.isDark ? '/home/dark' : '/home/light';

    return Scaffold(
      // drawer removed per request (menu icon removed)
      appBar: AppBar(
        // back button moved into the leading position (replacing the menu)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Home',
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(homeRoute);
          },
        ),
        title: const Text('Shared Folder'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFiles,
            tooltip: 'Refresh',
          ),
          IconButton(
            // theme toggle placed to right of refresh
            icon: Icon(controller.isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: controller.isDark ? 'Switch to light' : 'Switch to dark',
            onPressed: () {
              controller.setMode(controller.isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFiles,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.folder_open_outlined, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      const Center(child: Text('No files yet. Use Upload to add files.')),
                    ],
                  )

                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final f = _files[index];
                      return ListTile(
                        tileColor: theme.cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(f.name),
                        subtitle: Text('${_readableSize(f.size)} • ${f.uploadedAt.toLocal()}'.split('.').first),
                        leading: _fileIcon(f, theme),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(f),
                            ),
                          ],
                        ),
                        onTap: () => _openFile(f),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUpload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }
}
