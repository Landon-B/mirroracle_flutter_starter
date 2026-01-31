import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/camera_ready_notifier.dart';
import '../services/camera_service.dart';
import '../services/mic_service.dart';
import '../services/mood_service.dart';
import 'logger.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initialize all services and register them with the service locator.
///
/// Call this once at app startup, after Supabase is initialized.
Future<void> setupServiceLocator() async {
  // Core services
  sl.registerLazySingleton<AppLogger>(() => AppLogger());

  // Supabase client (already initialized by the time this runs)
  sl.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Camera service (singleton pattern already exists, but now accessible via DI)
  sl.registerLazySingleton<CameraService>(() => CameraService());

  // Camera ready notifier (tracks global camera state for UI)
  sl.registerLazySingleton<CameraReadyNotifier>(() => CameraReadyNotifier());

  // Mic service (new instance per session typically, but factory for flexibility)
  sl.registerFactory<MicService>(() => MicService());

  // Mood service
  sl.registerLazySingleton<MoodService>(() => MoodService());
}

/// Reset all services (useful for testing or logout).
Future<void> resetServiceLocator() async {
  await sl.reset();
}
