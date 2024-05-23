import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:ansi/ansi.dart' as ansi;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart' as intl;

import 'package:findin/console/output.dart';
import 'package:findin/context.dart';
import 'package:findin/providers/verbose.dart';

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

class FindIn {
  final String pathToSearch;
  final List<String> filesToInclude;
  final List<String> filesToExclude;
  final int previewLinesAroundMatches;
  final bool matchCase;
  final bool matchWholeWord;
  final bool useRegex;
  final bool useColors;

  FindIn({
    required this.pathToSearch,
    required this.filesToInclude,
    required this.filesToExclude,
    required this.previewLinesAroundMatches,
    required this.matchCase,
    required this.matchWholeWord,
    required this.useRegex,
    required this.useColors,
  }) {
    console.verbose(toJson());
  }

  Map<String, Object?> toJson() {
    return {
      'pathToSearch': pathToSearch,
      'filesToInclude': filesToInclude,
      'filesToExclude': filesToExclude,
      'previewLinesAroundMatches': previewLinesAroundMatches,
      'matchCase': matchCase,
      'matchWholeWord': matchWholeWord,
      'useRegex': useRegex,
      'useColors': useColors,
    };
  }

  bool get isVerboseModeEnabled => context.read(isVerboseEnabledProvider);

  Future<SearchResultRecord> transformWithSearch(
    File file,
    Pattern searchPattern,
  ) async {
    try {
      final lines = await file.readAsLines();
      final matchedLines = await Isolate.run(() {
        return lines.indexed.where((entry) {
          return entry.$2.contains(searchPattern);
        });
      });
      final extraLinesForPreview = await Isolate.run(() {
        final matchedIndices = matchedLines.map((e) => e.$1).toSet();
        final requiredIndices = <int>{};
        for (var index in matchedIndices) {
          for (int i = index - previewLinesAroundMatches;
              i < lines.length && i <= index + previewLinesAroundMatches;
              i++) {
            if (i < 0) continue;
            if (matchedIndices.contains(i)) continue;
            requiredIndices.add(i);
          }
        }
        return lines.indexed.where((record) {
          return requiredIndices.contains(record.$1);
        });
      });
      return SearchResultRecord.completed(
        file: file,
        matchedLines: matchedLines,
        extraLinesForPreview: extraLinesForPreview,
      );
    } catch (e) {
      console.verbose(e);
      return SearchResultRecord.failed(file: file);
    }
  }

  Stream<SearchResultRecord> search(Pattern searchPattern) {
    final dir = Directory(pathToSearch);

    final matchedFilesStream = dir
        .list(recursive: true)
        .asyncMap(
          (entity) async => (
            entity: entity,
            isFile: await FileSystemEntity.isFile(entity.path),
          ),
        )
        .where((event) => event.isFile)
        .map((event) => File(event.entity.path))
        .asyncMap((file) => transformWithSearch(file, searchPattern))
        .where((event) {
      final matchedLines = event.matchedLines;
      return matchedLines != null && matchedLines.isNotEmpty;
    });

    return matchedFilesStream;
  }

  @protected
  String toFileHeaderText(
    SearchResultRecord record,
    Pattern searchPattern,
  ) {
    final fileName = path.basename(record.file.path);
    final parentRelativePath = path.relative(
      record.file.parent.absolute.path,
      from: pathToSearch,
    );

    final matchCount = record.findAllMatchCount(searchPattern);
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

    return useColors
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
      return ' > $value <';
    }

    return useColors
        ? prettyColorFormatMatchedValue()
        : prettyFormatMatchedValue();
  }

  Future<StringBuffer> toPrettyStringWithHighlightedSearchTerm(
    SearchResultRecord record,
    Pattern searchPattern,
    String? replacementValue,
  ) async {
    final outputBuffer = StringBuffer();

    outputBuffer.writeln(toFileHeaderText(record, searchPattern));

    int maxLineIndex(int oldBiggestLineIndex, (int, String) e) {
      final lineIndex = e.$1;
      return lineIndex > oldBiggestLineIndex ? lineIndex : oldBiggestLineIndex;
    }

    final maxIndex = math.max<int>(
      record.extraLinesForPreview?.fold<int>(0, maxLineIndex) ?? 0,
      record.matchedLines?.fold<int>(0, maxLineIndex) ?? 0,
    );

    // string length of max index
    final indexPadding = maxIndex.toString().length;

    final linesWithHighlights = record.matchedLines?.map((e) {
      String lineWithHighlights = e.$2;

      for (final match in searchPattern.allMatches(e.$2)) {
        final value = match.group(0);
        if (value == null) continue;

        lineWithHighlights = lineWithHighlights.replaceAll(
          value,
          prettyFormatMatchedValue(value, replacementValue),
        );
      }
      return (e.$1, lineWithHighlights);
    });

    final List<MatchedLineRecord> linesBuffer = [
      ...?record.extraLinesForPreview,
      ...?linesWithHighlights,
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    String transformMatchedLineToPrettyString(MatchedLineRecord it) {
      final lineNumber = it.$1.toString().padRight(indexPadding);
      String prettyColorFormatLineNumber() {
        return ansi.blue(lineNumber);
      }

      String prettyFormatLineNumber() {
        return lineNumber;
      }

      return ' ${useColors ? prettyColorFormatLineNumber() : prettyFormatLineNumber()} ${it.$2}';
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
}
