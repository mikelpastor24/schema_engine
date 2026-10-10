import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Finder _textField(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

schema.JsonSchema _document(Map<String, Object?> value) =>
    schema.JsonSchema.fromJson(value);

void main() {
  testWidgets('editing additional keys preserves invalid named field input', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema
                .object({'count': schema.integer()})
                .passthrough()
                .toJsonSchema(),
            initialValue: {'count': 2},
          ),
        ),
      ),
    );
    await tester.enterText(_textField('count'), '-');
    await tester.enterText(
      _textField('Additional properties (JSON)'),
      '{"extra": true}',
    );
    expect(find.text('-'), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(_textField('count'), '3');
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets(
    'type overrides apply to declared types with complex constraints',
    (tester) async {
      final key = GlobalKey<FormState>();
      SchemaField? selected;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: _document({
                'type': 'string',
                'allOf': [
                  {'minLength': 3},
                  {'maxLength': 10},
                ],
              }),
              initialValue: 'No',
              typeBuilders: {
                schema.SchemaType.string: (_, field) {
                  selected = field;
                  return const Text('Complex string override');
                },
              },
            ),
          ),
        ),
      );
      expect(find.text('Complex string override'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      selected!.onChanged('Valid');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('inactive validation vocabularies do not add UI assertions', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final metaUri = Uri.parse('https://example.com/ui-meta');
    final document = schema.JsonSchema.fromJson({
      r'$schema': metaUri.toString(),
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
      'required': ['name'],
    }, draft: schema.SchemaDraft.draft202012);
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: document,
            initialValue: const <String, Object?>{},
            options: schema.SchemaOptions(
              resources: {
                metaUri: {
                  r'$schema': schema.SchemaDraft.draft202012.metaSchemaUri,
                  r'$vocabulary': {
                    'https://json-schema.org/draft/2020-12/vocab/core': true,
                    'https://json-schema.org/draft/2020-12/vocab/applicator':
                        true,
                  },
                },
              },
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets(
    'string edits validate, save, and reset through an ancestor Form',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      Object? saved;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.string().min(3).toJsonSchema(),
              initialValue: 'Original',
              onChanged: (value) => changed = value,
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'No');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.byType(InputDecorator).first, findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Updated');
      expect(key.currentState!.validate(), isTrue);
      key.currentState!.save();
      expect(changed, 'Updated');
      expect(saved, 'Updated');
      key.currentState!.reset();
      await tester.pump();
      expect(changed, 'Original');
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        'Original',
      );
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('required properties remain absent until edited', (tester) async {
    final key = GlobalKey<FormState>();
    Object? saved;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({'name': schema.string()}).toJsonSchema(),
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    key.currentState!.save();
    expect(saved, <String, Object?>{});
    await tester.enterText(_textField('name'), 'Temporary');
    await tester.enterText(_textField('name'), '');
    expect(key.currentState!.validate(), isTrue);
    key.currentState!.save();
    expect(saved, {'name': ''});
  });

  testWidgets('optional fields distinguish absence, empty string, and null', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? value;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'note': schema.string().nullable().optional(),
            }).toJsonSchema(),
            onChanged: (changed) => value = changed,
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isTrue);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Include note'));
    await tester.pump();
    expect(value, {'note': ''});
    await tester.tap(find.text('Use null for note'));
    await tester.pump();
    expect(value, {'note': null});
    expect(key.currentState!.validate(), isTrue);
    await tester.tap(find.text('Include note'));
    await tester.pump();
    expect(value, <String, Object?>{});
  });

  testWidgets(
    'numeric input retains exact large integers and rejects bad text',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.integer().toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '9007199254740993');
      expect(changed, BigInt.parse('9007199254740993'));
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), 'not a number');
      expect(key.currentState!.validate(), isTrue);
      expect(find.text('9007199254740993'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '-');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a JSON number.'), findsOneWidget);
      expect(changed, BigInt.parse('9007199254740993'));
      await tester.enterText(find.byType(TextFormField), '1.5');
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), '2');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets(
    'precise decimals use engine decoding and multipleOf validation',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.number().multipleOf(0.1).toJsonSchema(),
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '0.3');
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), '0.30000000000000004');
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byType(TextFormField),
        '0.123456789012345678901',
      );
      expect(changed, isA<schema.JsonNumber>());
    },
  );

  testWidgets('boolean fields change JSON booleans', (tester) async {
    Object? changed;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.boolean().toJsonSchema(),
          onChanged: (value) => changed = value,
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(changed, isTrue);
  });

  testWidgets(
    'array removal rebuilds indexed editors with the correct values',
    (tester) async {
      final key = GlobalKey<FormState>();
      Object? changed;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema
                  .array(schema.string().min(1))
                  .min(1)
                  .toJsonSchema(),
              initialValue: ['First', 'Second'],
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Remove item 1'));
      await tester.pump();
      expect(changed, ['Second']);
      expect(
        tester.widget<TextFormField>(_textField('0')).initialValue,
        'Second',
      );
      await tester.tap(find.text('Add item'));
      await tester.pump();
      expect(changed, ['Second', '']);
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(_textField('1'), 'Third');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  for (final draft in [
    schema.SchemaDraft.draft7,
    schema.SchemaDraft.draft202012,
  ]) {
    testWidgets('tuple editors follow ${draft.name} item spelling', (
      tester,
    ) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema
                  .tuple([schema.string(), schema.integer()])
                  .toJsonSchema(draft: draft),
              initialValue: ['Example', 3],
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _textField('1'),
                matching: find.byType(TextField),
              ),
            )
            .keyboardType,
        const TextInputType.numberWithOptions(signed: true),
      );
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(_textField('1'), '1.5');
      expect(find.text('3'), findsOneWidget);
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(_textField('1'), '-');
      expect(key.currentState!.validate(), isFalse);
    });
  }

  testWidgets('path overrides take precedence and use escaped JSON Pointers', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    SchemaField? selected;
    Object? saved;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'a/b~c': schema.string().min(3),
              'other': schema.string(),
            }).toJsonSchema(),
            initialValue: {'a/b~c': 'Original', 'other': 'Other'},
            onSaved: (value) => saved = value,
            typeBuilders: {
              schema.SchemaType.string: (_, field) =>
                  Text('Type ${field.instancePath}'),
            },
            pathBuilders: {
              '/a~1b~0c': (_, field) {
                selected = field;
                return TextFormField(
                  initialValue: field.value as String?,
                  validator: field.validator,
                  onChanged: field.onChanged,
                );
              },
            },
          ),
        ),
      ),
    );
    expect(selected!.instancePath, '/a~1b~0c');
    expect(find.text('Type /other'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'No');
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(selected!.errors.single.keyword, 'minLength');
    await tester.enterText(find.byType(TextFormField), 'Updated');
    expect(key.currentState!.validate(), isTrue);
    key.currentState!.save();
    expect(saved, {'a/b~c': 'Updated', 'other': 'Other'});
  });

  testWidgets(
    'root validation covers a custom editor without its own FormField',
    (tester) async {
      final key = GlobalKey<FormState>();
      SchemaField? selected;
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: SchemaForm(
              schema: schema.string().min(2).toJsonSchema(),
              initialValue: '',
              typeBuilders: {
                schema.SchemaType.string: (_, field) {
                  selected = field;
                  return const Text('Custom editor');
                },
              },
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      selected!.onChanged('Valid');
      await tester.pump();
      expect(key.currentState!.validate(), isTrue);
      selected!.setInputError('Incomplete document');
      expect(key.currentState!.validate(), isFalse);
      selected!.onChanged('Valid again');
      expect(key.currentState!.validate(), isTrue);
    },
  );

  testWidgets('root validation enforces dependencies across fields', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: _document({
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'email': {'type': 'string'},
              },
              'dependentRequired': {
                'name': ['email'],
              },
              'additionalProperties': false,
            }),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isTrue);
    await tester.tap(find.text('Include name'));
    await tester.pump();
    expect(key.currentState!.validate(), isFalse);
    await tester.tap(find.text('Include email'));
    await tester.pump();
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('references use root resources and a validated JSON editor', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: _document({r'$ref': 'name.json'}),
            baseUri: Uri.parse('https://example.com/root.json'),
            options: schema.SchemaOptions(
              resources: {
                Uri.parse('https://example.com/name.json'): {
                  'type': 'string',
                  'minLength': 3,
                },
              },
            ),
            initialValue: 'Original',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '"No"');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '"Valid"');
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('combinators keep complete engine semantics in the JSON editor', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.union([
              schema.string().min(2),
              schema.integer(),
            ]).toJsonSchema(),
            initialValue: 'Original',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'true');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '12');
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('boolean false schemas always fail validation', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.JsonSchema.never(),
            initialValue: null,
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '42');
    expect(key.currentState!.validate(), isFalse);
  });

  testWidgets('enum editor handles explicit null and deep JSON equality', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? saved;
    final document = _document({
      'enum': [
        null,
        {'a': 1, 'b': 2},
      ],
    });
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: document,
            initialValue: {'b': 2.0, 'a': 1},
            onSaved: (value) => saved = value,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      1,
    );
    expect(key.currentState!.validate(), isTrue);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('null').last);
    await tester.pumpAndSettle();
    key.currentState!.save();
    expect(saved, isNull);
    expect(key.currentState!.validate(), isTrue);
  });

  testWidgets('editing snapshots and preserves the original instance', (
    tester,
  ) async {
    final original = <String, Object?>{
      'name': 'Original',
      'extra': [1, 2],
    };
    Object? changed;
    final document = schema
        .object({'name': schema.string()})
        .passthrough()
        .toJsonSchema();
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: document,
          initialValue: original,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    original['name'] = 'External change';
    await tester.enterText(_textField('name'), 'Updated');
    expect(original['name'], 'External change');
    expect(changed, {
      'name': 'Updated',
      'extra': [1, 2],
    });
    expect(
      () => (changed! as Map<String, Object?>)['name'] = 'Mutation',
      throwsUnsupportedError,
    );
    expect(
      () => ((changed! as Map<String, Object?>)['extra']! as List<Object?>).add(
        3,
      ),
      throwsUnsupportedError,
    );
  });

  testWidgets('additional properties can be added and validated', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Object? changed;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.record(schema.integer()).toJsonSchema(),
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await tester.enterText(
      _textField('Additional properties (JSON)'),
      '{"count": 2}',
    );
    expect(changed, {'count': 2});
    expect(key.currentState!.validate(), isTrue);
    await tester.enterText(
      _textField('Additional properties (JSON)'),
      '{"count": "bad"}',
    );
    expect(key.currentState!.validate(), isFalse);
  });

  testWidgets('invalid sibling text survives optional field changes', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.object({
              'count': schema.integer(),
              'note': schema.string().optional(),
            }).toJsonSchema(),
            initialValue: {'count': 2},
          ),
        ),
      ),
    );
    await tester.enterText(_textField('count'), '-');
    await tester.tap(find.text('Include note'));
    await tester.pump();
    expect(find.text('-'), findsOneWidget);
    expect(key.currentState!.validate(), isFalse);
  });

  testWidgets('disabled and read-only nested fields reject changes', (
    tester,
  ) async {
    Object? changed;
    SchemaField? selected;
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: _document({
            'type': 'object',
            'readOnly': true,
            'properties': {
              'name': {'type': 'string'},
            },
            'required': ['name'],
            'additionalProperties': false,
          }),
          initialValue: {'name': 'Original'},
          onChanged: (value) => changed = value,
          typeBuilders: {
            schema.SchemaType.string: (_, field) {
              selected = field;
              return const Text('Custom');
            },
          },
        ),
      ),
    );
    expect(selected!.enabled, isFalse);
    selected!.onChanged('Changed');
    expect(changed, isNull);
    await tester.pumpWidget(
      _host(SchemaForm(schema: schema.string().toJsonSchema(), enabled: false)),
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
  });

  testWidgets(
    'theme decoration, typography, and layout extension are inherited',
    (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        inputDecorationTheme: const InputDecorationThemeData(
          filled: true,
          fillColor: Colors.amber,
        ),
        extensions: const [SchemaUiTheme(spacing: 23)],
      );
      await tester.pumpWidget(
        _host(
          SchemaForm(
            schema: schema.object({'name': schema.string()}).toJsonSchema(),
          ),
          theme: theme,
        ),
      );
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.filled, isTrue);
      expect(decorator.decoration.fillColor, Colors.amber);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding == const EdgeInsets.only(top: 23),
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('onUserInteraction automatically displays validation errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SchemaForm(
          schema: schema.string().min(3).toJsonSchema(),
          initialValue: 'Original',
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'No');
    await tester.pump();
    final decorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(decorator.decoration.errorText, isNotNull);
  });

  testWidgets('format assertion options are forwarded to the engine', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final document = schema.string().email().toJsonSchema();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(schema: document, initialValue: 'invalid email'),
        ),
      ),
    );
    expect(key.currentState!.validate(), isTrue);
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: document,
            initialValue: 'invalid email',
            options: schema.SchemaOptions(assertFormats: true),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
  });

  testWidgets('initial value updates apply on reset without discarding edits', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    final document = schema.string().toJsonSchema();
    Object? changed;
    Widget editor(String initial) => _host(
      Form(
        key: key,
        child: SchemaForm(
          schema: document,
          initialValue: initial,
          onChanged: (value) => changed = value,
        ),
      ),
    );
    await tester.pumpWidget(editor('First'));
    await tester.enterText(find.byType(TextFormField), 'Edited');
    await tester.pumpWidget(editor('Second'));
    expect(find.text('Edited'), findsOneWidget);
    key.currentState!.reset();
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(changed, 'Second');
  });

  testWidgets('schema changes rebuild editors and discard stale parse errors', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(schema: schema.integer().toJsonSchema()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '-');
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: SchemaForm(
            schema: schema.string().toJsonSchema(),
            initialValue: 'New',
          ),
        ),
      ),
    );
    expect(find.text('New'), findsOneWidget);
    expect(key.currentState!.validate(), isTrue);
  });

  for (final draft in [schema.SchemaDraft.draft2, schema.SchemaDraft.draft3]) {
    testWidgets(
      'historical ${draft.name} required properties use their dialect',
      (tester) async {
        final key = GlobalKey<FormState>();
        await tester.pumpWidget(
          _host(
            Form(
              key: key,
              child: SchemaForm(
                schema: schema
                    .object({
                      'name': schema.string(),
                      'note': schema.string().optional(),
                    })
                    .toJsonSchema(draft: draft),
              ),
            ),
          ),
        );
        expect(_textField('name'), findsOneWidget);
        expect(_textField('note'), findsNothing);
        expect(key.currentState!.validate(), isFalse);
        await tester.enterText(_textField('name'), 'Example');
        expect(key.currentState!.validate(), isTrue);
      },
    );
  }
}
