import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../Screen Capture/shared_Memory_Reader.dart';
import '../../native/remote_capture_ffi.dart';
import 'resize_And_Encode.dart';
import 'websocket_Input.dart';
import '../logging.dart';

class StreamingService {
  StreamingService._();
  static final instance = StreamingService._();

  final RemoteCapture _engine = RemoteCapture();
  final SharedMemoryReader _reader = SharedMemoryReader();
  final StreamFrameProcessor _processor = StreamFrameProcessor();

  bool _running = false;
  bool get isRunning => _running;

  // Current streaming resolution (affects processing target size)
  StreamResolution _resolution = StreamResolution.high;
  void setResolution(StreamResolution r) {
    _resolution = r;
    logDebug('[StreamingService] setResolution -> $_resolution');
    try {
      _resolutionCtrl.add(_resolution);
    } catch (_) {}
  }

  // Public getter to read the current streaming resolution from other parts of the app
  StreamResolution get resolution => _resolution;

  // Broadcast stream emitting resolution changes so UI can stay in sync
  final StreamController<StreamResolution> _resolutionCtrl = StreamController<StreamResolution>.broadcast();
  Stream<StreamResolution> get resolutionStream => _resolutionCtrl.stream;

  // Broadcasts the latest UI image for preview widgets
  final StreamController<ui.Image?> _imageCtrl = StreamController<ui.Image?>.broadcast();
  Stream<ui.Image?> get imageStream => _imageCtrl.stream;

  // Simple status stream for start/stop events
  final StreamController<bool> _statusCtrl = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusCtrl.stream;

  // Internal loop control
  int _lastRender = 0;
  int _lastSentFrame = 0;
  int _targetFrameIntervalMs = 16; // default ~60fps
  bool _isProcessing = false;
  bool _firstFrameSent = false;
  DateTime? _streamStartTime;

  // Configure target FPS
  void setTargetFps(int fps) {
    _targetFrameIntervalMs = (1000 / fps).round();
    logDebug('[StreamingService] setTargetFps: $fps -> $_targetFrameIntervalMs ms');
  }

  Future<bool> start() async {
    if (_running) return true;
    logInfo('[StreamingService] start()');

    try {
      _engine.startCapture();
    } catch (e, st) {
      logError('[StreamingService] engine.startCapture error: $e\n$st');
    }

    bool connected = false;
    for (int i = 0; i < 100; i++) {
      try {
        connected = _reader.connect();
      } catch (e, st) {
        logError('[StreamingService] reader.connect threw: $e\n$st');
        connected = false;
      }
      if (connected) break;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!connected) {
      logError('[StreamingService] Shared memory failed to connect');
      try {
        _engine.stopCapture();
      } catch (_) {}
      return false;
    }

    // Initialize processor if needed
    try {
      if (!_processor.isInitialized && !_processor.isDisposed) {
        await _processor.init();
      }
    } catch (e, st) {
      logError('[StreamingService] processor init failed: $e\n$st');
      return false;
    }

    _running = true;
    _streamStartTime = DateTime.now();
    _loop();
    _statusCtrl.add(true);
    return true;
  }

  void stop() {
    if (!_running) return;
    logInfo('[StreamingService] stop()');
    _running = false;
    try {
      _engine.stopCapture();
    } catch (e) {
      logError('[StreamingService] engine.stopCapture error: $e');
    }
    _statusCtrl.add(false);
  }

  void resetPreview() {
    _imageCtrl.add(null);
  }

  Future<void> _loop() async {
    logInfo('[StreamingService] _loop() enter');
    int frameCount = 0;
    while (_running) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRender < 16) {
        await Future.delayed(const Duration(milliseconds: 1));
        continue;
      }
      _lastRender = now;

      int w = 0, h = 0;
      Uint8List? bytes;
      try {
        w = _reader.getWidth();
        h = _reader.getHeight();
        bytes = _reader.getFrame();
      } catch (e, st) {
        logError('[StreamingService] read frame failed: $e\n$st');
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      if (bytes.isEmpty || w <= 0 || h <= 0) {
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }

      frameCount++;
      if (frameCount % 100 == 0) {
       // logInfo('[StreamingService] Read $frameCount frames total');
      }

      // Display original frame: decode to ui.Image and emit
      try {
        ui.decodeImageFromPixels(
          bytes,
          w,
          h,
          ui.PixelFormat.bgra8888,
          (img) {
            // Emit image to listeners
            _imageCtrl.add(img);
          },
        );
      } catch (e, st) {
        logError('[StreamingService] decodeImageFromPixels error: $e\n$st');
      }

      // Check if time to send
      final timeSinceLastSent = now - _lastSentFrame;
      if (timeSinceLastSent >= _targetFrameIntervalMs) {
        if (!_isProcessing && _running) {
          _isProcessing = true;
          _lastSentFrame = now;
          _processAndSendFrame(bytes, w, h).whenComplete(() {
            _isProcessing = false;
          });
        }
      }

      await Future.delayed(Duration.zero);
    }

    logInfo('[StreamingService] _loop() exit processed $frameCount frames');
  }

  Future<void> _processAndSendFrame(Uint8List imageBytes, int width, int height) async {
    try {
      final resolution = _resolution;
      final processed = await _processor.processFrame(
        imageBytes: imageBytes,
        originalWidth: width,
        originalHeight: height,
        resolution: resolution,
        jpegQuality: 80,
      );

      final ok = PairingService.instance.sendFrame(processed.jpegData);
      _firstFrameSent = _firstFrameSent || ok;

      if (ok && !_firstFrameSent) {
        _firstFrameSent = true;
        final sentAt = DateTime.now();
        final startupMs = _streamStartTime == null ? null : sentAt.difference(_streamStartTime!).inMilliseconds;
        logInfo('[StreamingService] FIRST FRAME SENT size=${processed.jpegData.length} startupMs=${startupMs ?? 'NA'}');
      } else if (!ok) {
        logDebug('[StreamingService] sendFrame returned FALSE');
      }
    } catch (e, st) {
      logError('[StreamingService] _processAndSendFrame ERROR: $e\n$st');
    }
  }

  void dispose() {
    stop();
    try {
      _processor.dispose();
    } catch (_) {}
    try {
      _imageCtrl.close();
      _statusCtrl.close();
      _resolutionCtrl.close();
    } catch (_) {}
  }
}
