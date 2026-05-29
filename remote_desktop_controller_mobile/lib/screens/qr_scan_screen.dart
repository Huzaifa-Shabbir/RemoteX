import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../receiver/receiver_screen.dart';
import 'package:flutter_app/webrtc/logger.dart';

/// Simple QR scanner that expects JSON payload with keys: ip, ws_port, udp_port
/// Example: {"ip":"192.168.1.10","ws_port":8080,"udp_port":5000}
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController();

  void _handleDetect(BarcodeCapture capture) async {
    if (_scanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    Logger.log('QR', 'Scanned: $code');

    try {
      String ip;
      int wsPort;
      int udpPort;

      // ✅ Try JSON first
      try {
        final data = jsonDecode(code);

        if (data is Map &&
            data.containsKey('ip') &&
            data.containsKey('ws_port') &&
            data.containsKey('udp_port')) {

          ip = data['ip'].toString();
          wsPort = int.parse(data['ws_port'].toString());
          udpPort = int.parse(data['udp_port'].toString());

        } else {
          throw FormatException("Missing keys");
        }
      } catch (_) {
        // ✅ Fallback: ip:udp:ws format
        final parts = code.split(":");

        if (parts.length != 3) {
          throw FormatException("Invalid QR format");
        }

        ip = parts[0];
        udpPort = int.parse(parts[1]);
        wsPort = int.parse(parts[2]);
      }

      Logger.log('QR', 'Parsed -> ip=$ip ws=$wsPort udp=$udpPort');

      if (wsPort <= 0 || udpPort <= 0) {
        throw FormatException('Invalid ports');
      }

      _scanned = true;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiverScreen(
            ip: ip,
            wsPort: wsPort,
            udpPort: udpPort,
          ),
        ),
      );

    } catch (e) {
      Logger.error('QR', 'Invalid QR payload: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code')),
      );
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on),
                    color: Colors.white,
                    onPressed: () => _controller.toggleTorch(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch),
                    color: Colors.white,
                    onPressed: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
