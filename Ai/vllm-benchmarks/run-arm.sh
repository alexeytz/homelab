#!/usr/bin/env bash
# Run ONE arm of the NVLink A/B: launch the server, wait for it, benchmark it.
#
# Usage: ./run-arm.sh <nvl|nop2p> <on|off> <tag>
#
# Design note, learned the hard way (twice):
#   Do NOT wait on the launch ssh. vLLM's multiprocess children keep the ssh
#   channel open even with `ssh -n`, `setsid`, `nohup` and full fd redirection,
#   so that call can hang indefinitely while the server itself starts perfectly.
#   Fire it and forget it; readiness comes from the arm's OWN log on the remote.
#   Reading the tag-specific log also removes the risk of benchmarking the
#   PREVIOUS arm's server, which endpoint-liveness polling cannot distinguish.
set -uo pipefail
ARM="${1:?arm}"; SPEC="${2:?spec}"; TAG="${3:?tag}"
# Host addressing. Defaults are the machine this was measured on; override both
# for any other server. HOST is where the vLLM endpoint answers, SSH_TARGET is the
# ssh login used to launch and to read the arm's log.
HOST="${HOST:-vllm3090}"
SSH_TARGET="${SSH_TARGET:-root@vllm3090}"
SSH="ssh -n -o BatchMode=yes -o ConnectTimeout=10 $SSH_TARGET"
MODEL=cyankiwi/Qwen3.8-27B-AWQ-FP8
BENCH=${BENCH:-$HOME/llm-assay}
# How to invoke the client. A fresh llm-assay clone has no dependencies installed,
# so plain `python3` fails on `import pydantic`; PY="uv run" resolves them, and a
# venv that already carries them works too. Deliberately unquoted below: PY may be
# two words.
PY=${PY:-python3}
# Remote working directory: where the launcher and the per-arm logs live.
# Deliberately left unexpanded -- $HOME must resolve on the SERVER, not here.
REMOTE_DIR=${REMOTE_DIR:-'$HOME'}
RES="$(cd "$(dirname "$0")" && pwd)/results"; mkdir -p "$RES"

echo "################ ARM $TAG (arm=$ARM spec=$SPEC prefix=off) ################"
date -u +%Y-%m-%dT%H:%M:%SZ

# fire and forget: this ssh may never return, and that is fine
( $SSH "cd $REMOTE_DIR && rm -f ab-$TAG.log && setsid nohup ./run-vllm3090-ab.sh $MODEL --arm $ARM --spec $SPEC --prefix off </dev/null >ab-$TAG.log 2>&1 & echo launched" >/dev/null 2>&1 & ) 
echo "launch fired"

UP=0
for i in $(seq 1 120); do
  sleep 5
  n=$($SSH "grep -ac 'Application startup complete' $REMOTE_DIR/ab-$TAG.log 2>/dev/null || echo 0" 2>/dev/null | tr -dc '0-9')
  if [ "${n:-0}" -ge 1 ]; then UP=1; echo "ready after ~$((i*5))s"; break; fi
  d=$($SSH "grep -ac 'Traceback (most recent call last)' $REMOTE_DIR/ab-$TAG.log 2>/dev/null || echo 0" 2>/dev/null | tr -dc '0-9')
  if [ "${d:-0}" -ge 1 ]; then echo "ARM $TAG TRACEBACK"; $SSH "tail -20 $REMOTE_DIR/ab-$TAG.log"; exit 1; fi
done
[ "$UP" -eq 1 ] || { echo "ARM $TAG FAILED TO START"; $SSH "tail -20 $REMOTE_DIR/ab-$TAG.log"; exit 1; }

# provenance: attach the config and the selected all-reduce path to the numbers
$SSH "grep -a RUN-CONFIG $REMOTE_DIR/ab-$TAG.log | tail -1; grep -aoE \"Using \[.*\] all-reduce backends\" $REMOTE_DIR/ab-$TAG.log | head -1; grep -aoE 'GPU KV cache size: [0-9,]+' $REMOTE_DIR/ab-$TAG.log | head -1"

( cd "$BENCH" && $PY llm-assay.py \
    --base-url "http://$HOST:8000/v1" --served-model-name VLLM3090 \
    --endpoint completions --pp 2048 16384 --tg 512 --concurrency 1 \
    --runs 5 --target-ci 0.02 --max-runs 12 --stats ci --skip-coherence \
    --save-result "$RES/$TAG.json" --format json ) 2>&1 | tail -12

pkill -f "[a]b-$TAG.log" 2>/dev/null || true   # reap the stray launch ssh
echo "ARM $TAG DONE -> $RES/$TAG.json"
