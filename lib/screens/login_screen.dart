import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../widgets/auth_animated_logo_header.dart';
import 'dashboards_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

const String _rememberMeKey = 'remember_me';
const String _rememberedEmailKey = 'remembered_email';
const Color _authFieldColor = Color(0xFF757575);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    _restoreRememberedLogin();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthStore.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      if (!result.success) {
        _showMessage(result.message);
        return;
      }

      await _persistRememberedLogin(email);
      try {
        await BatchStore.instance.loadForCurrentUser();
      } on Object {
        BatchStore.instance.clear();
      }
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DashboardScreen(promptCreateBatch: BatchStore.instance.isEmpty),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Login failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _restoreRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    final rememberedEmail = prefs.getString(_rememberedEmailKey) ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _rememberMe = rememberMe;
      if (rememberedEmail.isNotEmpty) {
        _emailController.text = rememberedEmail;
      }
    });
  }

  Future<void> _persistRememberedLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<void> _setRememberMe(bool value) async {
    setState(() => _rememberMe = value);
    await _persistRememberedLogin(_emailController.text.trim());
  }

  Future<void> _openForgotPasswordScreen() async {
    final result = await Navigator.of(context).push<ForgotPasswordResult>(
      MaterialPageRoute(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _emailController.text = result.email;
    _passwordController.text = result.newPassword;
    _showMessage('Password reset successful. You can now sign in.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF7EE), Color(0xFFF5FBF6), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -50,
              child: _Blob(
                color: const Color(0xFF4CAF50).withOpacity(0.08),
                size: 260,
              ),
            ),
            Positioned(
              bottom: 60,
              right: -70,
              child: _Blob(
                color: const Color(0xFF4CAF50).withOpacity(0.07),
                size: 300,
              ),
            ),
            Positioned(
              top: 160,
              right: -40,
              child: _Blob(
                color: const Color(0xFF81C784).withOpacity(0.06),
                size: 180,
              ),
            ),
            Positioned(
              bottom: 200,
              left: -30,
              child: _Blob(
                color: const Color(0xFFA5D6A7).withOpacity(0.08),
                size: 160,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _TopWavePainter(
                  color: const Color(0xFF4CAF50).withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -30,
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _ChickenSilhouettePainter(
                  color: const Color(0xFF4CAF50).withOpacity(0.07),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final veryShortScreen = constraints.maxHeight < 700;
                  final shortScreen = constraints.maxHeight < 780;
                  final extraShortScreen = constraints.maxHeight < 720;
                  final horizontalPadding = veryShortScreen
                      ? 20.0
                      : extraShortScreen
                      ? 22.0
                      : 28.0;
                  final topGap = veryShortScreen
                      ? 4.0
                      : extraShortScreen
                      ? 8.0
                      : shortScreen
                      ? 14.0
                      : 22.0;
                  final logoSize = veryShortScreen
                      ? 76.0
                      : extraShortScreen
                      ? 86.0
                      : shortScreen
                      ? 96.0
                      : 110.0;
                  final innerLogoSize = veryShortScreen
                      ? 40.0
                      : extraShortScreen
                      ? 46.0
                      : shortScreen
                      ? 50.0
                      : 54.0;
                  final brandFontSize = veryShortScreen
                      ? 22.0
                      : extraShortScreen
                      ? 24.0
                      : 26.0;
                  final brandGap = veryShortScreen
                      ? 6.0
                      : extraShortScreen
                      ? 8.0
                      : shortScreen
                      ? 12.0
                      : 18.0;
                  final cardPadding = veryShortScreen
                      ? 14.0
                      : extraShortScreen
                      ? 18.0
                      : shortScreen
                      ? 24.0
                      : 28.0;
                  final cardRadius = veryShortScreen
                      ? 22.0
                      : extraShortScreen
                      ? 26.0
                      : 32.0;
                  final sectionGap = veryShortScreen
                      ? 10.0
                      : extraShortScreen
                      ? 14.0
                      : 26.0;
                  final fieldGap = veryShortScreen
                      ? 10.0
                      : extraShortScreen
                      ? 12.0
                      : 18.0;
                  final footerGap = veryShortScreen
                      ? 10.0
                      : extraShortScreen
                      ? 12.0
                      : 24.0;
                  final buttonHeight = veryShortScreen
                      ? 44.0
                      : extraShortScreen
                      ? 46.0
                      : 52.0;
                  final footerBottom = veryShortScreen
                      ? 8.0
                      : extraShortScreen
                      ? 12.0
                      : 24.0;
                  final headingFontSize = veryShortScreen ? 20.0 : 22.0;
                  final subtitleFontSize = veryShortScreen ? 13.0 : 14.0;
                  final labelFontSize = veryShortScreen ? 10.0 : 11.0;
                  final inputFontSize = veryShortScreen ? 14.0 : 15.0;
                  final inputVerticalPadding = veryShortScreen
                      ? 11.0
                      : extraShortScreen
                      ? 12.0
                      : 14.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        SizedBox(height: topGap),
                        AuthAnimatedLogoHeader(
                          logoSize: logoSize,
                          innerLogoSize: innerLogoSize,
                          brandGap: brandGap,
                          brandFontSize: brandFontSize,
                        ),
                        SizedBox(height: brandGap),
                        SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: cardPadding,
                                vertical: cardPadding + 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(cardRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 35,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      'Welcome Back',
                                      style: TextStyle(
                                        fontSize: headingFontSize,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Center(
                                    child: Text(
                                      'Login to your account',
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _FieldLabel(
                                    'EMAIL ADDRESS',
                                    fontSize: labelFontSize,
                                  ),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _emailController,
                                    hintText: 'user@chicktemp.com',
                                    prefixIcon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    fontSize: inputFontSize,
                                    contentPadding: inputVerticalPadding,
                                  ),
                                  SizedBox(height: fieldGap),
                                  _FieldLabel(
                                    'PASSWORD',
                                    fontSize: labelFontSize,
                                  ),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _passwordController,
                                    hintText: 'Password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: _authFieldColor,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    fontSize: inputFontSize,
                                    contentPadding: inputVerticalPadding,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            _setRememberMe(value ?? false);
                                          },
                                          activeColor: const Color(0xFF02AC3F),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Remember me',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF616161),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _openForgotPasswordScreen,
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF02AC3F,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        child: const Text('Forgot?'),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: fieldGap),
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF18B548),
                                            Color(0xFF028A33),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF02AC3F,
                                            ).withOpacity(0.22),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Login',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: footerGap),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF02AC3F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: footerBottom),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final double fontSize;

  const _FieldLabel(this.text, {this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: _authFieldColor,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final double fontSize;
  final double contentPadding;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.fontSize = 15,
    this.contentPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: _authFieldColor,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: const Color(0xFFB6B6B6),
            fontSize: fontSize - 1,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFFBDBDBD),
            size: 20,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: contentPadding,
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TopWavePainter extends CustomPainter {
  final Color color;

  _TopWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.9, size.height * 0.08);
    path.cubicTo(
      size.width * 0.75,
      size.height * 0.16,
      size.width * 0.35,
      size.height * 0.08,
      size.width * 0.25,
      size.height * 0.21,
    );
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.30,
      size.width * 0.35,
      size.height * 0.38,
      size.width * 0.55,
      size.height * 0.31,
    );
    path.cubicTo(
      size.width * 0.78,
      size.height * 0.23,
      size.width * 0.85,
      size.height * 0.09,
      size.width * 0.65,
      size.height * 0.16,
    );
    path.cubicTo(
      size.width * 0.50,
      size.height * 0.22,
      size.width * 0.55,
      size.height * 0.32,
      size.width * 0.68,
      size.height * 0.35,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChickenSilhouettePainter extends CustomPainter {
  final Color color;

  _ChickenSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pWidth = size.width;
    final pHeight = size.height;

    final path = Path();
    path.moveTo(pWidth * 0.12, pHeight * 0.95);
    path.cubicTo(
      pWidth * 0.12,
      pHeight * 0.72,
      pWidth * 0.25,
      pHeight * 0.60,
      pWidth * 0.35,
      pHeight * 0.55,
    );
    path.cubicTo(
      pWidth * 0.38,
      pHeight * 0.40,
      pWidth * 0.48,
      pHeight * 0.30,
      pWidth * 0.65,
      pHeight * 0.33,
    );
    path.cubicTo(
      pWidth * 0.80,
      pHeight * 0.33,
      pWidth * 0.90,
      pHeight * 0.45,
      pWidth * 0.92,
      pHeight * 0.62,
    );
    path.cubicTo(
      pWidth * 0.93,
      pHeight * 0.72,
      pWidth * 0.85,
      pHeight * 0.82,
      pWidth * 0.72,
      pHeight * 0.92,
    );
    path.cubicTo(
      pWidth * 0.60,
      pHeight * 0.96,
      pWidth * 0.35,
      pHeight * 0.96,
      pWidth * 0.12,
      pHeight * 0.95,
    );
    path.close();

    path.moveTo(pWidth * 0.52, pHeight * 0.32);
    path.quadraticBezierTo(
      pWidth * 0.48,
      pHeight * 0.22,
      pWidth * 0.54,
      pHeight * 0.12,
    );
    path.quadraticBezierTo(
      pWidth * 0.60,
      pHeight * 0.08,
      pWidth * 0.65,
      pHeight * 0.22,
    );
    path.quadraticBezierTo(
      pWidth * 0.72,
      pHeight * 0.15,
      pWidth * 0.75,
      pHeight * 0.30,
    );
    path.quadraticBezierTo(
      pWidth * 0.82,
      pHeight * 0.24,
      pWidth * 0.82,
      pHeight * 0.38,
    );

    canvas.drawPath(path, paint);

    final solidPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pWidth * 0.68, pHeight * 0.52),
        width: pWidth * 0.05,
        height: pHeight * 0.07,
      ),
      solidPaint,
    );

    final beakPath = Path()
      ..moveTo(pWidth * 0.92, pHeight * 0.62)
      ..lineTo(pWidth * 0.99, pHeight * 0.65)
      ..lineTo(pWidth * 0.91, pHeight * 0.69)
      ..close();
    canvas.drawPath(beakPath, solidPaint);

    final wattlePath = Path();
    wattlePath.moveTo(pWidth * 0.88, pHeight * 0.71);
    wattlePath.cubicTo(
      pWidth * 0.88,
      pHeight * 0.76,
      pWidth * 0.83,
      pHeight * 0.78,
      pWidth * 0.81,
      pHeight * 0.73,
    );
    wattlePath.cubicTo(
      pWidth * 0.79,
      pHeight * 0.68,
      pWidth * 0.85,
      pHeight * 0.67,
      pWidth * 0.88,
      pHeight * 0.71,
    );
    canvas.drawPath(wattlePath, solidPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
