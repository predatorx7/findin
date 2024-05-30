import 'dart:io';
import 'dart:math' as math;
import 'package:ansi/ansi.dart' as ansi;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart' as intl;

import 'config.dart';
import 'findin_options.dart';
import 'search.dart';
import 'search_record.dart';

export 'findin_options.dart';

typedef ReplacementResult = ({int filesChanged, int replacements});

class FindIn {
  final FindinOptions parameters;

  FindIn(this.parameters);

  @protected
  Future<SearchResultRecord> searchBy(
    String filePath,
  ) async {
    final searchPattern = parameters.searchPattern;
    final previewLinesAroundMatches = parameters.previewLinesAroundMatches;

    final result = await searchInFile(
      filePath,
      searchPattern,
      previewLinesAroundMatches,
    );

    if (result == null) return SearchResultRecord.failed(filePath: filePath);

    return SearchResultRecord.completed(
      filePath: filePath,
      linesMatched: result.linesMatched,
      linesPreview: result.linesPreview,
    );
  }

  Stream<SearchResultRecord> search() {
    final dir = Directory(parameters.pathToSearch);

    final matchedFilesStream = dir
        .list(recursive: true)
        .asyncMap(
          (entity) async => (
            entity: entity,
            isFile: await FileSystemEntity.isFile(entity.path),
          ),
        )
        .where((event) => event.isFile)
        .asyncMap((event) => searchBy(event.entity.path))
        .where((result) => result.hasResults);

    return matchedFilesStream;
  }

  @protected
  String toFileHeaderText(
    SearchResultRecord record,
  ) {
    final fileName = path.basename(record.filePath);
    final parentRelativePath = path.relative(
      FileSystemEntity.parentOf(record.filePath),
      from: parameters.pathToSearch,
    );

    final matchCount = record.totalMatches;
    final matchCountText = intl.Intl.plural(
      matchCount,
      one: '$matchCount match',
      other: '$matchCount matches',
    );

    String prettyColorFormatFileInformation() {
      final o = StringBuffer();
      o.write(ansi.bold('⚬ $fileName '));
      o.write('> $parentRelativePath ($matchCountText)');
      return o.toString();
    }

    String prettyFormatFileInformation() {
      return '⚬ $fileName $parentRelativePath ($matchCountText)';
    }

    return FindinConfig.main.isConsoleColorsEnabled
        ? prettyColorFormatFileInformation()
        : prettyFormatFileInformation();
  }

  String prettyFormatMatchedValue(String value, String? replacementValue) {
    String prettyColorFormatMatchedValue() {
      if (replacementValue != null) {
        return '${ansi.bgRed(ansi.strikeThrough(value))}${ansi.bgGreen(replacementValue)}';
      }
      return ansi.bgGreen(value);
    }

    String prettyFormatMatchedValue() {
      return value;
    }

    return FindinConfig.main.isConsoleColorsEnabled
        ? prettyColorFormatMatchedValue()
        : prettyFormatMatchedValue();
  }

  Future<StringBuffer> toStringBufferAsPrettyStringWithHighlightedSearchTerm(
    SearchResultRecord record,
    String? replacementValue,
  ) async {
    final outputBuffer = StringBuffer();

    outputBuffer.writeln(toFileHeaderText(record));

    int maxLineIndex(int oldBiggestLineIndex, (int, String) e) {
      final lineIndex = e.$1;
      return lineIndex > oldBiggestLineIndex ? lineIndex : oldBiggestLineIndex;
    }

    final maxIndex = math.max<int>(
      record.linesPreview?.fold<int>(0, maxLineIndex) ?? 0,
      record.linesMatched?.fold<int>(
            0,
            (i, it) => maxLineIndex(i, (it.$1, it.$2)),
          ) ??
          0,
    );

    // string length of max index
    final indexPadding = maxIndex.toString().length;

    final linesWithHighlights = record.linesMatched?.map((e) {
      String lineWithHighlights = e.$2;
      int indexChange = 0;

      for (final match in e.$3) {
        final value = match.group(0);
        if (value == null) continue;

        final buffer = StringBuffer();
        buffer.write(
          lineWithHighlights.substring(0, match.start + indexChange),
        );
        final highlightedText = prettyFormatMatchedValue(
          value,
          replacementValue,
        );
        buffer.write(highlightedText);
        buffer.write(lineWithHighlights.substring(match.end + indexChange));
        lineWithHighlights = buffer.toString();

        final highlightedTextLength = highlightedText.length;
        final matchLength = match.end - match.start;
        final changeDifference = highlightedTextLength - matchLength;
        indexChange = indexChange + changeDifference;
      }
      return (e.$1, lineWithHighlights);
    });

    final List<LineInfo> linesBuffer = [
      ...?record.linesPreview,
      ...?linesWithHighlights,
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    String transformMatchedLineToPrettyString(LineInfo it) {
      final lineNumber = (it.$1 + 1).toString().padRight(indexPadding);
      String prettyColorFormatLineNumber() {
        return ansi.blue(lineNumber);
      }

      String prettyFormatLineNumber() {
        return lineNumber;
      }

      final formattedLineNumber = FindinConfig.main.isConsoleColorsEnabled
          ? prettyColorFormatLineNumber()
          : prettyFormatLineNumber();
      return ' $formattedLineNumber ${it.$2}';
    }

    for (int i = 0; i < linesBuffer.length; i++) {
      final lineInfo = linesBuffer[i];
      if (i > 0) {
        final previousLineIndex = linesBuffer[i - 1].$1;
        final currentLineIndex = lineInfo.$1;
        if (currentLineIndex - previousLineIndex > 1) {
          // add a blank line if this is a different section from same file
          outputBuffer.writeln();
        }
      }
      outputBuffer.writeln(transformMatchedLineToPrettyString(lineInfo));
    }

    // add blank line after each file
    outputBuffer.writeln();

    return outputBuffer;
  }

  Future<ReplacementResult> replaceAll(
    List<SearchResultRecord> searchResult,
    String replaceTerm,
  ) async {
    final temp = Directory.systemTemp;
    await temp.create(recursive: true);
    int countOfFilesChanged = 0;
    int countOfReplacements = 0;
    for (final result in searchResult) {
      final matchedLineIndices = result.linesMatched?.map((e) => e.$1).toSet();
      if (matchedLineIndices == null || matchedLineIndices.isEmpty) continue;
      final tempFile = File(path.join(
        temp.path,
        DateTime.now().millisecond.toString(),
      ));
      await tempFile.create();
      final tempFileIO = tempFile.openWrite(mode: FileMode.writeOnlyAppend);
      final targetFile = File(result.filePath);
      final lines = await targetFile.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (matchedLineIndices.contains(i)) {
          line = line.replaceAll(parameters.searchPattern, replaceTerm);
        }
        tempFileIO.writeln(line);
      }
      await tempFileIO.close();
      await targetFile.delete();
      await tempFile.rename(result.filePath);
      countOfFilesChanged++;
      countOfReplacements += result.totalMatches;
    }
    return (
      filesChanged: countOfFilesChanged,
      replacements: countOfReplacements
    );
  }
}
