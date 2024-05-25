import 'dart:io';

typedef LineInfo = (int index, String text);
typedef LineInfoWithMatches = (
  int index,
  String text,
  Iterable<Match> matches,
);
typedef ResultLines = ({
  Iterable<LineInfoWithMatches> linesMatched,
  Iterable<LineInfo> linesPreview,
});

Future<ResultLines?> searchInFile(
  String filePath,
  Pattern searchPattern,
  int previewLinesAroundMatches,
) async {
  try {
    final file = File(filePath);
    final lines = await file.readAsLines();

    if (lines.isEmpty) return null;

    final linesWithPattern = lines.indexed.where((entry) {
      return entry.$2.contains(searchPattern);
    });

    if (linesWithPattern.isEmpty) return null;

    final linesWithMatches = linesWithPattern.map((e) {
      return (e.$1, e.$2, searchPattern.allMatches(e.$2));
    });

    final previewLines = findPreviewLinesFrom(
      linesWithPattern,
      previewLinesAroundMatches,
      lines,
    );

    return (
      linesMatched: linesWithMatches,
      linesPreview: previewLines,
    );
  } on FileSystemException {
    // unsupported file
    return null;
  }
}

Iterable<LineInfo> findPreviewLinesFrom(
  Iterable<LineInfo> matchedLines,
  int previewLinesAroundMatches,
  List<String> lines,
) {
  final matchedIndices = matchedLines.map((e) => e.$1).toSet();
  final previewLineIndices = findPreviewLineIndices(
    matchedIndices,
    previewLinesAroundMatches,
    lines.length,
  );
  final previewLines = lines.indexed.where((record) {
    return previewLineIndices.contains(record.$1);
  });
  return previewLines;
}

Set<int> findPreviewLineIndices(
  Set<int> matchedIndices,
  int previewLinesAroundMatches,
  int totalLines,
) {
  final requiredIndices = <int>{};
  for (var index in matchedIndices) {
    final previewStart = index - previewLinesAroundMatches;
    final previewEnd = index + previewLinesAroundMatches;
    for (int i = previewStart; i < totalLines && i <= previewEnd; i++) {
      if (i < 0) continue;
      if (matchedIndices.contains(i)) continue;
      requiredIndices.add(i);
    }
  }
  return requiredIndices;
}
