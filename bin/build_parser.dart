import 'package:args/args.dart';
import 'dart:io';

ArgParser buildParser(ArgParser parser) {
  return parser
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'version',
      abbr: 'V',
      negatable: false,
      help: 'Print the tool version.',
    )
    ..addOption(
      'path',
      abbr: 'p',
      valueHelp: 'path-to-search',
      help:
          'Location where search operation will be performed. Defaults to current directory.',
      defaultsTo: Directory.current.absolute.path,
    )
    ..addMultiOption(
      'include',
      abbr: 'i',
      valueHelp: 'files-to-include',
      help: 'Files included while searching. e.g. *.ts, src/**/include.',
    )
    ..addMultiOption(
      'exclude',
      abbr: 'e',
      valueHelp: 'files-to-exclude',
      help: 'Files excluded while searching. e.g. *.js, src/**/exclude.',
    )
    ..addFlag(
      'match-case',
      abbr: 'c',
      negatable: true,
      help: 'Match case of while searching.',
    )
    ..addFlag(
      'match-wholeword',
      abbr: 'w',
      negatable: true,
      help: 'Match whole word of while searchin.g',
    )
    ..addFlag(
      'use-regex',
      abbr: 'r',
      negatable: true,
      help: 'Use search term as regular expression while searching.',
    );
}
