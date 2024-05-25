import 'dart:io';

typedef MatchedLineRecord = (int lineIndex, String lineText);

class SearchResultRecord {
  final File file;
  final Iterable<MatchedLineRecord>? matchedLines;
  final Iterable<MatchedLineRecord>? extraLinesForPreview;

  const SearchResultRecord.completed({
    required this.file,
    required this.matchedLines,
    required this.extraLinesForPreview,
  });

  const SearchResultRecord.failed({required this.file})
      : matchedLines = null,
        extraLinesForPreview = null;

  int findAllMatchCount(Pattern search) {
    final lines = matchedLines;
    if (lines == null) return 0;

    return lines.fold(0, (countOfMatches, line) {
      final matchesInLine = search.allMatches(line.$2);

      return countOfMatches + matchesInLine.length;
    });
  }
}
