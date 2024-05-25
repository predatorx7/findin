import 'dart:io';

import 'package:args/args.dart';
import 'package:findin/console/output.dart';
import 'package:findin/context.dart';
import 'package:findin/findin.dart';
import 'package:findin/providers/verbose.dart';

import 'build_parser.dart';
import 'print/search_info.dart';
import 'print/search_results.dart';
import 'print/usage.dart';
import 'print/version.dart';

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser(ArgParser());
  try {
    final ArgResults results = argParser.parse(arguments);
    context
        .read(isVerboseEnabledProvider.notifier)
        .update((state) => results.wasParsed('verbose'));

    if (results.wasParsed('help')) {
      return printUsage(argParser);
    }

    if (results.wasParsed('version')) {
      return printVersion();
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

    final find = FindIn(FindinOptions.fromArgResults(
      results,
      searchTerm: searchTerm,
      defaultFilesToExclude: (argParser.defaultFor('exclude') as List<String>),
    ));

    final startTime = DateTime.now();

    final searchResult = await find.search().toList();

    final endTime = DateTime.now();

    final fileCount = searchResult.length;
    final countOfMatches = searchResult.fold(
      0,
      (count, it) {
        final matches = it.totalMatches;
        return count + matches;
      },
    );

    await printSearchResults(searchResult, (event) {
      return find.toStringBufferAsPrettyStringWithHighlightedSearchTerm(
        event,
        replaceTerm,
      );
    });

    printSearchInfo(fileCount, countOfMatches, startTime, endTime);
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    console.error('${e.message}\n');
    printUsage(argParser);
    exit(1);
  }
}
