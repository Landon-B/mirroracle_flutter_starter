import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration loaded from .env file.
/// See .env.example for the required format.
String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
String get supabaseRedirectUri =>
    dotenv.env['SUPABASE_REDIRECT_URI'] ?? 'io.supabase.mirroracle://login-callback';
