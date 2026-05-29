import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_app/webrtc/logger.dart';
import 'package:flutter_app/connection/connection_state.dart';

class ReceiverService {
  // singleton
  static final ReceiverService _instance = ReceiverService._internal();
  factory ReceiverService() => _instance;
  ReceiverService._internal();

  WebSocket? ws;

  int udpPort = 0; // retained for compatibility with existing callers; UDP not used
  String serverIp = "";


  // callback when a decoded frame becomes available
  Function(ui.Image)? onFrame;

  // optional error callback
  Function(Object error)? onError;

  // whether the service is currently running
  bool running = false;

  // whether a decode is currently in progress
  bool _decoding = false;

  /// Sanitize string by removing invalid UTF-8 characters
  String _sanitizeUtf8String(String input) {
    try {
      // Encode to UTF-8 bytes, then decode back to remove invalid chars
      final bytes = utf8.encode(input);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return input;
    }
  }

  Future<void> connect({
    required String ip,
    required int wsPort,
    required int udpPort,
  }) async {
    serverIp = ip;
    this.udpPort = udpPort; // kept for backward compatibility

    Logger.log('RECV', 'Connecting to ws://$ip:$wsPort');

    try {
      // 1. Connect WebSocket
      ws = await WebSocket.connect('ws://$ip:$wsPort');
      running = true;

      Logger.log('RECV', '[WS] connected');

      // update global connection state
      ConnectionStateNotifier.instance.setConnected(serverIp, wsPort, udpPort);

      // send pairing message (udpPort field retained for compatibility)
      final pairMsg = jsonEncode({'type': 'pair', 'udpPort': udpPort});
      ws!.add(pairMsg);
      Logger.log('RECV', '[WS] sent pair: $pairMsg');

      // Listen for incoming websocket messages. The sender may transmit:
      // - JSON text messages (e.g. ack)
      // - base64-encoded image strings
      // - binary frames (List<int>) containing the image bytes
      ws!.listen((msg) {
        Logger.log('RECV', '[WS] recv (${msg.runtimeType})');
        try {
          if (msg is String) {
            // Sanitize the string first
            final sanitized = _sanitizeUtf8String(msg);

            // Try to parse JSON first (ack/info messages)
            try {
              final data = jsonDecode(sanitized);
              if (data is Map) {
                if (data['type'] == 'ack' || data['type'] == 'server-info' || data['type'] == 'paired') {
                  Logger.log('RECV', '[WS] received ${data['type']} message');
                  if (data.containsKey('senderIp') || data.containsKey('udpPort')) {
                    Logger.log('RECV', '[WS] sender info: ${jsonEncode(data)}');
                    try {
                      if (data['senderIp'] is String) serverIp = data['senderIp'];
                      if (data['udpPort'] is int) udpPort = data['udpPort'];
                    } catch (_) {}
                  }
                  return;
                }
              }
            } catch (_) {
              // not JSON - fall through to try as base64 image
            }

            // Treat the string as a base64-encoded image (optionally data URI)
            try {
              final base64Str = sanitized.startsWith('data:') ? sanitized.split(',').last : sanitized;
              final bytes = base64Decode(base64Str);
              _decodeAndDeliver(Uint8List.fromList(bytes));
            } catch (e) {
              Logger.error('RECV', 'WS string parse/decoding error: $e');
              onError?.call(e);
            }
          } else if (msg is List<int>) {
            // Binary frame received directly
            _decodeAndDeliver(Uint8List.fromList(msg));
          } else {
            Logger.log('RECV', 'Unknown WS message type: ${msg.runtimeType}');
          }
        } catch (e) {
          Logger.error('RECV', 'WS handler error: $e');
          onError?.call(e);
        }
      }, onError: (e) {
        Logger.error('RECV', '[WS] error: $e');
        onError?.call(e);
      }, onDone: () {
        Logger.log('RECV', '[WS] closed');
        running = false;
      });

      // No UDP listener or cleanup timers required anymore
    } catch (e) {
      Logger.error('RECV', 'Failed to connect: $e');
      onError?.call(e);
      rethrow;
    }
  }

  void _decodeAndDeliver(Uint8List buffer) {
    if (_decoding) return; // decode one at a time

    _decoding = true;
    Logger.log('RECV', 'Decoding image size=${buffer.length}');

    try {
      ui.decodeImageFromList(buffer, (img) {
        try {
          // frame delivered
          onFrame?.call(img);
         // Logger.log('RECV', 'Delivered image w=${img.width} h=${img.height} bytes=${buffer.length}');
        } catch (e) {
          Logger.error('RECV', 'Error in onFrame callback: $e');
          onError?.call(e);
        } finally {
          _decoding = false;
        }
      });
    } catch (e) {
      Logger.error('RECV', 'decodeImageFromList failed: $e');
      onError?.call(e);
      _decoding = false;
    }
  }

  /// Gracefully close sockets and free resources
  Future<void> dispose() async {
    running = false;
    try {
      await ws?.close();
      ws = null;
      Logger.log('RECV', 'Disposed');
    } catch (e) {
      Logger.error('RECV', 'Dispose error: $e');
    }
  }

  /// Clear connection state (call when user explicitly disconnects)
  void clearConnection() {
    ConnectionStateNotifier.instance.clear();
  }
}
