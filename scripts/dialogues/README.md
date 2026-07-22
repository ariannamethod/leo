# Shadow dialogue scenarios

Each `.txt` file is one fresh Leo conversation. Blank lines and lines beginning
with `#` are ignored. Every other line is sent as one human turn; `/quit` is
appended by the runner.

Run the default matrix:

```sh
make dialogue-probe
```

Run more than one deterministic sampling path:

```sh
LEO_DIALOGUE_SEEDS="83 137 211" scripts/shadow_dialogue_probe.sh
```

The runner writes raw transcripts, a causal `receipts.tsv`, and `summary.txt`
under a fresh temporary directory. The TSV associates a proposal at turn `t`
with the actual human prompt, Leo reply, and calibration verdict at `t+1`.
The last proposal in each conversation remains visibly pending rather than
being scored against an invented future.
