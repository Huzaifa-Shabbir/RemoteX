import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../logging.dart';


enum StreamResolution { low, medium, high }

extension StreamResolutionX on StreamResolution {
  int get width => switch (this) {
        StreamResolution.low => 854,
        StreamResolution.medium => 1280,
        StreamResolution.high => 1920,
      };
  int get height => switch (this) {
        StreamResolution.low => 480,
        StreamResolution.medium => 720,
        StreamResolution.high => 1080,
      };
}

class _IsolateProcessMessage {
  final Uint8List imageBytes;
  final int originalWidth;
  final int originalHeight;
  final int targetWidth;
  final int targetHeight;
  final int jpegQuality;

  _IsolateProcessMessage({
    required this.imageBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.targetWidth,
    required this.targetHeight,
    required this.jpegQuality,
  });
}

class ProcessedFrame {
  final Uint8List jpegData;
  final int width;
  final int height;
  final int processingTimeMs;

  ProcessedFrame({
    required this.jpegData,
    required this.width,
    required this.height,
    required this.processingTimeMs,
  });
}

Future<ProcessedFrame> _processFrameInIsolate(_IsolateProcessMessage message) async {
  final stopwatch = Stopwatch()..start();

  try {
    logDebug('[_processFrameInIsolate] Frame processing start input=${message.originalWidth}x${message.originalHeight} size=${message.imageBytes.length} target=${message.targetWidth}x${message.targetHeight} q=${message.jpegQuality}');

    // Decode BGRA bytes to image
    final image = img.Image.fromBytes(
      width: message.originalWidth,
      height: message.originalHeight,
      bytes: message.imageBytes.buffer,
      format: img.Format.uint8,
      order: img.ChannelOrder.bgra,
    );
    logDebug('[_processFrameInIsolate] Image decoded from BGRA bytes');

    // Resize if needed
    img.Image resized;
    if (image.width != message.targetWidth || image.height != message.targetHeight) {
      logDebug('[_processFrameInIsolate] Resizing ${image.width}x${image.height} -> ${message.targetWidth}x${message.targetHeight}');
      resized = img.copyResize(
        image,
        width: message.targetWidth,
        height: message.targetHeight,
        interpolation: img.Interpolation.linear,
      );
      logDebug('[_processFrameInIsolate] Resize completed');
    } else {
      logDebug('[_processFrameInIsolate] No resize needed');
      resized = image;
    }

    // Encode to JPEG
    final jpegData = img.encodeJpg(resized, quality: message.jpegQuality);
    logDebug('[_processFrameInIsolate] JPEG encoded size=${jpegData.length}');

    stopwatch.stop();
    logDebug('[_processFrameInIsolate] Processing time: ${stopwatch.elapsedMilliseconds}ms');

    return ProcessedFrame(
      jpegData: Uint8List.fromList(jpegData),
      width: resized.width,
      height: resized.height,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  } catch (e, st) {
    stopwatch.stop();
    logError('[_processFrameInIsolate] ERROR after ${stopwatch.elapsedMilliseconds}ms: $e\n$st');
    rethrow;
  }
}

/// Manager for frame processing with isolate
class StreamFrameProcessor {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  Stream<dynamic>? _broadcastStream;

  // Queue for managing frame processing requests
  final List<Completer<ProcessedFrame>> _pendingRequests = [];
  bool _isInitialized = false;
  bool _disposed = false;

  /// Initialize the isolate
  Future<void> init() async {
    if (_isInitialized || _disposed) {
      logDebug('[StreamFrameProcessor] init() skipped - already initialized or disposed');
      return;
    }

    try {
      logInfo('[StreamFrameProcessor] Initializing isolate...');
      _receivePort = ReceivePort();

      _isolate = await Isolate.spawn(
        _isolateEntryPoint,
        _receivePort!.sendPort,
        debugName: 'StreamFrameProcessor',
      );

      logDebug('[StreamFrameProcessor] Isolate spawned, waiting for SendPort...');

      // Convert to broadcast stream to allow multiple listeners
      _broadcastStream = _receivePort!.asBroadcastStream();

      // Get the first message (the SendPort from isolate)
      _sendPort = await _broadcastStream!.first;
      logDebug('[StreamFrameProcessor] Received SendPort from isolate');

      // NOW setup the listener for all subsequent messages
      _receiveSubscription = _broadcastStream!.listen(
        (message) {
          logDebug('[StreamFrameProcessor] Received message from isolate: ${message.runtimeType}');
          if (message is ProcessedFrame) {
            if (_pendingRequests.isNotEmpty) {
              final completer = _pendingRequests.removeAt(0);
              if (!completer.isCompleted) {
                completer.complete(message);
              }
            }
          } else if (message is Exception) {
            if (_pendingRequests.isNotEmpty) {
              final completer = _pendingRequests.removeAt(0);
              if (!completer.isCompleted) {
                completer.completeError(message);
              }
            }
          }
        },
        onError: (error, stackTrace) {
          logError('[StreamFrameProcessor] Isolate error: $error\n$stackTrace');
          // Complete pending requests with error
          for (final completer in _pendingRequests) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          }
          _pendingRequests.clear();
        },
        onDone: () {
          logInfo('[StreamFrameProcessor] Isolate closed');
          _isInitialized = false;
        },
      );

      _isInitialized = true;
      logInfo('[StreamFrameProcessor] Isolate initialized successfully');
    } catch (e, st) {
      logError('[StreamFrameProcessor] init() error: $e\n$st');
      _disposed = true;
      _isInitialized = false;
      // Clean up partial initialization
      try {
        _receiveSubscription?.cancel();
        _receivePort?.close();
        _isolate?.kill();
      } catch (_) {}
      _receiveSubscription = null;
      _receivePort = null;
      _isolate = null;
      _sendPort = null;
      _broadcastStream = null;
      rethrow;
    }
  }

  /// Process a frame asynchronously in isolate
  Future<ProcessedFrame> processFrame({
    required Uint8List imageBytes,
    required int originalWidth,
    required int originalHeight,
    required StreamResolution resolution,
    required int jpegQuality,
  }) async {
    if (!_isInitialized || _disposed) {
      logError('[StreamFrameProcessor] processFrame ERROR: Not initialized (initialized=$_isInitialized disposed=$_disposed)');
      throw StateError('StreamFrameProcessor not initialized or disposed');
    }

    logDebug('[StreamFrameProcessor] Queuing frame inputSize=${imageBytes.length} res=$resolution queue=${_pendingRequests.length}');

    final completer = Completer<ProcessedFrame>();
    _pendingRequests.add(completer);

    try {
      final message = _IsolateProcessMessage(
        imageBytes: imageBytes,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        targetWidth: resolution.width,
        targetHeight: resolution.height,
        jpegQuality: jpegQuality,
      );

      logDebug('[StreamFrameProcessor] Sending message to isolate');
      _sendPort!.send(message);
    } catch (e) {
      _pendingRequests.remove(completer);
      logError('[StreamFrameProcessor] processFrame ERROR sending to isolate: $e');
      completer.completeError(e);
    }

    return completer.future;
  }

  /// Dispose resources
  void dispose() {
    logInfo('[StreamFrameProcessor] Disposing...');
    _disposed = true;
    _isInitialized = false;

    // Complete all pending requests with error
    for (final completer in _pendingRequests) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Disposed'));
      }
    }
    _pendingRequests.clear();

    try {
      _receiveSubscription?.cancel();
      _receivePort?.close();
      _isolate?.kill();
    } catch (_) {}

    _receiveSubscription = null;
    _receivePort = null;
    _isolate = null;
    _sendPort = null;
    _broadcastStream = null;
  }

  bool get isInitialized => _isInitialized;
  bool get isDisposed => _disposed;
}

/// Entry point for isolate
void _isolateEntryPoint(SendPort parentPort) {
  final port = ReceivePort();
  parentPort.send(port.sendPort);
  port.listen((dynamic data) async {
    if (data is _IsolateProcessMessage) {
      try {
        final result = await _processFrameInIsolate(data);
        parentPort.send(result);
      } catch (e) {
        parentPort.send(Exception(e));
      }
    }
  });
}
