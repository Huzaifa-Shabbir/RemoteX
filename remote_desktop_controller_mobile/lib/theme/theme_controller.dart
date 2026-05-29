import 'package:flutter/material.dart';

class ThemeController {
  ThemeController({ThemeMode initialMode = ThemeMode.light})
      : themeMode = ValueNotifier<ThemeMode>(initialMode);

  final ValueNotifier<ThemeMode> themeMode;

  bool get isDark => themeMode.value == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  void toggle() {
    themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void dispose() {
    themeMode.dispose();
  }
}

class ThemeControllerScope extends InheritedWidget {
  const ThemeControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ThemeController controller;

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found in widget tree.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(ThemeControllerScope oldWidget) =>
      controller != oldWidget.controller;
}

