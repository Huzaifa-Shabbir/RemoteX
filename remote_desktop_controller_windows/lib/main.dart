import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/controller/supabase_service.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'core/streaming/websocket_Input.dart';
import 'core/streaming/pairing_state.dart';
import 'core/ui/global_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url:      'https://kxkckojiifwkqmolvyro.supabase.co',
    anonKey:  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4a2Nrb2ppaWZ3a3Ftb2x2eXJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNjIwODAsImV4cCI6MjA4ODczODA4MH0.Zqfn72P2ceYaFb6uIA5L5l6xIJvHRjwtZMa69CGhsBQ',
  );

  // Start pairing + UDP listener before launching UI
  await PairingService.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PairingState()),
      ],
      child: const RemoteXApp(),
    ),
  );
}

class RemoteXApp extends StatelessWidget {
  const RemoteXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'RemoteX',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      // Global messenger key so non-UI code can show SnackBars without
      // needing a BuildContext.
      scaffoldMessengerKey: globalScaffoldMessengerKey,
      // ── Route to dashboard if already signed in ──────────
      home: SupabaseService.currentUser != null
          ? DashboardPage(
              userName:  SupabaseService.displayName,
              userEmail: SupabaseService.displayEmail,
            )
          : const HomePage(),
    );
  }
}