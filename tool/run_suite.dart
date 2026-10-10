import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

/// Runs external official fixtures without a test-runner subprocess.
Future<void> main(List<String> arguments) async {
  final suiteRoot = arguments.isEmpty
      ? Platform.environment['SCHEMA_ENGINE_TEST_SUITE']
      : arguments[0];
  if (suiteRoot == null) {
    stderr.writeln('Pass the external JSON Schema Test Suite directory.');
    exitCode = 64;
    return;
  }
  final directory = Directory('$suiteRoot/tests');
  const supported = {
    'draft3',
    'draft4',
    'draft6',
    'draft7',
    'draft2019-09',
    'draft2020-12',
  };
  final failures = <Map<String, Object?>>[];
  final blocked = <Map<String, Object?>>[];
  final counts = <String, int>{};
  final excluded =
      directory
          .listSync()
          .whereType<Directory>()
          .map((entry) => entry.path.replaceAll('\\', '/').split('/').last)
          .where((name) => !supported.contains(name))
          .toList()
        ..sort();
  final resources = <Uri, Object?>{};
  final remote = Directory('$suiteRoot/remotes');
  if (remote.existsSync()) {
    for (final file in remote.listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith('.json')) {
        final name = file.path
            .substring(remote.path.length + 1)
            .replaceAll('\\', '/');
        resources[Uri.parse('http://localhost:1234/$name')] = decodeJson(
          file.readAsStringSync(),
        );
      }
    }
  }
  final files =
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .where(
            (file) => file.path
                .replaceAll('\\', '/')
                .split('/')
                .any(supported.contains),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final version = path.split('/').firstWhere(supported.contains);
    final draft = switch (version) {
      'draft3' => SchemaDraft.draft3,
      'draft4' => SchemaDraft.draft4,
      'draft6' => SchemaDraft.draft6,
      'draft7' => SchemaDraft.draft7,
      'draft2019-09' => SchemaDraft.draft201909,
      _ => SchemaDraft.draft202012,
    };
    final groups = decodeJson(file.readAsStringSync()) as List<Object?>;
    for (final rawGroup in groups) {
      final group = rawGroup! as Map<String, Object?>;
      try {
        final schema = JsonSchema.fromJson(group['schema'], draft: draft);
        final validator = await schema.compileAsync(
          options: SchemaOptions(
            resolver: (uri) async {
              if (!resources.containsKey(uri)) {
                throw ReferenceException(
                  uri,
                  'The external suite has no matching remote resource.',
                );
              }
              return resources[uri];
            },
            assertFormats: path.contains('/optional/format/'),
            legacyDependencies: path.endsWith(
              '/dependencies-compatibility.json',
            ),
            assertContent: path.endsWith('/draft7/optional/content.json'),
          ),
        );
        for (final rawCase in group['tests']! as List<Object?>) {
          final testCase = rawCase! as Map<String, Object?>;
          counts[version] = (counts[version] ?? 0) + 1;
          final actual = validator.isValid(testCase['data']);
          final first = validator.validate(testCase['data']) == null;
          final all = validator.errors(testCase['data']).isEmpty;
          if (actual != testCase['valid'] || first != actual || all != actual) {
            failures.add({
              'file': path,
              'group': group['description'],
              'case': testCase['description'],
              'expected': testCase['valid'],
              'actual': actual,
              'first': first,
              'all': all,
            });
          }
        }
      } on ReferenceException catch (error) {
        blocked.add({
          'file': path,
          'group': group['description'],
          'reference': error.reference.toString(),
          'error': error.message,
        });
      } on Exception catch (error) {
        failures.add({
          'file': path,
          'group': group['description'],
          'error': '$error',
        });
      }
    }
  }
  for (final failure in failures.take(100)) {
    stdout.writeln(jsonEncode(failure));
  }
  for (final group in blocked) {
    stdout.writeln('BLOCKED: ${jsonEncode(group)}');
  }
  stdout.writeln(
    'Counts: $counts; failures: ${failures.length}; blocked groups: ${blocked.length}; files: ${files.length}',
  );
  Directory('build').createSync(recursive: true);
  File('build/conformance_results.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'counts': counts,
      'failures': failures,
      'blocked': blocked,
      'files': files.length,
      'excludedDirectories': excluded,
      'formatAssertions': 'optional/format fixtures only',
      'legacyDependencies': 'optional dependencies-compatibility fixtures only',
      'contentAssertions': 'Draft 07 optional content fixtures only',
    }),
  );
  exitCode = failures.isNotEmpty
      ? 1
      : blocked.isNotEmpty
      ? 2
      : 0;
}
