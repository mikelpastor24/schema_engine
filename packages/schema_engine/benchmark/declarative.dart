import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart' as schema;

var _sink = 0;

/// Compares equivalent nullable representations produced by declarations.
void main() {
  const iterations = 200000;
  const samples = 7;
  final optimized = schema.string().min(1).nullable().compile();
  final general = schema.union([
    schema.string().min(1),
    schema.nullValue(),
  ]).compile();
  final valid = List<Object?>.generate(64, (i) => i.isEven ? null : 'record$i');
  final invalid = List<Object?>.generate(64, (i) => i.isEven ? '' : i);
  for (final input in [...valid, ...invalid]) {
    if (optimized.isValid(input) != general.isValid(input)) {
      throw StateError('Nullable representations disagree.');
    }
  }
  for (final input in valid) {
    if (!optimized.isValid(input)) {
      throw StateError('Invalid benchmark fixture.');
    }
  }
  for (final input in invalid) {
    if (optimized.isValid(input)) {
      throw StateError('Valid benchmark fixture in invalid pool.');
    }
  }
  for (var i = 0; i < 50000; i++) {
    _sink += optimized.isValid(valid[i % valid.length]) ? 1 : 0;
    _sink += general.isValid(valid[i % valid.length]) ? 1 : 0;
    _sink += optimized.isValid(invalid[i % invalid.length]) ? 1 : 0;
    _sink += general.isValid(invalid[i % invalid.length]) ? 1 : 0;
  }
  double measure(bool Function(Object?) test, List<Object?> inputs) {
    final timings = <double>[];
    for (var sample = 0; sample < samples; sample++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _sink += test(inputs[i % inputs.length]) ? 1 : 0;
      }
      watch.stop();
      timings.add(watch.elapsedMicroseconds * 1000 / iterations);
    }
    timings.sort();
    return timings[timings.length ~/ 2];
  }

  final result = {
    'sdk': Platform.version,
    'platform': Platform.operatingSystem,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'AOT' : 'JIT',
    'iterations': iterations,
    'samples': samples,
    'instancePool': valid.length,
    'fixture': 'Nullable nonempty string, with null/string valid pool and empty-string/integer invalid pool.',
    'results': {
      'typeList': {
        'validNs': measure(optimized.isValid, valid),
        'invalidNs': measure(optimized.isValid, invalid),
      },
      'anyOf': {
        'validNs': measure(general.isValid, valid),
        'invalidNs': measure(general.isValid, invalid),
      },
    },
    'sink': _sink,
  };
  Directory('build').createSync(recursive: true);
  File('build/declarative_benchmark_results.json')
      .writeAsStringSync(jsonEncode(result));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
}
