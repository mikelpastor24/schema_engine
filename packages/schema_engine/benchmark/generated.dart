import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

import '../test/generated_validators.dart';

var _sink = 0;

/// Compares specialized Dart source against the reusable runtime compiler.
void main() {
  const iterations = 200000;
  final schemas = <String, Object>{
    'integer': {'type': 'integer', 'minimum': 0, 'maximum': 1000},
    'object': {
      'type': 'object',
      'required': ['id', 'name'],
      'properties': {
        'id': {'type': 'integer', 'minimum': 0},
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 64},
        'active': {'type': 'boolean'},
      },
      'additionalProperties': false,
    },
    'array': {
      'type': 'array',
      'minItems': 1,
      'items': {'type': 'integer', 'minimum': 0},
    },
  };
  final instances = <String, List<Object>>{
    'integer': List.generate(64, (i) => i * 7),
    'object': List.generate(
      64,
      (i) => <String, Object>{'id': i, 'name': 'Record $i', 'active': i.isEven},
    ),
    'array': List.generate(
      64,
      (offset) => List.generate(20, (i) => i + offset),
    ),
  };
  final generated = <String, bool Function(Object?)>{
    'integer': GeneratedInteger().isValid,
    'object': GeneratedObject().isValid,
    'array': GeneratedArray().isValid,
  };
  double measure(bool Function(Object?) validate, List<Object> instances) {
    for (var i = 0; i < 50000; i++) {
      _sink += validate(instances[i % instances.length]) ? 1 : 0;
    }
    final samples = <double>[];
    for (var sample = 0; sample < 7; sample++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _sink += validate(instances[i % instances.length]) ? 1 : 0;
      }
      watch.stop();
      samples.add(watch.elapsedMicroseconds * 1000 / iterations);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  final results = <String, Object?>{};
  for (final entry in schemas.entries) {
    final runtime = JsonSchema.fromJson(entry.value).compile();
    final pool = instances[entry.key]!;
    for (final instance in pool) {
      if (!runtime.isValid(instance) || !generated[entry.key]!(instance)) {
        throw StateError('Invalid benchmark fixture.');
      }
    }
    final runtimeNs = measure(runtime.isValid, pool);
    final generatedNs = measure(generated[entry.key]!, pool);
    results[entry.key] = {
      'runtimeNs': runtimeNs,
      'generatedNs': generatedNs,
      'speedup': runtimeNs / generatedNs,
    };
  }
  final report = {
    'sdk': Platform.version,
    'platform': Platform.operatingSystem,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'AOT' : 'JIT',
    'iterations': iterations,
    'samples': 7,
    'instancePool': 64,
    'results': results,
    'sink': _sink,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  Directory('build').createSync(recursive: true);
  File('build/generated_benchmark_results.json')
      .writeAsStringSync(jsonEncode(report));
}
