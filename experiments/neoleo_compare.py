"""Matched births, fixed inputs and seeds; retain every response and vote trace."""
import argparse
import json
import pathlib
import subprocess

LINES = [
    "I am here with you.",
    "The bell is quiet.",
    "The bell is loud now.",
    "I am listening to the bell.",
    "The room is cold.",
    "The room is warm now.",
    "I am staying with you.",
    "I came back to listen.",
]
SEEDS = [20261114, 203, 42]
ARMS = {"on": [], "off": ["--off"], "without_first": ["--mask", "14"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--binary", type=pathlib.Path, default=pathlib.Path("neoleo"))
    parser.add_argument("--corpus", type=pathlib.Path, default=pathlib.Path("leo.txt"))
    args = parser.parse_args()
    args.output.mkdir(exist_ok=False, parents=True)
    runs = []
    for seed in SEEDS:
        for arm, flags in ARMS.items():
            trace = args.output / f"{seed}-{arm}.jsonl"
            command = [str(args.binary.resolve()), "--corpus", str(args.corpus.resolve()),
                       "--seed", str(seed), "--trace", str(trace.resolve()), *flags]
            result = subprocess.run(command, input="\n".join(LINES) + "\n",
                                    text=True, capture_output=True, check=True)
            answers = result.stdout.splitlines()
            if len(answers) != len(LINES):
                raise RuntimeError(f"{arm}/{seed}: {len(answers)} answers for {len(LINES)} turns")
            elections = [json.loads(line) for line in trace.read_text().splitlines()]
            if not elections:
                raise RuntimeError("No elections observed")
            if arm == "off" and any(e["delta"] != 0 or e["base_top"] != e["voted_top"]
                                    for e in elections):
                raise RuntimeError("Disabled parliament changed a candidate score")
            runs.append(dict(seed=seed, arm=arm, command=command, answers=answers,
                             stderr=result.stderr, choices=len(elections),
                             changed_top=sum(e["base_top"] != e["voted_top"] for e in elections)))
            (args.output / "responses.json").write_text(json.dumps(
                dict(inputs=LINES, runs=runs), ensure_ascii=False, indent=2) + "\n")
    pairs = []
    for seed in SEEDS:
        on = next(r for r in runs if r["seed"] == seed and r["arm"] == "on")
        for arm in ("off", "without_first"):
            other = next(r for r in runs if r["seed"] == seed and r["arm"] == arm)
            pairs.append(dict(seed=seed, comparison=f"on/{arm}",
                              different_answers=sum(a != b for a, b in zip(on["answers"], other["answers"]))))
    summary = dict(seeds=SEEDS, turns=len(LINES), pairs=pairs,
                   elections=[{k: r[k] for k in ("seed", "arm", "choices", "changed_top")} for r in runs])
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
