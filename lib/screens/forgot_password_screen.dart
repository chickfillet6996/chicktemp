import 'package:flutter/material.dart';

import '../models/auth_store.dart';
import '../widgets/auth_animated_logo_header.dart';

const Color _authFieldColor = Color(0xFF757575);

class ForgotPasswordResult {
  final String email;
  final String newPassword;

  const ForgotPasswordResult({
    required this.email,
    required this.newPassword,
  });
}

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
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
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      _showMessage('Enter your email address.');
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await AuthStore.instance.resetPassword(
        email: email,
        newPassword: newPassword,
      );
      if (!mounted) {
        return;
      }
      if (!result.success) {
        _showMessage(result.message);
        return;
      }

      Navigator.of(context).pop(
        ForgotPasswordResult(email: email, newPassword: newPassword),
      );
    } on Object catch (error) {
      if (mounted) {
        _showMessage('Password reset failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
                  final veryShortScreen = constraints.maxHeight < 720;
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
                      : 16.0;
                  final buttonHeight = veryShortScreen
                      ? 44.0
                      : extraShortScreen
                      ? 46.0
                      : 52.0;
                  final footerBottom = veryShortScreen
                      ? 8.0
                      : extraShortScreen
                      ? 10.0
                      : 18.0;
                  final headingFontSize = veryShortScreen ? 20.0 : 22.0;
                  final subtitleFontSize = veryShortScreen ? 13.0 : 14.0;
                  final fieldLabelFontSize = veryShortScreen ? 10.0 : 11.0;
                  final inputFontSize = veryShortScreen ? 13.0 : 14.0;
                  final inputVerticalPadding = veryShortScreen
                      ? 11.0
                      : extraShortScreen
                      ? 12.0
                      : 14.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topGap,
                      horizontalPadding,
                      footerBottom,
                    ),
                    child: Column(
                      children: [
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
                              width: double.infinity,
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
                                      'Forgot Password',
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
                                      'Reset your password to get back into your account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _ResetField(
                                    label: 'EMAIL ADDRESS',
                                    controller: _emailController,
                                    prefixIcon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    labelFontSize: fieldLabelFontSize,
                                    inputFontSize: inputFontSize,
                                    inputVerticalPadding: inputVerticalPadding,
                                  ),
                                  SizedBox(height: fieldGap),
                                  _ResetField(
                                    label: 'NEW PASSWORD',
                                    controller: _newPasswordController,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscureNewPassword,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureNewPassword =
                                              !_obscureNewPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureNewPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: _authFieldColor,
                                        size: 20,
                                      ),
                                    ),
                                    labelFontSize: fieldLabelFontSize,
                                    inputFontSize: inputFontSize,
                                    inputVerticalPadding: inputVerticalPadding,
                                  ),
                                  SizedBox(height: fieldGap),
                                  _ResetField(
                                    label: 'CONFIRM NEW PASSWORD',
                                    controller: _confirmPasswordController,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: _obscureConfirmPassword,
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: _authFieldColor,
                                        size: 20,
                                      ),
                                    ),
                                    labelFontSize: fieldLabelFontSize,
                                    inputFontSize: inputFontSize,
                                    inputVerticalPadding: inputVerticalPadding,
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
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitReset,
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
                                        child: _isSubmitting
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
                                                    'Reset Password',
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
                              'Remember your password? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF757575),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF02AC3F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _ResetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final double labelFontSize;
  final double inputFontSize;
  final double inputVerticalPadding;

  const _ResetField({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.labelFontSize = 11,
    this.inputFontSize = 14,
    this.inputVerticalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _authFieldColor,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(
            color: _authFieldColor,
            fontSize: inputFontSize,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: const Color(0xFFBDBDBD),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: inputVerticalPadding,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF86D19B), width: 1.2),
            ),
          ),
        ),
      ],
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

    final path = Path()
      ..moveTo(pWidth * 0.12, pHeight * 0.95)
      ..cubicTo(
        pWidth * 0.12,
        pHeight * 0.72,
        pWidth * 0.25,
        pHeight * 0.60,
        pWidth * 0.35,
        pHeight * 0.55,
      )
      ..cubicTo(
        pWidth * 0.38,
        pHeight * 0.40,
        pWidth * 0.48,
        pHeight * 0.30,
        pWidth * 0.65,
        pHeight * 0.33,
      )
      ..cubicTo(
        pWidth * 0.80,
        pHeight * 0.33,
        pWidth * 0.90,
        pHeight * 0.45,
        pWidth * 0.92,
        pHeight * 0.62,
      )
      ..cubicTo(
        pWidth * 0.93,
        pHeight * 0.72,
        pWidth * 0.85,
        pHeight * 0.82,
        pWidth * 0.72,
        pHeight * 0.92,
      )
      ..cubicTo(
        pWidth * 0.60,
        pHeight * 0.96,
        pWidth * 0.35,
        pHeight * 0.96,
        pWidth * 0.12,
        pHeight * 0.95,
      )
      ..close()
      ..moveTo(pWidth * 0.52, pHeight * 0.32)
      ..quadraticBezierTo(
        pWidth * 0.48,
        pHeight * 0.22,
        pWidth * 0.54,
        pHeight * 0.12,
      )
      ..quadraticBezierTo(
        pWidth * 0.60,
        pHeight * 0.08,
        pWidth * 0.65,
        pHeight * 0.22,
      )
      ..quadraticBezierTo(
        pWidth * 0.72,
        pHeight * 0.15,
        pWidth * 0.75,
        pHeight * 0.30,
      )
      ..quadraticBezierTo(
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

    final wattlePath = Path()
      ..moveTo(pWidth * 0.88, pHeight * 0.71)
      ..cubicTo(
        pWidth * 0.88,
        pHeight * 0.76,
        pWidth * 0.83,
        pHeight * 0.78,
        pWidth * 0.81,
        pHeight * 0.73,
      )
      ..cubicTo(
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
