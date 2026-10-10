import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

/// Checks semantic diagnostics directly when a launcher cannot spawn tools.
///
/// This API does not register SDK lint rules. Use `dart analyze`, or the SDK
/// server adapter in analyze_sdk.py, for the complete configured checks.
Future<void> main() async {
  final root = Directory.current.absolute.path;
  final collection = AnalysisContextCollection(includedPaths: [root]);
  var count = 0;
  for (final context in collection.contexts) {
    for (final file in context.contextRoot.analyzedFiles()) {
      if (!file.endsWith('.dart')) {
        continue;
      }
      final result = await context.currentSession.getResolvedUnit(file);
      if (result is ResolvedUnitResult) {
        for (final diagnostic in result.diagnostics) {
          stdout.writeln(
            '$file:${diagnostic.offset}: ${diagnostic.diagnosticCode.lowerCaseName}: ${diagnostic.message}',
          );
          count++;
        }
      }
    }
  }
  stdout.writeln('$count diagnostics.');
  exitCode = count == 0 ? 0 : 1;
}
