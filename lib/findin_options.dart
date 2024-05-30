import 'dart:io';

import 'package:args/args.dart';

import 'validate_format.dart';

enum OnResults {
  prompt,
  replaceAll,
  replaceFirst,
  doNothing;

  static from(String value) {
    switch (value) {
      case 'prompt':
        return OnResults.prompt;
      case 'replace-all':
        return OnResults.replaceAll;
      case 'replace-first':
        return OnResults.replaceFirst;
      case 'do-nothing':
        return OnResults.doNothing;
      default:
        throw FormatException(
          'Invalid $value when converting to $OnResults',
        );
    }
  }
}

class FindinOptions {
  final String pathToSearch;
  final Set<String> fileSystemPathsToInclude;
  final Set<String> fileSystemPathsToExclude;
  final Set<String>? ignoreFiles;
  final int previewLinesAroundMatches;
  final bool matchCase;
  final bool matchWholeWord;
  final Pattern searchPattern;
  final OnResults onResults;

  const FindinOptions({
    required this.pathToSearch,
    required this.fileSystemPathsToInclude,
    required this.fileSystemPathsToExclude,
    required this.ignoreFiles,
    required this.previewLinesAroundMatches,
    required this.matchCase,
    required this.matchWholeWord,
    required this.searchPattern,
    required this.onResults,
  });

  FindinOptions.fromArgResults(
    ArgResults results, {
    required String searchTerm,
    required Iterable<String> defaultFilesToExclude,
  })  : pathToSearch = results.option('path') ?? Directory.current.path,
        fileSystemPathsToInclude = results.multiOption('include').toSet(),
        fileSystemPathsToExclude = {
          ...defaultFilesToExclude,
          ...results.multiOption('exclude'),
        },
        ignoreFiles = results.flag('use-ignore-files')
            ? results.multiOption('ignore-file').toSet()
            : null,
        previewLinesAroundMatches = _getValidPreviewLinesAroundMatches(
          results.option('lines') ?? '2',
        ),
        matchCase = results.flag('match-case'),
        matchWholeWord = results.flag('match-wholeword'),
        onResults = OnResults.from(results.option('on-results')!),
        searchPattern =
            results.flag('use-regex') ? RegExp(searchTerm) : searchTerm {
    validateFormat(
      !FileSystemEntity.isFileSync(pathToSearch),
      'Path "$pathToSearch" is not a directory',
    );
    validateFormat(
      FileSystemEntity.isDirectorySync(pathToSearch),
      'No directory found at "$pathToSearch"',
    );
    validateFormat(
      previewLinesAroundMatches >= 0,
      'The \'lines\' for preview should be greater than 0',
    );
  }

  static int _getValidPreviewLinesAroundMatches(String value) {
    try {
      return int.parse(value);
    } on FormatException {
      throw FormatException('Invalid argument was provided for lines', value);
    }
  }
}
