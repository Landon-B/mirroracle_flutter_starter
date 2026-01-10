import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secrets.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/camera_service.dart';

const bool kForceOnboardingEveryLaunch = true; // TESTING ONLY

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp],
  );
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // fine to keep for email/password too
      // autoRefreshToken is true by default in flutter package
    ),
  );
  runApp(const MirroracleApp());
}

class MirroracleApp extends StatelessWidget {
  const MirroracleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirroracle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF7C4DFF)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
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

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _warmUpCamera();
  }

  Future<void> _warmUpCamera() async {
    try {
      final camera = CameraService();
      final granted = await camera.ensureCameraPermission();
      if (!granted) return;
      await camera.warmUp();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Keep the listener mounted at all times so signIn/signOut rebuilds the UI.
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginPage();
        }

        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) {
          return const LoginPage();
        }

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
