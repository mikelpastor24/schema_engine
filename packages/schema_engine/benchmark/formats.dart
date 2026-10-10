import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

var _sink = 0;

/// Measures format assertions with pools of valid and invalid input strings.
void main() {
  const iterations = 50000;
  final cases = <String, (List<String>, List<String>)>{
    'uri': (
      List.generate(64, (i) => 'https://example.com/records/$i?offset=$i'),
      List.generate(64, (i) => 'https://example.com/%GG/$i'),
    ),
    'uri-template': (
      List.generate(
        64,
        (i) => 'https://example.com/records/$i/{name}{?fields}',
      ),
      List.generate(64, (i) => 'https://example.com/{record$i:0}'),
    ),
    'ipv4': (
      List.generate(64, (i) => '192.0.2.$i'),
      List.generate(64, (i) => '256.0.2.$i'),
    ),
    'ipv6': (
      List.generate(64, (i) => '2001:db8::$i'),
      List.generate(64, (i) => '2001:db8:::$i'),
    ),
    'email': (
      List.generate(64, (i) => 'record$i@example.com'),
      List.generate(64, (i) => 'record$i..extra@example.com'),
    ),
    'idn-email': (
      List.generate(64, (i) => '记录$i@例子.测试'),
      List.generate(64, (i) => '记录$i@bad_host'),
    ),
    'hostname': (
      List.generate(64, (i) => 'record$i.example.com'),
      List.generate(64, (i) => 'record$i.bad_host'),
    ),
    'idn-hostname': (
      List.generate(64, (i) => '例子$i.测试'),
      List.generate(64, (i) => '例子$i.bad_host'),
    ),
    'date-time': (
      List.generate(
        64,
        (i) =>
            '2024-03-${(i % 28 + 1).toString().padLeft(2, '0')}'
            'T12:00:${(i % 60).toString().padLeft(2, '0')}Z',
      ),
      List.generate(
        64,
        (i) =>
            '2024-02-30T12:00:'
            '${(i % 60).toString().padLeft(2, '0')}Z',
      ),
    ),
    'regex': (
      List.generate(64, (i) => '^record$i\$'),
      List.generate(64, (i) => '[record$i'),
    ),
  };
  double measure(CompiledSchema validator, List<String> pool) {
    for (var i = 0; i < 10000; i++) {
      _sink += validator.isValid(pool[i % pool.length]) ? 1 : 0;
    }
    final samples = <double>[];
    for (var sample = 0; sample < 7; sample++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _sink += validator.isValid(pool[i % pool.length]) ? 1 : 0;
      }
      watch.stop();
      samples.add(watch.elapsedMicroseconds * 1000 / iterations);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  final results = <String, Object?>{};
  for (final entry in cases.entries) {
    final validator = JsonSchema.fromJson({'format': entry.key})
        .compile(options: SchemaOptions(assertFormats: true));
    for (final value in entry.value.$1) {
      if (!validator.isValid(value)) {
        throw StateError('Invalid valid-input fixture: ${entry.key}: $value');
      }
    }
    for (final value in entry.value.$2) {
      if (validator.isValid(value)) {
        throw StateError('Invalid invalid-input fixture: ${entry.key}: $value');
      }
    }
    results[entry.key] = {
      'validNs': measure(validator, entry.value.$1),
      'invalidNs': measure(validator, entry.value.$2),
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
  File('build/format_benchmark_results.json')
      .writeAsStringSync(jsonEncode(report));
}
