// filepath: g:\SE_Project\remote_desktop_controller_mobile\lib\connection\gesture_Input.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app/receiver/receiver_service.dart';

/// GestureInput: overlay widget that captures touch gestures and keyboard
/// input and sends lightweight JSON control messages over the existing
/// WebSocket connection provided by ReceiverService().ws.
///
/// Usage: place GestureInput around the video stream widget so it receives
/// gestures (it accepts a child widget).
class GestureInput extends StatefulWidget {
  final Widget child;
  // Optional GlobalKey pointing at the widget that actually displays the video frame
  // (e.g. the SizedBox wrapping RawImage). When provided, GestureInput will map
  // touch coordinates to that render box for accurate normalization.
  final GlobalKey? videoKey;
  // videoRect is an alternative to videoKey. If provided, it is used to map touches.
  final Rect? videoRect;
  final double moveSensitivity; // multiplier for movements before mapping to normalized space (optional)
  final double scrollSensitivity; // multiplier for scroll deltas

  const GestureInput({
    super.key,
    required this.child,
    this.videoKey,
    this.videoRect,
    this.moveSensitivity = 1.0,
    this.scrollSensitivity = 1.0,
  });

  @override
  State<GestureInput> createState() => _GestureInputState();
}

class _GestureInputState extends State<GestureInput> {
  // Movement throttling / accumulation
  static const int _moveMinIntervalMs = 16; // ~60Hz
  static const int _scrollMinIntervalMs = 33; // ~30Hz
  static const double _minMoveThreshold = 0.002; // minimum normalized movement to send
  static const double _smoothingAlpha = 0.35; // exponential smoothing factor

  bool _moveFlushScheduled = false;
  bool _isDragging = false; // true when one-finger drag (we sent left down)
  bool _longPressActive = false; // true while right-click long press is active
  Timer? _tapHoldTimer;
  bool _suppressTap = false;
  int _lastMoveSentMs = 0;
  // For absolute normalized movement
  double? _lastSentX;
  double? _lastSentY;
  double? _smoothedX;
  double? _smoothedY;
  double _pendingNormX = -1.0;
  double _pendingNormY = -1.0;

  double _pendingScrollDx = 0.0;
  double _pendingScrollDy = 0.0;
  bool _scrollFlushScheduled = false;
  int _lastScrollSentMs = 0;

  // Text input handling
  final TextEditingController _textController = TextEditingController();
  String _prevText = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _tapHoldTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // External API: allow parent to show/hide the soft keyboard and focus the hidden TextField.
  void showKeyboard() {
    try {
      // Request focus so keyboard input will be directed to the hidden TextField.
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
      // ignore: avoid_print
      print('GESTURE INPUT -> showKeyboard requested');
    } catch (_) {}
  }

  void hideKeyboard() {
    try {
      _focusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      // ignore: avoid_print
      print('GESTURE INPUT -> hideKeyboard requested');
    } catch (_) {}
  }

  void toggleKeyboard() {
    if (_focusNode.hasFocus) {
      hideKeyboard();
    } else {
      showKeyboard();
    }
  }

  void _send(Map<String, dynamic> msg) {
    try {
      final ws = ReceiverService().ws;
      final payload = jsonEncode(msg);
      // Print every outgoing control message so detected gestures are visible in console
      // This prints lightweight JSON strings like the ones required by the protocol.
      // Example: {"type":"mouse_move","dx":1.2,"dy":-0.6}
      // Use plain print to ensure visibility in debug console.
      // ignore: avoid_print
      print('GESTURE -> $payload');
      if (ws == null)
        {
          print('GESTURE -> no websocket connection, message dropped');
          return;
        }
      ws.add(payload);
    } catch (_) {
      // ignore send errors - non-blocking
    }
  }

  // Map a global focal point (from gesture details) into normalized coordinates [0..1]
  // relative to the provided videoRect (or the full widget area if videoRect is null).
  Offset? _mapGlobalToNormalized(Offset globalPoint) {
    try {
      // Prefer using videoKey if supplied (more accurate when using FittedBox)
      if (widget.videoKey != null) {
        final vctx = widget.videoKey!.currentContext;
        if (vctx != null) {
          final vbox = vctx.findRenderObject() as RenderBox?;
          if (vbox != null) {
            // Compute the actual painted global rect of this render object.
            // This handles cases where the child is scaled by a parent (e.g. FittedBox)
            // by transforming the paintBounds into global coordinates.
            final Matrix4 transform = vbox.getTransformTo(null);
            final Rect paintBounds = vbox.paintBounds;
            final Rect globalRect = MatrixUtils.transformRect(transform, paintBounds);
            final topLeft = globalRect.topLeft;
            final size = globalRect.size;
            if (size.width <= 0 || size.height <= 0) {
              // ignore: avoid_print
              print('GESTURE MAP -> video painted rect has zero size, cannot map');
              return null;
            }
            final local = globalPoint - topLeft;
            final dx = local.dx / size.width;
            final dy = local.dy / size.height;
            final nx = dx.clamp(0.0, 1.0);
            final ny = dy.clamp(0.0, 1.0);
            // debug mapping info
            // ignore: avoid_print
            print('GESTURE MAP -> videoKey paintedRect=$globalRect local=$local normalized=(${nx.toStringAsFixed(4)},${ny.toStringAsFixed(4)})');
            return Offset(nx, ny);
          }
        }
      }

      // Fallback: use provided videoRect in local coordinates or the full widget area
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return null;
      final local = box.globalToLocal(globalPoint);
      final rect = widget.videoRect ?? Offset.zero & box.size;
      if (rect.width <= 0 || rect.height <= 0) {
        // ignore: avoid_print
        print('GESTURE MAP -> fallback video rect has zero size, cannot map');
        return null;
      }
      final dx = (local.dx - rect.left) / rect.width;
      final dy = (local.dy - rect.top) / rect.height;
      final nx = dx.clamp(0.0, 1.0);
      final ny = dy.clamp(0.0, 1.0);
      // ignore: avoid_print
      print('GESTURE MAP -> fallback rect=$rect local=$local normalized=(${nx.toStringAsFixed(4)},${ny.toStringAsFixed(4)})');
      return Offset(nx, ny);
    } catch (_) {
      return null;
    }
  }

  void _queueNormalizedMove(double nx, double ny) {
    // apply smoothing
    if (_smoothedX == null || _smoothedY == null) {
      _smoothedX = nx;
      _smoothedY = ny;
    } else {
      _smoothedX = _smoothedX! * (1 - _smoothingAlpha) + nx * _smoothingAlpha;
      _smoothedY = _smoothedY! * (1 - _smoothingAlpha) + ny * _smoothingAlpha;
    }

    // If movement is very small after smoothing, ignore unless we never sent any value yet
    final dxSinceLast = _lastSentX == null ? double.infinity : (_smoothedX! - _lastSentX!).abs();
    final dySinceLast = _lastSentY == null ? double.infinity : (_smoothedY! - _lastSentY!).abs();
    if (dxSinceLast < _minMoveThreshold && dySinceLast < _minMoveThreshold) return;

    _pendingNormX = _smoothedX!;
    _pendingNormY = _smoothedY!;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMoveSentMs >= _moveMinIntervalMs) {
      _flushNormalizedMove();
    } else if (!_moveFlushScheduled) {
      _moveFlushScheduled = true;
      final delay = _moveMinIntervalMs - (now - _lastMoveSentMs);
      Timer(Duration(milliseconds: max(1, delay)), _flushNormalizedMove);
    }
  }

  void _flushNormalizedMove() {
    _moveFlushScheduled = false;
    final nx = _pendingNormX;
    final ny = _pendingNormY;
    _pendingNormX = -1.0;
    _pendingNormY = -1.0;
    if (nx < 0 || ny < 0) return;
    _lastMoveSentMs = DateTime.now().millisecondsSinceEpoch;
    _lastSentX = nx;
    _lastSentY = ny;
    _send({
      'type': 'mouse_move_abs',
      'x': double.parse(nx.toStringAsFixed(6)),
      'y': double.parse(ny.toStringAsFixed(6)),
    });
  }

  void _queueScroll(double dx, double dy) {
    dx *= widget.scrollSensitivity;
    dy *= widget.scrollSensitivity;
    if (dx.abs() < 0.5 && dy.abs() < 0.5) return; // small pixel noise for scroll

    _pendingScrollDx += dx;
    _pendingScrollDy += dy;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollSentMs >= _scrollMinIntervalMs) {
      _flushScroll();
    } else if (!_scrollFlushScheduled) {
      _scrollFlushScheduled = true;
      final delay = _scrollMinIntervalMs - (now - _lastScrollSentMs);
      Timer(Duration(milliseconds: max(1, delay)), _flushScroll);
    }
  }

  void _flushScroll() {
    _scrollFlushScheduled = false;
    final dx = _pendingScrollDx;
    final dy = _pendingScrollDy;
    _pendingScrollDx = 0.0;
    _pendingScrollDy = 0.0;
    if (dx == 0.0 && dy == 0.0) return;
    _lastScrollSentMs = DateTime.now().millisecondsSinceEpoch;
    _send({
      'type': 'scroll',
      'dx': dx,
      'dy': dy,
    });
  }

  // Mouse click helpers
  void _sendLeftDown() => _send({'type': 'mouse_click', 'button': 'left', 'action': 'down'});
  void _sendLeftUp() => _send({'type': 'mouse_click', 'button': 'left', 'action': 'up'});
  void _sendRightDown() => _send({'type': 'mouse_click', 'button': 'right', 'action': 'down'});
  void _sendRightUp() => _send({'type': 'mouse_click', 'button': 'right', 'action': 'up'});
  void _sendDoubleClick() => _send({'type': 'mouse_double_click'});
  void _sendLeftDownAt(double x, double y) => _send({'type': 'mouse_click', 'button': 'left', 'action': 'down', 'x': x, 'y': y});
  void _sendLeftUpAt(double x, double y) => _send({'type': 'mouse_click', 'button': 'left', 'action': 'up', 'x': x, 'y': y});
  void _sendRightDownAt(double x, double y) => _send({'type': 'mouse_click', 'button': 'right', 'action': 'down', 'x': x, 'y': y});
  void _sendRightUpAt(double x, double y) => _send({'type': 'mouse_click', 'button': 'right', 'action': 'up', 'x': x, 'y': y});

  // Keyboard handling via hidden TextField. We compare previous and current text
  // to infer inserts (send key down/up for characters) and deletions (backspace).
  void _onTextChanged(String text) {
    // Determine change
    if (text.length > _prevText.length) {
      // insertion(s)
      final inserted = text.substring(_prevText.length);
      for (final rune in inserted.runes) {
        final char = String.fromCharCode(rune);
        // normalize newline => Enter
        if (char == '\n') {
          _send({'type': 'key', 'key': 'Enter', 'action': 'down'});
          _send({'type': 'key', 'key': 'Enter', 'action': 'up'});
        } else if (char == ' ') {
          _send({'type': 'key', 'key': 'Space', 'action': 'down'});
          _send({'type': 'key', 'key': 'Space', 'action': 'up'});
        } else {
          _send({'type': 'key', 'key': char, 'action': 'down'});
          _send({'type': 'key', 'key': char, 'action': 'up'});
        }
      }
    } else if (text.length < _prevText.length) {
      // deletion(s) -> Backspace for each removed char
      final count = _prevText.length - text.length;
      for (int i = 0; i < count; i++) {
        _send({'type': 'key', 'key': 'Backspace', 'action': 'down'});
        _send({'type': 'key', 'key': 'Backspace', 'action': 'up'});
      }
    }
    _prevText = text;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Underlying content (video stream)
        IgnorePointer(
          child: widget.child,
        ),
        // Gesture capture layer
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              // ignore: avoid_print
              print('GESTURE DETECTED -> onTapDown at ${details.globalPosition}');
              // Start a short timer to detect if a long-press will occur; if long-press happens
              // we will suppress the tap. This prevents onTapUp from sending a left click when
              // a long-press is intended.
              _suppressTap = false;
              _tapHoldTimer?.cancel();
              _tapHoldTimer = Timer(const Duration(milliseconds: 480), () {
                // timer expired — no long-press started within this window
                _suppressTap = false;
              });
            },
            onTapUp: (details) {
              // ignore: avoid_print
              print('GESTURE DETECTED -> onTapUp at ${details.globalPosition}');
              _tapHoldTimer?.cancel();
              if (_suppressTap || _longPressActive || _isDragging) {
                // ignore: avoid_print
                print('GESTURE IGNORED -> tap suppressed (suppress=$_suppressTap longPress=$_longPressActive isDragging=$_isDragging)');
                _suppressTap = false;
                return;
              }
              final norm = _mapGlobalToNormalized(details.globalPosition);
              if (norm != null) {
                // send a quick click (down+up) at the tapped normalized position
                _sendLeftDownAt(norm.dx, norm.dy);
                _sendLeftUpAt(norm.dx, norm.dy);
              } else {
                _sendLeftDown();
                _sendLeftUp();
              }
            },
            onTapCancel: () {
              _tapHoldTimer?.cancel();
              _suppressTap = false;
              // ignore: avoid_print
              print('GESTURE DETECTED -> onTapCancel');
            },
            onDoubleTap: () {
              // ignore: avoid_print
              print('GESTURE DETECTED -> onDoubleTap');
              _sendDoubleClick();
            },
            onLongPressStart: (details) {
              // ignore: avoid_print
              print('GESTURE DETECTED -> onLongPressStart at ${details.globalPosition}');
              // A long press has started — suppress any tap that may follow
              _tapHoldTimer?.cancel();
              _suppressTap = true;
               // Long press should cancel any pending drag left-down
               if (_isDragging) {
                 // cancel dragging
                 final normCancel = _mapGlobalToNormalized(details.globalPosition);
                 if (normCancel != null) {
                   _sendLeftUpAt(normCancel.dx, normCancel.dy);
                 } else {
                   _sendLeftUp();
                 }
                 _isDragging = false;
               }
               _longPressActive = true;
               final norm = _mapGlobalToNormalized(details.globalPosition);
               if (norm != null) {
                 _sendRightDownAt(norm.dx, norm.dy);
               } else {
                 _sendRightDown();
               }
             },
             onLongPressEnd: (details) {
               // ignore: avoid_print
               print('GESTURE DETECTED -> onLongPressEnd at ${details.globalPosition}');
               _longPressActive = false;
               final norm = _mapGlobalToNormalized(details.globalPosition);
               if (norm != null) {
                 _sendRightUpAt(norm.dx, norm.dy);
               } else {
                 _sendRightUp();
               }
             },
            onScaleStart: (details) {
              // ignore: avoid_print
              print('GESTURE DETECTED -> onScaleStart pointers=${details.pointerCount}');
              // Do not immediately send left-down here. We'll wait for movement in onScaleUpdate
              // to distinguish between a tap/long-press and a drag.
            },
            onScaleUpdate: (details) {
              final pc = details.pointerCount;
              final dx = details.focalPointDelta.dx;
              final dy = details.focalPointDelta.dy;
              // debug: print small summary to ensure callback fires
              // ignore: avoid_print
              print('GESTURE DETECTED -> onScaleUpdate pointers=$pc dx=${dx.toStringAsFixed(2)} dy=${dy.toStringAsFixed(2)}');
              if (pc == 1) {
                // Determine whether to start a drag (left-down) based on movement threshold
                const double dragStartPx = 4.0; // minimum pixel movement to consider as drag
                if (!_isDragging && !_longPressActive && (dx.abs() > dragStartPx || dy.abs() > dragStartPx)) {
                  // Begin dragging: send left down at current focal point
                  final normStart = _mapGlobalToNormalized(details.focalPoint);
                  if (normStart != null) {
                    _sendLeftDownAt(normStart.dx, normStart.dy);
                  } else {
                    _sendLeftDown();
                  }
                  _isDragging = true;
                  // ignore: avoid_print
                  print('GESTURE -> drag started');
                }

                final norm = _mapGlobalToNormalized(details.focalPoint);
                if (norm != null) {
                  if (_isDragging) {
                    _queueNormalizedMove(norm.dx, norm.dy);
                  } else {
                    // not yet dragging (finger slight move) - do not send moves to avoid accidental moves
                  }
                }
              } else if (pc == 2) {
                _queueScroll(dx, dy);
              }
            },
            onScaleEnd: (details) {
              // ensure pending deltas are flushed when gesture ends
              // ignore: avoid_print
              print('GESTURE DETECTED -> onScaleEnd');
              // If we were dragging, end the left click
              if (_isDragging) {
                if (_lastSentX != null && _lastSentY != null) {
                  _sendLeftUpAt(_lastSentX!, _lastSentY!);
                } else {
                  _sendLeftUp();
                }
                _isDragging = false;
                // ignore: avoid_print
                print('GESTURE -> drag ended');
              }
              _flushNormalizedMove();
              _flushScroll();
            },
             child: Container(
               color: Colors.transparent,
             ),

           ),
        ),
        // Hidden TextField to capture text input. Tapping the overlay should
        // request focus externally; we keep it at the top-right so it doesn't
        // interfere visually. It is invisible.
        Positioned(
          right: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: false,
              enableInteractiveSelection: false,
              showCursor: false,
              decoration: const InputDecoration(border: InputBorder.none),
              keyboardType: TextInputType.text,
              onChanged: _onTextChanged,
            ),
          ),
        ),
      ],
    );
  }
}
