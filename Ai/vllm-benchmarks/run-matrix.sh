#!/usr/bin/env bash
# Full NVLink A/B matrix. Four arms; prefix caching OFF throughout so one server
# per arm yields both a prefill and a decode number. Client params are IDENTICAL
# across arms - that is the whole point.
set -uo pipefail
# See run-arm.sh: HOST is the endpoint, SSH_TARGET the ssh login. Override both
# for any server other than the one this was measured on.
HOST="${HOST:-vllm3090}"
SSH_TARGET="${SSH_TARGET:-root@vllm3090}"
SSH="ssh -n -o BatchMode=yes $SSH_TARGET"
MODEL=cyankiwi/Qwen3.8-27B-AWQ-FP8
BENCH=${BENCH:-$HOME/llm-assay}
PY=${PY:-python3}
# Remote working directory: where the launcher and the per-arm logs live.
# Deliberately left unexpanded -- $HOME must resolve on the SERVER, not here.
REMOTE_DIR=${REMOTE_DIR:-'$HOME'}   # see run-arm.sh: "uv run" for a fresh clone. Unquoted on purpose.
RES="$(dirname "$0")/results"
mkdir -p "$RES"

CLIENT_ARGS=( --base-url "http://$HOST:8000/v1" --served-model-name VLLM3090
  --endpoint completions --pp 2048 16384 --tg 512 --concurrency 1
  --runs 5 --target-ci 0.02 --max-runs 12 --stats ci --skip-coherence )

run_arm () {
  local arm="$1" spec="$2" tag="$3"
  echo; echo "################ ARM $tag  (arm=$arm spec=$spec prefix=off) ################"
  date -u +%Y-%m-%dT%H:%M:%SZ

  # setsid + stdin from /dev/null on BOTH ends. Without it the backgrounded server
  # holds the ssh channel open and this call never returns -- cost 13 min to learn.
  $SSH "cd $REMOTE_DIR && rm -f ab-$tag.log && setsid nohup ./run-vllm3090-ab.sh $MODEL --arm $arm --spec $spec --prefix off </dev/null >ab-$tag.log 2>&1 & echo launched" </dev/null || return 1

  # wait for the endpoint, not for a log string
  local up=0
  for i in $(seq 1 120); do
    if curl -sf -m 3 "http://$HOST:8000/v1/models" >/dev/null 2>&1; then up=1; echo "  endpoint up after ~$((i*5))s"; break; fi
    sleep 5
  done
  if [ "$up" -ne 1 ]; then echo "  ARM $tag FAILED TO START"; $SSH "tail -15 $REMOTE_DIR/ab-$tag.log"; return 1; fi

  $SSH "grep -aoE 'RUN-CONFIG.*|GPU KV cache size: [0-9,]+|Using \[.*\] all-reduce backends' $REMOTE_DIR/ab-$tag.log | head -4"

  ( cd "$BENCH" && $PY llm-assay.py "${CLIENT_ARGS[@]}" \
      --save-result "$RES/$tag.json" --format json ) 2>&1 | tail -14
  echo "  saved: $RES/$tag.json"
}

# Arms to run may be named as arguments, e.g.  ./run-matrix.sh decode-nop2p spec-nvl
WANT="${*:-decode-nvl decode-nop2p spec-nvl spec-nop2p}"
case " $WANT " in *" decode-nvl "*)   run_arm nvl   off "decode-nvl"   ;; esac
case " $WANT " in *" decode-nop2p "*) run_arm nop2p off "decode-nop2p" ;; esac
case " $WANT " in *" spec-nvl "*)     run_arm nvl   on  "spec-nvl"     ;; esac
case " $WANT " in *" spec-nop2p "*)   run_arm nop2p on  "spec-nop2p"   ;; esac

echo; echo "################ MATRIX COMPLETE ################"
date -u +%Y-%m-%dT%H:%M:%SZ
ls -la "$RES"
