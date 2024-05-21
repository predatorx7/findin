import 'dart:io';
import 'dart:isolate';

import 'package:findin/console/output.dart';
import 'package:findin/context.dart';
import 'package:findin/providers/verbose.dart';

typedef FindInSearchResult = Iterable<
    ({List<String> content, File file, Map<int, String> matchedLines})>;

class FindIn {
  final String pathToSearch;
  final List<String> filesToInclude;
  final List<String> filesToExclude;
  final bool matchCase;
  final bool matchWholeWord;
  final bool useRegex;

  FindIn({
    required this.pathToSearch,
    required this.filesToInclude,
    required this.filesToExclude,
    required this.matchCase,
    required this.matchWholeWord,
    required this.useRegex,
  }) {
    console.verbose({
      'pathToSearch': pathToSearch,
      'filesToInclude': filesToInclude,
      'filesToExclude': filesToExclude,
      'matchCase': matchCase,
      'matchWholeWord': matchWholeWord,
      'useRegex': useRegex,
    });
  }

  bool get isVerboseModeEnabled => context.read(isVerboseEnabledProvider);

  Future<bool> isSearchTermInLine(String line, String searchTerm) {
    return Isolate.run(() {
      return line.contains(searchTerm);
    });
  }

  Future<FindInSearchResult> search(String searchTerm) async {
    if (searchTerm.isEmpty) {
      throw FormatException('Cannot search using an empty term');
    }
    final dir = Directory(pathToSearch);
    final entities = dir.listSync(recursive: true);
    final files = (await Future.wait(entities.map((entity) async {
      if (await FileSystemEntity.isFile(entity.path)) {
        return File(entity.path);
      }
      return null;
    })))
        .whereType<File>();
    final result = (await Future.wait(files.map((file) async {
      final lines = await file.readAsLines().catchError(
            (_) async => const <String>[],
          );

      final matchedLines = <int, String>{};
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!await isSearchTermInLine(line, searchTerm)) continue;
        matchedLines[i] = line;
      }
      return (file: file, content: lines, matchedLines: matchedLines);
    })))
        .where((data) => data.matchedLines.isNotEmpty);
    return result;
  }

  void replace(String replaceTerm) {}
}
