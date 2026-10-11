# Development

The repository uses a [Pub workspace](https://dart.dev/tools/pub/workspaces) with
one dependency resolution. Developing the complete workspace requires Flutter
3.47 or later and Dart 3.13 or later. Package versions remain independent.

From the repository root:

```sh
flutter pub get
dart format packages tool
flutter analyze --no-pub
dart run tool/check.dart
```

`tool/check.dart` resolves dependencies, checks formatting, analyzes both
packages, runs engine and widget tests, and runs the engine's all-drafts example.
It also runs the example application's widget tests and exits as soon as a
check fails.

Package-local analysis options mirror the root rules so that published archives
can also be analyzed on their own. Keep these configurations aligned.

To run individual tests:

```sh
cd packages/schema_engine
dart test
dart run example/all_drafts.dart
```

```sh
cd packages/schema_ui
flutter test --no-pub
```

Run engine generators, benchmarks, and conformance adapters from
`packages/schema_engine`. Their relative paths remain package-local. Existing
conformance evidence and measurements are preserved in its
[conformance report](../packages/schema_engine/doc/conformance.md) and
[performance report](../packages/schema_engine/doc/performance.md).

## Engine checks and measurements

```sh
flutter pub get
dart format lib test example benchmark tool
dart analyze
dart test
dart run example/all_drafts.dart
dart run benchmark/validation.dart
```

In this repository, run these commands from `packages/schema_engine`.
Workspace dependency resolution uses Flutter because the sibling `schema_ui`
package depends on it. The engine itself still has no Flutter dependency.

Benchmarks independently measure compilation, valid/invalid boolean checks,
first errors, and all errors after warmup across repeated samples. See
[performance measurements](../packages/schema_engine/doc/performance.md) for
commands and measured scope.

The conformance harness reads the official JSON Schema Test Suite from an
external directory, retaining its license there. Third-party fixtures and
copyright notices are not vendored into this repository.

## UI example and checks

The [example application](../packages/schema_ui/example/README.md) includes Web
and Windows runners, submission, reset, optional properties, a string override,
and a schema builder with synchronized visual and JSON editors. From the
repository root:

```sh
flutter pub get
cd packages/schema_ui/example
flutter run -d chrome
```

Use `flutter run -d windows` for the desktop application when the Windows
development toolchain is installed. The entry point is
[example/lib/main.dart](../packages/schema_ui/example/lib/main.dart).

From the repository root run `flutter pub get`; from `packages/schema_ui` run
`flutter test --no-pub`. Widget tests exercise Form integration, overrides,
exact numbers, references, themes, arrays, presence, and lifecycle behavior.
Schema authoring tests also verify nested generation, constraints, definition
renames, draft selection, preserved keywords, invalid edits, and submission.
Run the example's widget tests separately from `packages/schema_ui/example`
with the same command.

For browser and Windows setup, downloaded package archives, and example-specific
checks, see the [example guide](../packages/schema_ui/doc/example.md).
