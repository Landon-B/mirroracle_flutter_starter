import 'package:flutter/foundation.dart';

/// Log levels for categorizing messages.
enum LogLevel { debug, info, warning, error }

/// Centralized logging service for the app.
///
/// Provides structured logging with levels, context, and optional error details.
/// In production, this could be extended to send logs to a remote service.
class AppLogger {
  /// Minimum log level to output. Messages below this level are ignored.
  LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Log a debug message (development only).
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log an informational message.
  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message.
  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log an error message.
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Log a camera-related message.
  void camera(String message, {LogLevel level = LogLevel.debug, Object? error}) {
    _log(level, message, tag: 'camera', error: error);
  }

  /// Log a mic/speech-related message.
  void mic(String message, {LogLevel level = LogLevel.debug, Object? error}) {
    _log(level, message, tag: 'mic', error: error);
  }

  /// Log a Supabase/database-related message.
  void db(String message, {LogLevel level = LogLevel.debug, Object? error}) {
    _log(level, message, tag: 'db', error: error);
  }

  /// Log an auth-related message.
  void auth(String message, {LogLevel level = LogLevel.debug, Object? error}) {
    _log(level, message, tag: 'auth', error: error);
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final prefix = _levelPrefix(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    final errorStr = error != null ? ' | Error: $error' : '';

    final output = '$prefix $tagStr$message$errorStr';

    // In debug mode, use debugPrint for better formatting
    if (kDebugMode) {
      debugPrint(output);
      if (stackTrace != null && level == LogLevel.error) {
        debugPrintStack(stackTrace: stackTrace, maxFrames: 10);
      }
    }

    // TODO: In production, send errors to a crash reporting service
    // if (level == LogLevel.error && !kDebugMode) {
    //   CrashReporting.recordError(error, stackTrace);
    // }
  }

  String _levelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }
}
