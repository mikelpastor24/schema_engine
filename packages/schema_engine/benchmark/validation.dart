import 'dart:convert';
import 'dart:io';

import 'package:schema_engine/schema_engine.dart';

var _sink = 0;

/// Measures compilation and repeated validation independently.
void main(List<String> arguments) {
  final iterations = arguments.isEmpty ? 50000 : int.parse(arguments.first);
  final schemas = <String, Object?>{
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
    'branches': {
      'anyOf': [
        {'type': 'string', 'pattern': '^[a-z]+\u0024'},
        {'type': 'integer', 'minimum': 0},
      ],
    },
    'recursive': {
      'type': 'object',
      'properties': {
        'value': {'type': 'integer'},
        'next': {r'$ref': '#'},
      },
    },
    'unevaluated': {
      'allOf': [
        {
          'properties': {
            'id': {'type': 'integer'},
          },
        },
        {
          'properties': {
            'name': {'type': 'string'},
          },
        },
      ],
      'unevaluatedProperties': false,
    },
    'decimal': {'type': 'number', 'multipleOf': 0.01},
  };
  final instances = <String, (Object?, Object?)>{
    'integer': (42, -1),
    'object': (
      {'id': 42, 'name': 'Example', 'active': true},
      {'id': -1, 'name': ''},
    ),
    'array': (List.generate(20, (i) => i), [0, 1, -1]),
    'branches': ('example', false),
    'recursive': (
      {
        'value': 1,
        'next': {
          'value': 2,
          'next': {'value': 3},
        },
      },
      {
        'next': {'value': false},
      },
    ),
    'unevaluated': ({'id': 1, 'name': 'Example'}, {'id': 1, 'extra': true}),
    'decimal': (19.99, 19.991),
  };
  double measure(void Function() body, int count) {
    final samples = <double>[];
    for (var sample = 0; sample < 7; sample++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        body();
      }
      watch.stop();
      samples.add(watch.elapsedMicroseconds * 1000 / count);
    }
    samples.sort();
    return samples[samples.length ~/ 2];
  }

  final results = <String, Object?>{};
  for (final entry in schemas.entries) {
    final schema = JsonSchema.fromJson(entry.value);
    final source = schema.toJsonString();
    final validator = schema.compile();
    final values = instances[entry.key]!;
    if (!validator.isValid(values.$1) || validator.isValid(values.$2)) {
      throw StateError('Invalid benchmark fixtures for ${entry.key}.');
    }
    void valid() {
      _sink += validator.isValid(values.$1) ? 1 : 0;
    }

    void invalid() {
      _sink += validator.isValid(values.$2) ? 1 : 0;
    }

    void first() {
      _sink += validator.validate(values.$2) == null ? 1 : 0;
    }

    void errors() {
      _sink += validator.errors(values.$2).length;
    }

    for (var i = 0; i < 20000; i++) {
      valid();
      invalid();
      first();
      errors();
    }
    results[entry.key] = {
      'parseNs': measure(() {
        _sink += JsonSchema.parse(source).draft.index;
      }, 300),
      'compileNs': measure(() {
        _sink += schema.compile().draft.index;
      }, 300),
      'validNs': measure(valid, iterations),
      'invalidNs': measure(invalid, iterations),
      'firstErrorNs': measure(first, iterations),
      'allErrorsNs': measure(errors, iterations),
    };
  }
  final report = {
    'sdk': Platform.version,
    'platform': Platform.operatingSystem,
    'iterations': iterations,
    'samples': 7,
    'mode': const bool.fromEnvironment('dart.vm.product') ? 'AOT' : 'JIT',
    'results': results,
    'sink': _sink,
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  Directory('build').createSync(recursive: true);
  File('build/benchmark_results.json').writeAsStringSync(jsonEncode(report));
}
