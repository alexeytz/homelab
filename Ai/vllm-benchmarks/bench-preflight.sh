#!/usr/bin/env bash
# Preflight for the NVLink A/B. Captures the facts the measurement rests on,
# BEFORE any serving. Run once per boot; attach the output to any published result.
#
# Why this exists: NCCL_P2P_DISABLE=1 disables *all* peer-to-peer, not just NVLink.
# So the A/B measures "NVLink path" vs "no P2P path", and the honest reading of the
# result is bounded by that. It does NOT yield a PCIe-P2P baseline: while an NVLink
# bridge is fitted, peer access is provided by the bridge, so you cannot infer what
# a newer PCIe generation would do from these numbers.
set -euo pipefail

GPUS="${GPUS:-2,3}"
VENV="${VENV:-$HOME/vllm}"   # the venv vllm and torch live in, on this host
OUT="preflight-$(date -u +%Y%m%dT%H%M%SZ).txt"

{
  echo "=== host / date ==="
  hostname; date -u +%Y-%m-%dT%H:%M:%SZ; uname -r

  echo; echo "=== driver / cuda ==="
  nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1
  nvcc --version 2>/dev/null | tail -2 || echo "nvcc: not installed"

  echo; echo "=== gpus ==="
  nvidia-smi --query-gpu=index,name,pci.bus_id,memory.total --format=csv

  echo; echo "=== topology matrix (NV# = NVLink, PHB/SYS = through host) ==="
  nvidia-smi topo -m

  echo; echo "=== nvlink status, GPUs $GPUS ==="
  for g in ${GPUS//,/ }; do
    echo "--- GPU $g ---"
    nvidia-smi nvlink --status -i "$g" 2>&1 || echo "  no nvlink reported"
  done

  echo; echo "=== P2P capability as the server sees it ==="
  # must run inside the venv: torch lives there, and the binary is python3
  ( source "$VENV/bin/activate" 2>/dev/null || true
    CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES="$GPUS" \
    python3 - <<'PY' ) 2>&1 || echo "  torch check failed"
import torch
n = torch.cuda.device_count()
print(f"  visible devices: {n}")
for i in range(n):
    print(f"  [{i}] {torch.cuda.get_device_name(i)}")
if n >= 2:
    ok = torch.cuda.can_device_access_peer(0, 1)
    print(f"  can_device_access_peer(0,1): {ok}")
    # NOTE: with an NVLink bridge fitted, this capability is most likely provided
    # BY NVLink. True here does NOT establish that PCIe-only P2P would work with
    # the bridge removed - that baseline is unobtainable while it is installed.
    print("  peer access available (via NVLink while the bridge is fitted)" if ok else
          "  no peer access: arm B fallback is HOST-STAGED")
PY

  echo; echo "=== vllm version ==="
  ( source "$VENV/bin/activate" && vllm --version ) 2>&1 || true

  echo; echo "=== does this vllm expose custom all-reduce control? ==="
  # vLLM's custom all-reduce uses CUDA IPC/P2P directly and does NOT consult
  # NCCL_P2P_DISABLE. If this flag exists, arm B must pass it, or NVLink may
  # still carry the small all-reduces you think you turned off.
  ( source "$VENV/bin/activate" && vllm serve --help 2>/dev/null \
      | grep -i "custom-all-reduce" || echo "  flag not found in --help; check startup log for the selected all-reduce path" )
} | tee "$OUT"

echo
echo "written: $OUT"
