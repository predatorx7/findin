import 'dart:io';
import 'package:args/args.dart';

ArgParser buildParser(ArgParser parser) {
  return parser
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      defaultsTo: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: true,
      defaultsTo: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'version',
      abbr: 'V',
      negatable: false,
      defaultsTo: false,
      help: 'Print the tool version.',
    )
    ..addSeparator(
      'Configure inclusion & exclusion of files and folders while searching',
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
      valueHelp: 'fs-path-to-include',
      help:
          'Add glob patterns for including files and directories while searching. e.g. *.ts, src/**/include.',
    )
    ..addMultiOption(
      'exclude',
      abbr: 'e',
      valueHelp: 'fs-path-to-exclude',
      help:
          'Add glob patterns for excluding files and directories while searching. e.g. *.js, src/**/exclude. Default exclusions can be removed by adding them in `include` cli option.',
      defaultsTo: [
        '**/.git',
        '**/.svn',
        '**/.hg',
        '**/CVS',
        '**/.DS_Store',
        '**/Thumbs.db',
      ],
    )
    ..addMultiOption(
      'ignore-file',
      abbr: 'x',
      valueHelp: 'ignore-files',
      defaultsTo: ['.gitignore', '.ignore'],
      help:
          'Files with glob patterns for including & excluding files & folders. e.g. .gitignore.',
    )
    ..addFlag(
      'use-ignore-files',
      negatable: true,
      defaultsTo: true,
      help: 'Whether to use ignore files.',
    )
    ..addSeparator(
      'Configure how the search term is used using these options',
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
      help: 'Match whole word of while searching.',
    )
    ..addFlag(
      'use-regex',
      abbr: 'r',
      negatable: true,
      help: 'Use search term as regular expression while searching.',
    )
    ..addSeparator(
      'Customise how results are shown',
    )
    ..addFlag(
      'use-colors',
      abbr: 'P',
      negatable: true,
      defaultsTo: true,
      help: 'Use colors when printing output on console.',
    )
    ..addOption(
      'lines',
      abbr: 'l',
      valueHelp: 'lines-around-matched-previews',
      help: 'Number of lines shown around matched lines.',
      defaultsTo: '2',
    )
    ..addSeparator(
      'Customise how replacement is performed',
    )
    ..addOption(
      'on-results',
      abbr: 'R',
      defaultsTo: 'prompt',
      allowed: ['prompt', 'replace-all', 'replace-first', 'do-nothing'],
      allowedHelp: {
        'prompt':
            'Will prompt for other available options after search results to decide replacement',
        'replace-all': 'Replace all matched results without prompt',
        'replace-first':
            'Replace only the first matched result without prompt.',
        'do-nothing': 'Only show results and quit',
      },
      valueHelp: 'replacement-mode',
      help: 'Decides how replacement of matched results are performed.',
    );
}
