# Performance measurements

Measured with Dart 3.13.5 on Windows x64. These are local microbenchmarks of the
original implementation, not claims of the fastest validator across all Dart
packages, machines, schemas, or workloads. Timing variability and the unrecorded
hardware configuration limit cross-machine comparisons.

The runtime benchmark uses seven warmed samples and 50,000 validations per
sample, reporting the median. Parsing and compilation are measured separately
with 300 operations per sample. Boolean validation does not build diagnostics.
The generated-code comparison uses seven samples of 200,000 operations and a
pool of 64 varied instances to reduce constant-input effects. Both backends
validate the same inputs before timing; results are consumed by a counter.

## Runtime validation

Representative valid-instance medians from the recorded AOT run:

| Schema | Boolean validation | First error on invalid input |
| --- | ---: | ---: |
| Integer with bounds | 22 ns | 458 ns |
| Object with required fields and extra-key rejection | 363 ns | 759 ns |
| Array of 20 constrained integers | 593 ns | 1,140 ns |
| String/integer alternatives | 387 ns | 719 ns |
| Three nested recursive objects | 1,100 ns | 1,361 ns |
| Combined properties with unevaluated-key rejection | 720 ns | 1,539 ns |
| Exact decimal multiple | 96 ns | 675 ns |

Compilation medians in that run range from roughly 10 to 45 microseconds for
these small schemas. Reusing the compiled object avoids repeating that work.
Larger and more complex schemas need their own measurements.

## Generated Dart checks

The generated backend emits ordinary expressions and loops for supported
schemas. Diagnostic fallback compilation is lazy. Unsupported specialized
keywords and custom options retain the runtime backend's behavior.

| Pooled AOT workload | Runtime | Generated | Relative improvement |
| --- | ---: | ---: | ---: |
| Integer with bounds | 31 ns | 12 ns | 2.65x |
| Object with three properties | 383 ns | 214 ns | 1.79x |
| Array of 20 integers | 558 ns | 170 ns | 3.29x |

The JIT run also improves on these inputs; exact values and the complete runtime
results are in [the machine-readable record](benchmark_results.json). Results
for generated code must not be extrapolated to schemas that use its fallback.
Numeric nodes use a lazily compiled fallback for BigInt and JsonNumber
instances. Documents containing exact numbers use the runtime backend; ordinary
numeric checks still use generated expressions.

## Format assertions

`benchmark/formats.dart` measures ten formats with pools of 64 valid and invalid
strings, seven samples, and 50,000 assertions per sample. It checks fixture
validity before timing. The engine's IPv4 parser scans ASCII digits once,
without splitting strings or creating per-call regular expressions.

| Pooled IPv4 workload | Previous AOT parser | Single-pass AOT parser |
| --- | ---: | ---: |
| Valid address | 1,250 ns | 27 ns |
| Invalid first octet | 445 ns | 16 ns |

The valid-address improvement is 45.6x for this measured input pool. A paired
repeat measured 1,266 ns versus 28 ns (44.8x). The JIT pair measured 1,382 ns
versus 26 ns. See [the complete before/after measurements](format_optimization_results.json).
Other formats are recorded as controls; they do not support a uniform speedup
claim. The latest complete format measurements are in `benchmark_results.json`.

## Reproduce

```sh
dart run tool/generate_validators.dart
dart format test/generated_validators.dart
dart run benchmark/validation.dart 50000
dart run benchmark/generated.dart
dart run benchmark/formats.dart
dart compile aot-snapshot benchmark/validation.dart -o build/validation.aot
dartaotruntime build/validation.aot 50000
dart compile aot-snapshot benchmark/generated.dart -o build/generated.aot
dartaotruntime build/generated.aot
dart compile aot-snapshot benchmark/formats.dart -o build/formats.aot
dartaotruntime build/formats.aot
```

The scripts also write JSON records under `build/`. Compare on the same SDK,
machine, mode, fixture set, and sample configuration. No allocation counts have
been measured yet; avoiding known allocations is an implementation property,
not a measured memory-performance claim.

The current implementation specializes scalar predicates, reuses compiled
property lookups and regular expressions, avoids contexts for acyclic static
references, and uses bounded integer arithmetic for common exact decimal
checks, with `BigInt` fallback. Preserve conformance checks when changing any
of these paths.
