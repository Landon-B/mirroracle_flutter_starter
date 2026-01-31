# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
flutter pub get          # Install dependencies
flutter run -d ios       # Run on iOS simulator (open -a Simulator first)
flutter analyze          # Static analysis
dart format lib/         # Format code
flutter test             # Run tests
flutter build ios        # Build iOS
flutter build apk        # Build Android
```

## Architecture Overview

**Mirroracle** is a Flutter app for guided affirmation practice sessions. Users speak affirmations while the app uses real-time speech recognition to track progress. Camera provides presence detection during sessions.

### Tech Stack
- **Backend**: Supabase (auth, database)
- **Speech**: speech_to_text plugin with custom keep-alive wrapper
- **Camera**: camera plugin with resolution fallback
- **State**: ChangeNotifier pattern (no Provider/Riverpod/Bloc)

### Core Services

**MicService** (`lib/services/mic_service.dart`): Speech-to-text wrapper with keep-alive support for continuous listening. Exposes streams for partial/final text, sound levels, errors, and state. Implements exponential backoff on "no-speech" errors (750ms → 8s). Configures iOS audio session for spokenAudio mode.

**CameraService** (`lib/services/camera_service.dart`): Singleton camera lifecycle manager. Supports warm-up initialization, resolution fallback (veryHigh → low), tap-to-focus, and image streaming for frame processing.

**SessionController** (`lib/controllers/session_controller.dart`): Central state machine for practice sessions. Manages lifecycle (idle → live → saving → done), affirmation progression (3 affirmations × 3 reps = 9 utterances), and speech matching. Persists session data to Supabase with presence scoring.

**MoodService** (`lib/services/mood_service.dart`): CRUD for mood checkins with range queries.

**StreakService** (`lib/services/streak_service.dart`): Computes current/best streak days from completed sessions.

### Speech Matching

`SessionSpeechMatcher` uses token-based fuzzy matching with Levenshtein distance. Matching rules:
- Exact match wins
- Suffix stripping: "running" → "run"
- Levenshtein ≤ 1 for tokens ≥ 4 chars
- 700ms debounce between utterances to prevent false matches

### Key Files

- `lib/main.dart` - Entry point, Supabase init, auth gate
- `lib/secrets.dart` - Supabase credentials (not committed)
- `lib/pages/home_page.dart` - Main affirmations carousel
- `lib/pages/new_session_page.dart` - Session container with camera/mic
- `lib/pages/new_session/session_overlay.dart` - HUD during practice

### Supabase Tables

- `affirmations` - Affirmation text and categories
- `favorite_affirmations` - User favorites (user_id, affirmation_id)
- `sessions` - Session records with presence_score, duration, aff_count
- `mood_checkins` - Mood entries with score (1-10) and tags

## Conventions

- Explicit relative imports (`../services/mic_service.dart`)
- Widget disposal always cancels streams & timers
- UI uses Material 3 with warm earth tones (0xFFE5D6CB, 0xFF2F2624)
- Fonts: Manrope, DM Serif Display via google_fonts

## Debug Features

- Long-press "Practice" button on HomePage opens hidden mic debug page
- `kForceOnboardingEveryLaunch` flag in code for testing onboarding flow
- "TEST MODE" overlay appears for test accounts
