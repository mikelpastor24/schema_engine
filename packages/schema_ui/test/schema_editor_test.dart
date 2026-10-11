import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Finder _input(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

Finder _dropdown(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is InputDecorator && widget.decoration.labelText == label,
  ),
  matching: find.byType(DropdownButtonFormField<String>),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _kind(WidgetTester tester, int index, String kind) async {
  tester
      .widget<DropdownButtonFormField<String>>(_dropdown('Type').at(index))
      .onChanged!(kind);
  await tester.pumpAndSettle();
}

class _Messages extends SchemaEditorMessages {
  const _Messages();

  @override
  String get addProperty => 'Create field';

  @override
  String get invalidNumber => 'A numeric constraint is required.';
}

void main() {
  testWidgets('creates a required nullable email property with constraints', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: SchemaEditor(onSaved: (value) => output = value),
        ),
      ),
    );
    await _tap(tester, find.text('Add property'));
    await _enter(tester, _input('Property name'), 'email');
    await _tap(tester, find.text('Required'));
    await _tap(tester, find.text('Allow null').last);
    await _tap(tester, find.text('Constraints and annotations').last);
    await _enter(tester, _input('Minimum length'), '3');
    await _enter(tester, _input('Maximum length'), '100');
    await _enter(tester, _input('Format'), 'email');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    form.currentState!.save();
    expect(output!.draft, schema.SchemaDraft.draft202012);
    expect(output!.toJson(), {
      r'$schema': schema.SchemaDraft.draft202012.metaSchemaUri,
      'type': 'object',
      'properties': {
        'email': {
          'type': ['string', 'null'],
          'minLength': 3,
          'maxLength': 100,
          'format': 'email',
        },
      },
      'required': ['email'],
    });
    final validator = output!.compile(
      options: schema.SchemaOptions(assertFormats: true),
    );
    expect(validator.isValid({'email': 'user@example.com'}), isTrue);
    expect(validator.isValid({'email': null}), isTrue);
    expect(validator.isValid({}), isFalse);
    expect(validator.isValid({'email': '123'}), isFalse);
  });

  testWidgets('creates nested objects and typed array items', (tester) async {
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(SchemaEditor(onChanged: (value) => output = value)),
    );
    await _tap(tester, find.text('Add property'));
    await _enter(tester, _input('Property name'), 'address');
    await _kind(tester, 1, 'object');
    await _tap(tester, find.text('Add property').first);
    await _enter(tester, _input('Property name').last, 'city');
    await _tap(tester, find.text('Add property').last);
    await _enter(tester, _input('Property name').last, 'scores');
    await _kind(tester, 3, 'array');
    await _kind(tester, 4, 'integer');
    await _tap(tester, find.text('Unique items'));
    final validator = output!.compile();
    expect(
      validator.isValid({
        'address': {'city': 'Madrid'},
        'scores': [1, 2],
      }),
      isTrue,
    );
    expect(
      validator.isValid({
        'address': {'city': 3},
      }),
      isFalse,
    );
    expect(
      validator.isValid({
        'scores': [1.5],
      }),
      isFalse,
    );
    expect(
      validator.isValid({
        'scores': [1, 1],
      }),
      isFalse,
    );
  });

  testWidgets('retains exact limits and JSON annotations', (tester) async {
    schema.JsonSchema? output;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: SchemaEditor(
            schema: schema.JsonSchema.build(type: schema.SchemaType.number),
            onChanged: (value) => output = value,
          ),
        ),
      ),
    );
    await _tap(tester, find.text('Constraints and annotations'));
    await _enter(tester, _input('Minimum'), '9007199254740993');
    await _enter(tester, _input('Multiple of'), '0.123456789012345678901');
    await _enter(tester, _input('Default value (JSON)'), 'null');
    await _enter(tester, _input('Examples (JSON array)'), '[9007199254740993]');
    expect(form.currentState!.validate(), isTrue);
    final value = output!.toJson() as Map<String, Object?>;
    expect(value['minimum'], BigInt.parse('9007199254740993'));
    expect(value['multipleOf'], isA<schema.JsonNumber>());
    expect(value.containsKey('default'), isTrue);
    expect(value['default'], isNull);
    expect(value['examples'], [BigInt.parse('9007199254740993')]);
    await _enter(tester, _input('Multiple of'), '0');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter a number greater than zero.'), findsOneWidget);
  });

  testWidgets('renames definitions and escaped local references safely', (
    tester,
  ) async {
    final original = schema.JsonSchema.fromJson({
      'type': 'object',
      'properties': {
        'name': {r'$ref': r'#/$defs/text'},
        'dynamic': {r'$dynamicRef': r'#/$defs/text'},
        'scoped': {r'$ref': r'#/$defs/scope'},
      },
      r'$defs': {
        'text': {'type': 'string', 'minLength': 1},
        'scope': {
          r'$id': 'https://example.com/scope',
          r'$defs': {
            'text': {'type': 'integer'},
          },
          r'$ref': r'#/$defs/text',
        },
      },
      'default': {r'$ref': r'#/$defs/text'},
      'allOf': [
        {
          'properties': {
            'alias': {r'$ref': r'#/$defs/text'},
          },
        },
      ],
    });
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(
        SchemaEditor(schema: original, onChanged: (value) => output = value),
      ),
    );
    await _enter(tester, _input('Definition name').first, 'text /~%#');
    final document = output!.toJson() as Map<String, Object?>;
    final properties = document['properties']! as Map<String, Object?>;
    final reference = (properties['name']! as Map)[r'$ref']! as String;
    expect(
      Uri.decodeComponent(Uri.parse(reference).fragment),
      r'/$defs/text ~1~0%#',
    );
    expect((document['default']! as Map)[r'$ref'], r'#/$defs/text');
    expect(
      output!.compile().isValid({'name': 'Example', 'alias': ''}),
      isFalse,
    );
    expect(
      output!.compile().isValid({'name': 'Example', 'alias': 'Alias'}),
      isTrue,
    );
    expect(((original.toJson() as Map)[r'$defs']! as Map)['text'], {
      'type': 'string',
      'minLength': 1,
    });
    await _enter(tester, _input('Definition name').first, 'percent%20/%2F');
    final renamed = output!.toJson() as Map;
    final fields = renamed['properties']! as Map;
    final wire = (fields['name']! as Map)[r'$ref']! as String;
    expect(
      Uri.decodeComponent(Uri.parse(wire).fragment),
      r'/$defs/percent%20~1%2F',
    );
    expect((fields['dynamic']! as Map)[r'$dynamicRef'], wire);
    expect(
      ((renamed[r'$defs']! as Map)['scope']! as Map)[r'$ref'],
      r'#/$defs/text',
    );
    expect(output!.compile().isValid({'scoped': 3, 'dynamic': 'Text'}), isTrue);
    expect(output!.compile().isValid({'scoped': 'Text'}), isFalse);
    await _enter(tester, _input('Reference').first, '#/%FF');
    await _enter(tester, _input('Definition name').first, 'repaired');
    expect(tester.takeException(), isNull);
    await _enter(tester, _input('Reference').first, r'#/$defs/repaired');
    expect(output!.compile().isValid({'name': 'Text'}), isTrue);
  });

  testWidgets('creates reusable definitions and selects a reference', (
    tester,
  ) async {
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(SchemaEditor(onChanged: (value) => output = value)),
    );
    await _tap(tester, find.text('Add definition'));
    await _enter(tester, _input('Definition name'), 'activeState');
    await _kind(tester, 1, 'boolean');
    await _tap(tester, find.text('Add property'));
    await _enter(tester, _input('Property name'), 'active');
    await _kind(tester, 1, 'reference');
    expect(_dropdown('Use definition'), findsOneWidget);
    expect(output!.compile().isValid({'active': true}), isTrue);
    expect(output!.compile().isValid({'active': 'yes'}), isFalse);
  });

  testWidgets('invalid edits cannot emit or save and recover when corrected', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    var changes = 0;
    var saves = 0;
    final validity = <bool>[];
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: SchemaEditor(
            schema: schema.JsonSchema.build(type: schema.SchemaType.number),
            onChanged: (_) => changes++,
            onSaved: (_) => saves++,
            onValidityChanged: validity.add,
          ),
        ),
      ),
    );
    await _tap(tester, find.text('Constraints and annotations'));
    await _enter(tester, _input('Minimum'), '-');
    expect(form.currentState!.validate(), isFalse);
    form.currentState!.save();
    expect(changes, 0);
    expect(saves, 0);
    await _enter(tester, _input('Minimum'), '12.');
    expect(form.currentState!.validate(), isTrue);
    form.currentState!.save();
    expect(changes, 1);
    expect(saves, 1);
    expect(validity, [false, true]);
    await _enter(tester, _input('Allowed values (JSON array)'), 'false');
    expect(form.currentState!.validate(), isFalse);
    form.currentState!.save();
    expect(saves, 1);
    form.currentState!.reset();
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isTrue);
    expect(validity, [false, true, false, true]);
  });

  testWidgets('duplicate properties and definitions remain editable', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: SchemaEditor(
            onChanged: (value) => output = value,
            schema: schema.JsonSchema.fromJson({
              'type': 'object',
              'properties': {
                'a': {r'$ref': r'#/$defs/a'},
                'b': {'type': 'string'},
              },
              r'$defs': {
                'a': {'type': 'string'},
                'b': {'type': 'boolean'},
              },
              'required': ['a'],
            }),
          ),
        ),
      ),
    );
    await _enter(tester, _input('Property name').last, 'a');
    expect(form.currentState!.validate(), isFalse);
    await _enter(tester, _input('Property name').last, 'b');
    await _enter(tester, _input('Definition name').last, 'a');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _enter(tester, _input('Definition name').last, 'b');
    expect(form.currentState!.validate(), isTrue);
    final result = output!.toJson() as Map;
    expect(result['required'], ['a']);
    expect(
      ((result['properties']! as Map)['a']! as Map)[r'$ref'],
      r'#/$defs/a',
    );
  });

  testWidgets('additional property schemas validate dynamic object values', (
    tester,
  ) async {
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(SchemaEditor(onChanged: (value) => output = value)),
    );
    tester
        .widget<DropdownButtonFormField<String>>(
          _dropdown('Additional properties'),
        )
        .onChanged!('schema');
    await tester.pumpAndSettle();
    await _kind(tester, 1, 'integer');
    expect(output!.compile().isValid({'count': 3}), isTrue);
    expect(output!.compile().isValid({'count': 'three'}), isFalse);
    tester
        .widget<DropdownButtonFormField<String>>(
          _dropdown('Additional properties').first,
        )
        .onChanged!('forbid');
    await tester.pump();
    expect(output!.compile().isValid({}), isTrue);
    expect(output!.compile().isValid({'count': 3}), isFalse);
  });

  testWidgets('removing a used definition blocks submission until repaired', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    var saves = 0;
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: SchemaEditor(
            schema: schema.JsonSchema.fromJson({
              'type': 'object',
              'properties': {
                'value': {r'$ref': r'#/$defs/text'},
              },
              r'$defs': {
                'text': {'type': 'string'},
              },
            }),
            onChanged: (value) => output = value,
            onSaved: (_) => saves++,
          ),
        ),
      ),
    );
    await _tap(tester, find.byTooltip('Remove text'));
    expect(form.currentState!.validate(), isFalse);
    form.currentState!.save();
    expect(saves, 0);
    expect(output, isNull);
    await _tap(tester, find.byTooltip('Remove value'));
    expect(form.currentState!.validate(), isTrue);
    form.currentState!.save();
    expect(saves, 1);
    expect(output!.compile().isValid({}), isTrue);
  });

  testWidgets(
    'preserves implied types, union types, and recursive definitions',
    (tester) async {
      schema.JsonSchema? output;
      final implicit = schema.JsonSchema.fromJson({
        'properties': {
          'name': {'type': 'string'},
        },
        r'$defs': {
          'tree': {
            'type': 'object',
            'properties': {
              'children': {
                'type': 'array',
                'items': {r'$ref': r'#/$defs/tree'},
              },
            },
          },
        },
      });
      Widget editor(schema.JsonSchema source) => _host(
        SchemaEditor(schema: source, onChanged: (value) => output = value),
      );
      await tester.pumpWidget(editor(implicit));
      await _enter(tester, _input('Property name').first, 'displayName');
      expect((output!.toJson() as Map).containsKey('type'), isFalse);
      expect(
        (output!.toJson() as Map)[r'$defs'],
        (implicit.toJson() as Map)[r'$defs'],
      );
      expect(output!.compile().isValid({'displayName': 3}), isFalse);
      final union = schema.JsonSchema.fromJson({
        'type': ['string', 'integer', 'null'],
        'x-extension': [1, 2],
      });
      await tester.pumpWidget(editor(union));
      expect(find.text('Multiple types'), findsOneWidget);
      await _tap(tester, find.text('Constraints and annotations'));
      await _enter(tester, _input('Title'), 'Identifier');
      expect((output!.toJson() as Map)['type'], ['string', 'integer', 'null']);
      expect((output!.toJson() as Map)['x-extension'], [1, 2]);
      expect(output!.compile().isValid(3), isTrue);
      expect(output!.compile().isValid(false), isFalse);
      await tester.pumpWidget(
        editor(
          schema.JsonSchema.fromJson({
            'type': ['null'],
          }),
        ),
      );
      expect(find.text('Null'), findsOneWidget);
      expect(find.text('Multiple types'), findsNothing);
    },
  );

  testWidgets(
    'uses themed controls and interactive type and format selectors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      schema.JsonSchema? output;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.deepPurple,
            ),
            extensions: const [SchemaUiTheme(spacing: 8)],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchemaEditor(onChanged: (value) => output = value),
            ),
          ),
        ),
      );
      await _tap(tester, _dropdown('Type'));
      await _tap(tester, find.text('String').last);
      await _tap(tester, find.text('Constraints and annotations'));
      await _enter(tester, _input('Format'), 'em');
      await _tap(tester, find.text('email').last);
      expect((output!.toJson() as Map)['format'], 'email');
      await _enter(tester, _input('Format'), 'ur');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect((output!.toJson() as Map)['format'], 'uri');
      final decorator = tester.widget<InputDecorator>(
        find.descendant(
          of: _input('Title'),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(decorator.decoration.fillColor, Colors.deepPurple);
      await _enter(
        tester,
        _input('Allowed values (JSON array)'),
        '["yes","no"]',
      );
      await _enter(tester, _input('Constant value (JSON)'), '"yes"');
      expect(output!.compile().isValid('yes'), isTrue);
      expect(output!.compile().isValid('no'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renaming and deleting required properties updates required', (
    tester,
  ) async {
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(
        SchemaEditor(
          schema: schema.JsonSchema.fromJson({
            'type': 'object',
            'properties': {
              'a': {'type': 'string'},
            },
            'required': ['a'],
          }),
          onChanged: (value) => output = value,
        ),
      ),
    );
    await _enter(tester, _input('Property name'), 'renamed');
    expect((output!.toJson() as Map)['required'], ['renamed']);
    await _tap(tester, find.byTooltip('Remove renamed'));
    expect((output!.toJson() as Map)['required'], isEmpty);
    expect(output!.compile().isValid({}), isTrue);
  });

  testWidgets('external documents replace controls and preserve extensions', (
    tester,
  ) async {
    schema.JsonSchema? output;
    final second = schema.JsonSchema.fromJson({
      'type': 'array',
      'items': {'type': 'boolean'},
      'prefixItems': [
        {'type': 'integer'},
      ],
      'x-extension': {'enabled': true},
    });
    Widget editor(schema.JsonSchema source) => _host(
      SchemaEditor(schema: source, onChanged: (value) => output = value),
    );
    await tester.pumpWidget(
      editor(schema.JsonSchema.build(type: schema.SchemaType.string)),
    );
    await tester.pumpWidget(editor(second));
    expect(find.text('Item schema'), findsOneWidget);
    await _tap(tester, find.text('Unique items'));
    final value = output!.toJson() as Map;
    expect(value['x-extension'], {'enabled': true});
    expect(value['prefixItems'], [
      {'type': 'integer'},
    ]);
    expect(value['items'], {'type': 'boolean'});
  });

  testWidgets('message changes preserve pending text and disabled edits', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final source = schema.JsonSchema.build(type: schema.SchemaType.number);
    Widget editor(SchemaEditorMessages messages, {bool enabled = true}) =>
        _host(
          Form(
            key: form,
            child: SchemaEditor(
              schema: source,
              messages: messages,
              enabled: enabled,
            ),
          ),
        );
    await tester.pumpWidget(editor(const SchemaEditorMessages()));
    await _tap(tester, find.text('Constraints and annotations'));
    await _enter(tester, _input('Minimum'), '-');
    await tester.pumpWidget(editor(const _Messages()));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('A numeric constraint is required.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: _input('Minimum'),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '-',
    );
    await tester.pumpWidget(editor(const _Messages(), enabled: false));
    expect(tester.widget<TextFormField>(_input('Minimum')).enabled, isFalse);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(_dropdown('Type'))
          .onChanged,
      isNull,
    );
  });

  testWidgets('selects schema kinds and rejects historical drafts', (
    tester,
  ) async {
    schema.JsonSchema? output;
    await tester.pumpWidget(
      _host(SchemaEditor(onChanged: (value) => output = value)),
    );
    for (final kind in [
      'integer',
      'number',
      'boolean',
      'null',
      'any',
      'never',
    ]) {
      await _kind(tester, 0, kind);
      expect(output!.draft, schema.SchemaDraft.draft202012);
      if (kind == 'never') {
        expect(output!.toJson(), false);
      } else {
        expect((output!.toJson() as Map)['type'], kind == 'any' ? null : kind);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _host(
        SchemaEditor(
          schema: schema.JsonSchema.build(draft: schema.SchemaDraft.draft7),
        ),
      ),
    );
    expect(tester.takeException(), isArgumentError);
  });

  testWidgets('empty and fragment references preserve recursive schemas', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    schema.JsonSchema? saved;
    for (final reference in ['', '#']) {
      await tester.pumpWidget(
        _host(
          Form(
            key: form,
            child: SchemaEditor(
              schema: schema.JsonSchema.fromJson({
                'type': 'object',
                'properties': {
                  'child': {r'$ref': reference},
                },
              }),
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(saved!.compile().isValid({'child': <String, Object?>{}}), isTrue);
      expect(saved!.compile().isValid({'child': 12}), isFalse);
      final field = tester.widget<TextFormField>(_input('Reference'));
      field.onChanged!('');
      await tester.pump();
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(((saved!.toJson() as Map)['properties']! as Map)['child'], {
        r'$ref': '',
      });
    }
  });

  testWidgets('2020-12 enums preserve empty and repeated values', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    schema.JsonSchema? saved;
    for (final values in [
      <Object?>[],
      <Object?>[1, 1],
    ]) {
      await tester.pumpWidget(
        _host(
          Form(
            key: form,
            child: SchemaEditor(
              schema: schema.JsonSchema.fromJson({'enum': values}),
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(saved!.compile().isValid(1), values.isNotEmpty);
      await _tap(tester, find.text('Constraints and annotations'));
      await _enter(
        tester,
        _input('Allowed values (JSON array)'),
        schema.encodeJson(values),
      );
      await _enter(tester, _input('Examples (JSON array)'), '[]');
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect((saved!.toJson() as Map)['enum'], values);
      await _enter(tester, _input('Examples (JSON array)'), '1');
      expect(form.currentState!.validate(), isFalse);
    }
  });
}
