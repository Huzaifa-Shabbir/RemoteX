import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'features/shared/file_service.dart';
import 'features/shared/presentation/file_preview_page.dart';
import 'features/auth/controller/supabase_service.dart';
import 'features/auth/presentation/sign_in_page.dart';

class SharedFolderPage extends StatefulWidget {
  const SharedFolderPage({super.key});

  @override
  State<SharedFolderPage> createState() => _SharedFolderPageState();
}

class _SharedFolderPageState extends State<SharedFolderPage> {
  List<FileItem> _files = [];
  bool _loading = false;
  bool _uploading = false;

  // new state
  String _query = '';
  bool _sortNewest = true;

  // per-item busy state
  final Set<String> _busyIds = {};

  // helper to run async work marking an item busy during execution
  Future<T> _withBusy<T>(String id, Future<T> Function() fn) async {
    setState(() => _busyIds.add(id));
    try {
      return await fn();
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
    });
    try {
      final files = await FileService.getFiles();
      files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _files = files);
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleError(Object e) {
    final msg = e.toString();
    if (msg.contains('Unauthorized')) {
      // Token missing/expired — redirect to sign in
      SupabaseService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInPage()),
          (_) => false,
        );
      }
      return;
    }

    String userMsg = 'An error occurred';
    if (msg.contains('Forbidden')) userMsg = 'Access forbidden';
    if (msg.contains('Not Found')) userMsg = 'File not found';
    if (msg.contains('Server error')) userMsg = 'Server error';

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMsg)));
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(path);
      await FileService.uploadFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload successful')));
      }
      await _loadFiles();
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openFile(FileItem item) async {
    try {
      await _withBusy(item.id, () async {
        final url = await FileService.getDownloadUrl(item.id);
        if (url.isEmpty) throw Exception('Empty url');
        await openFile(item.fileName, url, context);
      });
    } catch (e) {
      _handleError(e);
    }

  }

  Future<void> _deleteFile(FileItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Are you sure you want to delete "${item.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _withBusy(item.id, () async {
        await FileService.deleteFile(item.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File deleted')));
      });
      await _loadFiles();
    } catch (e) {
      _handleError(e);
    }
  }

  // Helpers for UI
  String _extOf(String name) {
    final parts = name.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : '';
  }

  IconData _iconForExt(String ext) {
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Icons.movie;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.architecture;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.notes;
      case 'csv':
        return Icons.grid_on;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForExt(String ext) {
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Colors.deepOrange;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Colors.teal;
      case 'pdf':
        return Colors.redAccent;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'txt':
      case 'csv':
        return Colors.indigo;
      default:
        return Colors.grey.shade600;
    }
  }

  // helper to detect video extensions
  bool _isVideoExt(String ext) {
    const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
    return videoExts.contains(ext.toLowerCase());
  }

  Future<void> _showActions(FileItem item) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(ctx);
                _openFile(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Preview'),
              onTap: () async {
                Navigator.pop(ctx);
                // fetch download URL while showing per-item busy indicator
                String url;
                try {
                  url = await _withBusy(item.id, () async => await FileService.getDownloadUrl(item.id));
                } catch (e) {
                  _handleError(e);
                  return;
                }
                if (url.isEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preview unavailable')));
                  return;
                }
                final ext = _extOf(item.fileName);
                if (_isVideoExt(ext)) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video preview not supported here — opening externally')));
                  await openFile(item.fileName, url, context);
                } else {
                  if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => FilePreviewPage(url: url, name: item.fileName)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () async {
                Navigator.pop(ctx);
                String url;
                try {
                  url = await _withBusy(item.id, () async => await FileService.getDownloadUrl(item.id));
                } catch (e) {
                  _handleError(e);
                  return;
                }
                if (url.isNotEmpty) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started')));
                  await openFile(item.fileName, url, context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteFile(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // filtered + sorted files
    final filtered = _files.where((f) => _query.isEmpty || f.fileName.toLowerCase().contains(_query.toLowerCase())).toList();
    filtered.sort((a, b) => _sortNewest ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));

    return Stack(
      children: [
        Column(
          children: [
            // Search & sort row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _sortNewest ? 'A->Z' : 'Z->A',
                    
                    icon: Icon(
                      Icons.swap_vert,
                      color: _sortNewest ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () => setState(() => _sortNewest = !_sortNewest),
                  ),
                  // refresh button to
                  // reload file list
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadFiles,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFiles,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(bottom: 88),
                            children: const [
                              Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No files')))
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final f = filtered[i];
                              final ext = _extOf(f.fileName);
                              final icon = _iconForExt(ext);
                              final color = _colorForExt(ext);
                              final time = f.createdAt.toLocal().toString().split('.').first;


                              return Dismissible(
                                key: ValueKey(f.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: const Icon(Icons.delete_forever, color: Colors.white),
                                ),
                                confirmDismiss: (_) async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: const Text('Delete file'),
                                      content: Text('Delete "${f.fileName}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _deleteFile(f);
                                    return true;
                                  }
                                  return false;
                                },
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  onTap: _busyIds.contains(f.id) ? null : () => _openFile(f),
                                  onLongPress: () => _showActions(f),
                                  leading: Builder(builder: (ctx) {
                                    // show thumbnail for images
                                    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
                                      return FutureBuilder<String>(
                                        future: FileService.getDownloadUrl(f.id),
                                        builder: (ctx2, snap) {
                                          if (snap.hasData && snap.data!.isNotEmpty) {
                                            return CircleAvatar(
                                              radius: 24,
                                              backgroundColor: color.withOpacity(0.2),
                                              backgroundImage: NetworkImage(snap.data!),
                                            );
                                          }
                                          return CircleAvatar(
                                            radius: 24,
                                            backgroundColor: color,
                                            child: Icon(icon, color: Colors.white),
                                          );
                                        },
                                      );
                                    }
                                    return CircleAvatar(
                                      radius: 24,
                                      backgroundColor: color,
                                      child: Icon(icon, color: Colors.white),
                                    );
                                  }),
                                  title: Text(
                                    f.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text(time, style: const TextStyle(fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(ext.isEmpty ? 'file' : ext.toUpperCase(), style: TextStyle(fontSize: 11, color: color)),
                                      ),
                                    ],
                                  ),
                                  trailing: _busyIds.contains(f.id)
                                      ? const SizedBox(width: 36, height: 36, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                                      : IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteFile(f),
                                        ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
        // Floating upload button bottom-right
        Positioned(
          bottom: 16,
          right: 16,
          child: SafeArea(
            child: FloatingActionButton(
              onPressed: _uploading ? null : _pickAndUpload,
              tooltip: 'Upload',
              child: _uploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.upload_file),
            ),
          ),
        ),
      ],
    );
  }
}
