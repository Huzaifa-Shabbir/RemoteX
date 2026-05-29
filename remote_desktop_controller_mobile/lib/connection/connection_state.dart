import 'package:flutter/foundation.dart';

class ConnectionInfo {
  final bool connected;
  final String ip;
  final int wsPort;
  final int udpPort;

  ConnectionInfo({
    required this.connected,
    required this.ip,
    required this.wsPort,
    required this.udpPort,
  });
}

/// Global connection state notifier. value == null => not connected.
class ConnectionStateNotifier extends ValueNotifier<ConnectionInfo?> {
  ConnectionStateNotifier._() : super(null);

  static final ConnectionStateNotifier instance = ConnectionStateNotifier._();

  void setConnected(String ip, int wsPort, int udpPort) {
    value = ConnectionInfo(connected: true, ip: ip, wsPort: wsPort, udpPort: udpPort);
  }

  void clear() {
    value = null;
  }

  bool get isConnected => value != null && value!.connected;
}

