import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/sign_up_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/home_screen.dart';
import 'screens/connection_flow_screen.dart';
import 'screens/remote_screen.dart';
import 'screens/shared_folder_screen.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Validate config early (fail fast)
  if (supabaseUrl == null || supabaseUrl.isEmpty ||
      supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Missing Supabase configuration in .env file.\n'
      'Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set.',
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const RemoteXApp());
}

class RemoteXApp extends StatefulWidget {
  const RemoteXApp({super.key});

  @override
  State<RemoteXApp> createState() => _RemoteXAppState();
}

class _RemoteXAppState extends State<RemoteXApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController(initialMode: ThemeMode.light);
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: _themeController,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeController.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'RemoteX',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F172A),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F172A),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeMode,
            home: const _AuthGate(),
            routes: {
              '/signup': (context) => const SignUpScreen(),
              '/signin': (context) => const SignInScreen(),

              '/home/light': (context) => const HomeLightScreen(),
              '/home/dark': (context) => const HomeDarkScreen(),
              '/shared/light': (context) => const SharedFolderLightScreen(),
              '/shared/dark': (context) => const SharedFolderDarkScreen(),
              '/connect/light': (context) => const ConnectionLightScreen(),
              '/connect/dark': (context) => const ConnectionDarkScreen(),
              '/qr/light': (context) => const QrLightScreen(),
              '/qr/dark': (context) => const QrDarkScreen(),
              '/connected/light': (context) => const ConnectedLightScreen(),
              '/connected/dark': (context) => const ConnectedDarkScreen(),
              '/remote/light': (context) => const RemoteLightScreen(),
              '/remote/dark': (context) => const RemoteDarkScreen(),
            },
            onUnknownRoute: (settings) => MaterialPageRoute(
              builder: (context) => const NotFoundScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late bool _hasSession;
  late final Stream<AuthState> _authStateStream;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _hasSession = auth.currentSession != null;
    _authStateStream = auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);

    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      builder: (context, snapshot) {
        final authEvent = snapshot.data?.event;
        if (authEvent == AuthChangeEvent.signedOut) {
          _hasSession = false;
        } else if (snapshot.data?.session != null) {
          _hasSession = true;
        }

        if (!_hasSession) {
          return const SignUpScreen();
        }
        return themeController.isDark
            ? const HomeDarkScreen()
            : const HomeLightScreen();
      },
    );
  }
}