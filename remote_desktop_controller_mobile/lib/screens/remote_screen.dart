import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class RemoteLightScreen extends StatefulWidget {
  const RemoteLightScreen({super.key});

  @override
  State<RemoteLightScreen> createState() => _RemoteLightScreenState();
}

class _RemoteLightScreenState extends State<RemoteLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _RemoteScaffold(isDark: false);
  }
}

class RemoteDarkScreen extends StatefulWidget {
  const RemoteDarkScreen({super.key});

  @override
  State<RemoteDarkScreen> createState() => _RemoteDarkScreenState();
}

class _RemoteDarkScreenState extends State<RemoteDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _RemoteScaffold(isDark: true);
  }
}

class _RemoteScaffold extends StatelessWidget {
  const _RemoteScaffold({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeControllerScope.of(context);
    final cs = theme.colorScheme;

    final bgColor = isDark ? const Color(0xFF0E1117) : const Color(0xFFF5F6F8);
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF1E242E) : const Color(0xFFF1F3F6);
    final titleColor = isDark ? const Color(0xFF7DA2FF) : const Color(0xFF1F4FC9);
    final secondaryTextColor =
        isDark ? Colors.white.withOpacity(0.70) : Colors.grey.shade600;
    final iconBg = isDark ? const Color(0xFF252B36) : Colors.grey.shade200;
    final cardShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _StatusChip(isDark: isDark),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          final nextRoute =
                              controller.isDark ? '/remote/light' : '/remote/dark';
                          controller.toggle();
                          Navigator.of(context).pushReplacementNamed(nextRoute);
                        },
                        child: Ink(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconBg,
                          ),
                          child: Icon(
                            controller.isDark
                                ? Icons.wb_sunny_outlined
                                : Icons.nightlight_round,
                            size: 18,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RemoteX',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PreviewCard(isDark: isDark),
                  const SizedBox(height: 16),
                  _CardContainer(
                    color: cardColor,
                    shadows: cardShadow,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Controls',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ControlButton(
                                icon: Icons.refresh,
                                label: 'Refresh',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _ControlButton(
                                icon: Icons.open_in_full,
                                label: 'Full',
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: _ControlButton(
                                icon: Icons.mouse,
                                label: 'Control',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardContainer(
                    color: cardColor,
                    shadows: cardShadow,
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Quality',
                          value: 'HD',
                          valueColor: isDark ? Colors.white : Colors.black87,
                          labelColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Latency',
                          value: '25ms',
                          valueColor: const Color(0xFF22C55E),
                          labelColor: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CardContainer(
                    color: cardColor,
                    shadows: cardShadow,
                    child: Row(
                      children: [
                        Text(
                          'Desktop View',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 26 / 1.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.open_in_full,
                          size: 18,
                          color: secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF1010),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: isDark ? 0 : null,
                    ),
                    onPressed: () {
                      final backRoute =
                          controller.isDark ? '/home/dark' : '/home/light';
                      Navigator.of(context).pushReplacementNamed(backRoute);
                    },
                    child: const Text('Disconnect from PC'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      final backRoute =
                          controller.isDark ? '/home/dark' : '/home/light';
                      Navigator.of(context).pushReplacementNamed(backRoute);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Home'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12361E) : const Color(0xFFDDF7E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Color(0xFF22C55E), size: 10),
          const SizedBox(width: 6),
          Text(
            'Connected',
            style: TextStyle(
              color: isDark ? const Color(0xFF7BE5A4) : const Color(0xFF16A34A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2140A4), Color(0xFF152A72)]
              : const [Color(0xFF3B82F6), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.desktop_windows,
              color: Colors.white.withOpacity(0.95),
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              'Your Desktop Screen',
              style: TextStyle(color: Colors.white.withOpacity(0.82)),
            ),
            const SizedBox(height: 2),
            Text(
              'Live Preview',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242B36) : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: labelColor)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CardContainer extends StatelessWidget {
  const _CardContainer({
    required this.child,
    required this.color,
    required this.shadows,
  });

  final Widget child;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
