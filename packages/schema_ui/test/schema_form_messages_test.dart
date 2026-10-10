import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Finder _field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

String? _error(WidgetTester tester, Finder field) => tester
    .widget<InputDecorator>(
      find.descendant(of: field, matching: find.byType(InputDecorator)),
    )
    .decoration
    .errorText;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('messages customize nested labels and actions', (tester) async {
    Object? changed;
    final messages = SchemaFormMessages(
      valueLabel: 'Document',
      additionalPropertiesLabel: 'Extra JSON',
      addItemLabel: 'Append entry',
      optionalLabel: (label) => 'Not required: $label',
      clearValueTooltip: (label) => 'Discard $label',
      useNullLabel: (label) => 'Set $label to null',
      removeItemTooltip: (number) => 'Delete entry #$number',
    );
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema
              .object({
                'note': schema.string().withKeywords({
                  'title': 'Note',
                  'description': 'The original description.',
                }).optional(),
                'flag': schema.boolean().optional(),
                'details': schema.object({
                  'nested': schema.string().optional(),
                }).optional(),
                'nullable': schema.string().nullable().optional(),
                'items': schema.array(schema.string()).optional(),
              })
              .passthrough()
              .toJsonSchema(),
          initialValue: const {
            'note': 'Keep this text',
            'items': ['First'],
          },
          messages: messages,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    expect(find.text('Document'), findsOneWidget);
    expect(_field('Not required: Note'), findsOneWidget);
    expect(find.text('The original description.'), findsOneWidget);
    expect(find.text('Not required: flag'), findsOneWidget);
    expect(find.text('Not required: details'), findsOneWidget);
    expect(_field('Not required: nested'), findsOneWidget);
    expect(find.text('Set Not required: nullable to null'), findsOneWidget);
    expect(_field('Extra JSON'), findsOneWidget);
    expect(find.text('Append entry'), findsOneWidget);

    await _tap(tester, find.byTooltip('Discard Note'));
    expect(changed, {
      'items': ['First'],
    });
    await _tap(tester, find.byTooltip('Delete entry #1'));
    expect(changed, <String, Object?>{});
    await _tap(tester, find.text('Append entry'));
    expect(changed, {
      'items': [''],
    });
    await _tap(tester, find.text('Set Not required: nullable to null'));
    expect(changed, {
      'items': [''],
      'nullable': null,
    });
  });

  testWidgets('required and schema errors use configured messages', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final errors = <schema.ValidationError>[];
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'name': schema.string().min(3),
              'email': schema.string().email().optional(),
            }).toJsonSchema(),
            options: schema.SchemaOptions(assertFormats: true),
            messages: SchemaFormMessages(
              requiredPropertyError: 'Fill in this field.',
              validationError: (error) {
                errors.add(error);
                return 'Rule ${error.keyword} at ${error.instancePath}';
              },
              errorSummary: (path, message) => 'Issue at $path: $message',
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(_error(tester, _field('name')), 'Fill in this field.');
    expect(errors.any((error) => error.keyword == 'required'), isTrue);
    expect(find.text('Issue at : Rule required at '), findsOneWidget);

    await tester.enterText(_field('name'), 'No');
    await tester.enterText(_field('email (optional)'), '12231312312');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(_error(tester, _field('name')), 'Rule minLength at /name');
    expect(_error(tester, _field('email (optional)')), 'Rule format at /email');
    final formatError = errors.firstWhere((error) => error.keyword == 'format');
    expect(formatError.schemaPath, '/properties/email/format');
    expect(formatError.message, isNot('Rule format at /email'));

    await tester.enterText(_field('name'), 'Reader');
    await tester.enterText(_field('email (optional)'), 'reader@example.com');
    expect(key.currentState!.validate(), isTrue);
    await tester.pump();
    expect(_error(tester, _field('name')), isNull);
    expect(_error(tester, _field('email (optional)')), isNull);
  });

  testWidgets('message changes preserve invalid JSON text and pending errors', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final document = schema.JsonSchema.fromJson(true);
    var changes = 0;
    Widget editor(String message) => _host(
      Form(
        key: key,
        child: SchemaForm(
          schema: document,
          initialValue: const {'original': true},
          messages: SchemaFormMessages(invalidJsonError: message),
          onChanged: (_) => changes++,
        ),
      ),
    );
    await tester.pumpWidget(editor('JSON syntax is invalid.'));
    await tester.enterText(find.byType(TextFormField), '{');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      _error(tester, find.byType(TextFormField)),
      'JSON syntax is invalid.',
    );
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller;

    await tester.pumpWidget(editor('Cannot parse this JSON.'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller,
      same(controller),
    );
    expect(controller!.text, '{');
    expect(changes, 0);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      _error(tester, find.byType(TextFormField)),
      'Cannot parse this JSON.',
    );
    expect(find.text('/: Cannot parse this JSON.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '{"corrected": true}');
    expect(key.currentState!.validate(), isTrue);
    expect(changes, 1);
  });

  testWidgets('additional property errors use localized parsing messages', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? changed;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema
                .object({'count': schema.integer()})
                .passthrough()
                .toJsonSchema(),
            initialValue: const {'count': 1},
            messages: const SchemaFormMessages(
              additionalPropertiesLabel: 'Extra JSON',
              invalidAdditionalPropertiesError: 'Use an object with new keys.',
              invalidJsonError: 'JSON syntax is invalid.',
            ),
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    for (final text in ['[]', '{"count": 2}']) {
      await tester.enterText(_field('Extra JSON'), text);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        _error(tester, _field('Extra JSON')),
        'Use an object with new keys.',
      );
      expect(changed, isNull);
    }
    await tester.enterText(_field('Extra JSON'), '{');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(_error(tester, _field('Extra JSON')), 'JSON syntax is invalid.');
    await tester.enterText(_field('Extra JSON'), '{"note": true}');
    expect(key.currentState!.validate(), isTrue);
    expect(changed, {'count': 1, 'note': true});
  });

  testWidgets('invalid numeric input translates the schema diagnostic first', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    var parsingErrors = 0;
    Object? saved;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.number().toJsonSchema(),
            initialValue: 2,
            messages: SchemaFormMessages(
              validationError: (error) => 'Rule ${error.keyword}',
              numberInputError: (error) {
                parsingErrors++;
                return 'Number syntax: ${error.message}';
              },
            ),
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '-');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(_error(tester, find.byType(TextFormField)), 'Rule type');
    expect(find.text('/: Rule type'), findsOneWidget);
    expect(parsingErrors, 0);
    key.currentState!.save();
    expect(saved, 2);
    await tester.enterText(find.byType(TextFormField), '3');
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('numeric decoder errors can be translated without assertions', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final metaUri = Uri.parse('https://example.com/messages-meta');
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
    FormatException? parsingError;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: document,
            options: options,
            initialValue: 2,
            messages: SchemaFormMessages(
              numberInputError: (error) {
                parsingError = error;
                return 'Complete the number.';
              },
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '-');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(parsingError, isA<FormatException>());
    expect(parsingError!.message, isNotEmpty);
    expect(_error(tester, find.byType(TextFormField)), 'Complete the number.');
    expect(find.text('/: Complete the number.'), findsOneWidget);
  });

  testWidgets('custom editors receive localized labels and messages', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final messages = SchemaFormMessages(
      optionalLabel: (label) => '$label (not required)',
      invalidJsonError: 'The custom editor cannot decode this value.',
    );
    SchemaField? selected;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'custom': schema.string().withKeywords({
                'title': 'Custom',
              }).optional(),
            }).toJsonSchema(),
            messages: messages,
            pathBuilders: {
              '/custom': (_, field) {
                selected = field;
                return Text(field.label);
              },
            },
          ),
        ),
      ),
    );
    expect(find.text('Custom (not required)'), findsOneWidget);
    expect(selected!.messages, same(messages));
    selected!.setInputError(selected!.messages.invalidJsonError);
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('/custom: The custom editor cannot decode this value.'),
      findsOneWidget,
    );
    selected!.onChanged('Corrected');
    expect(key.currentState!.validate(), isTrue);
  });
}
