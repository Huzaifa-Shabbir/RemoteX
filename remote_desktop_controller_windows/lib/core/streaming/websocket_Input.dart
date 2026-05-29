import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:win32/win32.dart';
import '../logging.dart';


class PairingService {
  PairingService._();

  static final instance = PairingService._();

  // configurable ports
  final int wsPort = 8081;
  final int udpPort = 50001;

  HttpServer? _httpServer;
  WebSocket? _wsClient;

  // paired device info
  InternetAddress? pairedAddress;
  int? pairedClientUdpPort;

  // streams
  final StreamController<Map<String, dynamic>> _pairingCtrl =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get pairingUpdates => _pairingCtrl.stream;

  // NEW: input events stream (mouse/touch/keyboard)
  final StreamController<Map<String, dynamic>> _inputCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get inputEvents => _inputCtrl.stream;

  Future<void> start() async {
    logInfo('[PairingService] start() called - starting WS:$wsPort (UDP disabled)');
    await _startWebSocketServer();
    logInfo('[PairingService] start() completed');
  }

  Future<void> stop() async {
    logInfo('[PairingService] stop() called');
    try {
      await _httpServer?.close(force: true);
      logInfo('[PairingService] HTTP/WebSocket server closed');
    } catch (e, st) {
      logError('[PairingService] stop() http close error: $e\n$st');
    }
    _httpServer = null;
    try {
      _wsClient?.close();
      logInfo('[PairingService] websocket client closed');
    } catch (e) {
      logError('[PairingService] stop() ws close error: $e');
    }
    _wsClient = null;

    // Close input controller
    try {
      await _inputCtrl.close();
    } catch (e) {
      logError('[PairingService] stop() inputCtrl close error: $e');
    }
  }

  Future<void> disconnectClient() async {
    try {
      if (_wsClient != null) {
        logInfo('[PairingService] disconnectClient() closing client socket');

        try {
          _sendJson({'type': 'server-disconnect', 'reason': 'disconnected by user'});
          // give the message a short moment to be sent
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          logError('[PairingService] error sending disconnect message: $e');
        }

        await _wsClient!.close(WebSocketStatus.normalClosure, 'client disconnected by user');
      }
    } catch (e, st) {
      logError('[PairingService] disconnectClient error: $e\n$st');
    }
    _wsClient = null;
    pairedAddress = null;
    pairedClientUdpPort = null;
    _pairingCtrl.add({'event': 'disconnected'});
  }

  Future<void> _startWebSocketServer() async {
    if (_httpServer != null) {
      logDebug('[PairingService] _startWebSocketServer() already running');
      return;
    }
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, wsPort);
    logInfo('[PairingService] WebSocket server bound on ${_httpServer!.address.address}:$wsPort');
    _httpServer!.listen((HttpRequest req) async {
      // Only accept WebSocket upgrade requests
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        try {

          logDebug('[PairingService] WebSocket upgrade request from ${req.connectionInfo?.remoteAddress}');
          final socket = await WebSocketTransformer.upgrade(req);
          _handleWs(socket, req.connectionInfo?.remoteAddress);
        } catch (e, st) {
          logError('[PairingService] _startWebSocketServer upgrade error: $e\n$st');
        }
      } else {
        // simple response for non-ws
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}))
          ..close();
      }
    });
  }

  void _handleWs(WebSocket socket, InternetAddress? remoteInfo) {
    _wsClient?.close();
    _wsClient = socket;
    pairedAddress = remoteInfo;
    logInfo('[PairingService] WebSocket client connected: ${remoteInfo?.address}');
    // send server info right away
    _sendJson({'type': 'server-info', 'udpPort': udpPort, 'wsPort': wsPort});
    _pairingCtrl.add({
      'event': 'connected',
      'remote': remoteInfo?.address,
      'remotePort': remoteInfo == null ? null : null
    });

    // Helper to normalize input payloads
    Map<String, dynamic> _normalizeInput(Map m) {
      num? _toNum(dynamic v) {
        if (v == null) return null;
        if (v is num) return v;
        if (v is String) return num.tryParse(v);
        return null;
      }

      final type = m['type']?.toString();
      final keyVal = m['key']?.toString();
      final button = m['button']?.toString();
      final action = m['action']?.toString();
      final xRaw = _toNum(m['x']);
      final yRaw = _toNum(m['y']);
      final deltaX = _toNum(m['dx']);
      final deltaY = _toNum(m['dy']);
      final extra = <String, dynamic>{};
      // include other fields if present
      for (final k in m.keys) {
        // keep known top-level keys out of extra (including 'key')
        if (k == 'type' || k == 'button' || k == 'action' || k == 'x' || k == 'y' || k == 'dx' || k == 'dy' || k == 'key') continue;
        extra[k.toString()] = m[k];
      }
      return {
        'type': type,
        if (keyVal != null) 'key': keyVal,
        if (button != null) 'button': button,
        if (action != null) 'action': action,
        if (xRaw != null) 'x': (xRaw is int) ? xRaw.toDouble() : xRaw.toDouble(),
        if (yRaw != null) 'y': (yRaw is int) ? yRaw.toDouble() : yRaw.toDouble(),
        if (deltaX != null) 'dx': deltaX,
        if (deltaY != null) 'dy': deltaY,
        if (extra.isNotEmpty) 'meta': extra,
      };
    }

    socket.listen((data) async {

      if (data is String) {
        final preview = data.length > 300 ? '${data.substring(0, 300)}...' : data;
        logDebug('[PairingService] received TEXT frame (${remoteInfo?.address}): $preview');
      } else if (data is List<int>) {
        logDebug('[PairingService] received BINARY frame (${remoteInfo?.address}): ${data.length} bytes');
      } else {
        logDebug('[PairingService] received frame of unknown type: ${data.runtimeType}');
      }

      try {

        if (data is String) {
          // Log trimmed raw text
          final rawPreview = data.length > 300 ? '${data.substring(0, 300)}...' : data;
          logDebug('[PairingService] WS TEXT recv from ${remoteInfo?.address}: $rawPreview');

          // Attempt to parse JSON; if it fails, log and ignore the message
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) {
              final m = Map<String, dynamic>.from(decoded);
              logDebug('[PairingService] WS parsed JSON: ${m.keys.join(', ')}');
              // Always log the received raw JSON and parsed type as required
              logInfo('[WS RECEIVED] ${data}');
              logInfo('[PARSED] type = ${m['type']}');


              // NEW: handle pairing and simple control messages
              final type = m['type']?.toString();
              if (type == 'pair') {
                if (m.containsKey('udpPort')) {
                  pairedClientUdpPort = m['udpPort'] is int
                      ? m['udpPort'] as int
                      : int.tryParse(m['udpPort'].toString());
                }
                _pairingCtrl.add({
                  'event': 'paired',
                  'clientIp': pairedAddress?.address,
                  'clientUdpPort': pairedClientUdpPort
                });


                final localIp = await getLocalIp();
                _sendJson({
                  'type': 'paired',
                  'receiverIp': localIp,
                  'receiverUdpPort': udpPort,
                  'receiverWsPort': wsPort
                });
                logInfo('[PairingService] WS paired with ${pairedAddress?.address} clientUdpPort=$pairedClientUdpPort');
              } else if (type == 'ping') {
                _sendJson({'type': 'pong'});

              } else if (type == 'mouse_click' || type == 'mouse_move' || type == 'touch' || type == 'key' || type == 'mouse_move_abs' || type == 'mouse_double_click' || type == 'scroll') {
                // Normalize and forward all input events to the input stream.
                final normalized = _normalizeInput(m);

                  if (type == 'key') {
                  final keyVal = (normalized['key'] ?? '').toString();
                  if (keyVal.isEmpty) {
                    final altCandidates = ['k', 'char', 'character', 'keyChar', 'keyCode', 'code'];
                    String? found;
                    for (final c in altCandidates) {
                      if (m.containsKey(c) && m[c] != null && m[c].toString().isNotEmpty) {
                        found = m[c].toString();
                        break;
                      }
                    }
                    if (found != null && found.isNotEmpty) {
                      normalized['key'] = found;
                      logDebug('[PairingService] Recovered key for key-event: $found');
                    } else {
                      // Nothing we can do — log and skip emitting an empty key event.
                      logError('[PairingService] received key event with empty key - skipping. raw=${jsonEncode(m)}');
                      // Also notify pairing updates listeners that an invalid input was ignored
                      _pairingCtrl.add({'event': 'input_ignored', 'reason': 'empty_key', 'payload': m});
                      return; // exit this listener callback for the current message
                    }
                  }
                }

                try {
                  _inputCtrl.add(normalized);
                } catch (e) {
                  logError('[PairingService] error emitting input event: $e');
                }
                // Also emit as a pairing update so existing listeners can pick it up
                _pairingCtrl.add({'event': 'input', 'payload': normalized});
              } else {
                _pairingCtrl.add({'event': 'message', 'payload': m});
              }
            } else {
              logDebug('[PairingService] WS JSON parsed but not an object: ${decoded.runtimeType}');
            }
          } catch (e) {
            logError('[PairingService] WS JSON parse error: $e - raw:$rawPreview');
          }
        } else {
          // Explicitly ignore binary frames (images, etc.)
          logDebug('[PairingService] WS received non-text frame of type ${data.runtimeType} - ignored');
        }
      } catch (e, st) {
        logError('[PairingService] WS message handling error: $e\n$st');
      }
    }, onDone: () {
      logInfo('[PairingService] WebSocket client disconnected: ${pairedAddress?.address}');
      _pairingCtrl.add({'event': 'disconnected'});
      _wsClient = null;
    }, onError: (err, st) {
      logError('[PairingService] WebSocket error: $err\n$st');
      _wsClient = null;
    });
  }

  void _sendJson(Map m) {
    try {
      final preview = jsonEncode(m);
      logDebug('[PairingService] WS send: ${preview.length > 300 ? preview.substring(0, 300) + "..." : preview}');
      _wsClient?.add(jsonEncode(m));
    } catch (e) {
      logError('[PairingService] _sendJson error: $e');
    }
  }

  bool sendFrame(Uint8List frame) {
    try {
      if (_wsClient == null) {
        logDebug('[PairingService] sendFrame: no websocket client connected, frame dropped (${frame.length} bytes)');
        return false;
      }
      // Send raw binary frame
      _wsClient!.add(frame);
      if (frame.length > 1024 * 50) {
        logDebug('[PairingService] sendFrame: sent binary frame size=${frame.length} bytes');
      }
      return true;
    } catch (e, st) {
      logError('[PairingService] sendFrame ERROR: $e\n$st');
      return false;
    }
  }

  // Returns a best-effort local IPv4 address or '127.0.0.1'
  Future<String> getLocalIp() async => _getLocalIpAsync();

  Future<String> _getLocalIpAsync() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith(RegExp(r'10\.|172\.|192\.|169\.|127\.'))) {
            return addr.address;
          }
          if (!addr.isLoopback && !addr.address.startsWith('127\.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      logError('[PairingService] _getLocalIpAsync error: $e');
    }
    return '127.0.0.1';
  }

  void _handleControlMessage(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString();
    switch (type) {
      case 'mouse_move_abs':
        final x = (m['x'] is num) ? (m['x'] as num).toDouble() : double.tryParse(m['x']?.toString() ?? '') ?? 0.0;
        final y = (m['y'] is num) ? (m['y'] as num).toDouble() : double.tryParse(m['y']?.toString() ?? '') ?? 0.0;
        logInfo('[PARSED] type = mouse_move_abs');
        _moveCursorNormalized(x, y);
        logInfo('[EXECUTED] MOVE to (${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})');
        break;

      case 'mouse_click':
        final button = (m['button'] ?? 'left').toString().toLowerCase();
        final action = (m['action'] ?? 'down').toString().toLowerCase();
        double? xNorm;
        double? yNorm;
        if (m.containsKey('x')) {
          final xv = m['x'];
          xNorm = xv is num ? xv.toDouble() : double.tryParse(xv?.toString() ?? '');
        }
        if (m.containsKey('y')) {
          final yv = m['y'];
          yNorm = yv is num ? yv.toDouble() : double.tryParse(yv?.toString() ?? '');
        }

        // Compute coords string safely
        String coordsStr = 'unknown';
        if (xNorm != null && yNorm != null) {
          _moveCursorNormalized(xNorm, yNorm);
          final sx = (xNorm * GetSystemMetrics(SM_CXSCREEN)).round();
          final sy = (yNorm * GetSystemMetrics(SM_CYSCREEN)).round();
          coordsStr = '$sx,$sy';
        }

        logInfo('[PARSED] type = mouse_click');
        _mouseClick(button, action);
        logInfo('[EXECUTED] ${button.toUpperCase()} ${action.toUpperCase()} at ${coordsStr}');
        break;

      case 'mouse_double_click':
        logInfo('[PARSED] type = mouse_double_click');
        _mouseDoubleClick();
        logInfo('[EXECUTED] DOUBLE CLICK (left)');
        break;

      case 'scroll':
        final dx = (m['dx'] is num) ? (m['dx'] as num).toDouble() : 0.0;
        final dy = (m['dy'] is num) ? (m['dy'] as num).toDouble() : 0.0;
        logInfo('[PARSED] type = scroll');
        _mouseScroll(dx, dy);
        logInfo('[EXECUTED] SCROLL dx=${dx.toStringAsFixed(2)} dy=${dy.toStringAsFixed(2)}');
        break;

      case 'key':
        final key = (m['key'] ?? '').toString();
        final action = (m['action'] ?? 'down').toString().toLowerCase();
        logInfo('[PARSED] type = key');
        _sendKey(key, action == 'down');
        logInfo('[EXECUTED] KEY ${action.toUpperCase()} ${key}');
        break;

      default:
        logError('[ERROR] invalid message format - unknown type: $type');
    }
  }

  void _moveCursorNormalized(double xNorm, double yNorm) {
    final int screenW = GetSystemMetrics(SM_CXSCREEN);
    final int screenH = GetSystemMetrics(SM_CYSCREEN);
    final int x = (xNorm * screenW).clamp(0, screenW).round();
    final int y = (yNorm * screenH).clamp(0, screenH).round();
    // Move instantly using SetCursorPos
    final moved = SetCursorPos(x, y);
    if (moved == 0) {
      logError('[ERROR] SetCursorPos failed');
    }
  }

  void _mouseClick(String button, String action) {
    final down = action == 'down';
    final flags = (button == 'right')
        ? (down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP)
        : (down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP);

    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;
      input.ref.mi.mouseData = 0;
      input.ref.mi.dwFlags = flags;
      input.ref.mi.time = 0;
      input.ref.mi.dwExtraInfo = GetMessageExtraInfo();
      final sent = SendInput(1, input, sizeOf<INPUT>());
      if (sent != 1) logError('[ERROR] SendInput mouse click failed');
    } finally {
      calloc.free(input);
    }
  }

  void _mouseDoubleClick() {
    // left down + up twice
    _mouseClick('left', 'down');
    _mouseClick('left', 'up');
    _mouseClick('left', 'down');
    _mouseClick('left', 'up');
  }

  void _mouseScroll(double dx, double dy) {
    // Windows wheel uses units of 120 per notch
    final int wheel = (dy * 120).round();
    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;
      input.ref.mi.mouseData = wheel & 0xFFFFFFFF;
      input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
      input.ref.mi.time = 0;
      input.ref.mi.dwExtraInfo = GetMessageExtraInfo();
      final sent = SendInput(1, input, sizeOf<INPUT>());
      if (sent != 1) logError('[ERROR] SendInput mouse wheel failed');
    } finally {
      calloc.free(input);
    }
  }

  void _sendKey(String keyStr, bool down) {
    // Map some named keys
    int vk = 0;
    final k = keyStr;
    if (k.length == 1) {
      final codeUnit = k.codeUnitAt(0);
      // Try VkKeyScan to get VK
      final res = VkKeyScan(codeUnit);
      vk = res & 0xFF;
    } else {
      switch (k.toLowerCase()) {
        case 'enter': vk = VK_RETURN; break;
        case 'space': vk = VK_SPACE; break;
        case 'backspace': vk = VK_BACK; break;
        case 'tab': vk = VK_TAB; break;
        case 'escape': vk = VK_ESCAPE; break;
        case 'left': vk = VK_LEFT; break;
        case 'right': vk = VK_RIGHT; break;
        case 'up': vk = VK_UP; break;
        case 'down': vk = VK_DOWN; break;
        default:
          // fallback: try first char
          if (k.isNotEmpty) {
            final res = VkKeyScan(k.codeUnitAt(0));
            vk = res & 0xFF;
          }
      }
    }

    if (vk == 0) {
      logError('[ERROR] unknown key mapping for: $keyStr');
      return;
    }

    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_KEYBOARD;
      input.ref.ki.wVk = vk;
      input.ref.ki.wScan = 0;
      input.ref.ki.time = 0;
      input.ref.ki.dwExtraInfo = GetMessageExtraInfo();
      input.ref.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
      final sent = SendInput(1, input, sizeOf<INPUT>());
      if (sent != 1) logError('[ERROR] SendInput key failed for vk=$vk');
    } finally {
      calloc.free(input);
    }
  }
}
