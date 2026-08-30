// Reading command line arguments and the environment, without a package.

import 'dart:io';

class Options {
  Options({this.verbose = false, this.repeat = 1, this.names = const []});

  final bool verbose;
  final int repeat;
  final List<String> names;
}

Options parse(List<String> arguments) {
  var verbose = false;
  var repeat = 1;
  final names = <String>[];

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];

    switch (argument) {
      case '-v':
      case '--verbose':
        verbose = true;
      case '-n':
      case '--repeat':
        if (index + 1 >= arguments.length) {
          throw FormatException('$argument needs a count');
        }
        repeat = int.parse(arguments[++index]);
      case '-h':
      case '--help':
        usage();
        exit(0);
      default:
        if (argument.startsWith('-')) {
          throw FormatException('unknown option: $argument');
        }
        names.add(argument);
    }
  }
  return Options(verbose: verbose, repeat: repeat, names: names);
}

void usage() {
  stdout.writeln('usage: dart cli_args.dart [-v] [-n COUNT] NAME...');
}

void main(List<String> arguments) {
  final Options options;

  try {
    options = parse(arguments.isEmpty ? ['-n', '2', 'Alder Cross'] : arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    usage();
    exit(2);
  }

  if (options.names.isEmpty) {
    usage();
    exit(2);
  }

  if (options.verbose) {
    stderr.writeln('greeting ${options.names.length} name(s) ${options.repeat} time(s)');
    stderr.writeln('running on ${Platform.operatingSystem}');
  }

  for (var round = 0; round < options.repeat; round++) {
    for (final name in options.names) {
      stdout.writeln('Hello, $name!');
    }
  }
}
