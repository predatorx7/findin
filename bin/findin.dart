import 'dart:io';

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
    if (searchReplaceArguments.isEmpty) {
      throw FormatException('No search argument provided');
    }

    console.verbose('[VERBOSE] All arguments: $searchReplaceArguments');
    final searchTerm = searchReplaceArguments.removeAt(0);
    if (searchTerm.isEmpty) {
      throw FormatException('Cannot search using an empty term');
    }

    final replaceTerm = searchReplaceArguments.isNotEmpty
        ? searchReplaceArguments.removeAt(0)
        : null;
    console.verbose({
      'search': searchTerm,
      'replace': replaceTerm,
    });

    final pathToSearch = results.option('path')!;
    final useRegex = results.flag('use-regex');

    final find = FindIn(
      pathToSearch: pathToSearch,
      filesToInclude: results.multiOption('include'),
      filesToExclude: results.multiOption('exclude'),
      previewLinesAroundMatches:
          int.tryParse(results.option('lines') ?? '2') ?? 2,
      matchCase: results.flag('match-case'),
      matchWholeWord: results.flag('match-wholeword'),
      useRegex: useRegex,
      useColors: results.flag('use-colors'),
    );

    final Pattern searchPattern = useRegex ? RegExp(searchTerm) : searchTerm;

    final searchResultStream = find.search(searchPattern).asBroadcastStream();
    int fileCount = 0;
    int countOfMatches = 0;

    if (replaceTerm == null) {
      // just show results of search
      final outputLines = searchResultStream.asyncMap((event) {
        fileCount++;
        countOfMatches += event.findAllMatchCount(searchPattern);

        return find.toPrettyStringWithHighlightedSearchTerm(
          event,
          searchPattern,
        );
      });
      await for (final line in outputLines) {
        console.out(line);
      }
    } else {
      // show replacements in search results
      console.warn('! Replace in development');
    }

    console.out('# $countOfMatches results in $fileCount files');
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    console.out(e.message);
    console.out('');
    printUsage(argParser);
    exit(1);
  }
}
