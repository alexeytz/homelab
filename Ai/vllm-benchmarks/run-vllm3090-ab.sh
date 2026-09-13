#!/usr/bin/env bash
# VLLM3090 A/B launcher — Qwen3.8-27B, TP=2 on RTX 3090 (GPUs 2,3).
# Derived from run-vllm3090.sh (settled config 2026-08-19); every serving flag is
# identical across arms so the only difference is the interconnect path.
#
# Usage:  ./run-vllm3090-ab.sh <model> --arm nvl|nop2p [--spec on|off] [--prefix on|off]
#
#   --arm nvl     NCCL_P2P_LEVEL=NVL              (baseline: NVLink in use)
#   --arm nop2p   NCCL_P2P_DISABLE=1              (+ --disable-custom-all-reduce)
#                 NCCL_P2P_LEVEL is deliberately NOT set here: one knob per arm.
#   --arm nvl-nocustom
#                 NCCL_P2P_LEVEL=NVL + --disable-custom-all-reduce. Transport stays
#                 on NVLink; only vLLM's custom all-reduce kernel is removed. This
#                 exists because `nop2p` changes TWO things at once (transport AND
#                 kernel), so nvl vs nvl-nocustom isolates the kernel and
#                 nvl-nocustom vs nop2p isolates the transport.
#
#   --spec off    drops --speculative-config. MTP verification adds inter-GPU
#                 traffic, so it is exactly what an interconnect A/B is sensitive
#                 to. Measure decode BOTH ways or the result is unattributable.
#   --prefix off  drops --enable-prefix-caching. Mandatory for any PREFILL
#                 comparison: with it on, a warm cache is worth ~32.9x here
#                 (TTFT 282s -> 8.7s at 260k) and swamps the effect being measured.
#
# Every run prints its own configuration line. Keep it with the numbers.
set -euo pipefail

# Paths on the serving host, relative to the invoking user's home. The original
# original run was as root in an LXC container; that was inheritance, not a
# requirement. Nothing here needs root.
VENV="${VENV:-$HOME/vllm}"
CHAT_TEMPLATE="${CHAT_TEMPLATE:-$HOME/qwen3.6-enhanced.jinja}"

MODEL="${1:?usage: $0 <model> --arm nvl|nop2p [--spec on|off] [--prefix on|off]}"; shift
ARM=""; SPEC="on"; PREFIX="on"
while [ $# -gt 0 ]; do
  case "$1" in
    --arm)    ARM="${2:?}";    shift 2 ;;
    --spec)   SPEC="${2:?}";   shift 2 ;;
    --prefix) PREFIX="${2:?}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
case "$ARM" in nvl|nop2p|nvl-nocustom) ;; *) echo "--arm must be nvl, nop2p or nvl-nocustom" >&2; exit 2 ;; esac

# --- reap any previous run (workers retitle themselves, so match both patterns) ---
# Matters doubly here: a stray worker from the previous arm holds VRAM and would
# poison the next arm's profiling.
pkill -f "[v]llm serve" 2>/dev/null || true
pkill -f "[V]LLM::"    2>/dev/null || true
for i in $(seq 1 60); do pgrep -f "[v]llm serve|[V]LLM::" >/dev/null || break; sleep 1; done
pkill -9 -f "[v]llm serve" 2>/dev/null || true
pkill -9 -f "[V]LLM::"    2>/dev/null || true
for i in $(seq 1 60); do
  used=$(nvidia-smi --query-gpu=index,memory.used --format=csv,noheader,nounits \
         | awk -F, '$1==2||$1==3 {s+=$2} END{print s+0}')
  [ "${used:-9999}" -lt 500 ] && break
  sleep 2
done

export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=2,3
export OMP_NUM_THREADS=8

EXTRA=()
if [ "$ARM" = "nvl" ]; then
  export NCCL_P2P_LEVEL=NVL
  unset NCCL_P2P_DISABLE || true
elif [ "$ARM" = "nvl-nocustom" ]; then
  export NCCL_P2P_LEVEL=NVL
  unset NCCL_P2P_DISABLE || true
  EXTRA+=( --disable-custom-all-reduce )
else
  export NCCL_P2P_DISABLE=1
  unset NCCL_P2P_LEVEL || true
  # vLLM's custom all-reduce talks P2P directly and ignores NCCL_P2P_DISABLE.
  # Without this, NVLink can still carry small all-reduces in the "off" arm.
  EXTRA+=( --disable-custom-all-reduce )
fi

[ "$SPEC" = "on" ] && EXTRA+=( --speculative-config '{"method":"mtp","num_speculative_tokens":3,"draft_sample_method":"probabilistic"}' )
[ "$PREFIX" = "on" ] && EXTRA+=( --enable-prefix-caching )

echo "RUN-CONFIG arm=$ARM spec=$SPEC prefix=$PREFIX model=$MODEL" \
     "NCCL_P2P_LEVEL=${NCCL_P2P_LEVEL:-unset} NCCL_P2P_DISABLE=${NCCL_P2P_DISABLE:-unset}" \
     "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

source "$VENV/bin/activate"

exec vllm serve "$MODEL" \
  --chat-template "$CHAT_TEMPLATE" \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --reasoning-parser qwen3 \
  --host 0.0.0.0 \
  --port 8000 \
  --served-model-name VLLM3090 \
  --trust-remote-code \
  --language-model-only \
  --tensor-parallel-size 2 \
  --max-model-len 262144 \
  --max-num-seqs 16 \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.96 \
  --kv-cache-memory=7247757312 \
  --mamba-cache-mode align \
  --mamba-ssm-cache-dtype float16 \
  --compilation-config '{"custom_ops":["+rms_norm","+silu_and_mul"]}' \
  "${EXTRA[@]}"
