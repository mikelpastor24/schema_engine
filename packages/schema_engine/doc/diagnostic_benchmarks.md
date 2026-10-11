# Structured diagnostic benchmark

These measurements compare the previous generic diagnostic representation with
the structured diagnostic implementation. Both runs use the same fixtures and
command from `packages/schema_engine`:

```sh
dart run benchmark/validation.dart 20000
```

Environment: Dart 3.13.5 stable, Windows x64, JIT, seven samples per measurement,
20,000 validation iterations per sample, and 20,000 warm-up rounds. Results are
median nanoseconds per operation. The benchmark also consumes results and
measures parsing and compilation separately. Fixtures are defined in
[benchmark/validation.dart](../benchmark/validation.dart).

| Fixture | Valid boolean, before → after | Invalid boolean, before → after | First error, before → after | All errors, before → after |
| --- | ---: | ---: | ---: | ---: |
| Integer | 39.80 → 32.55 | 40.95 → 38.95 | 1,083.80 → 1,165.80 | 544.35 → 731.90 |
| Object | 284.80 → 308.90 | 89.25 → 89.80 | 581.75 → 939.25 | 1,537.55 → 2,323.25 |
| Array | 434.95 → 429.30 | 104.60 → 100.90 | 856.75 → 1,163.50 | 869.00 → 1,200.10 |
| Branches | 392.70 → 471.05 | 59.30 → 58.45 | 505.80 → 855.55 | 576.15 → 929.45 |
| Recursive | 1,052.90 → 935.20 | 414.30 → 393.05 | 948.35 → 1,272.60 | 1,104.85 → 1,435.60 |
| Unevaluated | 708.05 → 642.35 | 613.55 → 508.65 | 1,117.55 → 1,510.25 | 1,259.65 → 1,675.10 |
| Decimal | 103.80 → 106.70 | 113.05 → 111.50 | 431.25 → 747.75 | 554.65 → 908.15 |

The richer first/all-error paths cost more in these runs because they construct
immutable constraint parameters and actual failure details. Message formatting
is lazy and is **excluded** from both diagnostic timing columns; these numbers
must not be presented as localized text-rendering timings. Boolean validation
does not create those maps or invoke formatters, as independently checked by
tests. Its observed timings vary by fixture; this is not a speed-improvement or
no-regression claim. In particular, the branch fixture's valid boolean timing
was higher after the change.

This is one paired local comparison, with an additional development run used
to observe variability. It does not establish statistical significance,
allocation counts, memory retention, AOT behavior, or JavaScript performance.
No arbitrary validity tolerances or assertion changes were introduced to meet
these measurements. The official local suite passes all 9,361 cases in boolean,
first-error, and all-error modes after the changes.
