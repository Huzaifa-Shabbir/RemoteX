import 'package:flutter/material.dart';
import 'core/theme/rx_colors.dart';
import 'core/theme/theme_toggle_button.dart';
import 'features/auth/presentation/sign_in_page.dart';
import 'features/auth/presentation/sign_up_page.dart';

// ── Navigation helpers ─────────────────────────────────────────
void _goToSignIn(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const SignInPage()));

void _goToSignUp(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const SignUpPage()));

// ── Home Page ──────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          const _NavBar(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: const Column(
                children: [
                  _HeroSection(),
                  _FeaturesSection(),
                  _WhyChooseSection(),
                  _HowItWorksSection(),
                  _CTASection(),
                  _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation Bar ─────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      height: 56,
      color: c.bg.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const _Logo(),
          const Spacer(),
          // ── Theme toggle in navbar ───────────────────────
          const ThemeToggleButton(),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => _goToSignIn(context),
            child: Text('Sign In',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _goToSignUp(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Get Started',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.desktop_windows,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Text('RemoteX',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
      ],
    );
  }
}

// ── Hero Section ───────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final w = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 480),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.isDark
              ? const [Color(0xFF0F1F3D), Color(0xFF0F172A)]
              : const [Color(0xFFF0F4FF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: c.isDark ? 0.08 : 0.04,
              child: CustomPaint(painter: _GridPainter(isDark: c.isDark)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 80, vertical: 60),
            child: w > 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Expanded(flex: 5, child: _HeroLeft()),
                      SizedBox(width: 48),
                      Expanded(flex: 4, child: _HeroRight()),
                    ],
                  )
                : const Column(children: [
                    _HeroLeft(),
                    SizedBox(height: 40),
                    _HeroRight(),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _HeroLeft extends StatelessWidget {
  const _HeroLeft();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge pill
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: c.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: c.blue, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Remote PC Controller',
                  style: TextStyle(
                      color: c.blueLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Control Your PC',
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1)),
        Text('From Anywhere',
            style: TextStyle(
                color: c.blue,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1)),
        const SizedBox(height: 20),
        Text(
          'RemoteX is a powerful PC controller that lets you access,\n'
          'control, and manage your computer from your mobile\n'
          'device. Stream your screen, transfer files, and control your\n'
          'PC remotely with ease.',
          style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              height: 1.6),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _goToSignUp(context),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Get Started'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _goToSignIn(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border, width: 1.5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            _StatItem(value: '100%', label: 'Secure', c: c),
            const SizedBox(width: 32),
            _StatItem(value: '24ms', label: 'Low Latency', c: c),
            const SizedBox(width: 32),
            _StatItem(value: '24/7', label: 'Available', c: c),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final RXColors c;
  const _StatItem(
      {required this.value, required this.label, required this.c});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(
                color: c.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _HeroRight extends StatelessWidget {
  const _HeroRight();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.4 : 0.08),
              blurRadius: 40,
              offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(children: [
                Text('Latency',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w500)),
                Text('24ms',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DeviceCard(
                  icon: Icons.desktop_windows,
                  label: 'Your PC',
                  color: c.blue),
              const SizedBox(width: 16),
              Column(children: [
                Icon(Icons.arrow_forward, color: c.blue, size: 18),
                const SizedBox(height: 6),
                Container(width: 1, height: 16, color: c.border),
                const SizedBox(height: 6),
                Icon(Icons.arrow_back, color: c.blue, size: 18),
              ]),
              const SizedBox(width: 16),
              _DeviceCard(
                  icon: Icons.smartphone,
                  label: 'Your Mobile',
                  color: c.blueDark),
            ],
          ),
          const SizedBox(height: 20),
          _StatusRow(
              icon: Icons.circle,
              iconColor: const Color(0xFF22C55E),
              label: 'Connection Status',
              status: 'Connected',
              statusColor: const Color(0xFF22C55E),
              c: c),
          const SizedBox(height: 8),
          _StatusRow(
              icon: Icons.monitor,
              iconColor: c.textSecondary,
              label: 'Screen Streaming',
              status: 'Ready',
              statusColor: c.textPrimary,
              c: c),
          const SizedBox(height: 8),
          _StatusRow(
              icon: Icons.gamepad,
              iconColor: c.textSecondary,
              label: 'Remote Control',
              status: 'Available',
              statusColor: c.textPrimary,
              c: c),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DeviceCard(
      {required this.icon,
      required this.label,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14)),
        child:
            const Icon(Icons.desktop_windows, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: TextStyle(
              color: c.textSecondary, fontSize: 12)),
    ]);
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor, statusColor;
  final String label, status;
  final RXColors c;
  const _StatusRow(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.status,
      required this.statusColor,
      required this.c});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: c.textSecondary, fontSize: 13)),
        ),
        Text(status,
            style: TextStyle(
                color: statusColor,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Features Section ───────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final features = [
      _FeatureData(
          icon: Icons.tv,
          iconBg: c.blue,
          title: 'Screen Streaming',
          desc: 'Stream your PC screen to your mobile device in '
              'real-time with low latency and high quality.'),
      _FeatureData(
          icon: Icons.gamepad_outlined,
          iconBg: c.isDark ? c.purple : const Color(0xFF10B981),
          title: 'Remote Control',
          desc: 'Control your PC mouse and keyboard directly from '
              'your mobile device, anywhere you are.'),
      _FeatureData(
          icon: Icons.folder_open,
          iconBg: c.isDark ? c.cyan : const Color(0xFFF59E0B),
          title: 'File Sharing',
          desc: 'Seamlessly share files between your PC and mobile '
              'through a synchronized shared folder.'),
    ];
    return Container(
      color: c.isDark ? const Color(0xFF111827) : c.surfaceLight,
      padding:
          const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      child: Column(
        children: [
          _SectionHeader(
              title: 'Powerful Features',
              subtitle:
                  'Everything you need to control your PC remotely, '
                  'all in one powerful application.'),
          const SizedBox(height: 48),
          LayoutBuilder(builder: (ctx, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features
                    .map((f) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: _FeatureCard(data: f),
                        )))
                    .toList(),
              );
            }
            return Column(
                children: features
                    .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _FeatureCard(data: f)))
                    .toList());
          }),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color iconBg;
  final String title, desc;
  const _FeatureData(
      {required this.icon,
      required this.iconBg,
      required this.title,
      required this.desc});
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;
  const _FeatureCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: data.iconBg,
                borderRadius: BorderRadius.circular(10)),
            child:
                Icon(data.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(data.title,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(data.desc,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.6)),
        ],
      ),
    );
  }
}

// ── Why Choose Section ─────────────────────────────────────────
class _WhyChooseSection extends StatelessWidget {
  const _WhyChooseSection();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    const items = [
      _WhyData(
          icon: Icons.shield_outlined,
          title: 'Secure Connection',
          desc: 'End-to-end encrypted connections keep your data '
              'safe and private.'),
      _WhyData(
          icon: Icons.bolt,
          title: 'Lightning Fast',
          desc: 'Ultra-low latency ensures smooth remote control '
              'experience.'),
      _WhyData(
          icon: Icons.wifi,
          title: 'Always Connected',
          desc: 'Reliable connection that works across different networks.'),
    ];
    return Container(
      color: c.bg,
      padding:
          const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      child: Column(
        children: [
          _SectionHeader(
              title: 'Why Choose RemoteX?',
              subtitle:
                  'Built with performance, security, and ease of use in mind.'),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (ctx, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map((d) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: _WhyCard(data: d),
                        )))
                    .toList(),
              );
            }
            return Column(
                children: items
                    .map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _WhyCard(data: d)))
                    .toList());
          }),
        ],
      ),
    );
  }
}

class _WhyData {
  final IconData icon;
  final String title, desc;
  const _WhyData(
      {required this.icon, required this.title, required this.desc});
}

class _WhyCard extends StatelessWidget {
  final _WhyData data;
  const _WhyCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
        ),
        child: Icon(data.icon, color: c.blue, size: 28),
      ),
      const SizedBox(height: 16),
      Text(data.title,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(data.desc,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.textSecondary, fontSize: 13, height: 1.6)),
    ]);
  }
}

// ── How It Works Section ───────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    final steps = [
      _StepData(
          number: '1',
          color: c.blue,
          title: 'Install & Sign Up',
          desc: 'Download RemoteX on your PC and mobile device, '
              'then create your account.'),
      _StepData(
          number: '2',
          color: c.isDark ? c.purple : const Color(0xFF10B981),
          title: 'Pair Devices',
          desc: 'Connect your mobile device to your PC with our '
              'secure pairing system.'),
      _StepData(
          number: '3',
          color: c.isDark ? c.cyan : const Color(0xFFF59E0B),
          title: 'Start Controlling',
          desc: 'Access your PC from anywhere with full control '
              'and file sharing capabilities.'),
    ];
    return Container(
      color: c.isDark ? const Color(0xFF111827) : c.surfaceLight,
      padding:
          const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      child: Column(
        children: [
          _SectionHeader(
              title: 'How Does It Work?',
              subtitle: 'Get started in three simple steps'),
          const SizedBox(height: 48),
          LayoutBuilder(builder: (ctx, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                children: steps.asMap().entries.map((e) {
                  final isLast = e.key == steps.length - 1;
                  return Expanded(
                    child: Row(children: [
                      Expanded(child: _StepCard(data: e.value)),
                      if (!isLast) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right,
                            color: c.textMuted, size: 24),
                        const SizedBox(width: 8),
                      ]
                    ]),
                  );
                }).toList(),
              );
            }
            return Column(
                children: steps
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _StepCard(data: s)))
                    .toList());
          }),
        ],
      ),
    );
  }
}

class _StepData {
  final String number, title, desc;
  final Color color;
  const _StepData(
      {required this.number,
      required this.color,
      required this.title,
      required this.desc});
}

class _StepCard extends StatelessWidget {
  final _StepData data;
  const _StepCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: data.color, shape: BoxShape.circle),
            child: Center(
                child: Text(data.number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800))),
          ),
          const SizedBox(height: 14),
          Text(data.title,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(data.desc,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.6)),
        ],
      ),
    );
  }
}

// ── CTA Section ────────────────────────────────────────────────
class _CTASection extends StatelessWidget {
  const _CTASection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
      ),
      child: Column(children: [
        const Text('Ready to Get Started?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        const SizedBox(height: 12),
        const Text(
            'Join thousands of users who trust RemoteX for their remote PC control needs.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.5)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _goToSignUp(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3B82F6),
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create Free Account'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      color: c.isDark
          ? const Color(0xFF0A1120)
          : const Color(0xFFF1F5F9),
      padding:
          const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          final versionText = Text(
            'Version 1.0.0 • © 2026 RemoteX • All rights reserved',
            style: TextStyle(
                color: c.textMuted.withOpacity(0.7), fontSize: 12),
            textAlign: TextAlign.center,
          );

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Logo(),
                const SizedBox(height: 12),
                versionText,
              ],
            );
          }

          return Row(
            children: [
              const _Logo(),
              const Spacer(),
              versionText,
            ],
          );
        },
      ),
    );
  }
}

// ── Shared Section Header ──────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader(
      {required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Column(children: [
      Text(title,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5)),
      const SizedBox(height: 10),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: c.textSecondary, fontSize: 14, height: 1.5)),
    ]);
  }
}

// ── Grid Background Painter ────────────────────────────────────
class _GridPainter extends CustomPainter {
  final bool isDark;
  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? const Color(0xFF3B82F6)
          : const Color(0xFF3B82F6)
      ..strokeWidth = 0.5;
    const gap = 40.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.isDark != isDark;
}