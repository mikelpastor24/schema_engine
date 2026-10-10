"""Download a pinned official conformance suite outside this repository."""

import argparse
import io
import json
from pathlib import Path
import re
import tarfile
import tempfile
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", default="f6fd52a0a95472e079cbfc6ef7f089702b80e045")
    parser.add_argument("--directory", type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.revision):
        parser.error("revision must be a complete immutable Git commit hash")
    target = (args.directory or Path(tempfile.gettempdir()) /
              f"schema_engine_conformance_{args.revision}").resolve()
    repository = Path(__file__).resolve().parents[3]
    if target == repository or repository in target.parents:
        parser.error("third-party fixtures must remain outside this repository")
    if target.exists() and any(target.iterdir()):
        parser.error("choose an empty external directory for a reproducible pinned checkout")
    url = f"https://codeload.github.com/json-schema-org/JSON-Schema-Test-Suite/tar.gz/{args.revision}"
    request = urllib.request.Request(url, headers={"User-Agent": "schema_engine-conformance"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    target.mkdir(parents=True, exist_ok=True)
    count = 0
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for member in archive:
            if not member.isfile():
                continue
            parts = Path(member.name).parts[1:]
            if not parts or parts[0] not in {"tests", "remotes", "LICENSE", "README.md"}:
                continue
            if parts[0] in {"tests", "remotes"} and not member.name.endswith(".json"):
                continue
            path = (target / Path(*parts)).resolve()
            if target not in path.parents:
                raise ValueError("Unsafe archive path")
            source = archive.extractfile(member)
            if source is None:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(source.read())
            count += 1
    (target / "REVISION.json").write_text(json.dumps({"commit": args.revision,
        "source": url}, indent=2), encoding="utf-8")
    print(f"Saved {count} files to {target}; commit {args.revision}")


if __name__ == "__main__":
    main()
