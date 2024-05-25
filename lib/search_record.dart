import 'search.dart';

class SearchResultRecord {
  final String filePath;
  final Iterable<LineInfoWithMatches>? linesMatched;
  final Iterable<LineInfo>? linesPreview;

  const SearchResultRecord.completed({
    required this.filePath,
    required this.linesMatched,
    required this.linesPreview,
  });

  const SearchResultRecord.failed({required this.filePath})
      : linesMatched = null,
        linesPreview = null;

  int get totalMatches {
    final lines = linesMatched;
    if (lines == null) return 0;

    return lines.fold(0, (countOfMatches, line) {
      final matchesInLine = line.$3;

      return countOfMatches + matchesInLine.length;
    });
  }

  bool get hasResults {
    final lines = linesMatched;
    return lines != null && lines.isNotEmpty;
  }
}
