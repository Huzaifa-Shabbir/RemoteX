import 'package:flutter/material.dart';

// Global scaffold messenger key so non-UI code can show SnackBars.
final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Show a non-blocking global SnackBar from anywhere in the app.
void showGlobalSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
  final messenger = globalScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    ),
  );
}
