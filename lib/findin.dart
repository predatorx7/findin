import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:ansi/ansi.dart' as ansi;
import 'package:path/path.dart' as path;

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
    return lines.fold(0, (totalMatches, line) {
      return search.allMatches(line.$2).length;
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

  Future<StringBuffer> toPrettyStringWithHighlightedSearchTerm(
    SearchResultRecord record,
    Pattern searchPattern,
  ) async {
    final fileName = path.basename(record.file.path);
    final parentRelativePath = path.relative(
      record.file.parent.absolute.path,
      from: pathToSearch,
    );
    final outputBuffer = StringBuffer();

    String prettyColorFormatFileInformation() {
      final o = StringBuffer();
      o.write(ansi.bold('⚬ $fileName '));
      o.write('> $parentRelativePath');
      return o.toString();
    }

    String prettyFormatFileInformation() {
      return '⚬ $fileName $parentRelativePath';
    }

    outputBuffer.writeln(
      useColors
          ? prettyColorFormatFileInformation()
          : prettyFormatFileInformation(),
    );

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

    final List<MatchedLineRecord> linesBuffer =
        record.extraLinesForPreview?.toList() ?? [];

    final linesWithHighlights = record.matchedLines?.map((e) {
      String lineWithHighlights = e.$2;

      for (final match in searchPattern.allMatches(e.$2)) {
        final value = match.group(0);
        if (value == null) continue;

        String prettyColorFormatMatchedValue() {
          return ansi.green(value);
        }

        String prettyFormatMatchedValue() {
          return ' > $value <';
        }

        lineWithHighlights = lineWithHighlights.replaceAll(
          value,
          useColors
              ? prettyColorFormatMatchedValue()
              : prettyFormatMatchedValue(),
        );
      }
      return (e.$1, lineWithHighlights);
    });

    if (linesWithHighlights != null) {
      linesBuffer.addAll(linesWithHighlights);
    }

    linesBuffer.sort((a, b) => a.$1.compareTo(b.$1));

    final prettyResultLines = linesBuffer.map((it) {
      final lineNumber = it.$1.toString().padRight(indexPadding);
      String prettyColorFormatLineNumber() {
        return ansi.blue(lineNumber);
      }

      String prettyFormatLineNumber() {
        return lineNumber;
      }

      return ' ${useColors ? prettyColorFormatLineNumber() : prettyFormatLineNumber()} ${it.$2}';
    });

    outputBuffer.writeAll(prettyResultLines, '\n');

    return outputBuffer;
  }
}
