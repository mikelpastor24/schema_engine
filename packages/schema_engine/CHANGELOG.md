## 1.0.0

* Use a single ValidationError.message getter with safe formatter fallbacks.

* Centralize built-in message identifiers in ValidationErrorCodes with string
  constants, a keyword registry, and shared diagnostic/catalog references.

* Add specific lazy validation explanations with stable codes and immutable
  constraint parameters for all implemented assertion families.
* Add an open ValidationMessages catalog API, English defaults, template-based
  overrides, and compilation/per-call/presentation formatters in portable Dart.
* Preserve exact numeric limits, Unicode lengths, property context, and
  short-circuit count semantics; expose formatters on generated validators.

* Move into `packages/schema_engine` in the shared Dart/Flutter workspace;
  preserve the public API and dependency-free portable runtime.

* Add an immutable declarative API with concise scalar/object/array constructors,
  optional and nullable properties, shape operations, tuples, and composition.
* Generate declarative schemas for every published draft and compile through
  the existing validation engine, with no instance-time declaration traversal.

* Replace the Flutter template with a portable, dependency-free Dart core.
* Add immutable parsing, serialization, and dialect-aware schema construction.
* Add published-draft dispatch, including historical Draft 00 through Draft 03.
* Compile reusable validators with specialized boolean checks and diagnostics.
* Add URI resources, JSON Pointer, anchors, recursive and dynamic references.
* Track evaluated properties and items for unevaluated applicators.
* Add exact decimal multiples, deep equality, and hashed uniqueness checks.
* Preserve large JSON integers and precise decimals with lossless decoding,
  exact numeric assertions, and serialization on the VM and JavaScript.
* Add formats, original IDNA/Punycode checks, and custom vocabularies/keywords.
* Check registered custom meta-schemas during compilation, including recursive
  restrictions, and resolve built-in vocabulary meta-schemas offline.
* Apply draft-specific Format vocabulary defaults and reject unknown formats
  when using the 2020-12 Format-Assertion vocabulary.
* Check core URI syntax, modern resource boundaries and identifier fragments,
  and the keyword syntax of custom meta-schemas.
* Add a direct SDK analysis server adapter with full lint coverage and generate
  idiomatic Dart checks, including direct empty-string and collection checks.
* Add original tests, all-drafts examples, external conformance tooling, and
  reproducible JIT/AOT benchmarks.
* License the original implementation under MIT.
* Pass all 9,361 official published-draft cases in all three validation modes,
  including optional formats, legacy dependencies, and Draft 07 content checks.
* Select legacy hostname/time formats by draft, support CSS colors and IPvFuture
  URI literals, and resolve legacy reference aliases without sibling identifiers.
* Optimize IPv4 assertions with one allocation-free ASCII pass and add a pooled
  format benchmark.
