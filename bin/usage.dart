
import 'package:args/args.dart';
import 'package:findin/console/output.dart';

void printUsage(ArgParser argParser) {
  console.out(
      '''usage: findin [-V | --version] [-h | --help] [-v | --verbose]
              [-p | --path=<path-to-search>] [-i | --include=<files-to-include>] [-e | --exclude=<files-to-exclude>]
              [-c | --match-case] [-w | --match-wholeword] [-r | --use-regex]
              <search> [<replace>]
''');
  console.out(argParser.usage);
}
