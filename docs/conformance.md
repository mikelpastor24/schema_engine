# Conformance and support

The package parses, builds, serializes, compiles, and validates schemas for
Draft 00, 01, 02, 03, 04, 06, 07, 2019-09, and 2020-12. Draft 05 uses the Draft 04
dialect. These are the published versions listed by the
[official specification index](https://json-schema.org/specification-links).
Unknown annotations and extension keywords survive serialization.

## Official validation suite

The complete supplied JSON Schema Test Suite archive passes **9,361 cases** in
each of the boolean, first-error, and all-error modes: **28,083 validity checks**,
with zero failures and zero missing-resource groups across 356 fixture files.
This run includes every mandatory and optional fixture for published drafts.
The same complete run also passes after compiling the portable engine to
JavaScript with Dart 3.13.5 and executing it on Node.js 22.18.0. Together, the
VM and JavaScript runs perform 56,166 validity checks.

| Dialect | Executed cases | Result |
| --- | ---: | --- |
| Draft 03 | 569 | Passed |
| Draft 04 | 1,009 | Passed |
| Draft 06 | 1,352 | Passed |
| Draft 07 | 1,827 | Passed |
| 2019-09 | 2,280 | Passed |
| 2020-12 | 2,324 | Passed |
| Draft 00, 01, 02 | No upstream fixtures | Original specification-derived tests |

The archive directory identifies commit
`f6fd52a0a95472e079cbfc6ef7f089702b80e045`. It was supplied as an extracted
archive, rather than independently retrieved through Git. The
[snapshot manifest](conformance_snapshot.json) records that provenance,
SHA-256 hashes of every fixture/resource, executed counts, and harness policies.
The archive's Git commit provenance has not been independently verified.
Third-party fixtures and their intact license stay outside this repository.

The harness uses lossless `decodeJson`, resolves remote fixtures locally and
on demand, and applies these explicit optional-test policies:

- `assertFormats: true` for `optional/format/` fixtures; ordinary formats remain
  annotations under the standard dialect defaults.
- `legacyDependencies: true` only for modern `dependencies-compatibility`
  fixtures. The retired keyword is ignored in modern dialects by default.
- `assertContent: true` only for Draft 07 optional content fixtures. Modern
  content keywords remain annotations as required by their vocabulary.

The suite's `v1` directory concerns an unpublished dialect and is explicitly
excluded. Separate upstream annotation/output fixture directories do not test
this package's public error representation and are outside this validity run.
Passing a finite suite is evidence of the recorded cases, not proof that every
possible schema and instance is correct.

## Original tests and historical coverage

Original tests exercise every published dialect, including Draft 00 through 02
using the historical documents linked from the official specification index.
Their fixtures cover `optional`, `requires`, `extends`, `disallow`, tuple
handling, equality flags, `maxDecimal`, and the Draft 02 additions `divisibleBy`
and `uniqueItems`. They are not mislabeled as upstream official fixtures.

Additional tests cover reusable immutable validators, escaped diagnostic paths,
resource boundaries, custom vocabulary policies, offline vocabulary
meta-schemas, recursive/dynamic references, and asynchronous custom meta-schema
loading. A decimal grid checks more than 8,000 multiples against an independent
integer-arithmetic oracle. Numeric regressions cover exact large values,
adjacent decimal bounds, uniqueness, serialization, and generated validators.
JavaScript smoke checks exercise the portable core and lossless numeric model.
There are 301 original tests, 65 core JavaScript smoke checks, and 102
declarative JavaScript checks. Declarative tests generate and validate each
published draft, including property presence, nullable values, tuples, and
legacy union spelling. Both construction APIs use the same compiled engine.

## Numeric and platform scope

Ordinary Dart JSON values remain supported. `JsonSchema.parse` and `decodeJson`
retain large integers as `BigInt` and precise decimals as `JsonNumber`. Exact
representations work for numeric types, bounds, multiples, equality, and
uniqueness; `encodeJson` and schema serialization write them as JSON numbers.

Precision already lost through another decoder cannot be reconstructed.
JavaScript also merges native integer and double representations. Use
`decodeJson` to preserve decimal-literal syntax when validating Draft 04 and
earlier there. Decimal exponents must fit the supported integer representation;
available memory and input size bound exact arithmetic.

## Reproduce

```sh
python tool/fetch_suite.py --directory /path/outside/repository/suite
dart run tool/run_suite.dart /path/outside/repository/suite
python tool/snapshot_suite.py /path/outside/repository/suite
```

Run the same external fixtures in JavaScript before recording the snapshot:

```sh
dart compile js -O2 tool/run_web_suite.dart -o build/run_web_suite.js
node tool/run_web_suite.cjs /path/outside/repository/suite
```

The downloader defaults to the recorded immutable commit hash. A complete
external extracted archive can also be passed directly. Missing resources are
reported explicitly. The harness exits with 0 for success, 1 for assertion or
schema failures, and 2 for missing resources.

Normal development uses `dart analyze` and `dart test`. If the Dart launcher
cannot spawn child tools, the SDK server adapter runs the official analyzer
including the configured lint rules:

```sh
python tool/analyze_sdk.py --sdk /path/to/dart-sdk
dart run tool/run_tests.dart
```

If the launcher cannot start subprocesses or signal subscriptions are denied,
invoke the SDK's `dartvm` executable with
`--packages=.dart_tool/package_config.json` and the adapter path. The test
adapter runs the same test declarations through development-only `test_api`
internals. `tool/analyze.dart` checks semantic diagnostics only and does not
replace the full SDK lint check. These adapters are development tools outside
the package's public API.
