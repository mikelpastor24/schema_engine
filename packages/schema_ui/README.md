# schema_ui

Theme-aware Flutter form fields generated from
[schema_engine](../schema_engine) JSON Schema documents. Use the same schema to
build an editor and validate the resulting JSON instance. Requires Flutter 3.47
and Dart 3.13 or later. Original implementation, licensed under MIT.

## Create or edit an instance

```dart
import 'package:flutter/material.dart';
import 'package:schema_engine/schema_engine.dart' as schema;
import 'package:schema_ui/schema_ui.dart';

final document = schema.object({
  'name': schema.string().min(1),
  'age': schema.integer().nonnegative().optional(),
  'active': schema.boolean(),
  'tags': schema.array(schema.string()).optional(),
}).toJsonSchema();
final formKey = GlobalKey<FormState>();

final editor = Form(
  key: formKey,
  child: SchemaForm(
    schema: document,
    initialValue: {'name': 'Example', 'active': true},
    autovalidateMode: AutovalidateMode.onUserInteraction,
    onChanged: (instance) => print(schema.encodeJson(instance)),
    onSaved: (instance) => print(instance),
  ),
);
```

Omit `initialValue` to start a new instance. Object properties stay absent until
edited or explicitly assigned. A required string does not become present merely
because its empty editor is displayed. Empty strings and explicit null remain
distinct from absent properties. Every optional property is visible from the
start and its default label includes `(optional)`. Untouched optional fields
are omitted from the JSON. Nullable types provide a null switch.

Clearing an optional free-text or numeric field omits its property. Removing
the last item from an optional array omits the array. Empty optional object
ancestors are removed when their last assigned property is cleared; root
objects and array items remain intact. A clear button appears beside assigned
or invalid optional fields so booleans, enum selections, nulls, and containers
can also return to an absent state. Required fields continue to follow their
schema validation rules.

Zero, false, explicitly selected null, enum choices (including an empty string),
and explicitly assigned JSON values are retained. Existing initial instance
values are not stripped, including empty strings and containers. Merely showing
a control, changing focus, validating, or saving never assigns a default value.

`SchemaForm` does not add a nested `Form`. Place it inside your own `Form` and
call `formKey.currentState!.validate()`, then `save()` to submit, or `reset()` to
restore the initial instance. It can also edit and emit values without a Form.
Initial-value changes take effect on reset. Schema, options, or base URI changes
recompile and restart the editor; keep those objects stable across ordinary
parent rebuilds.

The schema is compiled once per configuration. Diagnostic results are computed
on validation and reused across fields until the instance changes. Validation
covers the complete document, including dependencies, combinators, references,
and container constraints. Field validators show errors at their instance
pointer; the root shows the first overall error, including failures at
properties without dedicated controls. `save()` follows Flutter's behavior and
does not implicitly validate. Parsing errors keep the last JSON value and make
the form invalid until corrected.

Values emitted by `onChanged` and `onSaved` are immutable snapshots. The editor
never modifies the supplied instance. Numbers use the engine's lossless JSON
decoder, including `BigInt` and `JsonNumber`; use `schema.encodeJson` for these
values. Defaults are suggestions when explicitly adding an array item, not
automatic changes to an existing instance.

## Text and numeric input

Text, numeric, and raw JSON editors have separate implementations and input
policies. Integer fields request a signed integer keyboard and accept a leading
minus sign and ASCII digits. Number fields request a signed decimal keyboard
and also accept fractions and scientific notation. A dot or comma can be used
as the decimal separator; a leading separator such as `.5` is decoded as `0.5`.
Grouping separators are not supported. Exact decoding still preserves large
integers and precise decimals.

Numeric formatters reject the entire edit for misplaced signs, repeated
separators, alphabetic text, or other malformed input rather than stripping
characters into a different number. Partial edits such as `-`, `1.`, or `1e-`
remain visible and fail form validation until completed. Clearing an optional
numeric field removes the property instead. IME composition and caret positions
are preserved. Integral decimal representations already present in an instance
are retained; newly entered integer text uses integer notation.
Bounds and `multipleOf` remain validator checks, and numeric keyboards keep the
minus sign available so invalid negative values can be corrected explicitly.

When numeric text cannot be decoded, validation checks a temporary document
containing that text at the field's JSON Pointer and displays the engine's
diagnostic, usually the `type` assertion. The saved instance still retains the
last decoded value. If the schema accepts the text, for example because its
validation vocabulary is inactive, the engine's decoder diagnostic reports the
parsing failure. Messages are not hardcoded in the numeric widget.

Strings use a single-line formatter and a text keyboard, with email keyboards
for `email`/`idn-email`, URL keyboards for URI/IRI formats, and date/time keyboards
for `date`, `time`, and `date-time`. These hints also apply when formats are
annotations. Patterns and length constraints are validated without filtering
or truncating text, preserving JSON Schema's Unicode code-point semantics.
Numeric and structured-format fields disable autocorrection and suggestions.
Raw JSON editors use multiline keyboards and do not apply numeric filtering.
Custom builders continue to control their own keyboards and formatters.

## Override widgets

Override every string editor, for example with an application rich text editor,
using `typeBuilders`. A builder receives the schema fragment, instance pointer,
value, presence, enabled state, validation policy, engine errors, and callbacks.
Feed the editor's JSON string into `field.onChanged`; use `field.validator` in
your FormField to show schema errors. For example, a multiline replacement:

```dart
SchemaForm(
  schema: document,
  typeBuilders: {
    schema.SchemaType.string: (context, field) => TextFormField(
      initialValue: field.value as String?,
      enabled: field.enabled,
      autovalidateMode: field.autovalidateMode,
      decoration: InputDecoration(
        labelText: field.label,
      ),
      minLines: 3,
      maxLines: null,
      validator: field.validator,
      onChanged: field.onChanged,
    ),
  },
);
```

For one particular field, use `pathBuilders: {'/biography': builder}`.
Path overrides take precedence over type overrides, including default enum and
nullable editors. Paths are escaped JSON Pointers: `/a~1b~0c` identifies key
`a/b~c`; `''` identifies the root and `/tags/0` identifies an array element.
After removing array items, index-based overrides follow the new indexes.

Custom editors can use `field.setInputError(message)` for unparseable input and
clear it with null. `field.onChanged` also clears the field's input error. Honor
`field.enabled`, and call `onChanged` before invoking validation: the validator
checks the current full document, not its candidate argument. The root remains
registered with the ancestor Form even when an override has no FormField.
Custom editors handle their own display state; their subtree is recreated on
reset and structural changes such as nullable switches or array removals.

Custom builders receive absent optional fields too. Use `field.label` for the
localized display label, `field.messages` for the form's message configuration,
and `field.isPresent` to distinguish absence from null.
`field.onChanged('')` omits an optional free-text property. Call `field.clear()`
to omit other optional values and reset the editor:

```dart
IconButton(
  tooltip: field.messages.clearValueTooltip(field.label),
  onPressed: field.enabled && !field.isRequired ? field.clear : null,
  icon: const Icon(Icons.clear),
);
```

Required fields, root values, and array items cannot be omitted through `clear`.

## Theme

Controls inherit `ThemeData`, including input decoration, colors, typography,
button themes, switch themes, and control sizing. `title` supplies labels and
`description` supplies helper text. No control colors or font sizes are fixed
by the package. Boolean fields show their label once, beside the switch; their
input decorator still displays descriptions and validation errors. Configure
layout spacing through a theme extension:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  extensions: const [SchemaUiTheme(spacing: 12)],
);
```

`readOnly: true` disables a field and its descendants. `enabled: false` disables
the whole editor. These are presentation policies, not validation assertions.

## Localize form messages

Pass `SchemaFormMessages` to `SchemaForm.messages` and override only the text or
formatters you need. Defaults preserve the current English labels and original
engine diagnostics. For example, to customize the optional marker and controls:

```dart
SchemaForm(
  schema: document,
  messages: SchemaFormMessages(
    optionalLabel: (label) => '$label (not required)',
    addItemLabel: 'Add another item',
    clearValueTooltip: (label) => 'Clear field: $label',
    removeItemTooltip: (number) => 'Remove entry $number',
    requiredPropertyError: 'A value is required.',
    invalidJsonError: 'The JSON text is invalid.',
  ),
);
```

Strings and callbacks can come directly from your application's
[Flutter localizations](https://docs.flutter.dev/ui/internationalization).
For example, pass a generated getter to `addItemLabel` and a generated method
tear-off to `optionalLabel`. The package requires no additional localization
dependency or delegate. It does not select a language automatically; the
application supplies the messages for its current locale.

The configuration covers the fallback root label, optional markers, clear
tooltips, nullable switches, array add/remove controls, additional-property
labels, required-property errors, and JSON parsing errors. Label callbacks
receive the full label so translations control punctuation and word order.
Array removal callbacks receive one-based item numbers. Schema titles,
descriptions, property names, and enum values remain application-supplied text.

Use `validationError` to share an engine `ValidationMessages` catalog. Errors
carry a stable `code`, immutable `parameters`, and their original schema/instance
locations, so translations can include limits and expected types without
matching English text. Only English is bundled; the application supplies any
other locale through templates or a custom catalog. For example:

```dart
final errors = schema.ValidationMessages.fromTemplates({
  schema.ValidationErrorCodes.minLength: (error) => 'Minimum length: ${error.parameters['limit']}.',
});
SchemaForm(
  schema: document,
  messages: SchemaFormMessages(validationError: errors.format),
);
```

This changes presentation only; the engine's validity results and
`SchemaField.errors` remain intact. Missing required fields use their specific
engine diagnostic by default; `requiredPropertyError` can override that text.
The same catalog can be used with pure Dart validators through
`SchemaOptions.messageFormatter` or per-call `messageFormatter`. In Flutter,
updating `SchemaFormMessages.validationError` selects another catalog while
preserving edits; changing engine compilation options restarts the editor.
See the engine's [diagnostic reference](../schema_engine/docs/diagnostics.md)
for all codes and parameters. `numberInputError` formats the decoder's
`FormatException` only when no schema assertion rejects the pending numeric
input. `errorSummary` formats the root's JSON Pointer and already formatted
error. Messages supplied by custom editors through `setInputError` stay as
provided; custom editors are responsible for localizing those strings.

`ValidationErrorCodes` is also exported by `schema_ui`, so form-only imports can
use constants such as `ValidationErrorCodes.minLength` directly in their catalog
keys and error comparisons. The engine owns the shared values.

Rebuilding with different messages preserves the instance, typed text, focus,
and pending input errors, without recompiling the schema. Updated error text
is used on the next validation, including automatic validation. Widget
overrides can use `field.label` and `field.messages` to share the same labels and
translations as generated fields.

## Rendering and validation scope

| Schema shape | Default editor |
| --- | --- |
| `string` | TextFormField with format-aware keyboard hints and single-line input |
| `integer` | Dedicated numeric TextFormField with a signed integer keyboard and integer formatter |
| `number` | Dedicated numeric TextFormField with a signed decimal keyboard, numeric formatter, and exact decoding |
| `boolean` | FormField with a SwitchListTile |
| `enum`, supported-draft `const` | DropdownButtonFormField; accepts null and structured JSON choices |
| One type plus `null` | Type editor with an explicit null switch |
| `object`, named `properties` | All fields shown; optional labels and clear controls |
| Additional properties and records | JSON object TextFormField; validates against the complete schema |
| `array` | Nested item editors with add/remove controls |
| Tuple schemas | Draft-aware `prefixItems` or tuple `items` editors |
| `$ref`, dynamic/recursive references, compositions, conditionals | JSON TextFormField or a path override |
| Boolean schemas, null-only schemas, multiple non-null types, unknown shapes | JSON TextFormField or a path override |
| An initial value with the wrong type | JSON TextFormField so it is preserved and can be corrected |

Automatic layouts are intentionally narrower than engine validation support.
References are not expanded into recursive widget trees. Branch selection,
dynamic property widgets, specialized format controls such as date pickers,
and automatic layouts for
custom vocabularies are not implemented. The engine still checks their
constraints in the fallback editor. See the engine's
[draft/feature matrix](../schema_engine/docs/conformance.md) for its recorded
validation evidence; the UI does not claim complete automatic rendering of
every keyword or draft.

Formats such as `email` and `uri` are annotations by default in the standard
dialects. To reject malformed values, create
`schema.SchemaOptions(assertFormats: true)` and pass the same options instance
to `SchemaForm.options` across parent rebuilds. Format-aware keyboards alone
do not enable validation. The example enables these assertions and displays
schema diagnostics while preventing invalid submissions.

Pass offline reference resources and
`baseUri` through the same options as engine compilation. The UI performs no
network loading; prepare resource maps separately. Invalid schemas and missing
resources propagate engine exceptions rather than becoming instance errors.

## Example and checks

The [example application](example/README.md) includes Web and Windows runners,
submission, reset, optional properties, and a string override. From the
repository root:

```sh
flutter pub get
cd packages/schema_ui/example
flutter run -d chrome
```

Use `flutter run -d windows` for the desktop application when the Windows
development toolchain is installed. The entry point is
[example/lib/main.dart](example/lib/main.dart).

From the repository root run `flutter pub get`; from this package run
`flutter test --no-pub`. Widget tests exercise Form integration, overrides,
exact numbers, references, themes, arrays, presence, and lifecycle behavior.
Run the example's widget tests separately from `example` with the same command.
