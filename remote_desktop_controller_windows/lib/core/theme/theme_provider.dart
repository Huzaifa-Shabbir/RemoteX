import 'package:flutter/material.dart';

/// Holds the current [ThemeMode] and notifies listeners when it changes.
/// Inject this at the top of the widget tree via [ChangeNotifierProvider]
/// (or pass it down manually if not using provider).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setDark()  { _mode = ThemeMode.dark;  notifyListeners(); }
  void setLight() { _mode = ThemeMode.light; notifyListeners(); }
}