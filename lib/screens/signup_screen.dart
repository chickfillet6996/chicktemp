import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../models/batch_store.dart';
import '../widgets/auth_animated_logo_header.dart';
import 'dashboards_screen.dart';

const Color _authFieldColor = Color(0xFF757575);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Fill in your name, email, and password.');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthStore.instance.signUp(
        fullName: fullName,
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

      BatchStore.instance.clear();
      await BatchStore.instance.saveAllForCurrentUser();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(promptCreateBatch: true),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Sign up failed: $error');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
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
              top: -58,
              left: -48,
              child: _Blob(
                color: const Color(0xFF4CAF50).withOpacity(0.08),
                size: 260,
              ),
            ),
            Positioned(
              bottom: 82,
              right: -68,
              child: _Blob(
                color: const Color(0xFF4CAF50).withOpacity(0.07),
                size: 300,
              ),
            ),
            Positioned(
              top: 162,
              right: -38,
              child: _Blob(
                color: const Color(0xFF81C784).withOpacity(0.06),
                size: 180,
              ),
            ),
            Positioned(
              bottom: 198,
              left: -32,
              child: _Blob(
                color: const Color(0xFFA5D6A7).withOpacity(0.08),
                size: 160,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _TopWavePainter(
                  color: const Color(0xFF4CAF50).withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -18,
              left: -28,
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _ChickenSilhouettePainter(
                  color: const Color(0xFF4CAF50).withOpacity(0.06),
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
                      ? 18.0
                      : extraShortScreen
                      ? 22.0
                      : 28.0;
                  final topGap = veryShortScreen
                      ? 2.0
                      : extraShortScreen
                      ? 6.0
                      : shortScreen
                      ? 12.0
                      : 20.0;
                  final logoSize = veryShortScreen
                      ? 74.0
                      : extraShortScreen
                      ? 82.0
                      : shortScreen
                      ? 92.0
                      : 104.0;
                  final innerLogoSize = veryShortScreen
                      ? 38.0
                      : extraShortScreen
                      ? 42.0
                      : shortScreen
                      ? 48.0
                      : 52.0;
                  final brandGap = veryShortScreen
                      ? 6.0
                      : extraShortScreen
                      ? 8.0
                      : 12.0;
                  final cardPadding = veryShortScreen
                      ? 12.0
                      : extraShortScreen
                      ? 14.0
                      : shortScreen
                      ? 18.0
                      : 22.0;
                  final fieldGap = veryShortScreen
                      ? 6.0
                      : extraShortScreen
                      ? 8.0
                      : 12.0;
                  final sectionGap = veryShortScreen
                      ? 6.0
                      : extraShortScreen
                      ? 8.0
                      : 16.0;
                  final actionGap = veryShortScreen
                      ? 8.0
                      : extraShortScreen
                      ? 10.0
                      : 18.0;
                  final footerGap = veryShortScreen
                      ? 8.0
                      : extraShortScreen
                      ? 10.0
                      : 16.0;
                  final buttonHeight = veryShortScreen
                      ? 42.0
                      : extraShortScreen
                      ? 44.0
                      : 50.0;
                  final inputVerticalPadding = veryShortScreen
                      ? 7.0
                      : extraShortScreen
                      ? 8.0
                      : 11.0;
                  final labelGap = veryShortScreen
                      ? 4.0
                      : extraShortScreen
                      ? 6.0
                      : 8.0;
                  final headingFontSize = veryShortScreen
                      ? 20.0
                      : extraShortScreen
                      ? 21.0
                      : 24.0;
                  final brandFontSize = veryShortScreen
                      ? 22.0
                      : extraShortScreen
                      ? 23.0
                      : 26.0;
                  final subtitleFontSize = veryShortScreen
                      ? 12.0
                      : extraShortScreen
                      ? 13.0
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
                        SizedBox(
                          height: veryShortScreen
                              ? 8.0
                              : shortScreen
                              ? 12.0
                              : 18.0,
                        ),
                        SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _fadeAnim,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(cardPadding),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: headingFontSize,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: extraShortScreen ? 2 : 3),
                                  Center(
                                    child: Text(
                                      'Join ChickTemp today',
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _FieldLabel(
                                    'FULL NAME',
                                    fontSize: extraShortScreen ? 10.0 : 11.0,
                                  ),
                                  SizedBox(height: labelGap),
                                  _InputField(
                                    controller: _nameController,
                                    hintText: 'Jane Doe',
                                    prefixIcon: Icons.person_outline_rounded,
                                    contentPadding: inputVerticalPadding,
                                    iconSize: extraShortScreen ? 18.0 : 20.0,
                                    fontSize: extraShortScreen ? 14.0 : 15.0,
                                  ),
                                  SizedBox(height: fieldGap),
                                  _FieldLabel(
                                    'EMAIL ADDRESS',
                                    fontSize: extraShortScreen ? 10.0 : 11.0,
                                  ),
                                  SizedBox(height: labelGap),
                                  _InputField(
                                    controller: _emailController,
                                    hintText: 'user@farm.com',
                                    prefixIcon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    contentPadding: inputVerticalPadding,
                                    iconSize: extraShortScreen ? 18.0 : 20.0,
                                    fontSize: extraShortScreen ? 14.0 : 15.0,
                                  ),
                                  SizedBox(height: fieldGap),
                                  _FieldLabel(
                                    'PASSWORD',
                                    fontSize: extraShortScreen ? 10.0 : 11.0,
                                  ),
                                  SizedBox(height: labelGap),
                                  _InputField(
                                    controller: _passwordController,
                                    hintText: 'Password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    contentPadding: inputVerticalPadding,
                                    iconSize: extraShortScreen ? 18.0 : 20.0,
                                    fontSize: extraShortScreen ? 14.0 : 15.0,
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
                                          _obscurePassword =
                                              !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(height: fieldGap),
                                  _FieldLabel(
                                    'CONFIRM PASSWORD',
                                    fontSize: extraShortScreen ? 10.0 : 11.0,
                                  ),
                                  SizedBox(height: labelGap),
                                  _InputField(
                                    controller: _confirmPasswordController,
                                    hintText: 'Confirm password',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscureConfirm,
                                    contentPadding: inputVerticalPadding,
                                    iconSize: extraShortScreen ? 18.0 : 20.0,
                                    fontSize: extraShortScreen ? 14.0 : 15.0,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: _authFieldColor,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirm = !_obscureConfirm;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(height: actionGap),
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
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
                                        onPressed: _isLoading ? null : _signUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
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
                                                    'Sign Up',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
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
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF02AC3F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: extraShortScreen ? 4 : 8),
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
  final double contentPadding;
  final double fontSize;
  final double iconSize;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.contentPadding = 15,
    this.fontSize = 15,
    this.iconSize = 20,
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
            fontSize: fontSize,
            color: const Color(0xFFB6B6B6),
          ),
          isDense: true,
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFFBDBDBD),
            size: iconSize,
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
  const _TopWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.9, size.height * 0.08)
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.16,
        size.width * 0.35,
        size.height * 0.08,
        size.width * 0.25,
        size.height * 0.21,
      )
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.30,
        size.width * 0.35,
        size.height * 0.38,
        size.width * 0.55,
        size.height * 0.31,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.23,
        size.width * 0.85,
        size.height * 0.09,
        size.width * 0.65,
        size.height * 0.16,
      )
      ..cubicTo(
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
  bool shouldRepaint(covariant _TopWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ChickenSilhouettePainter extends CustomPainter {
  const _ChickenSilhouettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    final path = Path()
      ..moveTo(width * 0.12, height * 0.95)
      ..cubicTo(
        width * 0.12,
        height * 0.72,
        width * 0.25,
        height * 0.60,
        width * 0.35,
        height * 0.55,
      )
      ..cubicTo(
        width * 0.38,
        height * 0.40,
        width * 0.48,
        height * 0.30,
        width * 0.65,
        height * 0.33,
      )
      ..cubicTo(
        width * 0.80,
        height * 0.33,
        width * 0.90,
        height * 0.45,
        width * 0.92,
        height * 0.62,
      )
      ..cubicTo(
        width * 0.93,
        height * 0.72,
        width * 0.85,
        height * 0.82,
        width * 0.72,
        height * 0.92,
      )
      ..cubicTo(
        width * 0.60,
        height * 0.96,
        width * 0.35,
        height * 0.96,
        width * 0.12,
        height * 0.95,
      )
      ..close()
      ..moveTo(width * 0.52, height * 0.32)
      ..quadraticBezierTo(
        width * 0.48,
        height * 0.22,
        width * 0.54,
        height * 0.12,
      )
      ..quadraticBezierTo(
        width * 0.60,
        height * 0.08,
        width * 0.65,
        height * 0.22,
      )
      ..quadraticBezierTo(
        width * 0.72,
        height * 0.15,
        width * 0.75,
        height * 0.30,
      )
      ..quadraticBezierTo(
        width * 0.82,
        height * 0.24,
        width * 0.82,
        height * 0.38,
      );

    canvas.drawPath(path, outlinePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width * 0.68, height * 0.52),
        width: width * 0.05,
        height: height * 0.07,
      ),
      fillPaint,
    );

    final beakPath = Path()
      ..moveTo(width * 0.92, height * 0.62)
      ..lineTo(width * 0.99, height * 0.65)
      ..lineTo(width * 0.91, height * 0.69)
      ..close();
    canvas.drawPath(beakPath, fillPaint);

    final wattlePath = Path()
      ..moveTo(width * 0.88, height * 0.71)
      ..cubicTo(
        width * 0.88,
        height * 0.76,
        width * 0.83,
        height * 0.78,
        width * 0.81,
        height * 0.73,
      )
      ..cubicTo(
        width * 0.79,
        height * 0.68,
        width * 0.85,
        height * 0.67,
        width * 0.88,
        height * 0.71,
      );
    canvas.drawPath(wattlePath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ChickenSilhouettePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
