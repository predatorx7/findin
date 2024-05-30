import 'package:duration/duration.dart';
import 'package:findin/console/output.dart';
import 'package:findin/findin.dart';
import 'package:intl/intl.dart';

void printReplacementInfo(
  ReplacementResult replacements,
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
  if (replacements.filesChanged == 0) {
    console.out(
      'No replacements were made.',
    );
  } else {
    final filesChangedCount = Intl.plural(
      replacements.filesChanged,
      one: '${replacements.filesChanged} file',
      other: '${replacements.filesChanged} files',
    );
    console.out(
      'Replaced ${replacements.replacements} in $filesChangedCount (in $searchDurationPretty)',
    );
  }
}
