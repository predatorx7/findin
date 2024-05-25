import 'package:findin/console/output.dart';
import 'package:findin/search_record.dart';

Future<void> printSearchResults(
  List<SearchResultRecord> searchResult,
  Future<StringBuffer> Function(SearchResultRecord record) toStringBuffer,
) async {
  for (final event in searchResult) {
    final line = await toStringBuffer(event);
    console.out(line.toString());
  }
}
