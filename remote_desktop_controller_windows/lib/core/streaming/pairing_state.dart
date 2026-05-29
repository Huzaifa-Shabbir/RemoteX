import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_Input.dart';

class PairingState extends ChangeNotifier {
  PairingState() {
    _sub = PairingService.instance.pairingUpdates.listen(_onEvent, onError: (_) {});
  }

  StreamSubscription? _sub;

  bool _isConnected = false;
  String? _clientIp;

  bool get isConnected => _isConnected;
  String? get clientIp => _clientIp;

  void _onEvent(Map<String, dynamic> event) {
    final e = event['event'];
    if (e == 'connected' || e == 'paired') {
      _isConnected = true;
      _clientIp = event['clientIp'] ?? event['remote'];
      notifyListeners();
    } else if (e == 'disconnected') {
      _isConnected = false;
      _clientIp = null;
      notifyListeners();
    } else if (e == 'message') {
      // ignore for now
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

