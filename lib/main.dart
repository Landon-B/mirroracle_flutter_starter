import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'core/service_locator.dart';
import 'pages/auth_landing_page.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'secrets.dart';
import 'services/camera_ready_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MirroracleApp());
}

class MirroracleApp extends StatelessWidget {
  const MirroracleApp({super.key});

  static final Future<void> _initFuture = _initializeApp();

  static Future<void> _initializeApp() async {
    await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp],
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ).timeout(kSupabaseInitTimeout);

    // Initialize service locator after Supabase is ready
    await setupServiceLocator();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirroracle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF)),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Startup failed',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your network connection and try again.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return const AuthGate();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;
  Future<bool>? _onboardingFuture;
  String? _onboardingUserId;
  bool _forcedOnboardingShown = false;
  bool _cameraWarmStarted = false;

  CameraReadyNotifier get _cameraNotifier => sl<CameraReadyNotifier>();

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  /// Start camera warm-up in the background without blocking UI.
  void _startCameraWarmUp() {
    if (_cameraWarmStarted) return;
    _cameraWarmStarted = true;

    // Use microtask to avoid blocking the current frame
    Future.microtask(() {
      _cameraNotifier.warmUp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const AuthLandingPage();
        }

        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) {
          return const AuthLandingPage();
        }

        _startCameraWarmUp();

        if (kForceOnboardingEveryLaunch) {
          if (_forcedOnboardingShown) {
            return const HomePage();
          }
          return OnboardingPage(
            onFinished: () async {
              _forcedOnboardingShown = true;
              if (!mounted) return;
              setState(() {});
            },
          );
        }

        if (_onboardingUserId != uid) {
          _onboardingUserId = uid;
          _onboardingFuture = _hasSeenOnboarding(uid);
        }

        return FutureBuilder<bool>(
          future: _onboardingFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.data == true) {
              return const HomePage();
            }
            return OnboardingPage(
              onFinished: () async {
                await _setOnboardingSeen(uid);
                if (!mounted) return;
                setState(() {});
              },
            );
          },
        );
      },
    );
  }
}

Future<bool> _hasSeenOnboarding(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_seen_$uid') ?? false;
}

Future<void> _setOnboardingSeen(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_seen_$uid', true);
}
