import 'package:flutter/material.dart';
import 'qr_scan_screen.dart';
import '../theme/connection_flow_theme.dart';
import '../theme/theme_controller.dart';
import '../connection/connection_state.dart';
import '../receiver/receiver_screen.dart';

class ConnectionLightScreen extends StatefulWidget {
  const ConnectionLightScreen({super.key});

  @override
  State<ConnectionLightScreen> createState() => _ConnectionLightScreenState();
}

class _ConnectionLightScreenState extends State<ConnectionLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _ConnectionScaffold(isDark: false);
  }
}

class ConnectionDarkScreen extends StatefulWidget {
  const ConnectionDarkScreen({super.key});

  @override
  State<ConnectionDarkScreen> createState() => _ConnectionDarkScreenState();
}

class _ConnectionDarkScreenState extends State<ConnectionDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _ConnectionScaffold(isDark: true);
  }
}

class QrLightScreen extends StatefulWidget {
  const QrLightScreen({super.key});

  @override
  State<QrLightScreen> createState() => _QrLightScreenState();
}

class _QrLightScreenState extends State<QrLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _QrScaffold(isDark: false);
  }
}

class QrDarkScreen extends StatefulWidget {
  const QrDarkScreen({super.key});

  @override
  State<QrDarkScreen> createState() => _QrDarkScreenState();
}

class _QrDarkScreenState extends State<QrDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _QrScaffold(isDark: true);
  }
}

class ConnectedLightScreen extends StatefulWidget {
  const ConnectedLightScreen({super.key});

  @override
  State<ConnectedLightScreen> createState() => _ConnectedLightScreenState();
}

class _ConnectedLightScreenState extends State<ConnectedLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _ConnectedScaffold(isDark: false);
  }
}

class ConnectedDarkScreen extends StatefulWidget {
  const ConnectedDarkScreen({super.key});

  @override
  State<ConnectedDarkScreen> createState() => _ConnectedDarkScreenState();
}

class _ConnectedDarkScreenState extends State<ConnectedDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _ConnectedScaffold(isDark: true);
  }
}

class _ConnectionScaffold extends StatelessWidget {
  const _ConnectionScaffold({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = connectionFlowColors(isDark);
    final controller = ThemeControllerScope.of(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    isDark: isDark,
                    onBack: () {
                      final homeRoute =
                          controller.isDark ? '/home/dark' : '/home/light';
                      Navigator.of(context).pushReplacementNamed(homeRoute);
                    },
                  ),
                  const SizedBox(height: 18),
                  _ConnectionCard(colors: colors, isDark: isDark),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<ConnectionInfo?>(
                    valueListenable: ConnectionStateNotifier.instance,
                    builder: (context, conn, _) {
                      final connected = conn != null && conn.connected;
                      return ElevatedButton(
                        style: _buttonStyle(colors.primary),
                        onPressed: () {
                          if (connected) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiverScreen(
                              ip: conn.ip,
                              wsPort: conn.wsPort,
                              udpPort: conn.udpPort,
                              fullscreenLandscape: true,
                            )));
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen()));
                        },
                        child: Text(connected ? 'View Screen' : 'Connect to PC'),
                      );
                    },
                  ),
                ],
              ),

            ),
          ),
        ),
      ),
    );
  }
}

class _QrScaffold extends StatelessWidget {
  const _QrScaffold({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = connectionFlowColors(isDark);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    isDark: isDark,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(colors.cardBackground, colors.shadow),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Scan QR Code',
                          style: TextStyle(
                            fontSize: 24 / 1.2,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 210,
                          decoration: BoxDecoration(
                            color: colors.surfaceBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_2_rounded, size: 120),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Open RemoteX on your PC and scan this QR code to establish connection',
                          style: TextStyle(color: colors.mutedText),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: _buttonStyle(colors.primary),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const QrScanScreen()));
                          },
                          child: const Text('Scan Complete'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedScaffold extends StatelessWidget {
  const _ConnectedScaffold({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = connectionFlowColors(isDark);
    final controller = ThemeControllerScope.of(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    isDark: isDark,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  _ConnectedCard(colors: colors, isDark: isDark),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: _buttonStyle(colors.primary),
                    onPressed: () {
                      // If a websocket connection exists, open the fullscreen ReceiverScreen in landscape
                      final conn = ConnectionStateNotifier.instance.value;
                      if (conn != null && conn.connected) {
                        final c = conn; // local non-null alias
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReceiverScreen(
                          ip: c.ip,
                          wsPort: c.wsPort,
                          udpPort: c.udpPort,
                          fullscreenLandscape: true,
                        )));
                        return;
                      }

                      // Fallback: open the existing Remote screen route
                      final route = controller.isDark ? '/remote/dark' : '/remote/light';
                      Navigator.of(context).pushReplacementNamed(route);
                    },
                    child: const Text('View PC Screen'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      // Explicitly disconnect
                      ConnectionStateNotifier.instance.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.onBack,
  });

  final bool isDark;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = connectionFlowColors(isDark);
    final controller = ThemeControllerScope.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            final nextRoute = _themeVariantRoute(
              currentRoute: ModalRoute.of(context)?.settings.name ?? '',
              toDark: !controller.isDark,
            );
            controller.toggle();
            Navigator.of(context).pushReplacementNamed(nextRoute);
          },
          child: Ink(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.iconCircle,
            ),
            child: Icon(
              controller.isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.colors,
    required this.isDark,
  });

  final ConnectionFlowColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(colors.cardBackground, colors.shadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RemoteX',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 38 / 1.3,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PC Screen Connection',
            style: TextStyle(
              fontSize: 28 / 1.4,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect to your PC screen to view\nand control your desktop remotely',
            style: TextStyle(color: colors.mutedText, height: 1.35),
          ),
          const SizedBox(height: 18),
          // Dynamic connection card: reflects global connection state
          ValueListenableBuilder<ConnectionInfo?>(
            valueListenable: ConnectionStateNotifier.instance,
            builder: (context, conn, _) {
              final connected = conn != null && conn.connected;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: connected ? colors.successBackground : colors.surfaceBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      connected ? Icons.desktop_windows : Icons.desktop_windows_outlined,
                      size: 40,
                      color: connected ? colors.successForeground : colors.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      connected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      connected
                          ? 'Connected to ${conn.ip}:${conn.wsPort}'
                          : 'Scan QR code on your PC to connect',
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFD5DAE1),
              ),
            ),
            child: Column(
              children: [
                // show live connection info
                ValueListenableBuilder<ConnectionInfo?>(
                  valueListenable: ConnectionStateNotifier.instance,
                  builder: (context, conn, _) {
                    final status = conn == null ? 'Disconnected' : 'Connected';
                    final device = conn == null ? '-' : 'Desktop PC';
                    final ctype = conn == null ? '-' : 'Secure';
                    return Column(
                      children: [
                        _ConnectionInfoRow(label: 'Status', value: status, isDark: isDark, green: conn != null),
                        _ConnectionInfoRow(label: 'Device', value: device, isDark: isDark),
                        _ConnectionInfoRow(label: 'Connection Type', value: ctype, isDark: isDark),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({
    required this.colors,
    required this.isDark,
  });

  final ConnectionFlowColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(colors.cardBackground, colors.shadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RemoteX',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 38 / 1.3,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'PC Screen Connection',
            style: TextStyle(
              fontSize: 28 / 1.4,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.successBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: colors.successForeground, size: 50),
                const SizedBox(height: 10),
                Text(
                  'Connected!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Successfully connected to your PC',
                  style: TextStyle(color: colors.successText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFD5DAE1),
              ),
            ),
            child: Column(
              children: [
                _ConnectionInfoRow(
                  label: 'Status',
                  value: 'Active',
                  isDark: isDark,
                  green: true,
                ),
                _ConnectionInfoRow(
                  label: 'Device',
                  value: 'Desktop PC',
                  isDark: isDark,
                ),
                _ConnectionInfoRow(
                  label: 'Connection Type',
                  value: 'Secure',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionInfoRow extends StatelessWidget {
  const _ConnectionInfoRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.green = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: green
                  ? const Color(0xFF22C55E)
                  : (isDark ? Colors.white : Colors.black87),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(Color color, List<BoxShadow> shadow) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(16),
    boxShadow: shadow,
  );
}

ButtonStyle _buttonStyle(Color primary) {
  return ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

String _themeVariantRoute({
  required String currentRoute,
  required bool toDark,
}) {
  if (currentRoute.contains('/connect/')) {
    return toDark ? '/connect/dark' : '/connect/light';
  }
  if (currentRoute.contains('/qr/')) {
    return toDark ? '/qr/dark' : '/qr/light';
  }
  if (currentRoute.contains('/connected/')) {
    return toDark ? '/connected/dark' : '/connected/light';
  }
  return toDark ? '/connect/dark' : '/connect/light';
}
