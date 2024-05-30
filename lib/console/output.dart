import 'dart:io';

import 'package:ansi/ansi.dart' as ansi;
import 'package:findin/config.dart';

enum OutputLevel {
  log,
  verbose,
  warning,
  error,
}

class ConsoleOutput {
  const ConsoleOutput();

  void _emit(OutputLevel level, Object? message) {
    switch (level) {
      case OutputLevel.verbose:
        if (!FindinConfig.main.isVerboseModeEnabled) return;
      case OutputLevel.warning:
        message = FindinConfig.main.isConsoleColorsEnabled
            ? message
            : ansi.yellow(message.toString());
        break;
      case OutputLevel.error:
        message = FindinConfig.main.isConsoleColorsEnabled
            ? message
            : ansi.red(message.toString());
        return stderr.writeln(message);
      default:
    }

    print(message);
  }

  void out(Object? message) {
    _emit(OutputLevel.log, message);
  }

  void warn(Object? message) {
    _emit(OutputLevel.warning, message);
  }

  void error(Object? message) {
    _emit(OutputLevel.error, message);
  }

  void verbose(Object? message) {
    _emit(OutputLevel.verbose, message);
  }
}

final console = const ConsoleOutput();
