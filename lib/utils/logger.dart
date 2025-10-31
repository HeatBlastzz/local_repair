import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('FlutterApp');
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      if (record.level >= Level.SEVERE) {
        print('❌ ${record.time}: ${record.loggerName}: ${record.message}');
      } else if (record.level >= Level.WARNING) {
        print('⚠️ ${record.time}: ${record.loggerName}: ${record.message}');
      } else if (record.level >= Level.INFO) {
        print('ℹ️ ${record.time}: ${record.loggerName}: ${record.message}');
      } else {
        print('🔍 ${record.time}: ${record.loggerName}: ${record.message}');
      }
    });

    _initialized = true;
  }

  static void debug(String message) {
    _logger.fine(message);
  }

  static void info(String message) {
    _logger.info(message);
  }

  static void warning(String message) {
    _logger.warning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  static void firestore(String message) {
    _logger.info('[Firestore] $message');
  }

  static void auth(String message) {
    _logger.info('[Auth] $message');
  }

  static void job(String message) {
    _logger.info('[Job] $message');
  }

  static void payment(String message) {
    _logger.info('[Payment] $message');
  }

  static void map(String message) {
    _logger.info('[Map] $message');
  }
}
