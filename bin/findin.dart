import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:args/args.dart';
import 'package:findin/console/output.dart';
import 'package:findin/context.dart';
import 'package:findin/findin.dart';
import 'package:findin/providers/help.dart';
import 'package:findin/providers/verbose.dart';
import 'package:findin/spec.dart';

import 'build_parser.dart';
import 'usage.dart';

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser(ArgParser());
  try {
    final ArgResults results = argParser.parse(arguments);
    context
        .read(isHelpEnabledProvider.notifier)
        .update((state) => results.wasParsed('help'));
    context
        .read(isVerboseEnabledProvider.notifier)
        .update((state) => results.wasParsed('verbose'));

    if (context.read(isHelpEnabledProvider)) {
      printUsage(argParser);
      return;
    }

    if (results.wasParsed('version')) {
      console.out('findin version ${Spec.version}');
      console.out('Developed by Mushaheed Syed <smushaheed@gmail.com>');
      return;
    }

    // Act on the arguments provided.
    final searchReplaceArguments = [...results.rest];
    if (searchReplaceArguments.isNotEmpty) {
      console.verbose('[VERBOSE] All arguments: $searchReplaceArguments');
      final searchTerm = searchReplaceArguments.removeAt(0);
      final replaceTerm = searchReplaceArguments.isNotEmpty
          ? searchReplaceArguments.removeAt(0)
          : null;
      console.verbose({
        'search': searchTerm,
        'replace': replaceTerm,
      });

      final pathToSearch = results.option('path')!;

      final find = FindIn(
        pathToSearch: pathToSearch,
        filesToInclude: results.multiOption('include'),
        filesToExclude: results.multiOption('exclude'),
        matchCase: results.flag('match-case'),
        matchWholeWord: results.flag('match-wholeword'),
        useRegex: results.flag('use-regex'),
      );

      final resultFiles = await find.search(searchTerm);

      final matchedData = resultFiles.map((e) {
        final name = path.basename(e.file.path);
        final parentRelativePath =
            path.relative(e.file.parent.absolute.path, from: pathToSearch);
        final padLength = e.matchedLines.length.toString().length;
        final outputLines = e.matchedLines.entries.map((entry) {
          final key = entry.key;
          final value = entry.value;
          final lineNumber = key.toString().padRight(padLength);
          return '  $lineNumber: $value';
        });
        return ['> $name ($parentRelativePath)', ...outputLines, ''].join('\n');
      }).join('\n');

      final resultCount = resultFiles
          .map((e) => e.matchedLines.length)
          .fold(0, (previousValue, element) => previousValue + element);

      console.out('# $resultCount results in ${resultFiles.length} files');
      console.out(matchedData);
      if (replaceTerm != null) {
        find.replace(replaceTerm);
      }
    } else {
      printUsage(argParser);
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    console.out(e.message);
    console.out('');
    printUsage(argParser);
    exit(1);
  }
}
