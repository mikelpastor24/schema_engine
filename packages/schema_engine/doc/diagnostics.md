# Validation diagnostic parameters

`ValidationError.code` is independent of language and identifies a message
template. `keyword` identifies the assertion at `schemaPath` and
`schemaLocation`; `instancePath` is an escaped JSON Pointer. Parameter maps and
schema-derived lists/objects are immutable. Numeric parameters retain their
exact Dart JSON representation (`num`, `BigInt`, or `JsonNumber`).

Use the public `ValidationErrorCodes` namespace instead of writing code strings
in catalogs or diagnostic comparisons. For example, use
`ValidationErrorCodes.minLength` as a `ValidationMessages.fromTemplates` key.
Constants are strings, compatible with `ValidationError.code` and serialized
diagnostics. Member names match the codes below except for reserved Dart words:
`enumValue` is `enum`, `constant` is `const`, and `falseSchema` is `false`.
`ValidationErrorCodes.byKeyword` provides an immutable registry for catalog
generation and coverage checks. `forKeyword` maps an assertion name to its
canonical code and preserves unknown extension names. Applicators can select a
more specific code when a false schema rejects a property or item.

| Code | Parameters |
| --- | --- |
| `type` | `expectedTypes`: JSON type names; `actualType`: received JSON type; historical schema unions also have `schemaAlternatives` |
| `enum` | `allowedValues`: the frozen schema choices |
| `const` | `expectedValue`: the frozen schema constant |
| `minimum`, `maximum` | `limit`, `exclusive`, `actualValue` |
| `exclusiveMinimum`, `exclusiveMaximum` | `limit`, `actualValue` |
| `multipleOf`, historical `divisibleBy` | `divisor`, `actualValue` |
| Historical `maxDecimal` | `limit`, `decimalPlaces` |
| `minLength`, `maxLength` | `limit`, `length`: Unicode code points, not UTF-16 units |
| `pattern` | `pattern`: the source regular expression |
| `format` | `format`: the asserted format name |
| `contentEncoding` | `encoding`: the asserted encoding |
| `contentMediaType` | `mediaType`; `encoding` when base64 decoding applies |
| `minItems`, `maxItems`, `minProperties`, `maxProperties` | `limit`, `count` |
| `uniqueItems` | `firstIndex`, `secondIndex`: zero-based indexes of one equal pair |
| `required`, historical `optional` | `property`: the missing property name |
| `dependencies`, `dependentRequired`, historical `requires` | `property`: the trigger; `missingProperty`: its absent dependency |
| `additionalProperties`, `unevaluatedProperties` | `property`: the forbidden property name |
| `items`, `additionalItems` | `index`: the forbidden zero-based index; `limit`: allowed prefix length |
| `unevaluatedItems` | `index`: the forbidden zero-based index |
| `contains` | `minimum`, nullable `maximum`, `matches`, `reason`: `tooFew` or `tooMany` |
| `anyOf`, `oneOf`, `not` | `branchCount`, `matches` |
| Historical `disallow` | `disallowedTypes` and `actualType`, or `schemaIndex` for a disallowed schema; schema branches also expose combinator counts |
| `false` | No additional parameters |
| `custom` | `constraint`: the frozen application keyword value; use `keyword` for the application assertion name |

When a failure comes from `propertyNames`, `propertyName` identifies the name
being checked, including through references. The English catalog identifies it
before explaining the underlying constraint. Other catalogs can use this
parameter to format their own equivalent context.

False schemas under container applicators retain `keyword: false` and their
original schema location, while `code` identifies the applicator and supplies
the forbidden property or index. Historical missing-property diagnostics point
to the property's `optional` or `required` keyword. Historical string
dependencies point to their `requires` keyword.

`contains` with `reason: tooFew` has an exact match count. With `tooMany`,
`matches` is a lower bound because validation may stop when the maximum is
exceeded. Likewise, `oneOf` with multiple matching branches may stop after two;
its `matches` is an observed count, not necessarily the total. Messages must
not claim that unexamined branches or items were counted.

`allOf`, historical `extends`, conditional branches, schema dependencies,
references, `properties`, `patternProperties`, `propertyNames`, and schema-valued
item/applicator constraints propagate the failing child's specific diagnostic.
They do not replace it with a generic container error. Historical type unions
with schemas report code `type` with their type names and alternative count.
Integer diagnostics respect the dialect's decimal-versus-integer policy.

This representation covers the engine's implemented assertions. Format
annotations and inactive vocabularies do not become validation failures merely
because a message catalog exists. See [conformance and support](conformance.md)
for the implemented dialects and verification scope. The structure follows the
idea of carrying constraint details independently of text in
[jsonschema's error kinds](https://docs.rs/jsonschema/latest/jsonschema/error/enum.ValidationErrorKind.html),
with an original Dart implementation and code-based catalog API.

## Application-owned catalogs

Only `EnglishValidationMessages` is bundled. Any language can be supplied by
implementing `ValidationMessages.format`, extending the English class with
selected overrides, or using `ValidationMessages.fromTemplates` and a custom
fallback. No locale names, registries, Flutter types, or translation dependencies
are imposed on applications. A catalog works as `SchemaOptions.messageFormatter`,
a per-call formatter, or a presentation formatter on an existing error.

`ValidationError.message` is the single explanation getter. Formatters receive
the structured diagnostic without an active formatter and can use
`error.message` as a fallback. This keeps fallback handling identical for every
catalog and generates the base text only when requested.

Parameters are presentation data, not a new validation API. Custom formatters
return a string and cannot suppress an assertion failure by returning null.
Templates for `custom` can inspect `error.keyword` to distinguish application
keywords. Choose fallbacks explicitly; never match translated message text to
recover a code or a constraint.
