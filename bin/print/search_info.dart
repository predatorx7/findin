import 'package:duration/duration.dart';
import 'package:findin/console/output.dart';
import 'package:intl/intl.dart';

void printSearchInfo(
  int fileCount,
  int countOfMatches,
  DateTime startTime,
  DateTime endTime,
) {
  final searchDuration = endTime.difference(startTime);
  final searchDurationPretty = prettyDuration(
    searchDuration,
    tersity: DurationTersity.millisecond,
    delimiter: ', ',
    conjunction: ' and, ',
    abbreviated: true,
  );

  if (countOfMatches == 0) {
    console.out(
      'No results found. Review your settings for configured exclusions.',
    );
  } else {
    final countOfMatchesText = Intl.plural(
      countOfMatches,
      one: '$countOfMatches result',
      other: '$countOfMatches results',
    );
    final fileCountText = Intl.plural(
      fileCount,
      one: '$fileCount file',
      other: '$fileCount files',
    );

    console.out(
      'Found $countOfMatchesText from $fileCountText (in $searchDurationPretty)',
    );
  }
}
