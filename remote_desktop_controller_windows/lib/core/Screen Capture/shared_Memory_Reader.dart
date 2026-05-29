import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class SharedMemoryReader {
  static const int HEADER_SIZE = 16;

  late Pointer<Uint8> buffer;

  bool connect() {
    final lib = DynamicLibrary.open('kernel32.dll');

    final openFileMapping = lib.lookupFunction<
        IntPtr Function(Uint32, Int32, Pointer<Utf16>),
        int Function(int, int, Pointer<Utf16>)>('OpenFileMappingW');

    final mapViewOfFile = lib.lookupFunction<
        Pointer<Uint8> Function(IntPtr, Uint32, Uint32, Uint32, IntPtr),
        Pointer<Uint8> Function(int, int, int, int, int)>('MapViewOfFile');

    final name = "RemoteXSharedMemory".toNativeUtf16();

    final handle = openFileMapping(0x0004, 0, name);
    if (handle == 0) return false;

    buffer = mapViewOfFile(handle, 0x0004, 0, 0, 0);

    return buffer != nullptr;
  }

  int getWidth() => buffer.cast<Int32>().elementAt(0).value;
  int getHeight() => buffer.cast<Int32>().elementAt(1).value;

  Uint8List getFrame() {
    final w = getWidth();
    final h = getHeight();

    return buffer
        .elementAt(HEADER_SIZE)
        .cast<Uint8>()
        .asTypedList(w * h * 4);
  }
}