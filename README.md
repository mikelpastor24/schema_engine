# schema_engine

A portable Dart package for parsing, constructing, serializing, and compiling
JSON Schemas into reusable validators. The implementation is original Dart,
with no runtime dependencies or Flutter requirement. Its architecture applies
compilation and specialization ideas from the Rust [json-schema-rs / jsonschema](https://docs.rs/jsonschema/) project.

Requires Dart 3.13 or later. Licensed under MIT.

## Parse once, compile once, validate many times

```dart
import 'package:schema_engine/schema_engine.dart';

void main() {
  final schema = JsonSchema.parse(r'''
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "name": {"type": "string", "minLength": 1},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"],
      "additionalProperties": false
    }
  ''');
  final validator = document.compile();

  print(validator.isValid({'name': 'Example', 'age': 30})); // true
  print(validator.validate({'age': 30})); // First error, or null if valid.
  print(validator.errors({'name': '', 'age': -1})); // All assertion errors.
}
```

`isValid` avoids diagnostic errors, messages, and instance paths. Regular
expressions, references, and property lookups are prepared during compilation.
Scalar assertions have specialized boolean functions. Acyclic static references
avoid cycle-tracking state; recursive and dynamic references use a per-validation
context. Evaluation tracking is allocated where `unevaluated*` semantics require it.

Inputs are decoded JSON values: null, booleans, strings, finite numbers, lists,
and maps with string keys. Validators do not modify instances or perform I/O.
Schema documents are copied and frozen, so changing an original map cannot
change an already compiled validator.
Use `decodeJson` for JSON text whose large integers or precise decimals must
remain exact. The validators also accept `BigInt` and `JsonNumber` values.

## Declare schemas with a concise API

Use a Dart import namespace to compose immutable declarations:

```dart
import 'package:schema_engine/schema_engine.dart' as schema;

void main() {
  final user = schema.object({
    'name': schema.string().min(1),
    'age': schema.integer().min(0).optional(),
    'email': schema.string().email().optional(),
    'tags': schema.array(schema.string()).max(10).optional(),
  });

  final document = user.toJsonSchema(draft: schema.SchemaDraft.draft202012);
  print(document.toJsonString(indent: '  '));

  final validator = user.compile(options: schema.SchemaOptions(assertFormats: true));
  print(validator.isValid({'name': 'Example'})); // true
  print(validator.isValid({})); // false: name is required.
}
```

The construction style is inspired by [Zod](https://zod.dev/api), with an original
Dart implementation. Every property is required by default. Objects reject
additional properties; `.passthrough()` permits them, while `.catchall(definition)`
validates their values. Validation never strips properties or transforms input.
The default closed shape matches [Zod's JSON Schema output](https://zod.dev/json-schema).

`.optional()` allows an absent object property, `.nullable()` accepts null, and
`.nullish()` permits both. Optional markers do not affect root values or array
elements. `.defaultValue(value)` adds an annotation without filling missing
properties or making them optional. All modifiers return new declarations.

| Constructor or modifier | Purpose |
| --- | --- |
| `schema.string().min(1).max(100)` | Unicode code-point length bounds |
| `schema.string().pattern(r'^[a-z]+$')` | JSON Schema regular-expression checks |
| `schema.number().gt(0).multipleOf(0.5)` | Exclusive bounds and exact multiples |
| `schema.integer()` or `schema.number().int()` | Draft-specific integer constraints |
| `schema.boolean()`, `schema.nullValue()` | Boolean and null values |
| `schema.array(schema.string()).nonempty()` | Homogeneous arrays |
| `schema.tuple([schema.string(), schema.integer()]).rest(schema.boolean())` | Tuples with required positions and optional rest |
| `schema.record(schema.number())` | Objects with constrained property values |
| `schema.literal('ready')`, `schema.enumValues(['ready', 'pending'])` | Constants and string enumerations |
| `schema.union([schema.string(), schema.number()])`, `definition.or(other)` | Alternatives |
| `schema.intersection(left, right)`, `definition.and(other)` | Independent conjunctions |
| `schema.any()`, `schema.never()` | Arbitrary or impossible JSON values |

Object shapes support `.extend({...})`, `.pick(['name'])`, `.omit(['age'])`,
`.partial()`, and `.required()`. The last two accept `keys: [...]` for selected
properties and operate only on the current shape. Use `.extend()` to combine
closed shapes: an intersection validates each shape independently.

Generate a document with `.toJsonSchema(draft: ...)`, JSON values with
`.toJson(draft: ...)`, or text with `.toJsonString(draft: ..., indent: '  ')`.
The same declaration can target every published draft. Generation translates
presence rules, tuples, unions, exclusive bounds, and literal spelling. Features
absent from a selected dialect throw `SchemaException`, such as numeric multiples
in Draft 00/01 or unique arrays before Draft 02.

Compile once with `.compile()` or `.compileAsync()` and reuse the resulting
`CompiledSchema`. `SchemaOptions.draft` selects the generation target too.
The declaration layer delegates to the existing engine and adds no work during
instance validation. `SchemaCodeGenerator` accepts the resulting `JsonSchema`.

Use `.describe(text)`, `.defaultValue(value)`, and `.withKeywords({...})` after
typed constraints to add annotations or extensions. Raw keywords may override
generated assertions; compilation checks their syntax. `schema.fromSchema(document)`
embeds an existing document for the same selected draft, preserving references
and less common features. These declarations generate JSON Schemas; they do not
perform TypeScript type inference, coercion, or data transformation.

See [the executable declaration example](example/declarative.dart).

## Build schemas with typed arguments

```dart
final schema = JsonSchema.build(
  type: SchemaType.object,
  properties: {
    'name': JsonSchema.build(type: SchemaType.string, minLength: 1),
    'age': JsonSchema.build(type: SchemaType.integer, minimum: 0),
  },
  required: ['name'],
  additionalProperties: JsonSchema.fromJson(false),
  keywords: {'description': 'An example record.', 'x-purpose': 'sample'},
);

final jsonValue = schema.toJson();
final jsonText = schema.toJsonString(indent: '  ');
final parsed = JsonSchema.fromJson(jsonValue);
```

The builder translates tuple keywords, identifiers, definitions, exclusive
bounds, dependencies, and historical property-presence rules for the selected
draft. Unsupported typed options throw `SchemaException`. Use `keywords` for
annotations and extensions. Parsing and serialization preserve unknown keywords
and JSON semantics, including boolean schemas and null constants.

## Generate Dart code for known schemas

```dart
final source = SchemaCodeGenerator(schema).generate(className: 'RecordValidator');
// Save source as a Dart file and run dart format on it.
```

The generated class exposes `isValid`, `validate`, and `errors`. It emits direct
Dart expressions and loops for supported schemas and compiles diagnostics
lazily. Schemas requiring unsupported specialized checks use the runtime engine.
Custom options also select that engine so extensions and overrides keep their
semantics. `isSpecialized` reports which backend is active. The generated code
depends only on this package; no runtime source compilation or FFI is involved.

## Published drafts

| Specification | Selection | Important differences |
| --- | --- | --- |
| Draft 00 | `SchemaDraft.draft0` | `optional`, `requires`, equality flags, `maxDecimal`, `extends`, `disallow` |
| Draft 01 | `SchemaDraft.draft1` | Corrected original specification |
| Draft 02 | `SchemaDraft.draft2` | `divisibleBy` and `uniqueItems` |
| Draft 03 | `SchemaDraft.draft3` | Property-level `required`, `dependencies`, `patternProperties` |
| Draft 04 | `SchemaDraft.draft4` | Required-name arrays, boolean exclusive bounds, combinators |
| Draft 05 documents | `SchemaDraft.draft4` | Reuses the Draft 04 dialect and meta-schema |
| Draft 06 | `SchemaDraft.draft6` | Boolean schemas, `$id`, numeric exclusive bounds, `const`, `contains` |
| Draft 07 | `SchemaDraft.draft7` | `if`, `then`, `else` |
| 2019-09 | `SchemaDraft.draft201909` | Vocabularies, recursive references, unevaluated applicators |
| 2020-12 | `SchemaDraft.draft202012` | Dynamic references, `prefixItems`, revised `contains` annotations |

`$schema` selects the dialect when parsing. Undeclared documents default to
2020-12. The `draft` argument overrides the root declaration; an explicit
`SchemaOptions.draft` takes precedence during compilation. Nested resources can
declare their dialect. Undeclared resources inherit the root draft unless
`SchemaOptions.defaultDraft` is supplied.
In 2019-09 and 2020-12, nested dialect declarations require a separate resource
identifier. The builder enforces this when embedding a schema from another
dialect. Core URI values and modern identifier fragments are checked during
compilation under the `validateSchema` policy.

See [the original sample documents](example/schemas) and
[the executable all-drafts example](example/all_drafts.dart). This table describes
implemented dispatch and keywords. All 9,361 official cases for the published
drafts pass in each validation mode, including optional cases under their
documented policies. Drafts 00 through 02 have original specification-derived
tests. Details are recorded in [the support report](docs/conformance.md).

## References and resources

```dart
final validator = JsonSchema.fromJson({r'$ref': 'value.json'}).compile(
  baseUri: Uri.parse('https://example.com/root.json'),
  options: SchemaOptions(resources: {
    Uri.parse('https://example.com/value.json'): {'type': 'integer'},
  }),
);
```

URI resolution, escaped JSON Pointers, anchors, and recursive/dynamic references
are compiled before validation. Missing resources or fragments throw
`ReferenceException`. Use `compileAsync` with `SchemaOptions.resolver` to retrieve
decoded schema resources during preparation. Each missing retrieval URI is
loaded once. The core has no automatic network or filesystem access.
Published dialect meta-schemas and the 2019-09/2020-12 vocabulary meta-schemas
are available locally through their standard URIs. Their keyword grammars are
implemented originally in Dart.

## Formats, vocabularies, and extensions

Formats are annotations by default. Enable assertions explicitly:

```dart
final validator = JsonSchema.build(type: SchemaType.string, format: 'email')
    .compile(options: SchemaOptions(assertFormats: true));
```

Built-in checks include dates, times, durations, email, hostnames, IPv4/IPv6,
URI/IRI references, URI templates, UUIDs, JSON Pointers, and regular expressions.
International hostnames use an original Punycode/IDNA implementation with
generated Unicode 15.1 facts, normalization, joining context, and bidi checks.
Unknown formats are ignored in annotation dialects; `SchemaOptions.formats`
adds or overrides checks.

`SchemaOptions.keywords` registers application-defined assertions. Unknown
required vocabularies are rejected unless registered in
`SchemaOptions.vocabularies`. Register custom meta-schemas as resources and parse
their schemas with the corresponding published base `draft`. Their vocabulary
declarations control active built-in keywords. The 2020-12 Format-Assertion
vocabulary enforces formats and rejects unknown format names during compilation,
including when declared optional. A required 2019-09 Format vocabulary defaults
to assertions; `assertFormats: false` explicitly disables those assertions.

Content and metadata keywords are annotations by default. Enable
`SchemaOptions(assertContent: true)` for optional Draft 07 JSON/base64 assertions.
Content keywords remain annotations in 2019-09 and 2020-12.
`SchemaOptions(legacyDependencies: true)` enables the retired `dependencies`
keyword in those modern dialects as an explicit compatibility extension.
Compilation checks keyword
syntax by default, including definitions and inactive branches. Registered
custom meta-schemas can impose additional constraints, including constraints on
nested schemas through dynamic or recursive meta-schema references. These
checks run once during preparation and can be disabled with
`SchemaOptions(validateSchema: false)` for trusted schemas.

## Numeric representations

`multipleOf` uses exact decimal arithmetic over the supplied number's decimal
representation. Ordinary coefficients use bounded integer arithmetic; larger
values use `BigInt`. No epsilon is used: `0.3` is a multiple of `0.1`, while
`0.30000000000000004` is not.

`JsonSchema.parse` and `decodeJson` preserve integers beyond the portable exact
range as `BigInt`. Decimals that would round or overflow use `JsonNumber`, which
stores a decimal coefficient and scale. Bounds, equality, uniqueness, and
multiples understand all three representations. Use `encodeJson` for instances
containing exact numbers; `JsonSchema.toJsonString` handles them automatically.

```dart
final schema = JsonSchema.parse('{"type":"integer","minimum":9007199254740993}');
final instance = decodeJson('9007199254740993');
print(schema.compile().isValid(instance)); // true, on VM and JavaScript.
```

Precision lost before validation cannot be recovered. Ordinary JavaScript
numbers also lose the integer-versus-integral-double distinction used by Draft
04 and earlier. `decodeJson` preserves that distinction for decimal literals
on JavaScript using `JsonNumber`. Decimal exponents must fit the supported Dart
integer representation; memory and input size still bound exact arithmetic.

## Development and measurements

```sh
dart pub get
dart format lib test example benchmark tool
dart analyze
dart test
dart run example/all_drafts.dart
dart run benchmark/validation.dart
```

Benchmarks independently measure compilation, valid/invalid boolean checks,
first errors, and all errors after warmup across repeated samples. See
[performance measurements](docs/performance.md) for commands and measured scope.

The conformance harness reads the official JSON Schema Test Suite from an
external directory, retaining its license there. Third-party fixtures and
copyright notices are not vendored into this repository.
