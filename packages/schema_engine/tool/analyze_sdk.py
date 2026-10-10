"""Run the SDK analysis server directly, including its configured lint rules."""

import argparse
import json
import os
from pathlib import Path
from queue import Empty, Queue
import subprocess
import sys
from threading import Thread
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    root = Path(__file__).resolve().parent.parent
    runtime = sdk / "bin" / ("dartaotruntime.exe" if os.name == "nt" else "dartaotruntime")
    snapshot = sdk / "bin" / "snapshots" / "analysis_server_aot.dart.snapshot"
    if not runtime.is_file() or not snapshot.is_file():
        parser.error("SDK must contain the analysis server AOT snapshot and runtime")
    process = subprocess.Popen(
        [str(runtime), str(snapshot), "--protocol=analyzer", f"--dart-sdk={sdk}",
         f"--cache={root / '.dart_tool' / 'analysis_cache'}"],
        cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, encoding="utf-8",
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )
    events = Queue()
    stderr = []

    def read_events():
        for line in process.stdout:
            try:
                events.put(json.loads(line))
            except json.JSONDecodeError:
                events.put({"invalidOutput": line.rstrip()})
        events.put({"closed": True})

    def read_stderr():
        for line in process.stderr:
            stderr.append(line.rstrip())

    Thread(target=read_events, daemon=True).start()
    Thread(target=read_stderr, daemon=True).start()

    def request(identifier, method, params=None):
        message = {"id": identifier, "method": method}
        if params is not None:
            message["params"] = params
        process.stdin.write(json.dumps(message) + "\n")
        process.stdin.flush()

    diagnostics = {}
    started = False
    completed = False
    root_registered = False
    deadline = time.monotonic() + args.timeout
    try:
        request("subscriptions", "server.setSubscriptions", {"subscriptions": ["STATUS"]})
        request("roots", "analysis.setAnalysisRoots", {
            "included": [str(root)],
            "excluded": [str(root / "build"), str(root / ".dart_tool")],
        })
        while time.monotonic() < deadline:
            try:
                event = events.get(timeout=min(1, max(0.01, deadline - time.monotonic())))
            except Empty:
                continue
            if "error" in event or "invalidOutput" in event:
                raise RuntimeError(f"Analysis server error: {event}")
            if event.get("closed"):
                raise RuntimeError("Analysis server exited before completing analysis")
            if event.get("id") == "roots":
                root_registered = True
            if event.get("event") == "analysis.errors":
                params = event["params"]
                diagnostics[params["file"]] = params["errors"]
            if event.get("event") == "server.status":
                analysis = event["params"].get("analysis")
                if analysis is not None:
                    if analysis["isAnalyzing"]:
                        started = True
                    elif not analysis["isAnalyzing"] and root_registered and started:
                        completed = True
                        break
        if not completed:
            raise RuntimeError("Analysis server timed out")
        count = 0
        for path, errors in sorted(diagnostics.items()):
            for error in errors:
                location = error["location"]
                print(f"{path}:{location['startLine']}:{location['startColumn']}: "
                      f"{error.get('code', error['type'])}: {error['message']}")
                count += 1
        print(f"{count} SDK diagnostics, including configured lint rules.")
        return 1 if count else 0
    finally:
        if process.poll() is None:
            try:
                request("shutdown", "server.shutdown")
                process.wait(timeout=10)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                process.terminate()
                process.wait(timeout=10)
        if process.returncode:
            for line in stderr[-20:]:
                print(line, file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
