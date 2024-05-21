import 'package:findin/providers/verbose.dart';
import 'package:riverpod/riverpod.dart';
import 'package:findin/context.dart';

enum OutputLevel {
  log,
  verbose,
}

class ConsoleOutput {
  final ProviderContainer _context;

  ConsoleOutput(ProviderContainer context) : _context = context;

  bool get isVerboseModeEnabled => _context.read(isVerboseEnabledProvider);

  void _emit(OutputLevel level, Object? message) {
    switch (level) {
      case OutputLevel.verbose:
        if (!isVerboseModeEnabled) return;
      default:
    }

    print(message);
  }

  void out(Object? message) {
    _emit(OutputLevel.log, message);
  }

  void verbose(Object? message) {
    _emit(OutputLevel.verbose, message);
  }
}

final console = ConsoleOutput(context);
