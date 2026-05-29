import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'websocket_Input.dart';
import '../logging.dart';
import '../ui/global_messenger.dart';

class RemoteControlService {
  RemoteControlService._();

  static final instance = RemoteControlService._().._initSubscriptionIfNeeded();

  // ── State ────────────────────────────────────────────────────
  bool _enabled = false;
  bool get isEnabled => _enabled;

  StreamSubscription<Map<String, dynamic>>? _inputSub;


  DateTime? _lastWarnAt;
  final Duration _warnCooldown = const Duration(seconds: 5);

  // Broadcast so multiple UI widgets can react.
  final StreamController<bool> _statusCtrl =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusCtrl.stream;


  void enable() {
    if (_enabled) return;
    _enabled = true;

    _statusCtrl.add(true);
    logInfo('[RemoteControlService] ENABLED');
  }


  void disable() {
    if (!_enabled) return;
    _enabled = false;
    _statusCtrl.add(false);
    logInfo('[RemoteControlService] DISABLED');
  }

  void toggle() => _enabled ? disable() : enable();

  void dispose() {
    // stop executing
    disable();
    // cancel global subscription if present
    _inputSub?.cancel();
    _inputSub = null;
    _statusCtrl.close();
  }


  void _initSubscriptionIfNeeded() {
    if (_inputSub != null) return;
    _inputSub = PairingService.instance.inputEvents.listen(
      _handleInput,
      onError: (e) => logError('[RemoteControlService] inputEvents error: $e'),
    );
  }

  void _handleInput(Map<String, dynamic> m) {

    final type = m['type']?.toString() ?? '';
    if (!_enabled) {
      final now = DateTime.now();
      if (_lastWarnAt == null || now.difference(_lastWarnAt!) >= _warnCooldown) {
        _lastWarnAt = now;
        try {
          showGlobalSnackBar('Please enable quick control from dashboard!');
        } catch (e) {
          logError('[RemoteControlService] failed to show disabled warning: $e');
        }
      }
      return; // do not execute inputs when disabled
    }

    logDebug('[RemoteControlService] input: $type');

    switch (type) {
      case 'mouse_move':
      case 'mouse_move_abs':
        final x = _toDouble(m['x']);
        final y = _toDouble(m['y']);
        if (x != null && y != null) _moveCursorNormalized(x, y);
        break;

      case 'mouse_click':
        final button = (m['button'] ?? 'left').toString().toLowerCase();
        final action = (m['action'] ?? 'down').toString().toLowerCase();
        final x = _toDouble(m['x']);
        final y = _toDouble(m['y']);
        if (x != null && y != null) _moveCursorNormalized(x, y);
        _mouseButton(button, action == 'down');
        break;

      case 'mouse_double_click':
        _mouseButton('left', true);
        _mouseButton('left', false);
        _mouseButton('left', true);
        _mouseButton('left', false);
        break;

      case 'scroll':
        final dy = _toDouble(m['dy']) ?? 0.0;
        final dx = _toDouble(m['dx']) ?? 0.0;
        _scroll(dy, dx);
        break;

      case 'key':
        final key = (m['key'] ?? '').toString();
        final down = (m['action'] ?? 'down').toString().toLowerCase() == 'down';
        _sendKey(key, down);
        break;

      default:
        logDebug('[RemoteControlService] unhandled input type: $type');
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  void _moveCursorNormalized(double xNorm, double yNorm) {
    final sw = GetSystemMetrics(SM_CXSCREEN);
    final sh = GetSystemMetrics(SM_CYSCREEN);
    final x = (xNorm * sw).clamp(0, sw).round();
    final y = (yNorm * sh).clamp(0, sh).round();
    if (SetCursorPos(x, y) == 0) {
      logError('[RemoteControlService] SetCursorPos failed');
    }
  }

  void _mouseButton(String button, bool down) {
    final flags = button == 'right'
        ? (down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP)
        : (down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP);

    final input = calloc<INPUT>();
    try {
      input.ref.type = INPUT_MOUSE;
      input.ref.mi.dwFlags = flags;
      input.ref.mi.dx = 0;
      input.ref.mi.dy = 0;
      input.ref.mi.mouseData = 0;
      input.ref.mi.time = 0;
      input.ref.mi.dwExtraInfo = GetMessageExtraInfo();
      if (SendInput(1, input, sizeOf<INPUT>()) != 1) {
        logError('[RemoteControlService] SendInput mouse failed');
      }
    } finally {
      calloc.free(input);
    }
  }

  void _scroll(double dy, double dx) {
    // Vertical scroll
    if (dy != 0) {
      final wheel = (dy * 120).round();
      final input = calloc<INPUT>();
      try {
        input.ref.type = INPUT_MOUSE;
        input.ref.mi.dwFlags = MOUSEEVENTF_WHEEL;
        input.ref.mi.mouseData = wheel & 0xFFFFFFFF;
        input.ref.mi.dx = 0;
        input.ref.mi.dy = 0;
        input.ref.mi.time = 0;
        input.ref.mi.dwExtraInfo = GetMessageExtraInfo();
        SendInput(1, input, sizeOf<INPUT>());
      } finally {
        calloc.free(input);
      }
    }
    // Horizontal scroll
    if (dx != 0) {
      final wheel = (dx * 120).round();
      final input = calloc<INPUT>();
      try {
        input.ref.type = INPUT_MOUSE;
        input.ref.mi.dwFlags = MOUSEEVENTF_HWHEEL;
        input.ref.mi.mouseData = wheel & 0xFFFFFFFF;
        input.ref.mi.dx = 0;
        input.ref.mi.dy = 0;
        input.ref.mi.time = 0;
        input.ref.mi.dwExtraInfo = GetMessageExtraInfo();
        SendInput(1, input, sizeOf<INPUT>());
      } finally {
        calloc.free(input);
      }
    }
  }

  void _sendKey(String keyStr, bool down) {
    int vk = 0;
    if (keyStr.length == 1) {
      vk = VkKeyScan(keyStr.codeUnitAt(0)) & 0xFF;
    } else {
      switch (keyStr.toLowerCase()) {
        case 'enter':     vk = VK_RETURN;  break;
        case 'space':     vk = VK_SPACE;   break;
        case 'backspace': vk = VK_BACK;    break;
        case 'tab':       vk = VK_TAB;     break;
        case 'escape':    vk = VK_ESCAPE;  break;
        case 'left':      vk = VK_LEFT;    break;
        case 'right':     vk = VK_RIGHT;   break;
        case 'up':        vk = VK_UP;      break;
        case 'down':      vk = VK_DOWN;    break;
        case 'delete':    vk = VK_DELETE;  break;
        case 'home':      vk = VK_HOME;    break;
        case 'end':       vk = VK_END;     break;
        case 'pageup':    vk = VK_PRIOR;   break;
        case 'pagedown':  vk = VK_NEXT;    break;
        default:
          if (keyStr.isNotEmpty) {
            vk = VkKeyScan(keyStr.codeUnitAt(0)) & 0xFF;
          }
      }
    }

    if (vk == 0) {
      logError('[RemoteControlService] unknown key: $keyStr');
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
      if (SendInput(1, input, sizeOf<INPUT>()) != 1) {
        logError('[RemoteControlService] SendInput key failed vk=$vk');
      }
    } finally {
      calloc.free(input);
    }
  }
}