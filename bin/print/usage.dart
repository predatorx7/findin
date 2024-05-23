import 'package:args/args.dart';
import 'package:findin/console/output.dart';

void printUsage(ArgParser argParser) {
  console.out('''
Usage:  findin  [arguments] <search> [<replace>]

        findin  [-v | --verbose] [-V | --version] [-h | --help]
                [-p | --path=<path-to-search>] [-i | --include=<files-to-include>] [-e | --exclude=<files-to-exclude>] [-x, --exclusion-file=<files-with-exclusions>]
                [-c | --match-case] [-w | --match-wholeword] [-r | --use-regex]
                [-P | --use-colors] [-l, --lines=<lines-around-matched-previews>]
                <search-expression> [<replace>]

Available flags and options:
''');
  console.out(argParser.usage);
}
