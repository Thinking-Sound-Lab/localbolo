#!/usr/bin/env python3
"""Compare JSON reports from the opt-in macOS PerformanceBenchmarks suite.

Pass one or more reports per build; repeated runs of a build are pooled.
"""

import argparse
import csv
import hashlib
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


def load(paths):
    reports = [json.loads(path.read_text()) for path in paths]
    grouped = defaultdict(list)
    for report in reports:
        for item in report["records"]:
            grouped[item["name"]].append(item)
    return reports, grouped


def percentile(values, fraction):
    """Nearest-rank percentile."""
    return sorted(values)[max(0, math.ceil(len(values) * fraction) - 1)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, nargs="+", required=True)
    parser.add_argument("--after", type=Path, nargs="+", required=True)
    parser.add_argument("--csv", type=Path, help="Export individual samples, including output hashes.")
    args = parser.parse_args()
    before_reports, before = load(args.before)
    after_reports, after = load(args.after)

    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        fields = ["run", "name", "iteration", "seconds", "audioSeconds", "accepted", "footprintBytes",
                  "activeBytes", "cacheBytes", "peakBytes", "thermalState", "outputSHA256"]
        with args.csv.open("w", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            for report in before_reports + after_reports:
                for item in report["records"]:
                    row = {key: value for key, value in item.items() if key in fields}
                    row["run"] = report["label"]
                    if "output" in item:
                        row["outputSHA256"] = hashlib.sha256(item["output"].encode()).hexdigest()
                    writer.writerow(row)

    print("| Measurement | n | Before p50 / p95 | After p50 / p95 | Median change |")
    print("| --- | ---: | ---: | ---: | ---: |")
    for name in sorted(set(before) | set(after), key=lambda n: list(before).index(n) if n in before else 1e9):
        if name.startswith("load.") or name not in before or name not in after:
            continue
        old = [item["seconds"] * 1000 for item in before[name]]
        new = [item["seconds"] * 1000 for item in after[name]]
        old_median, new_median = statistics.median(old), statistics.median(new)
        change = (new_median / old_median - 1) * 100 if old_median else 0
        print(f"| {name} | {len(old)}/{len(new)} | {old_median:.1f} / {percentile(old, .95):.1f} ms | "
              f"{new_median:.1f} / {percentile(new, .95):.1f} ms | {change:+.1f}% |")
    only_after = [name for name in after if name not in before]
    if only_after:
        print(f"\nOnly in the new build: {', '.join(only_after)}")

    print("\nModel loads are excluded: first-use Core ML compilation and OS caches are not controlled.")
    for label, reports in (("before", before_reports), ("after", after_reports)):
        records = [item for report in reports for item in report["records"]]
        footprints = [item["footprintBytes"] for item in records if item.get("footprintBytes") is not None]
        print(f"{label} ({', '.join(r['label'] for r in reports)}): maximum sampled physical footprint "
              f"{max(footprints, default=0) / 1e6:.1f} MB; MLX peak "
              f"{max((item['peakBytes'] for item in records), default=0) / 1e6:.1f} MB; "
              f"thermal states {sorted(set(item['thermalState'] for item in records))}")

    print()
    for name in before:
        if name not in after or not any("output" in item for item in before[name]):
            continue
        outputs_before = {item["output"] for item in before[name] if "output" in item}
        outputs_after = {item["output"] for item in after[name] if "output" in item}
        accepted_before = [item["accepted"] for item in before[name] if "accepted" in item]
        accepted_after = [item["accepted"] for item in after[name] if "accepted" in item]
        acceptance = (f"; accepted {sum(accepted_before)}/{len(accepted_before)} -> "
                      f"{sum(accepted_after)}/{len(accepted_after)}" if accepted_before else "")
        print(f"{name}: identical outputs={outputs_before == outputs_after}{acceptance}")
        if outputs_before != outputs_after:
            print(f"  before: {sorted(outputs_before)}\n  after:  {sorted(outputs_after)}")


if __name__ == "__main__":
    main()
