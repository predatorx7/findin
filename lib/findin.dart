import 'dart:io';
import 'dart:math' as math;
import 'package:ansi/ansi.dart' as ansi;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart' as intl;
import 'package:glob/glob.dart' as glob;

import 'config.dart';
import 'findin_options.dart';
import 'search.dart';
import 'search_record.dart';

export 'findin_options.dart';

typedef ReplacementResult = ({int filesChanged, int replacements});

class FindIn {
  final FindinOption option;

  FindIn(this.option);

  @protected
  Future<SearchResultRecord> searchBy(
    String filePath,
  ) async {
    final searchPattern = option.searchPattern;
    final previewLinesAroundMatches = option.previewLinesAroundMatches;

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
    final dir = Directory(option.pathToSearch);
    final includePath = option.fileSystemPathsToInclude.map(glob.Glob.new);
    final exludePath = option.fileSystemPathsToExclude.map(glob.Glob.new);
    final includePathFromIgnore = <glob.Glob>[];
    final excludePathFromIgnore = <glob.Glob>[];

    final matchedFilesStream = dir
        .list(recursive: true)
        .asyncMap(
          (entity) async => (
            entity: entity,
            isFile: await FileSystemEntity.isFile(entity.path),
          ),
        )
        .where((event) => event.isFile)
        .asyncMap((entry) async {
          if (option.ignoreFiles.isNotEmpty) {
            final entity = entry.entity;
            final entityPath = entity.absolute.path;
            final parentPath = entity.parent.absolute.path;
            final isIgnoreFile = option.ignoreFiles.any((ignoreFilePath) {
              // path should match with full path or basename

              // is a match with ignore path
              if (path.equals(ignoreFilePath, entityPath) ||
                  path.equals(ignoreFilePath, path.basename(entityPath))) {
                return true;
              }
              // is a match with ignore path glob pattern
              final ignoreFileGlob = glob.Glob(ignoreFilePath);
              if (ignoreFileGlob.matches(entityPath) ||
                  ignoreFileGlob.matches(path.basename(entityPath))) {
                return true;
              }
              return false;
            });
            if (isIgnoreFile) {
              try {
                final ignoreFileLines = await File(entity.path).readAsLines();
                final inclusions = ignoreFileLines
                    .where((it) => !it.startsWith('!'))
                    .map((ignorePath) => ignorePath.contains(path.separator)
                        ? ignorePath
                        : path.join(parentPath, ignorePath))
                    .map(glob.Glob.new);
                final exclusions = ignoreFileLines
                    .where((it) => it.startsWith('!') && it.length >= 2)
                    .map((ignorePath) => ignorePath.substring(1))
                    .map((ignorePath) => ignorePath.contains(path.separator)
                        ? ignorePath
                        : path.join(parentPath, ignorePath))
                    .map(glob.Glob.new);
                includePathFromIgnore.addAll(inclusions);
                excludePathFromIgnore.addAll(exclusions);
              } on FileSystemException {
                // do nothing.
              }
            }
          }

          return entry;
        })
        .where((entry) {
          final entity = entry.entity;
          if (includePath.isNotEmpty) {
            final isIncluded = includePath.any(
              (pathGlob) => pathGlob.matches(entity.path),
            );
            if (!isIncluded) return false;
          }
          if (exludePath.isNotEmpty) {
            final isExcluded = exludePath.any(
              (pathGlob) => pathGlob.matches(entity.path),
            );
            if (isExcluded) return false;
          }
          // TODO: Fix inclusion and exclusion through ignore files
          // if (excludePathFromIgnore.isNotEmpty) {
          //   final isExcluded = excludePathFromIgnore.any(
          //     (pathGlob) => pathGlob.matches(entity.path),
          //   );
          //   if (isExcluded) {
          //     if (includePathFromIgnore.isNotEmpty) {
          //       final isIncluded = includePathFromIgnore.any(
          //         (pathGlob) => pathGlob.matches(entity.path),
          //       );
          //       if (!isIncluded) return false;
          //     }
          //   }
          // }

          return true;
        })
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
      from: option.pathToSearch,
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
          line = line.replaceAll(option.searchPattern, replaceTerm);
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
