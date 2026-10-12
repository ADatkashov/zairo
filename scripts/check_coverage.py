#!/usr/bin/env python3
"""Line-coverage gate for one Flutter package.

Usage: check_coverage.py <package-dir> [--update]

Reads <package-dir>/coverage/lcov.info (written by `flutter test --coverage`),
leaves out generated code (see EXCLUDED), prints the hand-written line coverage
and the least-covered files, and fails if it is below the package's entry in
config/coverage-thresholds.json.

The thresholds are a ratchet: they only ever go up. Raise one (with --update)
whenever tests have lifted the coverage, never lower it to get a build green.
"""
import fnmatch
import json
import os
import sys

# Generated or purely declarative files that carry no hand-written logic.
EXCLUDED = (
    "*.g.dart",
    "*.freezed.dart",
    "*/l10n/*",  # generated localizations
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THRESHOLDS = os.path.join(ROOT, "config", "coverage-thresholds.json")


def read_lcov(path):
    files, current = {}, None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("SF:"):
                current = line[3:]
                files[current] = [0, 0]  # lines found, lines hit
            elif line.startswith("LF:") and current:
                files[current][0] = int(line[3:])
            elif line.startswith("LH:") and current:
                files[current][1] = int(line[3:])
    return files


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    update = "--update" in sys.argv
    if len(args) != 1:
        sys.exit(__doc__)
    package = args[0].rstrip("/")
    lcov = os.path.join(package, "coverage", "lcov.info")
    if not os.path.exists(lcov):
        sys.exit(f"{lcov} not found: run `flutter test --coverage` in {package} first")

    files = {f: v for f, v in read_lcov(lcov).items()
             if not any(fnmatch.fnmatch(f, pattern) for pattern in EXCLUDED)}
    found = sum(v[0] for v in files.values())
    hit = sum(v[1] for v in files.values())
    percent = 100.0 * hit / found if found else 100.0

    print(f"{package}: {hit}/{found} hand-written lines covered = {percent:.2f}%")
    worst = sorted(((v[0] - v[1], f, v) for f, v in files.items() if v[0] > v[1]), reverse=True)[:8]
    for missed, f, v in worst:
        print(f"  {missed:4d} uncovered  {v[1]}/{v[0]}  {f}")

    with open(THRESHOLDS, encoding="utf-8") as fh:
        thresholds = json.load(fh)
    floor = thresholds.get(package, 0.0)
    if update:
        new = round(percent - 0.01, 2)  # tiny margin for rounding
        if new > floor:
            thresholds[package] = new
            with open(THRESHOLDS, "w", encoding="utf-8") as fh:
                json.dump(dict(sorted(thresholds.items())), fh, indent=2)
                fh.write("\n")
            print(f"threshold for {package} raised {floor} -> {new}")
        return
    if percent + 1e-9 < floor:
        sys.exit(f"FAIL: coverage {percent:.2f}% is below the {floor}% threshold for {package}")
    print(f"OK: at or above the {floor}% threshold")


if __name__ == "__main__":
    main()
