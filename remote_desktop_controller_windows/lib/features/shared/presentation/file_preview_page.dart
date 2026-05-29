import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:video_player/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

import '../file_service.dart';

String getFileType(String fileName) {
  if (!fileName.contains('.')) return '';
  return fileName.split('.').last.toLowerCase();
}

bool _isImage(String type) => type == 'jpg' || type == 'jpeg' || type == 'png';
bool _isPdf(String type) => type == 'pdf';
bool _isVideo(String type) => type == 'mp4';
bool _isAudio(String type) => type == 'mp3';

Future<void> _launchExternally(String url, String reason, BuildContext context) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw Exception('Invalid URL');
  }

  developer.log('Launching externally ($reason)');
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    throw Exception('Could not launch file');
  }
}

Future<void> openFile(String fileName, String url, BuildContext context) async {
  if (url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file URL.')),
      );
    }
    return;
  }

  final type = getFileType(fileName);
  developer.log('Opening file: $fileName (type: $type) from URL: $url');

  try {
    if (_isImage(type)) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ImagePreviewPage(fileName: fileName, url: url),
        ),
      );
      return;
    }

    if (_isPdf(type)) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewPage(fileName: fileName, url: url),
        ),
      );
      return;
    }

    if (_isVideo(type)) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoPreviewPage(fileName: fileName, url: url),
        ),
      );
      return;
    }

    if (_isAudio(type)) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AudioPreviewPage(fileName: fileName, url: url),
        ),
      );
      return;
    }

    await _launchExternally(url, 'unsupported type: $type', context);
  } catch (e, st) {
    developer.log('Error opening file: $e', stackTrace: st);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file: ${e.toString()}')),
      );
    }
  }
}

class _ImagePreviewPage extends StatelessWidget {
  final String fileName;
  final String url;

  const _ImagePreviewPage({required this.fileName, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Text('Failed to load image'),
          ),
        ),
      ),
    );
  }
}

class _PdfPreviewPage extends StatefulWidget {
  final String fileName;
  final String url;

  const _PdfPreviewPage({required this.fileName, required this.url});

  @override
  State<_PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<_PdfPreviewPage> {
  bool _loading = true;
  String? _error;

  void _markLoaded() {
    if (!mounted) return;
    developer.log('PDF loaded successfully: ${widget.fileName}');
    setState(() => _loading = false);
  }

  void _markError(String message) {
    if (!mounted) return;
    developer.log('PDF load failed: $message');
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  void initState() {
    super.initState();
    developer.log('Loading PDF: ${widget.fileName} from: ${widget.url}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: Stack(
        children: [
          if (_error == null)
            SfPdfViewer.network(
              widget.url,
              onDocumentLoaded: (_) => _markLoaded(),
              onDocumentLoadFailed: (details) => _markError(details.description),
            ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load PDF'),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPreviewPage extends StatefulWidget {
  final String fileName;
  final String url;

  const _VideoPreviewPage({required this.fileName, required this.url});

  @override
  State<_VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<_VideoPreviewPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    developer.log('Loading video: ${widget.fileName} from: ${widget.url}');
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      developer.log('Creating VideoPlayerController for: ${widget.fileName}');
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      developer.log('Video initialized successfully: ${widget.fileName}');
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e, st) {
      developer.log('Video initialization error: $e', stackTrace: st);
      if (!mounted) return;

      setState(() => _loading = false);

      try {
        await _launchExternally(widget.url, 'video_player init failed', context);
        if (mounted) Navigator.pop(context);
      } catch (fallbackError, fallbackStack) {
        developer.log('External fallback failed: $fallbackError', stackTrace: fallbackStack);
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    developer.log('Disposing video player for: ${widget.fileName}');
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Failed to load video'),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  )
                : _controller == null
                    ? const Text('Video unavailable')
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                          const SizedBox(height: 16),
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                              });
                            },
                            child: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                           ),
                           const SizedBox(height: 16),
                         ],
                       ),
      ),
    );
  }
}

class _AudioPreviewPage extends StatefulWidget {
  final String fileName;
  final String url;

  const _AudioPreviewPage({required this.fileName, required this.url});

  @override
  State<_AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<_AudioPreviewPage> {
  late final just_audio.AudioPlayer _player = just_audio.AudioPlayer();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    developer.log('Loading audio: ${widget.fileName} from: ${widget.url}');
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      developer.log('Calling setUrl() on AudioPlayer');
      await _player.setUrl(widget.url);
      if (!mounted) return;
      developer.log('Audio initialized successfully: ${widget.fileName}');
      setState(() => _loading = false);
    } catch (e, st) {
      developer.log('Audio initialization error: $e', stackTrace: st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load audio: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    developer.log('Disposing audio player for: ${widget.fileName}');
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Failed to load audio'),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.audiotrack, size: 72),
                      const SizedBox(height: 16),
                      StreamBuilder<just_audio.PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data?.playing ?? false;
                          return ElevatedButton.icon(
                            onPressed: () {
                              if (isPlaying) {
                                _player.pause();
                              } else {
                                _player.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            label: Text(isPlaying ? 'Pause' : 'Play'),
                          );
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}

class FilePreviewPage extends StatefulWidget {
  final String url;
  final String name;
  const FilePreviewPage({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  String? _textContent;
  bool _loadingText = false;
  String _error = '';

  String get _ext {
    final parts = widget.name.toLowerCase().split('.');
    return parts.length > 1 ? parts.last : '';
  }

  @override
  void initState() {
    super.initState();
    if (_isTextExt(_ext)) _loadText();
  }

  bool _isImageExt(String e) => ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(e);
  bool _isVideoExt(String e) => ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(e);
  bool _isPdfExt(String e) => e == 'pdf';
  bool _isTextExt(String e) => ['txt', 'csv', 'log', 'json', 'md'].contains(e);

  Future<void> _loadText() async {
    setState(() {
      _loadingText = true;
      _error = '';
    });
    try {
      final uri = Uri.parse(widget.url);
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) throw Exception('Failed to fetch (${resp.statusCode})');
      final bytes = await resp.fold<List<int>>(<int>[], (a, b) {
        a.addAll(b);
        return a;
      });
      final content = String.fromCharCodes(bytes);
      if (mounted) setState(() => _textContent = content);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load preview');
    } finally {
      if (mounted) setState(() => _loadingText = false);
    }
  }

  Future<void> _openExternally() async {
    await openFile(widget.name, widget.url, context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.name;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open externally',
          onPressed: _openExternally,
        )
      ]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Builder(builder: (ctx) {
            if (_isImageExt(_ext)) {
              return InteractiveViewer(
                child: Image.network(widget.url, fit: BoxFit.contain, errorBuilder: (_, __, ___) {
                  return const Text('Failed to load image');
                }),
              );
            }

            if (_isTextExt(_ext)) {
              if (_loadingText) return const CircularProgressIndicator();
              if (_error.isNotEmpty) return Text(_error);
              return _textContent == null
                  ? const Text('No preview available')
                  : SingleChildScrollView(child: SelectableText(_textContent!));
            }

            if (_isPdfExt(_ext)) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.picture_as_pdf, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text('PDF preview is not available inline.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open externally'),
                    onPressed: _openExternally,
                  ),
                ],
              );
            }

            if (_isVideoExt(_ext)) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.movie, size: 64, color: Colors.deepOrange),
                  const SizedBox(height: 12),
                  const Text('Inline video preview is not supported on this platform.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open externally'),
                    onPressed: _openExternally,
                  ),
                ],
              );
            }

            // Fallback for other types
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Preview not available.'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open externally'),
                  onPressed: _openExternally,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
