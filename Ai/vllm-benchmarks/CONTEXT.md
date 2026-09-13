# NVLink A/B — full context

Everything known about the NVLink measurement run of 2026-09-10/11 (local/UTC — see
§12), written so it
can be picked up cold. Measurements are marked as such; inferences are labelled.

---

## 1. Why this was run

The working assumption — stated on camera in the May 2026 eGPU build video — was
the standard one: *PCIe only loads the model weights; once they are resident all
heavy tensor traffic crosses NVLink, so PCIe width stops mattering.*

A later recollection refined it to "NVLink is worth ~25% on prefill and nothing
useful on decode; on PCIe 4 the bridge would be useless." That was remembered,
not measured. This run measured it.

**Outcome: the shape was right, the magnitudes were not, and the decode claim
needed a fifth arm to resolve correctly.**

---

## 2. Hardware (measured)

Host `vllm3090`, an **LXC container** (`systemd-detect-virt` → `lxc`). Physical
host is a Dell Precision 7820; the tested pair sits in an external MCIO rack.

| | |
|---|---|
| Test pair | **GPUs 2 and 3**, both RTX 3090 (`CUDA_VISIBLE_DEVICES=2,3`, `CUDA_DEVICE_ORDER=PCI_BUS_ID`) |
| Bridge | `nvidia-smi topo -m`: **GPU2 ↔ GPU3 = NV4** (bonded set of 4 NVLinks). Every other pair reports `NODE` |
| NVLink rate | 4 links × **14.062 GB/s** each, on both cards → **~56 GB/s per direction** |
| PCIe | `pcie.link.gen.max=3`, `width.current=16`, `width.max=16` on both → **PCIe 3.0 x16** |
| Peer access | `torch.cuda.can_device_access_peer(0,1)` → **True** |

`pcie.link.gen.current` reads **1** at idle — that is ASPM power management
downclocking the link, not a negotiation failure. It rises under load. Do not
misread it in a published preflight.

**Other GPUs in the machine:** GPU0 and GPU1, neither part of this test. During
the run GPU1 was in use with **no visible owning process** — expected, because
this is LXC: another container holds it, and PIDs do not cross namespaces.
**Consequence: the blanket `pkill -f "vllm serve"` in the launch scripts cannot
reach that other container.** Verified before running anything.

`nvcc` is **not installed**. It contributes nothing to this test — vLLM ships
prebuilt kernels and PyTorch carries its own runtime. Its only value would be
building the CUDA samples for a direct P2P probe (see §9).

---

## 3. Software (measured)

- vLLM **0.27.1**, venv at `/root/vllm`, Python 3.12
- NCCL **2.29.7** (`pynccl.py:113`)
- `SymmMemCommunicator` **unavailable** — "Device capability 8.6 not supported".
  Ampere, so symmetric memory is not a confounding third transport.
- Model: **`cyankiwi/Qwen3.8-27B-AWQ-FP8`**, 31.3 GB. Tensor types `BF16 · F8_E4M3`
  → mixed precision, FP8 base with salient tensors at BF16. This is why it is
  *larger* than the plain `Qwen/Qwen3.8-27B-FP8` (30.9 GB) sitting in the same
  cache. Model card states calibration on **STEM and agentic** data.
- Client: **`llm-assay` 0.5.0-dev+g1e4737f**, run from a separate workstation on
  the same LAN against the serving host's `:8000/v1` endpoint. Corpus: Project
  Gutenberg text, 787,094 tokens available, 3,996 tokens of licence text dropped.
  Model auto-detected from the endpoint, so no `--tokenizer` was needed.
  Client-side API latency is measured **per invocation**, so there is no single
  figure: the five arms recorded
  **3.36, 3.76, 3.92, 3.99 and 4.57 ms** (`latency_ms` in each result file).
  It is subtracted from TTFT to give `est_ppt`, so it affects prefill figures
  only, by well under 1% at these sizes.
- Driver and CUDA versions are captured in the preflight output file on the host
  (`/root/preflight-*.txt`) — they were not transcribed here, so read them there
  rather than assuming.

---

## 4. Baseline serving config

Inherited verbatim from `run-vllm3090.sh` (settled 2026-08-19) and **held constant
across every arm**:

```
--tensor-parallel-size 2  --max-model-len 262144  --max-num-seqs 16
--kv-cache-dtype fp8      --gpu-memory-utilization 0.96
--kv-cache-memory=7247757312
--mamba-cache-mode align  --mamba-ssm-cache-dtype float16
--compilation-config '{"custom_ops":["+rms_norm","+silu_and_mul"]}'
--chat-template /root/qwen3.6-enhanced.jinja
CUDA_DEVICE_ORDER=PCI_BUS_ID  CUDA_VISIBLE_DEVICES=2,3  OMP_NUM_THREADS=8
```

Three non-obvious choices, all previously measured on this host and documented in
the original script's header:

- **`--kv-cache-memory` is pinned.** Left to the profiler it grants ~7.28 GiB and
  the engine OOMs ~2 s into a long request in the MTP draft path. 6.75 GiB =
  380,767 KV tokens = 1.45× concurrency, ~0.5 GiB below the measured cliff.
- **`--enable-prefix-caching`** — vLLM defaults it *off* for hybrid models
  (`arg_utils.py:2604`). Worth **32.9×** on warm appends: TTFT at 260k drops
  282 s → 8.7 s.
- **No `--max-num-batched-tokens`** — costs ~41k KV tokens and buys nothing with
  caching on.

**Two deliberate deviations for this experiment:**

1. **Prefix caching OFF in every arm.** Mandatory: a 32.9× cache effect would
   bury a ~35% interconnect effect entirely. This means the prefill numbers here
   are cold-path and *not* comparable to production TTFT.
2. **Speculation toggled**, because MTP verification adds inter-GPU traffic and is
   therefore exactly the sensitivity under test.

---

## 5. Experimental design

Five arms. Every serving flag identical; only transport, all-reduce kernel and
speculation vary. Client parameters byte-identical throughout:

```
--endpoint completions --pp 2048 16384 --tg 512 --concurrency 1
--runs 5 --target-ci 0.02 --max-runs 12 --stats ci --skip-coherence
```

| arm | tag | env | extra flag | all-reduce (from log) | spec |
|---|---|---|---|---|---|
| 1 | `decode-nvl` | `NCCL_P2P_LEVEL=NVL` | — | `['CUSTOM','PYNCCL']` | off |
| 5 | `nvl-nocustom` | `NCCL_P2P_LEVEL=NVL` | `--disable-custom-all-reduce` | `['PYNCCL']` | off |
| 2 | `decode-nop2p` | `NCCL_P2P_DISABLE=1` | `--disable-custom-all-reduce` | `['PYNCCL']` | off |
| 3 | `spec-nvl` | `NCCL_P2P_LEVEL=NVL` | — | `['CUSTOM','PYNCCL']` | **on** |
| 4 | `spec-nop2p` | `NCCL_P2P_DISABLE=1` | `--disable-custom-all-reduce` | `['PYNCCL']` | **on** |

One knob per arm: `NCCL_P2P_LEVEL` is deliberately *unset* in the `nop2p` arms
rather than set alongside `NCCL_P2P_DISABLE`.

Engine facts per arm: KV cache **399,609** tokens (spec on — the draft model
reserves memory) and **437,170** (spec off). Startup ~**205 s** cold, ~**80 s**
once the model was in page cache.

> **This file recorded 433,243 for the spec-off arms. That was wrong, and the
> cause is now measured rather than guessed.** 433,243 is the spec-off figure
> with **prefix caching on** — and every arm in this experiment ran with it off.
> Confirmed 2026-09-12 by starting the two engines back to back:
>
> | spec | `--prefix off` | `--prefix on` |
> |---|---|---|
> | off | **437,170** | 433,243 |
> | on | **399,609** | 395,987 |
>
> The bolded column is this experiment. The spec-on figure was already correct;
> only the spec-off cell had been taken from a prefix-caching-on engine.
>
> Nothing in section 6 or 7 depends on it — KV cache size enters no result — but
> it was the one engine fact with no surviving evidence, since it is absent from
> `results/*.json` and the original arm logs went with the container rebuild. It
> is not corpus-dependent either: vLLM logs it during engine init, before any
> request, having skipped memory profiling because `--kv-cache-memory` is pinned.

### ⚠ The discovery the whole design rests on

**`NCCL_P2P_DISABLE=1` does not disable the fast path.** vLLM dispatches
`['CUSTOM','PYNCCL']` with its **custom all-reduce first**, and that path uses
CUDA IPC/P2P directly without consulting the NCCL environment variable.

A valid "bridge off" arm therefore also needs **`--disable-custom-all-reduce`**.
That option **exists in `ParallelConfig`** and **does not appear in
`vllm serve --help`** on 0.27.1 — confirmed by constructing the parser directly:

```python
from vllm.engine.arg_utils import AsyncEngineArgs
import argparse; p = AsyncEngineArgs.add_cli_args(argparse.ArgumentParser())
{a for act in p._actions for a in act.option_strings}   # contains it
```

**Always verify from the startup log that the backend list actually changed** to
`['PYNCCL']`. Without this, the experiment silently measures nothing and returns a
confident null with tight error bars.

---

## 6. Results (measured, t/s ± 95% CI)

> **Verified against the raw files.** On 2026-09-12 every number below that can be
> derived from `results/*.json` was recomputed from them: all 20 cells of this
> table (mean and 95% CI), all 10 TTFT and 10 peak-decode figures, and all 14
> derived percentages in §7 — which are the actual argument. All exact. The two
> figures that are *not* derivable from the result files were both wrong: the
> spec-off KV cache count (§5) and the §12 timestamps. Independently re-measured
> on a newer client the same day — see `results/revalidation-2026-09-12/`.

| arm | transport | kernel | spec | pp2048 | pp16384 | tg@2k | tg@16k |
|---|---|---|---|---|---|---|---|
| 1 | NVLink | CUSTOM | off | 2192.68 ±7.78 | 2045.95 ±3.57 | 49.64 ±0.11 | 48.23 ±0.05 |
| 5 | NVLink | NCCL | off | 2170.00 ±12.76 | 2041.08 ±2.23 | 47.37 ±0.14 | 46.21 ±0.02 |
| 2 | host-staged | NCCL | off | 1584.02 ±3.90 | 1508.58 ±0.94 | 46.39 ±0.07 | 45.26 ±0.05 |
| 3 | NVLink | CUSTOM | **on** | 2081.55 ±17.06 | 1979.55 ±0.78 | 61.75 ±1.22 | 63.20 ±1.41 |
| 4 | host-staged | NCCL | **on** | 1538.15 ±8.65 | 1477.92 ±0.50 | 57.80 ±1.55 | 59.50 ±1.96 |

TTFT (ms), same order: arm 1 937.38 / 8011.41 · arm 5 947.55 / 8030.88 ·
arm 2 1296.90 / 10864.53 · arm 3 987.91 / 8280.56 · arm 4 1336.14 / 11090.40.

Peak decode t/s: arm 1 50.20 / 49.00 · arm 5 48.20 / 47.00 · arm 2 47.20 / 46.20 ·
arm 3 74.80 / 76.08 · arm 4 70.92 / 72.42.

Adaptive sampling converged in **5 runs** for every spec-off arm. Run-to-run
spread there was remarkable — repeated 16,384-token prefills landed within ~40 ms
of each other.

---

## 7. Findings

### Decomposition, speculation off

| isolating | pp2048 | pp16384 | tg@2k | tg@16k |
|---|---|---|---|---|
| **kernel** (arm1 vs arm5 — custom all-reduce, transport held on NVLink) | +1.0% * | +0.2% * | **+4.8%** | **+4.4%** |
| **transport** (arm5 vs arm2 — NVLink vs host-staged, kernel held at NCCL) | **+37.0%** | **+35.3%** | +2.1% | +2.1% |
| combined (arm1 vs arm2) | +38.4% | +35.6% | +7.0% | +6.6% |

`*` below 3× the confidence interval — not distinguishable from noise.

1. **Prefill is transport, essentially all of it.** ~35–37%. The custom kernel
   adds nothing measurable to prompt processing.
2. **Decode is mostly the kernel, not the bridge.** Of the ~7% combined decode
   gain, roughly two-thirds is vLLM's custom all-reduce — software that *requires*
   P2P rather than benefiting from bandwidth — and only **~2% is NVLink
   transport**.
3. **MTP speculation dwarfs both** on decode: **+24.4% / +31.0%** (arm 3 vs arm 1)
   for a 3–5% prefill cost.
4. **With speculation on, the interconnect delta is barely visible:** +6.8% /
   +6.2% at CIs of 2.7–3.3%, i.e. ~2× the interval, against ~60× with speculation
   off. **A measurement taken in a production-like config could honestly conclude
   "no effect."** This is the most plausible explanation for the original
   recollection, and it needs no assumption of a different config.

### Net against the original claim

The instinct that *the bridge does little for decode* was **closer to right than
the first correction of it**. A ~2% transport contribution supports it; the
apparent 7% was an artifact of a confounded arm.

---

## 8. What the data cannot claim

- **"No P2P" means host-staged copies, not PCIe P2P.** `can_device_access_peer`
  is True, but with the bridge fitted that capability is *provided by the bridge*.
  There is no PCIe-P2P baseline obtainable without physically removing it.
- **Therefore nothing about PCIe 4.** "On PCIe 4 the bridge would be useless" was
  dropped from the write-up for this reason. It needs different hardware.
- **Concurrency 1 only.** Production runs `--max-num-seqs 16`; batched decode
  could legitimately differ, since bandwidth gains may offset sync costs.
- **Prefill numbers are cold-path** (prefix caching off) and not comparable to
  production TTFT.
- **One model, one quant, one context pair.** No claim about 70B, TP=4, or other
  architectures.

---

## 9. Open questions worth closing

1. **Direct P2P bandwidth *and latency* probe.** The mechanism claim — prefill is
   bandwidth-bound, decode latency-bound — is currently reasoning, not
   measurement. A short PyTorch script (large copies for bandwidth, many tiny
   copies for latency, `.to(device)` versus an explicit CPU round trip for the
   host-staged baseline) would make it evidence. **No `nvcc` required.**
2. **A concurrency-16 pass**, matching how the platform actually serves.
3. **The original measurement's config is unknown.** If it was taken with
   speculation and prefix caching on, §7 finding 4 explains the discrepancy
   entirely.

---

## 10. Errors made during the run

Recorded because every one cost time and none were in the experiment itself —
they were all in the measurement scaffolding.

1. **Confounded arm.** The first "bridge off" arm changed transport *and* kernel.
   It produced a clean, tight, confidently wrong decode conclusion. Arm 5 exists
   only because that was caught. **A confounded experiment does not fail — it
   returns a number, and nothing in the output says it measured the wrong thing.**
2. **Readiness detector false positive.** Grepping case-insensitively for `error`
   matched benign `[ERROR]` lines from the Qwen3VL video processor complaining
   about undocumented `min_frames`/`max_frames` kwargs. Reported FAILED while the
   server was loading normally.
3. **Waiting on the launch `ssh` hangs indefinitely** — 13 minutes, then 5:50 on
   the retry. vLLM's multiprocess children hold the channel open despite
   `ssh -n`, `setsid`, `nohup` and full fd redirection. **Fix: fire the launch and
   never wait on it; take readiness from the arm's own log on the remote.**
4. **Endpoint-liveness polling cannot distinguish the new server from the previous
   arm's.** During a restart the old server answers `/v1/models` until it is
   reaped, so an HTTP-200 poll can start benchmarking before the swap and
   mis-attribute results. **Fix: poll the tag-specific log**, since each arm
   `rm -f`s its own.
5. **`pkill -f "run-matrix.sh"` killed the orchestrating shell — twice.** The
   pattern matched its own command line. Use the bracket trick the other scripts
   here already use: `pkill -f "[r]un-matrix"`.
6. **stdout is block-buffered through a redirect**, so the driver log appeared
   frozen at 111 bytes while the script ran. Use `stdbuf -oL`.
7. **`sleep` in the orchestrating shell was blocked** by the calling environment,
   killing two command chains (exit 144). Do the sleeping inside the remote or
   backgrounded script.

---

## 11. Files

**Here** (`homelab/Ai/vllm-benchmarks/`):

| File | Purpose |
|---|---|
| `bench-preflight.sh` | Topology, NVLink status, P2P capability, versions, custom-all-reduce availability. Run once per boot; keep the output with any published result |
| `run-vllm3090-ab.sh` | Server launcher, `--arm nvl\|nop2p\|nvl-nocustom`, `--spec`, `--prefix` |
| `run-arm.sh` | Single arm end to end: launch, wait, benchmark. The correct orchestration |
| `run-matrix.sh` | Earlier multi-arm driver; **carries the launch-ssh hang** — prefer `run-arm.sh` |
| `README.md` | The headline result, how to run it, and why the confounders matter |
| `results/RESULTS.md` | The table, the decomposition, the trap, the bound |
| `results/*.json` | Five raw result files; each records its own model, prefix-caching state and latency mode |
| `results/revalidation-2026-09-12/` | Independent re-run of all five arms on a newer client; reproduces §7, and is the evidence for the KV cache table in §5. Not poolable with the above |

> The `/root` paths below and throughout this file record the original run,
> which was made as root inside an LXC container. That was inheritance, not a
> requirement: the scripts now resolve `$HOME`, `VENV` and `CHAT_TEMPLATE`
> relative to whoever runs them, and nothing in them needs root.

**On `vllm3090`:** `/root/bench-preflight.sh`, `/root/run-vllm3090-ab.sh`,
`/root/ab-<tag>.log` per arm, `/root/preflight-*.txt`. Original production
launcher is `/root/run-vllm3090.sh`; also present are `kv-probe.sh`,
`kv-sweep.sh`, `vllm-restart.sh`.

> **The server copies drift; this directory is the source of truth.** On
> 2026-09-12 `/root/run-vllm3090-ab.sh`, `/root/bench-preflight.sh` and
> `/root/preflight-*.txt` were found missing entirely — the container had been
> rebuilt since the run, though `/root/run-vllm3090.sh`, `kv-probe.sh`,
> `kv-sweep.sh` and `vllm-restart.sh` survived. They were restored the same day.
> **Always copy both scripts across before reproducing**, or `run-arm.sh` fires a
> launch that cannot start and then times out waiting for a log that is never
> written.

---

## 12. Timeline

**These are local times (UTC−4), not UTC, despite the `Z` this was originally
written with.** They are left as recorded rather than converted. For anything that
needs a real timestamp, use the result files — the authoritative UTC table is below.

2026-09-10 19:52 host state verified · 19:55 first preflight · 20:06 arm 1
launched · 20:44 arm 1 measured · 20:48 arm 2 launched · 20:55 arm 2 measured ·
20:59 arm 3 · 21:08 arm 4 · 21:17 arm 5 launched · ~21:25 all five complete.

Authoritative UTC, from the `timestamp` field each arm wrote into its own result
file — which is why `results/RESULTS.md` is dated 2026-09-11 while the local
timeline above reads 2026-09-10:

| arm | UTC |
|---|---|
| arm 1 `decode-nvl` | `2026-09-11 00:47:48Z` |
| arm 2 `decode-nop2p` | `2026-09-11 00:58:38Z` |
| arm 3 `spec-nvl` | `2026-09-11 01:08:56Z` |
| arm 4 `spec-nop2p` | `2026-09-11 01:16:56Z` |
| arm 5 `nvl-nocustom` | `2026-09-11 01:21:36Z` |

The offset was confirmed on 2026-09-12: the harness logged `2026-09-12T17:35:53Z`
from `date -u` while `llm-assay` printed `13:48:45` for the same run.

## 13. How to reproduce

```bash
./bench-preflight.sh                                   # keep the output
./run-arm.sh nvl           off decode-nvl              # transport + kernel
./run-arm.sh nvl-nocustom  off nvl-nocustom            # transport only
./run-arm.sh nop2p         off decode-nop2p            # neither
./run-arm.sh nvl           on  spec-nvl                # as served
./run-arm.sh nop2p         on  spec-nop2p
```

Each prints a `RUN-CONFIG` line and the selected all-reduce backends. **Keep them
with the numbers** — that provenance is what makes the result re-checkable rather
than remembered.
