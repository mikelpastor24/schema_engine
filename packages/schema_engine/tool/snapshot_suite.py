"""Record hashes and coverage of an external suite without copying its fixtures."""

import argparse
import hashlib
import json
from pathlib import Path
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path,
                        default=Path(tempfile.gettempdir()) / "schema_engine_conformance")
    args = parser.parse_args()
    root = args.directory.resolve()
    records = []
    for category in ["tests", "remotes"]:
        for path in sorted((root / category).rglob("*.json")):
            content = path.read_bytes()
            record = {"path": path.relative_to(root).as_posix(),
                      "sha256": hashlib.sha256(content).hexdigest()}
            if category == "tests":
                groups = json.loads(content)
                record["groups"] = len(groups)
                record["cases"] = sum(len(group["tests"]) for group in groups)
                record["executed"] = path.relative_to(root).parts[1] in {
                    "draft3", "draft4", "draft6", "draft7", "draft2019-09", "draft2020-12"
                }
            records.append(record)
    results_path = Path(__file__).resolve().parent.parent / "build/conformance_results.json"
    results = json.loads(results_path.read_text()) if results_path.exists() else {}
    web_path = results_path.with_name("web_conformance_results.json")
    web_results = json.loads(web_path.read_text()) if web_path.exists() else None
    revision_path = root / "REVISION.json"
    revision = json.loads(revision_path.read_text()) if revision_path.exists() else None
    manifest = {"source": "https://github.com/json-schema-org/JSON-Schema-Test-Suite",
        "revision": revision, "snapshotKind": (
            "content-hashed-user-archive" if revision and
            revision.get("acquisition") == "user-provided-extracted-archive"
            else "pinned-commit" if revision else "content-hashed-files"),
        "files": records, "executedCases": results.get("counts", {}),
        "failures": results.get("failures", []), "blockedGroups": results.get("blocked", []),
        "executedFiles": results.get("files"),
        "excludedDirectories": results.get("excludedDirectories", []),
        "javascriptResults": web_results,
        "policies": {key: results.get(key) for key in
                     ["formatAssertions", "legacyDependencies", "contentAssertions"]}}
    target = Path(__file__).resolve().parent.parent / "doc/conformance_snapshot.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Recorded {len(records)} external files in {target.name}")


if __name__ == "__main__":
    main()
