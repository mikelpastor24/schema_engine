"""Derive compact Unicode facts for the original Dart IDNA implementation.

Run with Python 3 and the regex module. No third-party implementation source is
copied. The generated file records the Unicode database version for reproducible
normalization and character-property checks.
"""

import json
from pathlib import Path
import unicodedata as ud

import regex


def ranges(values):
    result = []
    for point in values:
        if result and point == result[-1] + 1:
            result[-1] = point
        else:
            result.extend([point, point])
    return result


def derive():
    valid = []
    marks = []
    joining = []
    bidi = []
    combining = {}
    mappings = {}
    compositions = {}
    exceptions = {0xDF, 0x3C2, 0x6FD, 0x6FE, 0xF0B, 0x3007}
    prohibited = {0x640, 0x7FA, 0x302E, 0x302F, 0x303B, *range(0x3031, 0x3036)}
    ignored = regex.compile(r"\A(?:\p{Default_Ignorable_Code_Point}|\p{Noncharacter_Code_Point})\Z")
    join_patterns = [(index, regex.compile(rf"\A\p{{Joining_Type={name}}}\Z"))
                     for index, name in enumerate(["Dual_Joining", "Right_Joining", "Left_Joining", "Transparent"], 1)]
    bidi_codes = {name: index for index, name in enumerate(
        ["L", "R", "AL", "AN", "EN", "NSM", "ES", "CS", "ET", "ON", "BN"], 1)}

    def append_property(target, point, value):
        if value == 0:
            return
        if target and target[-1] == value and target[-2] + 1 == point:
            target[-2] = point
        else:
            target.extend([point, point, value])

    for point in range(0x110000):
        char = chr(point)
        category = ud.category(char)
        if category == "Cn":
            continue
        if category.startswith("M"):
            marks.append(point)
        if point in exceptions or (point not in prohibited and
            not (0x1100 <= point <= 0x11FF or 0xA960 <= point <= 0xA97F or 0xD7B0 <= point <= 0xD7FF) and
            category in {"Ll", "Lu", "Lo", "Nd", "Lm", "Mn", "Mc"} and
            ud.normalize("NFKC", char).casefold() == char and not ignored.fullmatch(char)):
            valid.append(point)
        append_property(bidi, point, bidi_codes.get(ud.bidirectional(char), 0))
        for index, expression in join_patterns:
            if expression.fullmatch(char):
                append_property(joining, point, index)
                break
        ccc = ud.combining(char)
        if ccc:
            combining[point] = ccc
        normalized = ud.normalize("NFKD", char).lower()
        if normalized != char and not (0xAC00 <= point <= 0xD7A3):
            mappings[point] = normalized
        decomposition = ud.decomposition(char)
        if decomposition and not decomposition.startswith("<"):
            parts = [int(item, 16) for item in decomposition.split()]
            if len(parts) == 2 and ud.normalize("NFC", "".join(map(chr, parts))) == char:
                compositions[(parts[0] << 21) | parts[1]] = point

    lines = ["// Generated Unicode facts; regenerate with tool/generate_unicode.py.",
             f"// Unicode database: {ud.unidata_version}.", "part of 'idna.dart';", ""]
    for name, values in [("_validRanges", ranges(valid)), ("_markRanges", ranges(marks)),
                         ("_joiningRanges", joining), ("_bidiRanges", bidi)]:
        lines.append(f"const {name} = <int>[")
        for offset in range(0, len(values), 12):
            lines.append("  " + ", ".join(map(str, values[offset:offset + 12])) + ",")
        lines.extend(["];", ""])
    for name, values, kind in [("_combining", combining, "int"),
                               ("_mappings", mappings, "String"),
                               ("_compositions", compositions, "int")]:
        lines.append(f"const {name} = <int, {kind}>{{")
        for key, value in values.items():
            rendered = json.dumps(value, ensure_ascii=True).replace('$', r'\$') if kind == "String" else str(value)
            lines.append(f"  {key}: {rendered},")
        lines.extend(["};", ""])
    target = Path(__file__).resolve().parent.parent / "lib/src/unicode_data.dart"
    target.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {target.name}: {target.stat().st_size} bytes, Unicode {ud.unidata_version}")


if __name__ == "__main__":
    derive()
