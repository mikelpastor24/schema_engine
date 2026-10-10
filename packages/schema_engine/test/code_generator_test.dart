import 'package:schema_engine/schema_engine.dart';
import 'package:test/test.dart';

import 'generated_validators.dart';

void main() {
  test('generated scalars match the runtime backend at every boundary', () {
    final generated = GeneratedInteger();
    final runtime = JsonSchema.fromJson({
      'type': 'integer',
      'minimum': 0,
      'maximum': 1000,
    }).compile();
    expect(generated.isSpecialized, isTrue);
    for (var value = -100; value <= 1100; value++) {
      expect(generated.isValid(value), runtime.isValid(value));
    }
    for (final value in <Object?>[null, 1.0, 1.1, '1', true, <Object?>[]]) {
      expect(generated.isValid(value), runtime.isValid(value));
    }
  });
  test('generated objects preserve constraints and diagnostics', () {
    final generated = GeneratedObject();
    expect(generated.isSpecialized, isTrue);
    expect(
      generated.isValid({'id': 1, 'name': 'Example', 'active': true}),
      isTrue,
    );
    for (final value in <Object?>[
      {},
      {'id': -1, 'name': 'Example'},
      {'id': 1, 'name': ''},
      {'id': 1, 'name': 'Example', 'extra': 4},
      {'id': 1, 'name': 'Example', 'active': null},
    ]) {
      expect(generated.isValid(value), isFalse);
      expect(generated.validate(value), isNotNull);
      expect(generated.errors(value), isNotEmpty);
    }
  });
  test('generated arrays and branches preserve semantics', () {
    expect(GeneratedArray().isValid([1, 2, 3]), isTrue);
    expect(GeneratedArray().isValid(<Object?>[]), isFalse);
    expect(GeneratedArray().isValid([1, -1]), isFalse);
    expect(GeneratedConditional().isValid('ab'), isTrue);
    expect(GeneratedConditional().isValid('a'), isFalse);
    expect(GeneratedConditional().isValid(0), isTrue);
    expect(GeneratedConditional().isValid(-1), isFalse);
    expect(GeneratedAlternatives().isValid('a'), isTrue);
    expect(GeneratedAlternatives().isValid(false), isFalse);
  });
  test('generated literals escape dollar signs and patterns', () {
    final validator = GeneratedPatterns();
    expect(validator.isValid({r'x$': 1}), isTrue);
    expect(validator.isValid({r'x$': 'wrong'}), isFalse);
    expect(validator.isValid({'other': 1}), isFalse);
  });
  test('generated empty collection constraints agree in every output mode', () {
    final validator = GeneratedEmptyCollection();
    expect(validator.isSpecialized, isTrue);
    for (final value in <Object?>[{}, <Object?>[]]) {
      expect(validator.isValid(value), isTrue);
      expect(validator.validate(value), isNull);
      expect(validator.errors(value), isEmpty);
    }
    for (final value in <Object?>[
      null,
      0,
      '',
      [1],
      {'name': null},
    ]) {
      expect(validator.isValid(value), isFalse);
      expect(validator.validate(value), isNotNull);
      expect(validator.errors(value), isNotEmpty);
    }
  });
  test('generated string bounds count Unicode code points', () {
    final validator = GeneratedUnicodeString();
    for (final value in ['a', '😀', '𝄞']) {
      expect(validator.isValid(value), isTrue);
      expect(validator.validate(value), isNull);
    }
    for (final value in <Object?>['', 'ab', '😀😀', 1, null]) {
      expect(validator.isValid(value), isFalse);
      expect(validator.validate(value), isNotNull);
    }
  });
  test(
    'unsupported checks and custom options use the correct runtime path',
    () {
      final fallback = GeneratedFallback();
      expect(fallback.isSpecialized, isFalse);
      expect(fallback.isValid(0.3), isTrue);
      expect(fallback.isValid(0.30000000000000004), isFalse);
      final custom = GeneratedInteger(
        options: SchemaOptions(
          keywords: {
            'minimum': (instance, _) => instance is! num || instance >= 10,
          },
        ),
      );
      expect(custom.isSpecialized, isFalse);
      expect(custom.isValid(1), isFalse);
      expect(custom.isValid(10), isTrue);
      expect(GeneratedEmpty().isValid(null), isTrue);
      expect(GeneratedFalse().isValid(null), isFalse);
    },
  );
  test('generates deterministically and rejects unsafe class names', () {
    final generator = SchemaCodeGenerator(
      JsonSchema.fromJson({'type': 'integer'}),
    );
    expect(generator.generate(), generator.generate());
    expect(
      () => generator.generate(className: 'bad;code'),
      throwsArgumentError,
    );
    expect(() => generator.generate(className: 'Object'), throwsArgumentError);
  });
  test('generated historical presence rules match every dialect', () {
    final checks = <bool Function(Object?)>[
      GeneratedDraft0().isValid,
      GeneratedDraft1().isValid,
      GeneratedDraft2().isValid,
      GeneratedDraft3().isValid,
      GeneratedDraft4().isValid,
      GeneratedDraft6().isValid,
      GeneratedDraft7().isValid,
      GeneratedDraft201909().isValid,
      GeneratedDraft202012().isValid,
    ];
    for (final check in checks) {
      expect(check({'name': 'Example'}), isTrue);
      expect(check({}), isFalse);
      expect(check({'name': 1}), isFalse);
    }
  });
}
