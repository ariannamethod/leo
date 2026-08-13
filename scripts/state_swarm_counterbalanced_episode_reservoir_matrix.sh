#!/usr/bin/env bash
# A.106 source: new lives with Williams-balanced writer-session carryover.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-${TMPDIR:-/tmp}/leo-state-swarm-counterbalanced-episode-reservoir-$STAMP}"

export LEO_STATE_PROSPECTIVE_CANDIDATES="$ROOT/scripts/state_swarm_counterbalanced_episode_reservoir_candidates.tsv"
export LEO_STATE_PROSPECTIVE_EXPECTED_CANDIDATES=80
export LEO_STATE_PROSPECTIVE_PRIMARY_CANDIDATES=40
export LEO_STATE_PROSPECTIVE_HOLDOUT_CANDIDATES=40
export LEO_STATE_PROSPECTIVE_PRIMARY_TARGET=32
export LEO_STATE_PROSPECTIVE_HOLDOUT_TARGET=32
export LEO_STATE_PROSPECTIVE_SEED_START=275283
export LEO_STATE_PROSPECTIVE_SEED_STEP=1033
export LEO_STATE_PROSPECTIVE_CAPTURE_EVENTS=1
export LEO_STATE_PROSPECTIVE_REPORTER="$ROOT/scripts/state_swarm_balanced_event_reservoir_report.awk"
export LEO_STATE_PROSPECTIVE_PROFILE_NAME=A.106-counterbalanced
export LEO_STATE_PROSPECTIVE_WRITER_ORDER_MODE=williams8

exec "$ROOT/scripts/state_swarm_prospective_incidence_matrix.sh" "$OUT"
