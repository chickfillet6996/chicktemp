import 'package:flutter/material.dart';

class ChickTempPageTransitionsTheme extends PageTransitionsTheme {
  ChickTempPageTransitionsTheme()
    : super(
        builders: const {
          TargetPlatform.android: _ChickTempTransitionsBuilder(),
          TargetPlatform.iOS: _ChickTempTransitionsBuilder(),
          TargetPlatform.linux: _ChickTempTransitionsBuilder(),
          TargetPlatform.macOS: _ChickTempTransitionsBuilder(),
          TargetPlatform.windows: _ChickTempTransitionsBuilder(),
        },
      );
}

class _ChickTempTransitionsBuilder extends PageTransitionsBuilder {
  const _ChickTempTransitionsBuilder();

  static const _enterOffset = Offset(0.03, 0);
  static const _exitOffset = Offset(-0.015, 0);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName && route.isFirst) {
      return child;
    }

    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slideIn = Tween<Offset>(
      begin: _enterOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    final slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: _exitOffset,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
      ),
    );

    return SlideTransition(
      position: slideOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: SlideTransition(
          position: slideIn,
          child: child,
        ),
      ),
    );
  }
}
