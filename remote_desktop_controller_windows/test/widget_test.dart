//import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remotex_app/main.dart';
import 'package:remotex_app/core/theme/theme_provider.dart';

void main() {
  testWidgets('App launches and shows RemoteX home page',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const RemoteXApp(),
      ),
    );

    // Allow all animations/frames to settle
    await tester.pumpAndSettle();

    // Verify the app title is present
    expect(find.text('RemoteX'), findsWidgets);

    // Verify key hero section text is present
    expect(find.text('Control Your PC'), findsOneWidget);
    expect(find.text('From Anywhere'), findsOneWidget);

    // Verify nav buttons are present
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Get Started'), findsWidgets);
  });
}