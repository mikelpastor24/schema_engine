import 'dart:io';

/// Runs repository checks, stopping with the first failing command's exit code.
Future<void> main() async {
  final repository = Directory.fromUri(Platform.script.resolve('../')).path;
  Future<void> run(
    String executable,
    List<String> arguments,
    String path,
  ) async {
    stdout.writeln('Running $executable ${arguments.join(' ')} in $path');
    final process = await Process.start(
      Platform.isWindows ? '$executable.bat' : executable,
      arguments,
      workingDirectory: path,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final result = await process.exitCode;
    if (result != 0) {
      exit(result);
    }
  }

  await run('flutter', ['pub', 'get'], repository);
  await run('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'packages',
    'tool',
  ], repository);
  await run('flutter', ['analyze', '--no-pub'], repository);
  final engine =
      '$repository${Platform.pathSeparator}packages'
      '${Platform.pathSeparator}schema_engine';
  final ui =
      '$repository${Platform.pathSeparator}packages'
      '${Platform.pathSeparator}schema_ui';
  await run('dart', ['test'], engine);
  await run('flutter', ['test', '--no-pub'], ui);
  await run('flutter', [
    'test',
    '--no-pub',
  ], '$ui${Platform.pathSeparator}example');
  await run('dart', ['run', 'example/all_drafts.dart'], engine);
}
