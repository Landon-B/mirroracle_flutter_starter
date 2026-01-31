/// App-wide constants for Mirroracle.
///
/// Centralizes magic numbers and configuration values for maintainability.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Session Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Default session duration in seconds.
const int kSessionDurationSeconds = 90;

/// Number of times each affirmation is repeated per session.
const int kRepsPerAffirmation = 3;

/// Number of affirmations to load for the home page.
const int kHomeAffirmationsLimit = 20;

// ─────────────────────────────────────────────────────────────────────────────
// Mic Service Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Default listen duration for speech recognition.
const Duration kMicListenDuration = Duration(minutes: 10);

/// Default pause duration before mic stops listening for silence.
const Duration kMicPauseDuration = Duration(seconds: 6);

/// Minimum gap required between mic events for new utterance detection.
const Duration kMinGapForNewUtterance = Duration(milliseconds: 700);

/// How often partial speech results are emitted.
const Duration kPartialEmitInterval = Duration(milliseconds: 100);

/// Smoothing factor for audio level visualization (0.0 - 1.0).
const double kLevelSmoothing = 0.25;

/// Base backoff delay for no-speech errors (milliseconds).
const int kNoSpeechBackoffBaseMs = 750;

/// Maximum backoff delay for no-speech errors (milliseconds).
const int kNoSpeechBackoffMaxMs = 8000;

/// Maximum no-speech streak count for exponential backoff.
const int kNoSpeechStreakMax = 6;

// ─────────────────────────────────────────────────────────────────────────────
// Camera Service Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Delay after focusing before locking settings.
const Duration kCameraFocusLockDelay = Duration(milliseconds: 300);

/// Delay for camera post-initialization tuning.
const Duration kCameraPostInitDelay = Duration(milliseconds: 500);

/// Delay between zoom steps for smooth zoom animation.
const Duration kCameraZoomStepDelay = Duration(milliseconds: 40);

/// Number of steps for smooth zoom animation.
const int kCameraZoomSteps = 3;

/// Target zoom offset from minimum zoom level.
const double kCameraZoomOffset = 0.35;

// ─────────────────────────────────────────────────────────────────────────────
// UI Animation Durations
// ─────────────────────────────────────────────────────────────────────────────

/// Standard fade animation duration.
const Duration kFadeDuration = Duration(milliseconds: 250);

/// Standard slide animation duration.
const Duration kSlideDuration = Duration(milliseconds: 350);

/// Profile overlay transition duration.
const Duration kOverlayTransitionDuration = Duration(milliseconds: 280);

/// Streak bar display duration before auto-hide.
const Duration kStreakBarDisplayDuration = Duration(seconds: 3);

/// Mic ignore window after switching affirmations.
const Duration kMicIgnoreWindow = Duration(milliseconds: 250);

/// Delay before restarting mic for next affirmation.
const Duration kMicRestartDelay = Duration(milliseconds: 250);

// ─────────────────────────────────────────────────────────────────────────────
// Supabase Initialization
// ─────────────────────────────────────────────────────────────────────────────

/// Timeout for Supabase initialization.
const Duration kSupabaseInitTimeout = Duration(seconds: 12);

// ─────────────────────────────────────────────────────────────────────────────
// UI Colors (App Theme)
// ─────────────────────────────────────────────────────────────────────────────

/// Primary background color.
const int kColorBackground = 0xFFEDE1D8;

/// Card background color.
const int kColorCardBackground = 0xFFF6EEE7;

/// Primary text color.
const int kColorTextPrimary = 0xFF4B3C36;

/// Secondary text color.
const int kColorTextSecondary = 0xFF6B5B52;

/// Theme accent color.
const int kColorAccent = 0xFF8B7C73;

/// Dark surface color.
const int kColorDarkSurface = 0xFF2F2624;

/// Border/divider color.
const int kColorBorder = 0xFFE5D6CB;

/// Favorite/heart color.
const int kColorFavorite = 0xFFE07A6B;

/// Light surface color.
const int kColorLightSurface = 0xFFF7F1EB;

/// Gradient start color.
const int kColorGradientStart = 0xFFF4ECE4;

/// Gradient end color.
const int kColorGradientEnd = 0xFFE5D6CB;

// ─────────────────────────────────────────────────────────────────────────────
// Feature Flags (Testing)
// ─────────────────────────────────────────────────────────────────────────────

/// Force onboarding to show on every launch (testing only).
const bool kForceOnboardingEveryLaunch = false;

/// Force streak bar to show on every launch (testing only).
const bool kForceStreakBarEveryLaunch = true;
