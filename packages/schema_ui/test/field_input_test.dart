import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

TextEditingValue _editing(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  testWidgets('invalid numeric text displays the compiled schema diagnostic', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final document = schema.object({
      'a/b~c': schema.number().min(1),
    }).toJsonSchema();
    final validator = document.compile();
    Object? saved;
    var changes = 0;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: document,
            initialValue: {'a/b~c': 2},
            onChanged: (_) => changes++,
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '-');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    final expected = validator.validate({'a/b~c': '-'})!;
    expect(expected.keyword, 'type');
    expect(expected.instancePath, '/a~1b~0c');
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .errorText,
      expected.message,
    );
    expect(
      find.text('${expected.instancePath}: ${expected.message}'),
      findsOneWidget,
    );
    key.currentState!.save();
    expect(saved, {'a/b~c': 2});
    expect(changes, 0);
    await tester.enterText(find.byType(TextFormField), '3');
    expect(key.currentState!.validate(), isTrue);
    key.currentState!.save();
    expect(saved, {'a/b~c': 3});
    expect(changes, 1);
  });

  testWidgets('independent numeric parsing errors clear only when corrected', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'first': schema.number(),
              'second': schema.number(),
            }).toJsonSchema(),
            initialValue: {'first': 1, 'second': 2},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '-');
    await tester.enterText(find.byType(TextFormField).last, '1e-');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField).first, '3');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    final error = schema.number().compile().validate('1e-')!;
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator).last)
          .decoration
          .errorText,
      error.message,
    );
    await tester.enterText(find.byType(TextFormField).last, '4');
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets(
    'numeric syntax still fails when the validation vocabulary is inactive',
    (tester) async {
      final key = GlobalKey<FormState>();
      final metaUri = Uri.parse('https://example.com/numeric-ui-meta');
      final document = schema.JsonSchema.fromJson({
        r'$schema': metaUri.toString(),
        'type': 'number',
      }, draft: schema.SchemaDraft.draft202012);
      final options = schema.SchemaOptions(
        resources: {
          metaUri: {
            r'$schema': schema.SchemaDraft.draft202012.metaSchemaUri,
            r'$vocabulary': {
              'https://json-schema.org/draft/2020-12/vocab/core': true,
            },
          },
        },
      );
      expect(document.compile(options: options).isValid('-'), isTrue);
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: document,
              options: options,
              initialValue: 2,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '-');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      String? message;
      try {
        schema.decodeJson('-');
      } on FormatException catch (error) {
        message = error.message;
      }
      expect(message, isNotNull);
      expect(
        tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration
            .errorText,
        message,
      );
      await tester.enterText(find.byType(TextFormField), '3');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  for (final integer in [true, false]) {
    testWidgets(
      '${integer ? 'integer' : 'number'} selects its numeric keyboard',
      (tester) async {
        await tester.pumpWidget(
          _host(
            SchemaForm(
              schema: (integer ? schema.integer() : schema.number())
                  .toJsonSchema(),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(
          field.keyboardType,
          TextInputType.numberWithOptions(signed: true, decimal: !integer),
        );
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        final formatter = field.inputFormatters!.single;
        final oldValue = _editing('12');
        final accepted = integer
            ? [
                '',
                '-',
                '0',
                '-0',
                '42',
                '-42',
                '12.',
                '12,',
                '-12.',
                '-12,',
                '9007199254740993',
              ]
            : [
                '',
                '-',
                '0',
                '-0',
                '42',
                '-42',
                '0.3',
                '-2.5',
                '2,5',
                '.5',
                ',5',
                '-.5',
                '-,5',
                '.',
                '-.',
                '1.',
                '1,',
                '1e',
                '1e-',
                '1e+',
                '1e3',
                '1E-3',
                '1e+3',
              ];
        for (final text in accepted) {
          final value = _editing(text);
          expect(
            formatter.formatEditUpdate(oldValue, value),
            same(value),
            reason: 'Allow numeric edit: $text',
          );
        }
        final rejected = [
          'text',
          '1-2',
          '--1',
          '+1',
          '01',
          ' 3',
          '1\n',
          'NaN',
          'Infinity',
          '١٢',
          '1e--2',
          '1e2e3',
          '1.2.3',
          '1,2,3',
          '1,234.56',
          if (integer) ...['1.5', '1,5', '1e2'],
        ];
        for (final text in rejected) {
          expect(
            formatter.formatEditUpdate(oldValue, _editing(text)),
            same(oldValue),
            reason: 'Reject the complete edit: $text',
          );
        }
      },
    );

    testWidgets(
      '${integer ? 'integer' : 'number'} decodes trailing separators',
      (tester) async {
        final key = GlobalKey<FormState>();
        Object? changed;
        Object? saved;
        await tester.pumpWidget(
          _host(
            Form(
              key: key,
              child: SchemaForm(
                schema: (integer ? schema.integer() : schema.number())
                    .toJsonSchema(),
                initialValue: 1,
                onChanged: (value) => changed = value,
                onSaved: (value) => saved = value,
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextFormField), '-');
        expect(key.currentState!.validate(), isFalse);
        await tester.pump();
        for (final text in [
          '12.',
          '12,',
          '-12.',
          '-12,',
          '0.',
          '0,',
          '9007199254740993.',
          '9007199254740993,',
        ]) {
          await tester.enterText(find.byType(TextFormField), text);
          final whole = text.substring(0, text.length - 1);
          final expected = schema.decodeJson(integer ? whole : '$whole.0');
          expect(
            schema.encodeJson(changed),
            schema.encodeJson(expected),
            reason: text,
          );
          if (text == '12.' || text == '12,') {
            expect(changed, integer ? isA<int>() : isA<double>());
          }
          expect(key.currentState!.validate(), isTrue, reason: text);
          await tester.pump();
          expect(
            tester
                .widget<InputDecorator>(find.byType(InputDecorator))
                .decoration
                .errorText,
            isNull,
          );
          final editing = tester
              .widget<TextField>(find.byType(TextField))
              .controller!
              .value;
          expect(editing.text, text);
          expect(editing.selection.baseOffset, text.length);
          key.currentState!.save();
          expect(schema.encodeJson(saved), schema.encodeJson(expected));
        }
        if (!integer) {
          await tester.enterText(find.byType(TextFormField), '12,5');
          expect(changed, 12.5);
          expect(key.currentState!.validate(), isTrue);
        }
      },
    );
  }

  testWidgets(
    'numeric formatter preserves composition and restores failed commits',
    (tester) async {
      await tester.pumpWidget(
        _host(SchemaForm(schema: schema.integer().toJsonSchema())),
      );
      final formatter = tester
          .widget<TextField>(find.byType(TextField))
          .inputFormatters!
          .single;
      const before = TextEditingValue(
        text: '12',
        selection: TextSelection.collapsed(offset: 1),
      );
      const composing = TextEditingValue(
        text: '12a',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      );
      expect(formatter.formatEditUpdate(before, composing), same(composing));
      expect(
        formatter.formatEditUpdate(composing, _editing('12a')),
        same(before),
      );
      final accepted = _editing('123');
      expect(formatter.formatEditUpdate(before, accepted), same(accepted));
      const selectionChange = TextEditingValue(
        text: '123',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(
        formatter.formatEditUpdate(accepted, selectionChange),
        same(selectionChange),
      );
    },
  );

  testWidgets(
    'decimal editing accepts locale separators and scientific notation exactly',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.number().toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      for (final (text, expected) in [
        ('-12,5', -12.5),
        ('.5', 0.5),
        ('-,5', -0.5),
        ('1e-3', 0.001),
        ('1E+3', 1000),
      ]) {
        await tester.enterText(find.byType(TextFormField), text);
        expect(changed, expected);
        expect(key.currentState!.validate(), isTrue);
      }
      await tester.enterText(
        find.byType(TextFormField),
        '0,123456789012345678901',
      );
      expect(changed, isA<schema.JsonNumber>());
      expect(
        schema.encodeJson(changed),
        schema.encodeJson(schema.decodeJson('0.123456789012345678901')),
      );
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'incomplete numbers remain editable but do not replace the last JSON value',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      Object? saved;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.number().toJsonSchema(),
              initialValue: 12,
              onChanged: (value) => changed = value,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      for (final text in ['', '-', '.', ',', '-.', '-,', '1e', '1e-', '1e+']) {
        await tester.enterText(find.byType(TextFormField), text);
        expect(key.currentState!.validate(), isFalse, reason: text);
        await tester.pump();
        final error = schema.number().compile().validate(text)!;
        expect(
          tester
              .widget<InputDecorator>(find.byType(InputDecorator))
              .decoration
              .errorText,
          error.message,
        );
        key.currentState!.save();
        expect(saved, 12);
        expect(changed, isNull);
      }
      await tester.enterText(find.byType(TextFormField), '2.5');
      expect(changed, 2.5);
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('malformed pastes leave the text and JSON unchanged', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    var changes = 0;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.number().toJsonSchema(),
            initialValue: 12.5,
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );
    for (final text in ['price: 123', '1.2.3', '1,234.56', '1e2e3']) {
      await tester.enterText(find.byType(TextFormField), text);
      expect(find.text('12.5'), findsOneWidget);
      expect(key.currentState!.validate(), isTrue);
      expect(changes, 0);
    }
  });

  testWidgets(
    'numeric bounds and multiples stay visible as validation errors',
    (tester) async {
      final key = GlobalKey<FormState>();
      final document = schema
          .number()
          .min(0)
          .max(10)
          .multipleOf(0.5)
          .toJsonSchema();
      final validator = document.compile();
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(schema: document),
          ),
        ),
      );
      for (final (text, value) in [
        ('-1', -1),
        ('-1.', -1.0),
        ('11', 11),
        ('11,', 11.0),
        ('0.3', 0.3),
      ]) {
        await tester.enterText(find.byType(TextFormField), text);
        expect(find.text(text), findsOneWidget);
        expect(key.currentState!.validate(), isFalse);
        await tester.pump();
        expect(
          tester
              .widget<InputDecorator>(find.byType(InputDecorator))
              .decoration
              .errorText,
          validator.validate(value)!.message,
        );
      }
      await tester.enterText(find.byType(TextFormField), '0,5');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  for (final (format, keyboard) in [
    (null, TextInputType.text),
    ('email', TextInputType.emailAddress),
    ('idn-email', TextInputType.emailAddress),
    ('uri', TextInputType.url),
    ('uri-reference', TextInputType.url),
    ('iri', TextInputType.url),
    ('iri-reference', TextInputType.url),
    ('date', TextInputType.datetime),
    ('time', TextInputType.datetime),
    ('date-time', TextInputType.datetime),
  ]) {
    testWidgets(
      'string format $format selects its keyboard and keeps Unicode input',
      (tester) async {
        Object? changed;
        await tester.pumpWidget(
          _host(
            SchemaForm(
              schema: schema.JsonSchema.build(
                type: schema.SchemaType.string,
                format: format,
              ),
              onChanged: (value) => changed = value,
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, keyboard);
        expect(field.autocorrect, keyboard == TextInputType.text);
        expect(
          field.inputFormatters!.single,
          FilteringTextInputFormatter.singleLineFormatter,
        );
        await tester.enterText(
          find.byType(TextFormField),
          'Ángel 👨‍👩‍👦 123',
        );
        expect(changed, 'Ángel 👨‍👩‍👦 123');
      },
    );
  }

  testWidgets(
    'string constraints validate without truncating or filtering text',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema
                  .string()
                  .max(1)
                  .pattern(r'^[A-Z]+$')
                  .toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '👨‍👩‍👦');
      expect(changed, '👨‍👩‍👦');
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), 'AB');
      expect(changed, 'AB');
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), 'A');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'JSON fallback keeps a multiline keyboard without numeric formatters',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.JsonSchema.any(),
              initialValue: 1,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.multiline);
      expect(field.inputFormatters, isNull);
      await tester.enterText(
        find.byType(TextFormField),
        '{\n"name": "Example"\n}',
      );
      expect(changed, {'name': 'Example'});
      expect(key.currentState!.validate(), isTrue);
    },
  );
}
