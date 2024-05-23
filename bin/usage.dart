import 'package:args/args.dart';
import 'package:findin/console/output.dart';

void printUsage(ArgParser argParser) {
  console.out('''usage: findin [-V | --version] [-h | --help] [-v | --verbose]
              [-p | --path=<path-to-search>] [-i | --include=<files-to-include>] [-e | --exclude=<files-to-exclude>]
              [-l | --lines=<lines-around-matched-previews>]
              [-c | --match-case] [-w | --match-wholeword] [-r | --use-regex] [-P | --use-colors]
              <search> [<replace>]
''');
  console.out(argParser.usage);
}
