# Agent instructions

## Project goal

`schema_engine` is intended to be a Dart package for parsing, building,
serializing, and validating JSON Schemas, and validating their JSON instances.
The goal is to support every JSON Schema draft/version through a simple API,
with the best validation performance that can be demonstrated in Dart.

Specification correctness is mandatory. Within that constraint, validation
speed is the main technical priority. Easy schema parsing and generation are
the main public API priorities.

Use [json-schema-rs / jsonschema](https://docs.rs/jsonschema/)
as the design foundation: study its schema compilation, reference resolution,
keyword validators, validation modes, and benchmarks. Adapt and measure these
ideas in Dart; do not mechanically translate Rust structures or assume its
performance results carry over to Dart.

Write the implementation originally in Dart. Use the Rust project's ideas as
design references, without copying its source code.

## Documentation language

All project documentation must be written in English. This includes code
comments, `///` documentation comments, Dartdoc output, Markdown files, README
content, changelogs, architecture notes, examples, benchmark reports,
configuration comments, and any other documentation created or updated for the
project. This file must also remain in English.

Use English identifiers and descriptive text in examples and tests. Keep
documentation clear, concise, and consistent with the public API. User-facing
conversation may remain in Spanish unless the user requests another language.

## Effective Dart

Follow [Effective Dart](https://dart.dev/effective-dart) for all Dart code,
documentation, style, language usage, and API design. Consult the relevant guide
when implementing or reviewing changes; formatter and analyzer checks do not
cover every guideline. Apply the guide's distinction between mandatory rules,
preferences, practices to avoid, and context-dependent recommendations.

- [Style](https://dart.dev/effective-dart/style): use `UpperCamelCase` for types
  and extensions, `lowerCamelCase` for members, variables, constants, and enum
  values, and `lowercase_with_underscores` for packages, directories, source
  files, and import prefixes. Order imports as `dart:`, `package:`, then relative
  imports, sorting each section alphabetically; place exports after imports.
  Use `dart format`, braces for control flow, and preferably lines of at most
  80 characters.
- [Documentation](https://dart.dev/effective-dart/documentation): use `///` for
  API documentation. Document public APIs, starting with a concise summary in
  its own paragraph. Use Markdown and `[identifier]` references where applicable.
  Explain parameters, return values, exceptions, and behavior that matters to
  callers. Include useful examples. Comments should explain intent, constraints,
  or reasoning instead of repeating the code, and remain accurate after changes.
- [Usage](https://dart.dev/effective-dart/usage): use idiomatic Dart features,
  collection literals, initializing formals, and tear-offs when appropriate.
  Prefer `final` for locals that are not reassigned, and `var` for mutable locals.
  Use `async`/`await` when asynchronous work is needed; distinguish exceptions
  from programming errors and preserve stack traces with `rethrow`.
- [Design](https://dart.dev/effective-dart/design): choose consistent, descriptive
  names and keep implementation details private. Annotate function parameter
  and return types; prefer `Object?` over `dynamic` when static checking is
  intended. Use named boolean parameters, appropriate class modifiers, and
  immutable state where practical. Keep `==` and `hashCode` consistent. Avoid
  unnecessary wrappers, static-only utility classes, and returning `this`
  solely to create a fluent interface.

Keep analyzer and lint configuration aligned with Effective Dart as the package
evolves. Address applicable diagnostics rather than suppressing them broadly.
Document the reason for any justified exception to a preference or avoidance
guideline, including benchmark evidence when motivated by performance.

## Current state and structure

- The package is a pure Dart library with no runtime dependencies.
- `lib/schema_engine.dart` exports the public schema, draft, options, validator,
  diagnostic, and code-generation APIs; implementation lives in `lib/src/`.
- `test/` contains original tests and generated validator fixtures.
- `example/all_drafts.dart` and `example/schemas/` cover published dialects.
- `benchmark/` measures parsing, compilation, diagnostics, and runtime/generated
  boolean validation separately.
- `tool/` contains example/code generators, restricted-environment verification
  adapters, and external conformance-suite download/snapshot tools.
- `docs/conformance.md` and its snapshot manifest distinguish verified cases
  from missing-resource groups. Do not turn partial coverage into a full claim.
- The original source uses MIT with the project copyright in `LICENSE`.

## Specification and compatibility

The normative sources are the
[official specifications](https://json-schema.org/specification-links).
When json-schema-rs differs from a specification, the relevant draft's
specification takes precedence.

- Scope includes 2020-12, 2019-09, drafts 07, 06, 04, and historical drafts 03,
  02, 01, and 00. Draft 05 reuses draft 04 meta-schemas; study its documents
  without inventing a separate `draft-05` dialect. Consult the specifications
  when adding other published versions.
- Distinguish compatibility goals from implemented support. Document a matrix
  by draft and feature; do not claim complete support without tests.
- Select the dialect through `$schema` and allow explicit selection. Document
  the default draft and precedence between options and the schema document.
  Reject unsupported dialects with a clear error.
- Keep differences between drafts explicit: boolean schemas, `id`/`$id`,
  exclusive bounds, `definitions`/`$defs`, `dependencies`, `items`/`prefixItems`,
  `$ref` siblings, anchors, and dynamic or recursive references. Do not interpret
  every document as the most recent draft.
- Cover Core, Validation, and the vocabularies, annotations, and formats
  applicable to each draft. Distinguish `format` annotations from assertions.
  Follow the rules for required vocabularies and unknown keywords.
- Distinguish malformed JSON, invalid schemas, reference resolution failures,
  and instances that fail validation. Validate schemas against their meta-schema
  under an explicit policy, outside the validation of individual instances.

## Architecture and performance

- Separate parsing/modeling, construction/serialization, compilation, and
  execution. Compile once and reuse a validator for many instances.
- Resolve and index references, prepare regular expressions and lookup
  structures, and specialize validators during compilation where possible.
  Do not traverse the schema document again for every validation.
- Offer a fast boolean path, a first-error path, and an all-errors path. The
  boolean path must avoid unnecessary messages, error objects, and diagnostic
  paths; generate diagnostics lazily when requested.
- Short-circuit only when correct for the dialect and output mode.
  `unevaluatedProperties`, `unevaluatedItems`, and some combinators require
  evaluation information even when returning only a boolean.
- Validate Dart JSON values directly, including those from `dart:convert`.
  Do not encode and decode instances or copy whole trees during each validation.
  Do not modify the user's instance.
- Reduce allocations, repeated work, and dynamic dispatch in frequent paths
  according to measured profiles. A compiled validator must retain its behavior
  if the user later modifies the source map.
- Keep validation of instances with resolved schemas synchronous and free of
  I/O. Separate asynchronous reference loading into preparation and offer a
  resource registry and configurable resolvers. Offline validation must work.
- Handle cyclic and recursive references without infinite expansion during
  compilation. Caches must account for the dialect, options, and relevant
  resources, with lifetimes that avoid retaining schemas indefinitely.
- Keep Flutter, `dart:io`, and FFI dependencies out of the portable core. Isolate
  platform-specific adapters. Evaluate code generation for known schemas when
  benchmarks justify its complexity.

## Parsing and generation API

- Allow loading schemas from JSON text and already decoded JSON values. Support
  object and boolean schemas wherever the dialect allows them.
- Make programmatic construction easy through composable types and builders,
  autocompletion, and understandable errors. Avoid requiring untyped maps for
  common operations while preserving an escape hatch for extension keywords.
- Support serialization to JSON values and JSON text. Preserve unknown keywords,
  metadata, and semantics through parsing/serialization; preserving whitespace
  or original key ordering is not required.
- Make the dialect explicit when generating schemas and check that constructed
  keywords belong to it. Do not implicitly migrate schemas between drafts.
- Keep the construction API independent of validator internals. Document every
  public addition with small working examples.
- Instance errors must identify the keyword, schema location, and instance
  location through JSON Pointer. Diagnostic detail must not add unnecessary
  overhead to the boolean path.

## Tests and measurements

Use the [official JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite)
as the conformance baseline for each draft, pinning the revision used. For
historical drafts without official coverage, derive fixtures from their
specifications and document their provenance. Keep remote test resources local
and results reproducible without external services.

- Test valid, invalid, and boundary cases for every keyword and draft difference.
  Record pending cases and their reasons; do not hide conformance failures
  through silent exclusions.
- Test URI resolution, JSON Pointer escaping, anchors, `$ref`, recursion,
  dynamic references, combinators, and evaluated property/item tracking.
- Cover deep JSON equality, uniqueness, Unicode, integers represented as
  `double`, numeric bounds, and `multipleOf`. Document precision differences
  between VM and web; do not introduce arbitrary tolerances that change validity.
- Verify semantic preservation through parsing/serialization and
  construction/serialization, including unknown keywords and boolean schemas.
- Compare the same validator's modes: they must agree on validity even when
  they return different information. Add regression tests for bug fixes and
  tests for validator reuse.
- Measure parsing, compilation, boolean validation, first error, and all errors
  separately. Include valid and invalid instances, small and large schemas,
  references, recursion, objects, arrays, and combinators.
- Warm up the VM, consume results, and repeat samples. Record SDK, platform,
  JIT/AOT/web mode, inputs, latency, throughput, and allocations/memory when
  possible. Compare changes with the same environment and fixtures.
- Do not claim improvements without measurements or sacrifice correctness for
  speed. For changes to critical paths, provide relevant benchmark results and
  the affected conformance tests.

## Development commands

```sh
dart pub get
dart format lib test example benchmark tool
dart analyze
dart test
dart run example/all_drafts.dart
dart run benchmark/validation.dart
dart run benchmark/generated.dart
```

Regenerate `test/generated_validators.dart` with
`dart run tool/generate_validators.dart` and format the result after changing
code generation. Regenerate Unicode facts only when changing the pinned Unicode
profile, using `python tool/generate_unicode.py`.

Use `dart run tool/run_suite.dart <external-suite-directory>` for official
fixtures and `python tool/snapshot_suite.py <external-suite-directory>` to record
hashes and outcomes. Keep third-party resources and their licenses outside this
repository. See `docs/conformance.md` for adapters when a restricted environment
blocks standard analyzer/test subprocesses.
`tool/analyze.dart` checks semantic diagnostics only. Use the official SDK
server adapter, `python tool/analyze_sdk.py --sdk <dart-sdk>`, to include the
configured lint rules when the standard launcher is unavailable.

Run checks appropriate to the change. Documentation-only edits require reviewing
accuracy and links. Report checks that could not run and their actual reasons.

## Working practices

- Keep changes within the requested scope and update examples, documentation,
  the support matrix, and changelog when behavior changes.
- Keep the implementation original and MIT-licensed. Keep external conformance
  fixtures and their required notices outside this repository.
- Always distinguish implemented functionality, measured results, and future
  goals. This file sets project direction; it does not mean the engine or
  compatibility support has already been implemented.
