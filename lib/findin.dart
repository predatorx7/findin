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

import 'findin_arguments.dart';
import 'search_record.dart';

export 'findin_arguments.dart';

class FindIn {
  final FindinParameters parameters;

  FindIn(this.parameters);

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
          for (int i = index - parameters.previewLinesAroundMatches;
              i < lines.length &&
                  i <= index + parameters.previewLinesAroundMatches;
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
      from: parameters.pathToSearch,
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

    return parameters.useColors
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

    return parameters.useColors
        ? prettyColorFormatMatchedValue()
        : prettyFormatMatchedValue();
  }

  Future<StringBuffer> toStringBufferAsPrettyStringWithHighlightedSearchTerm(
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

      return ' ${parameters.useColors ? prettyColorFormatLineNumber() : prettyFormatLineNumber()} ${it.$2}';
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
