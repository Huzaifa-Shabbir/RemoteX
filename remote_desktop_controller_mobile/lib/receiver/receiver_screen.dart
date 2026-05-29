import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'receiver_service.dart';
import 'package:flutter_app/webrtc/logger.dart';
import 'package:flutter_app/connection/connection_state.dart';
import 'package:flutter_app/connection/gesture_Input.dart';

class ReceiverScreen extends StatefulWidget {
  final String ip;
  final int wsPort;
  final int udpPort;
  final bool fullscreenLandscape;

  const ReceiverScreen({
    super.key,
    required this.ip,
    required this.wsPort,
    required this.udpPort,
    this.fullscreenLandscape = true,
  });

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final ReceiverService _receiver = ReceiverService();
  // Key for the widget that displays the video frame so GestureInput can map touches accurately
  final GlobalKey _videoKey = GlobalKey();
  // Key to access GestureInput State to show/hide keyboard (untyped to avoid private state type)
  final GlobalKey _gestureKey = GlobalKey();

  /// 🔥 PERFORMANCE: avoid full rebuild every frame
  final ValueNotifier<ui.Image?> _frameNotifier = ValueNotifier(null);

  String _status = 'idle';
  // Modifier states
  bool _ctrlDown = false;
  bool _altDown = false;
  bool _shiftDown = false;

  @override
  void initState() {
    super.initState();

    /// 🔥 Force immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    /// 🔥 Lock landscape
    if (widget.fullscreenLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    /// 🎥 Frame callback
    _receiver.onFrame = (img) {
      _frameNotifier.value = img;
      if (_status != 'receiving') {
        setState(() => _status = 'Receiving');
      }
    };

    /// ❌ Error callback
    _receiver.onError = (e) {
      Logger.error('UI', 'Receiver error: $e');
      if (!mounted) return;

      setState(() => _status = 'error');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receiver error: $e')),
      );
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
  }

  @override
  void dispose() {
    /// restore UI mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    /// restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    /// detach callbacks
    _receiver.onFrame = null;
    _receiver.onError = null;

    _frameNotifier.dispose();

    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _status = 'connecting');

    try {
      if (_receiver.running &&
          ConnectionStateNotifier.instance.isConnected) {
        setState(() => _status = 'connected');
        return;
      }

      await _receiver.connect(
        ip: widget.ip,
        wsPort: widget.wsPort,
        udpPort: widget.udpPort,
      );

      setState(() => _status = 'connected');
    } catch (e) {
      Logger.error('UI', 'Failed to start receiver: $e');
      setState(() => _status = 'failed');
    }
  }

  // Send key event over existing WebSocket via ReceiverService
  void _sendKeyEvent(String key, String action) {
    try {
      final ws = ReceiverService().ws;
      if (ws == null) return;
      final msg = jsonEncode({'type': 'key', 'key': key, 'action': action});
      // ignore: avoid_print
      print('CONTROL -> $msg');
      ws.add(msg);
    } catch (_) {}
  }

  void _toggleModifier(String key) {
    if (key == 'Ctrl') {
      _ctrlDown = !_ctrlDown;
      _sendKeyEvent('Ctrl', _ctrlDown ? 'down' : 'up');
    } else if (key == 'Alt') {
      _altDown = !_altDown;
      _sendKeyEvent('Alt', _altDown ? 'down' : 'up');
    } else if (key == 'Shift') {
      _shiftDown = !_shiftDown;
      _sendKeyEvent('Shift', _shiftDown ? 'down' : 'up');
    }
    setState(() {});
  }

  void _tapKey(String key) {
    _sendKeyEvent(key, 'down');
    _sendKeyEvent(key, 'up');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Prevent scaffold from resizing when keyboard appears; keyboard will overlay.
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [


          /// 🎥 STREAM VIEW (optimized) wrapped by GestureInput to capture touch/keyboard
          Positioned.fill(
            child: GestureInput(
              key: _gestureKey,
              videoKey: _videoKey,
              child: ValueListenableBuilder<ui.Image?>(
                valueListenable: _frameNotifier,
                builder: (_, frame, _) {
                  if (frame == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );

                  }

                  // Center the preview and attach the key to the FittedBox so
                  // coordinate mapping uses the painted/scaled rect.
                  return Center(
                    child: FittedBox(
                      key: _videoKey,
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: frame.width.toDouble(),
                        height: frame.height.toDouble(),
                        child: RawImage(image: frame),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          /// 📊 STATUS OVERLAY
          Positioned(
            top: 20,
            left: 20,
            child: _buildOverlay(),
          ),

          // Three-dot menu (contains restart, exit, keyboard toggle, modifiers and special keys)
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  try {
                    switch (value) {
                      case 'toggle_keyboard':
                        (_gestureKey.currentState as dynamic)?.toggleKeyboard();
                        break;
                      case 'toggle_ctrl':
                        _toggleModifier('Ctrl');
                        break;
                      case 'toggle_alt':
                        _toggleModifier('Alt');
                        break;
                      case 'toggle_shift':
                        _toggleModifier('Shift');
                        break;
                      case 'enter':
                        _tapKey('Enter');
                        break;
                      case 'backspace':
                        _tapKey('Backspace');
                        break;
                      case 'space':
                        _tapKey('Space');
                        break;
                      case 'restart':
                        await _receiver.dispose();
                        _frameNotifier.value = null;
                        setState(() => _status = 'restarting');
                        await _start();
                        break;
                      case 'exit':
                        Navigator.of(context).pop();
                        break;
                    }
                  } catch (_) {}
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'toggle_keyboard', child: Text('Toggle Keyboard')),
                  CheckedPopupMenuItem(value: 'toggle_ctrl', checked: _ctrlDown, child: const Text('Ctrl')),
                  CheckedPopupMenuItem(value: 'toggle_alt', checked: _altDown, child: const Text('Alt')),
                  CheckedPopupMenuItem(value: 'toggle_shift', checked: _shiftDown, child: const Text('Shift')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'enter', child: Text('Enter')),
                  const PopupMenuItem(value: 'backspace', child: Text('Backspace')),
                  const PopupMenuItem(value: 'space', child: Text('Space')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'restart', child: Text('Restart Stream')),
                  const PopupMenuItem(value: 'exit', child: Text('Exit')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color.fromRGBO(0, 0, 0, 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildModifierButton(String label, bool active) {
    return GestureDetector(
      onTap: () => _toggleModifier(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : const Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String key) {
    return GestureDetector(
      onTap: () => _tapKey(key),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}