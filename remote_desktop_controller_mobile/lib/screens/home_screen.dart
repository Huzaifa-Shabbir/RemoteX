import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme_controller.dart';

class HomeLightScreen extends StatefulWidget {
  const HomeLightScreen({super.key});

  @override
  State<HomeLightScreen> createState() => _HomeLightScreenState();
}

class _HomeLightScreenState extends State<HomeLightScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return const _HomeScaffold(isDarkPreview: false);
  }
}

class HomeDarkScreen extends StatefulWidget {
  const HomeDarkScreen({super.key});

  @override
  State<HomeDarkScreen> createState() => _HomeDarkScreenState();
}

class _HomeDarkScreenState extends State<HomeDarkScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ThemeControllerScope.of(context).setMode(ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return const _HomeScaffold(isDarkPreview: true);
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.isDarkPreview});

  final bool isDarkPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ThemeControllerScope.of(context);

    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    final pageBg = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : const Color(0xFFF6F8FC);
    final panelBg = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : Colors.white;
    final mutedText = onSurface.withOpacity(theme.brightness == Brightness.dark
        ? 0.72
        : 0.62);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: mutedText,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          try {
                            await Supabase.instance.client.auth.signOut();
                          } catch (_) {
                            // Ignore sign out failures and still navigate.
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/',
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          final nextRoute =
                              controller.isDark ? '/home/light' : '/home/dark';
                          controller.toggle();
                          Navigator.of(context).pushReplacementNamed(nextRoute);
                        },
                        child: Ink(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.35)
                                : const Color(0xFFF0F2F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            controller.isDark
                                ? Icons.wb_sunny_outlined
                                : Icons.nights_stay_outlined,
                            color: mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'RemoteX',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: theme.brightness == Brightness.dark
                          ? const []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome Back!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Choose what you'd like to do",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedText,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _ActionCard(
                          title: 'View PC Screen',
                          subtitle:
                              'Connect and control your\ndesktop remotely',
                          icon: Icons.desktop_windows_outlined,
                          isPrimary: true,
                          onTap: () {
                            final targetRoute = controller.isDark
                                ? '/connect/dark'
                                : '/connect/light';
                            Navigator.of(context).pushNamed(targetRoute);
                          },
                        ),
                        const SizedBox(height: 14),
                        _ActionCard(
                          title: 'Shared Folder',
                          subtitle: 'View and manage shared files',
                          icon: Icons.folder_shared_outlined,
                          isPrimary: false,
                          onTap: () {
                            final targetRoute = controller.isDark
                                ? '/shared/dark'
                                : '/shared/light';
                            Navigator.of(context).pushNamed(targetRoute);
                          },
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'QUICK STATS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: mutedText.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.35)
                                : const Color(0xFFF2F4F8),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                child: _StatTile(
                                  value: '0',
                                  label: 'Active Sessions',
                                  highlight: false,
                                ),
                              ),
                              Expanded(
                                child: _StatTile(
                                  value: '0',
                                  label: 'Files Uploaded',
                                  highlight: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _TipBanner(
                          text:
                              'Tip: Make sure RemoteX is installed on your PC to enable features.',
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;
    final fg = isPrimary ? Colors.white : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary && !isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E47B8),
                      Color(0xFF3C7BE9),
                    ],
                  )
                : null,
            color: isPrimary
                ? (isDark ? cs.primary.withOpacity(0.35) : null)
                : (isDark
                    ? cs.surfaceContainerHighest.withOpacity(0.35)
                    : Colors.white),
            borderRadius: BorderRadius.circular(22),
            boxShadow: isDark
                ? const []
                : [
                    BoxShadow(
                      color: isPrimary
                          ? const Color(0xFF1E47B8).withOpacity(0.25)
                          : Colors.black.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? (isDark
                            ? cs.onPrimary.withOpacity(0.10)
                            : Colors.white.withOpacity(0.18))
                        : (isDark
                            ? cs.surface.withOpacity(0.10)
                            : const Color(0xFFF2F4F8)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : cs.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.25,
                          color: isPrimary
                              ? Colors.white.withOpacity(0.85)
                              : cs.onSurface.withOpacity(isDark ? 0.72 : 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.highlight,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(isDark ? 0.72 : 0.62),
          ),
        ),
      ],
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.primary.withOpacity(0.12) : const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? cs.primary.withOpacity(0.28) : const Color(0xFFBBD6FF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.info_outline, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.25,
                color: theme.textTheme.bodySmall?.color?.withOpacity(isDark ? 0.80 : 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
