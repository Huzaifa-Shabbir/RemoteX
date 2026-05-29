import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/rx_colors.dart';
import '../../../core/theme/theme_toggle_button.dart';
import '../controller/supabase_service.dart';
import 'sign_in_page.dart';
import '../../../dashboard_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _usernameCtrl    = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool   _obscurePass        = true;
  bool   _obscureConfirmPass = true;
  bool   _agreedToTerms      = false;
  bool   _isLoading          = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final fullName = _fullNameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmPassCtrl.text;

    if (fullName.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to the Terms of Service.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await SupabaseService.signUp(
        email:    email,
        password: password,
        fullName: fullName,
        username: username,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            userName:  fullName.isNotEmpty ? fullName : username,
            userEmail: email,
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
              child: _SignUpCard(
                fullNameCtrl:       _fullNameCtrl,
                emailCtrl:          _emailCtrl,
                usernameCtrl:       _usernameCtrl,
                passwordCtrl:       _passwordCtrl,
                confirmPassCtrl:    _confirmPassCtrl,
                obscurePass:        _obscurePass,
                obscureConfirmPass: _obscureConfirmPass,
                agreedToTerms:      _agreedToTerms,
                isLoading:          _isLoading,
                errorMessage:       _errorMessage,
                onTogglePass:       () => setState(() => _obscurePass = !_obscurePass),
                onToggleConfirmPass: () =>
                    setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                onToggleTerms:      (v) => setState(() => _agreedToTerms = v ?? false),
                onSignUp:           _handleSignUp,
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

// ── Sign-Up Card ───────────────────────────────────────────────
class _SignUpCard extends StatelessWidget {
  final TextEditingController fullNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPassCtrl;
  final bool obscurePass;
  final bool obscureConfirmPass;
  final bool agreedToTerms;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirmPass;
  final ValueChanged<bool?> onToggleTerms;
  final VoidCallback onSignUp;

  const _SignUpCard({
    required this.fullNameCtrl,
    required this.emailCtrl,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.confirmPassCtrl,
    required this.obscurePass,
    required this.obscureConfirmPass,
    required this.agreedToTerms,
    required this.isLoading,
    required this.errorMessage,
    required this.onTogglePass,
    required this.onToggleConfirmPass,
    required this.onToggleTerms,
    required this.onSignUp,
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
          _RXLogo(textColor: c.blue),
          const SizedBox(height: 6),
          Text('Create your account',
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),

          _FieldLabel(label: 'Full Name', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: fullNameCtrl,
            hint: 'Enter your full name',
            prefixIcon: Icons.person_outline,
            colors: c,
          ),
          const SizedBox(height: 16),

          _FieldLabel(label: 'Email', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: emailCtrl,
            hint: 'Enter your email',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            colors: c,
          ),
          const SizedBox(height: 16),

          _FieldLabel(label: 'Username', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: usernameCtrl,
            hint: 'Choose a username',
            prefixIcon: Icons.person_outline,
            colors: c,
          ),
          const SizedBox(height: 16),

          _FieldLabel(label: 'Password', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: passwordCtrl,
            hint: 'Create a password',
            prefixIcon: Icons.lock_outline,
            obscureText: obscurePass,
            colors: c,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: c.textMuted, size: 20,
              ),
              onPressed: onTogglePass,
            ),
          ),
          const SizedBox(height: 16),

          _FieldLabel(label: 'Confirm Password', color: c.textPrimary),
          const SizedBox(height: 8),
          _AuthTextField(
            controller: confirmPassCtrl,
            hint: 'Confirm your password',
            prefixIcon: Icons.lock_outline,
            obscureText: obscureConfirmPass,
            colors: c,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: c.textMuted, size: 20,
              ),
              onPressed: onToggleConfirmPass,
            ),
          ),
          const SizedBox(height: 16),

          // Terms checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: agreedToTerms,
                  onChanged: onToggleTerms,
                  activeColor: c.blue,
                  side: BorderSide(color: c.checkboxBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(
                          color: c.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: 'Terms of Service\nand Privacy Policy',
                      style: TextStyle(
                          color: c.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
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
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 22),

          // Create Account button
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account'),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?  ',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                ),
                child: Text('Sign in',
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
  final TextInputType? keyboardType;
  final RXColors colors;

  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.colors,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
    final rng = _SimpleRng(99);

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