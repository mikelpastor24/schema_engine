import 'dart:convert';
import 'dart:js_interop';

import 'package:schema_engine/schema_engine.dart';

@JS('schemaSuiteInput')
external JSString get _suiteInput;

@JS('schemaSuiteResult')
external set _suiteResult(JSString value);

/// Runs external fixtures in JavaScript through the accompanying Node adapter.
Future<void> main() async {
  final input = jsonDecode(_suiteInput.toDart) as Map<String, Object?>;
  final resources = <Uri, Object?>{
    for (final raw in input['remotes']! as List<Object?>)
      Uri.parse((raw! as Map<String, Object?>)['uri']! as String): decodeJson(
        (raw as Map<String, Object?>)['source']! as String,
      ),
  };
  final counts = <String, int>{};
  final failures = <Map<String, Object?>>[];
  final blocked = <Map<String, Object?>>[];
  for (final raw in input['files']! as List<Object?>) {
    final file = raw! as Map<String, Object?>;
    final path = file['path']! as String;
    final version = path.split('/')[1];
    final draft = switch (version) {
      'draft3' => SchemaDraft.draft3,
      'draft4' => SchemaDraft.draft4,
      'draft6' => SchemaDraft.draft6,
      'draft7' => SchemaDraft.draft7,
      'draft2019-09' => SchemaDraft.draft201909,
      _ => SchemaDraft.draft202012,
    };
    for (final rawGroup
        in decodeJson(file['source']! as String)! as List<Object?>) {
      final group = rawGroup! as Map<String, Object?>;
      try {
        final validator =
            await JsonSchema.fromJson(
              group['schema'],
              draft: draft,
            ).compileAsync(
              options: SchemaOptions(
                resolver: (uri) async {
                  if (!resources.containsKey(uri)) {
                    throw ReferenceException(
                      uri,
                      'No matching local remote fixture.',
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
  _suiteResult = jsonEncode({
    'counts': counts,
    'failures': failures,
    'blocked': blocked,
    'files': (input['files']! as List<Object?>).length,
    'mode': 'JavaScript',
  }).toJS;
}
