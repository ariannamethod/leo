# Persistent dialogue lives

Each directory is one Leo life. Its numbered `.txt` files are separate process
sessions, read in lexical order. The runner saves Leo after each file, exits,
and requires the next process to load that exact state before dialogue resumes.

Run the default lives:

```sh
make life-probe
```

Use multiple deterministic paths:

```sh
LEO_DIALOGUE_SEEDS="83 137 211" scripts/shadow_life_probe.sh
```

Each later session uses `base seed + session index - 1`; `sessions.tsv` records
both values explicitly. The report retains ordinary causal receipts and adds
`sleep_edges.tsv`, which contains only proposals made in one process and judged
in a later process.
