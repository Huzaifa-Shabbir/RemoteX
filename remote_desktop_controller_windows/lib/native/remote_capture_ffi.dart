import 'dart:ffi';
import 'dart:io';

typedef StartCaptureNative = Bool Function();
typedef StopCaptureNative = Void Function();

typedef StartCaptureDart = bool Function();
typedef StopCaptureDart = void Function();

class RemoteCapture {
  late final DynamicLibrary _lib;

  late final StartCaptureDart startCapture;
  late final StopCaptureDart stopCapture;

  RemoteCapture() {
    _lib = Platform.isWindows
        ? DynamicLibrary.open('remoteX_Capture.dll')
        : throw UnsupportedError("Windows only");

    startCapture =
        _lib.lookupFunction<StartCaptureNative, StartCaptureDart>('start_Capture');

    stopCapture =
        _lib.lookupFunction<StopCaptureNative, StopCaptureDart>('stop_Capture');
  }
}