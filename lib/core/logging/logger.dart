import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

void logMessage(
  String message, {
  LogLevel level = LogLevel.info,
  Object? error,
  StackTrace? stackTrace,
}) {
  final tag = switch (level) {
    LogLevel.debug => 'DEBUG',
    LogLevel.info => 'INFO',
    LogLevel.warning => 'WARN',
    LogLevel.error => 'ERROR',
  };
  if (kDebugMode || level == LogLevel.warning || level == LogLevel.error) {
    developer.log(
      '[$tag] $message',
      name: 'NavMate',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

void logDebug(String message) => logMessage(message, level: LogLevel.debug);

void logInfo(String message) => logMessage(message, level: LogLevel.info);

void logWarn(String message, {Object? error, StackTrace? stackTrace}) =>
    logMessage(
      message,
      level: LogLevel.warning,
      error: error,
      stackTrace: stackTrace,
    );

void logError(String message, {Object? error, StackTrace? stackTrace}) =>
    logMessage(
      message,
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    );
