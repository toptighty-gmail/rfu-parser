import 'package:flutter/material.dart';

class ResponsiveLayout {
  // Breakpoints
  static const double mobileBreakpoint = 700;
  static const double tabletBreakpoint = 1100;
  static const double desktopBreakpoint = 1800;

  // Max Container Width for Ergonomic Reading on Ultrawide & 2560x1440 displays
  static const double maxContentWidth = 1440;
  static const double maxDialogWidth = 720;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  static bool isUltraWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  static EdgeInsets horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 16);
    } else if (width < tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    } else if (width < desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 36, vertical: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 28);
    }
  }

  static BoxConstraints contentConstraints(BuildContext context) {
    return const BoxConstraints(maxWidth: maxContentWidth);
  }
}
