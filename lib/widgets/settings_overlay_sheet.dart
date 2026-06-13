import 'package:flutter/material.dart';

import 'splash_background.dart';

class SettingsOverlaySheet extends StatelessWidget {
  final Widget headerBand;
  final CustomPainter backgroundPainter;
  final Widget child;

  const SettingsOverlaySheet({
    super.key,
    required this.headerBand,
    required this.backgroundPainter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F3),
      body: SplashBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: backgroundPainter),
                ),
              ),
              Column(
                children: [
                  headerBand,
                  Expanded(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: child,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
