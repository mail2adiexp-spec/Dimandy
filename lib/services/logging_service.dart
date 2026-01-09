import 'package:logger/logger.dart';

class LoggingService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  // Log levels
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // Specific event logging
  static void logUserAction(String action, Map<String, dynamic>? data) {
    _logger.i('User Action: $action', error: data);
  }

  static void logFirestoreOperation(String collection, String operation, [dynamic error]) {
    if (error != null) {
      _logger.e('Firestore $operation on $collection failed', error: error);
    } else {
      _logger.i('Firestore $operation on $collection');
    }
  }
}
