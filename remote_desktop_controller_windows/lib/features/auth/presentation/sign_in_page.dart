import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/rx_colors.dart';
import '../../../core/theme/theme_toggle_button.dart';
import '../controller/supabase_service.dart';
import 'sign_up_page.dart';
import '../../../dashboard_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool   _obscurePassword = true;
  bool   _rememberMe      = false;
  bool   _isLoading       = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await SupabaseService.signIn(email: email, password: password);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            userName:  SupabaseService.displayName,
            userEmail: SupabaseService.displayEmail,
          ),
        ),
        (_) => false,
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BuildingBgPainter(isDark: c.isDark)),
          ),
          Positioned.fill(
            child: Container(
              color: (c.isDark ? const Color(0xFF0D1B2E) : const Color(0xFFB8C8DC))
                  .withOpacity(c.bgOverlayOpacity),
            ),
          ),
          const Positioned(top: 20, right: 24, child: ThemeToggleButton()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: _SignInCard(
                emailCtrl:        _emailCtrl,
                passwordCtrl:     _passwordCtrl,
                obscurePassword:  _obscurePassword,
                rememberMe:       _rememberMe,
                isLoading:        _isLoading,
                errorMessage:     _errorMessage,
                onTogglePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onToggleRemember: (v) =>
                    setState(() => _rememberMe = v ?? false),
                onSignIn:         _handleSignIn,
              ),
            ),
          ),
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: Center(
              child: Text('Remote X © 2026',
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-In Card ───────────────────────────────────────────────
class _SignInCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool rememberMe;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSignIn;

  const _SignInCard({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isLoading,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onToggleRemember,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final c = RXColors.of(context);
    return Container(
      width: 390,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: c.cardShadow, blurRadius: 60, offset: const Offset(0, 24)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: c.isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6366F1), Color(0xFF06B6D4)])
                  : null,
              color: c.isDark ? null : const Color(0xFF3B82F6),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 18),

          // Logo
          _RXLogo(textColor: c.blue),
          const SizedBox(height: 6),
          Text('Sign in to your account',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),

          // Email (username field visually, but uses email)
          _FieldLabel(label: 'Email', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: emailCtrl,
            hint: 'Enter your email',
            prefixIcon: Icons.person_outline,
            colors: c,
          ),
          const SizedBox(height: 18),

          // Password
          _FieldLabel(label: 'Password', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: passwordCtrl,
            hint: 'Enter your password',
            prefixIcon: Icons.lock_outline,
            obscureText: obscurePassword,
            colors: c,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: c.textMuted, size: 20,
              ),
              onPressed: onTogglePassword,
            ),
          ),
          const SizedBox(height: 16),

          // Remember me + Forgot password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                SizedBox(
                  width: 20, height: 20,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: onToggleRemember,
                    activeColor: c.blue,
                    side: BorderSide(color: c.checkboxBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Remember me',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
              GestureDetector(
                onTap: () {},
                child: Text('Forgot password?',
                    style: TextStyle(
                        color: c.link, fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),

          // Error message
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Text(errorMessage!,
                  style: const TextStyle(
                      color: Color(0xFFEF4444), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 24),

          // Sign in button
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account?  ",
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                ),
                child: Text('Create one',
                    style: TextStyle(
                        color: c.link, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────
class _RXLogo extends StatelessWidget {
  final Color textColor;
  const _RXLogo({required this.textColor});
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: 'Remote',
          style: TextStyle(
              color: textColor, fontSize: 26,
              fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        TextSpan(
          text: 'X',
          style: TextStyle(
              color: textColor, fontSize: 26,
              fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _FieldLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final RXColors colors;

  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.colors,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: c.textMuted, size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: c.fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.blue, width: 1.5),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D3F57)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 24, height: 24,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
                color: Color(0xFF334155), shape: BoxShape.circle),
            child: const Icon(Icons.dark_mode,
                color: Color(0xFF94A3B8), size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Building Background Painter ────────────────────────────────
class _BuildingBgPainter extends CustomPainter {
  final bool isDark;
  const _BuildingBgPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF0A1628), Color(0xFF0D2040)]
            : const [Color(0xFFB8C8DC), Color(0xFFA0B8D0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const cols = 20;
    const rows = 15;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final rng = _SimpleRng(77);

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val = rng.next();
        final Color color;
        if (isDark) {
          color = val > 0.65
              ? const Color(0xFF2A4A7F).withOpacity(0.45)
              : val > 0.35
                  ? const Color(0xFF1A3050).withOpacity(0.55)
                  : const Color(0xFF0F2040).withOpacity(0.7);
        } else {
          color = val > 0.65
              ? const Color(0xFFD0DFF0).withOpacity(0.8)
              : val > 0.35
                  ? const Color(0xFFBACCE0).withOpacity(0.7)
                  : const Color(0xFFA8BDD4).withOpacity(0.6);
        }
        final rect = Rect.fromLTWH(c * cellW + 3, r * cellH + 3, cellW - 6, cellH - 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BuildingBgPainter old) => old.isDark != isDark;
}

class _SimpleRng {
  int _seed;
  _SimpleRng(this._seed);
  double next() {
    _seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_seed & 0xFFFF) / 0xFFFF;
  }
}