import 'dart:io';

import 'package:args/args.dart';

class FindinParameters {
  final String pathToSearch;
  final Set<String> fileSystemPathsToInclude;
  final Set<String> fileSystemPathsToExclude;
  final Set<String> exclusionFiles;
  final int previewLinesAroundMatches;
  final bool matchCase;
  final bool matchWholeWord;
  final bool useRegex;
  final bool useColors;
  final String searchTerm;

  const FindinParameters({
    required this.pathToSearch,
    required this.fileSystemPathsToInclude,
    required this.fileSystemPathsToExclude,
    required this.exclusionFiles,
    required this.previewLinesAroundMatches,
    required this.matchCase,
    required this.matchWholeWord,
    required this.useRegex,
    required this.useColors,
    required this.searchTerm,
  });

  FindinParameters.fromArgResults(
    ArgResults results, {
    required this.searchTerm,
    required Iterable<String> defaultFilesToExclude,
  })  : pathToSearch = results.option('path') ?? Directory.current.path,
        fileSystemPathsToInclude = results.multiOption('include').toSet(),
        fileSystemPathsToExclude = {
          ...defaultFilesToExclude,
          ...results.multiOption('exclude'),
        },
        exclusionFiles = results.multiOption('exclusion-file').toSet(),
        previewLinesAroundMatches = _getValidPreviewLinesAroundMatches(
          results.option('lines') ?? '2',
        ),
        matchCase = results.flag('match-case'),
        matchWholeWord = results.flag('match-wholeword'),
        useRegex = results.flag('use-regex'),
        useColors = results.flag('use-colors');

  static int _getValidPreviewLinesAroundMatches(String value) {
    try {
      return int.parse(value);
    } on FormatException {
      throw FormatException('Invalid argument was provided for lines', value);
    }
  }

  Pattern get searchPattern => useRegex ? RegExp(searchTerm) : searchTerm;
}
