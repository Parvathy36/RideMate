import 'package:flutter/material.dart';

/// Screen size breakpoints for responsive design
class ScreenBreakpoints {
  static const double mobileSmall = 320;
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double desktopLarge = 1440;
}

/// Responsive utility class for consistent sizing across different screen sizes
class Responsive {
  /// Get screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ScreenBreakpoints.mobile) {
      return ScreenSize.mobileSmall;
    } else if (width < ScreenBreakpoints.tablet) {
      return ScreenSize.mobile;
    } else if (width < ScreenBreakpoints.desktop) {
      return ScreenSize.tablet;
    } else if (width < ScreenBreakpoints.desktopLarge) {
      return ScreenSize.desktop;
    } else {
      return ScreenSize.desktopLarge;
    }
  }

  /// Check if screen is mobile size
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobileSmall ||
        getScreenSize(context) == ScreenSize.mobile;
  }

  /// Check if screen is tablet size
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// Check if screen is desktop size
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop ||
        getScreenSize(context) == ScreenSize.desktopLarge;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getPadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 16);
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 32);
      case ScreenSize.desktopLarge:
        return const EdgeInsets.symmetric(horizontal: 40, vertical: 40);
    }
  }

  /// Get responsive spacing based on screen size
  static double getSpacing(BuildContext context, [double baseSpacing = 16]) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return baseSpacing * 0.75;
      case ScreenSize.mobile:
        return baseSpacing;
      case ScreenSize.tablet:
        return baseSpacing * 1.25;
      case ScreenSize.desktop:
        return baseSpacing * 1.5;
      case ScreenSize.desktopLarge:
        return baseSpacing * 2;
    }
  }

  /// Get responsive font size based on screen size
  static double getFontSize(BuildContext context, double baseFontSize) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return baseFontSize * 0.85;
      case ScreenSize.mobile:
        return baseFontSize;
      case ScreenSize.tablet:
        return baseFontSize * 1.1;
      case ScreenSize.desktop:
        return baseFontSize * 1.2;
      case ScreenSize.desktopLarge:
        return baseFontSize * 1.3;
    }
  }

  /// Get responsive button padding based on screen size
  static EdgeInsets getButtonPadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ScreenSize.mobile:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case ScreenSize.tablet:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
      case ScreenSize.desktop:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case ScreenSize.desktopLarge:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 18);
    }
  }

  /// Get responsive card padding based on screen size
  static EdgeInsets getCardPadding(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return const EdgeInsets.all(12);
      case ScreenSize.mobile:
        return const EdgeInsets.all(16);
      case ScreenSize.tablet:
        return const EdgeInsets.all(20);
      case ScreenSize.desktop:
        return const EdgeInsets.all(24);
      case ScreenSize.desktopLarge:
        return const EdgeInsets.all(28);
    }
  }

  /// Get responsive icon size based on screen size
  static double getIconSize(BuildContext context, [double baseSize = 24]) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return baseSize * 0.8;
      case ScreenSize.mobile:
        return baseSize;
      case ScreenSize.tablet:
        return baseSize * 1.2;
      case ScreenSize.desktop:
        return baseSize * 1.4;
      case ScreenSize.desktopLarge:
        return baseSize * 1.6;
    }
  }

  /// Get responsive app bar height based on screen size
  static double getAppBarHeight(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return 56;
      case ScreenSize.mobile:
        return 56;
      case ScreenSize.tablet:
        return 64;
      case ScreenSize.desktop:
        return 64;
      case ScreenSize.desktopLarge:
        return 72;
    }
  }

  /// Get responsive container constraints for centered content
  static BoxConstraints getContentConstraints(BuildContext context) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
        return const BoxConstraints(maxWidth: 320);
      case ScreenSize.mobile:
        return const BoxConstraints(maxWidth: 400);
      case ScreenSize.tablet:
        return const BoxConstraints(maxWidth: 600);
      case ScreenSize.desktop:
        return const BoxConstraints(maxWidth: 800);
      case ScreenSize.desktopLarge:
        return const BoxConstraints(maxWidth: 1000);
    }
  }

  /// Get responsive grid cross axis count
  static int getGridCrossAxisCount(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.mobileSmall:
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet;
      case ScreenSize.desktop:
      case ScreenSize.desktopLarge:
        return desktop;
    }
  }

  /// Get responsive text alignment for titles
  static TextAlign getTitleTextAlign(BuildContext context) {
    return isMobile(context) ? TextAlign.center : TextAlign.left;
  }

  /// Get responsive scroll physics
  static ScrollPhysics getScrollPhysics(BuildContext context) {
    return isMobile(context) ? const BouncingScrollPhysics() : const ClampingScrollPhysics();
  }
}

/// Screen size enumeration
enum ScreenSize {
  mobileSmall,
  mobile,
  tablet,
  desktop,
  desktopLarge,
}

/// Theme extensions for responsive design
extension ResponsiveTheme on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}