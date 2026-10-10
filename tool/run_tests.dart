import 'dart:io';

import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/test.dart';

import '../test/code_generator_test.dart' as generation;
import '../test/conformance_regressions_test.dart' as regressions;
import '../test/core_resources_test.dart' as core;
import '../test/draft_semantics_test.dart' as semantics;
import '../test/formats_and_vocabularies_test.dart' as formats;
import '../test/schema_definition_test.dart' as definitions;
import '../test/schema_engine_test.dart' as tests;

/// Runs the same unit tests in-process when OS signal subscriptions are denied.
///
/// This adapter uses test_api internals and is limited to the pinned development
/// dependency. Normal development should use `dart test`.
Future<void> main() async {
  final declarer = Declarer();
  declarer.declare(tests.main);
  declarer.declare(semantics.main);
  declarer.declare(formats.main);
  declarer.declare(generation.main);
  declarer.declare(core.main);
  declarer.declare(regressions.main);
  declarer.declare(definitions.main);
  final suite = Suite(declarer.build(), SuitePlatform(Runtime.vm));
  var passed = 0;
  var failed = 0;
  Future<void> runGroup(Group group) async {
    for (final entry in group.entries) {
      if (entry is Group) {
        await runGroup(entry);
      } else if (entry is Test) {
        final live = entry.load(suite);
        final subscription = live.onError.listen((_) {});
        await live.run();
        if (live.errors.isEmpty) {
          passed++;
        } else {
          failed++;
          stderr.writeln('FAIL: ${entry.name}');
          for (final error in live.errors) {
            stderr.writeln('${error.error}\n${error.stackTrace}');
          }
        }
        await subscription.cancel();
      }
    }
  }

  await runGroup(suite.group);
  stdout.writeln('$passed passed, $failed failed.');
  exitCode = failed == 0 ? 0 : 1;
}
