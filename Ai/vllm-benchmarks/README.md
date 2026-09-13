# vLLM interconnect A/B

Measuring what an NVLink bridge is actually worth on a dual RTX 3090 pair running
tensor-parallel inference — rather than assuming, which is what I did for a year.

Five arms, every serving flag held identical, adaptive sampling to a 2% CI. The
raw result files are in `results/`, and every derived number in the write-up was
recomputed from them.

## What it found

Dual RTX 3090, NV4 bridge (~56 GB/s per direction), PCIe 3.0 x16, vLLM 0.27.1,
Qwen3.8-27B-AWQ-FP8 at TP=2, prefix caching off, concurrency 1. Gains are
throughput in tokens/s against the arm with that feature removed.

| isolating | prefill (2k / 16k) | decode (@2k / @16k) |
|---|---|---|
| **NVLink transport** | **+37.0% / +35.3%** | +2.1% / +2.1% |
| **vLLM's custom all-reduce kernel** | +1.0% / +0.2% (noise) | **+4.8% / +4.4%** |
| both together | +38.4% / +35.6% | +7.0% / +6.6% |
| MTP speculative decoding | −5.1% / −3.2% | **+24.4% / +31.0%** |

1. **Prefill is transport, essentially all of it** — ~35–37%. The custom kernel
   adds nothing measurable to prompt processing.
2. **Decode is mostly the kernel, not the bridge.** Of the ~7% combined decode
   gain, roughly two-thirds is vLLM's custom all-reduce — software that *requires*
   P2P rather than benefiting from bandwidth — and only **~2% is NVLink
   transport itself**.
3. **Speculative decoding dwarfs both on decode**, for a few percent of prefill.
4. **With speculation on, the interconnect delta is barely visible:** +6.8% /
   +6.2% at CIs of 2.7–3.3%. Measured in a production-like config, this could
   honestly be reported as "no effect" — which is probably why it was.

Separating (1) from (2) took a fifth arm. The first "bridge off" arm changed the
transport *and* the kernel at once, and returned a clean, tight, confidently
wrong decode conclusion.

**Bound on all of it:** "no P2P" here means *host-staged copies*, not PCIe P2P.
With the bridge fitted, peer access is provided by the bridge, so no PCIe-P2P
baseline is obtainable on this machine. These numbers compare a fast path against
none, and support **no** claim about what a newer PCIe generation would do.

`results/RESULTS.md` is the full table, with every arm, the decomposition and the
confidence intervals. **This file is the runbook** — what each script and flag
does, and how to run it.

## Why

The standard claim is that PCIe only loads the weights, after which all heavy
tensor traffic crosses NVLink and the bus stops mattering. That turns out to be
true for *prefill* and not for *decode*: per-token all-reduces are small, the
cards still synchronise, and at one token at a time that overhead can cost more
than the bandwidth saves. Decode is bound by VRAM bandwidth, not interconnect.

These scripts exist to put a number on that on this hardware.

## What you need before starting

| | |
|---|---|
| Server | A host serving vLLM on two NVLink-bridged GPUs, reachable over SSH from the client with a key (`BatchMode=yes` — no password prompts). Defaults target `vllm3090` on GPUs 2,3; override with `HOST` and `SSH_TARGET` |
| On the server | `run-vllm3090-ab.sh` and `bench-preflight.sh` from this directory, copied to the serving user's home; a vLLM venv (`VENV`, default `$HOME/vllm`); the chat template (`CHAT_TEMPLATE`, default `$HOME/qwen3.6-enhanced.jinja`). **Nothing here needs root** — the defaults simply follow the account the scripts run as |
| Client | [`llm-assay`](https://github.com/alexeytz/llm-assay), an external tool. `git clone https://github.com/alexeytz/llm-assay.git ~/llm-assay`. Its dependencies must be importable: a fresh clone needs `PY="uv run"` (or a venv that has them), because plain `python3 llm-assay.py` fails on `import pydantic`. Override the location with `BENCH=...` |
| Model | `cyankiwi/Qwen3.8-27B-AWQ-FP8`, hard-coded in `run-arm.sh` and `run-matrix.sh` |

The serving config in `run-vllm3090-ab.sh` is tuned for this specific box — GPU
indices, pinned KV cache size, model length. Read it before running it anywhere
else.

## Files

| File | Purpose |
|---|---|
| `bench-preflight.sh` | Captures topology, NVLink status, P2P capability, driver and vLLM versions, and whether custom all-reduce is available. **Run once per boot**; keep the output with any published result |
| `run-vllm3090-ab.sh` | **Server launcher**, parameterised by arm. Runs *on the server*. Every serving flag is identical across arms — only the interconnect path and the two confounder toggles change |
| `run-arm.sh` | **One arm, end to end**: launches the server remotely, waits for it, benchmarks it, saves JSON. The correct orchestration — use this |
| `run-matrix.sh` | Earlier multi-arm driver. **Carries the launch-ssh hang described below — prefer `run-arm.sh`.** Kept because it shows the arm list in one place |
| `results/RESULTS.md` | The results table, the decomposition, the trap, the bound on the claim |
| `results/*.json` | Raw `llm-assay` output, one per arm. Each records its own model, prefix-caching state and latency mode |
| `results/revalidation-2026-09-12/` | An independent re-run of all five arms on a newer client, made to test this runbook from a clean start. Reproduces the findings; **not poolable** with `results/*.json` — different client version, client colocated with the server |

## How to run it

First put the two server-side scripts on the server. **This directory is the
source of truth; the copies there drift** — they have gone missing entirely once,
when the container was rebuilt:

```bash
scp run-vllm3090-ab.sh bench-preflight.sh vllm3090:   # lands in $HOME
ssh vllm3090 'chmod +x ~/run-vllm3090-ab.sh ~/bench-preflight.sh'
```

Without them `run-arm.sh` fires a launch that cannot start, then waits out its full
120 x 5 s timeout for a log that is never written. Then:

```bash
./bench-preflight.sh                                  # once per boot, keep the output

./run-arm.sh nvl           off decode-nvl             # transport + custom kernel
./run-arm.sh nvl-nocustom  off nvl-nocustom           # transport only
./run-arm.sh nop2p         off decode-nop2p           # neither
./run-arm.sh nvl           on  spec-nvl               # as actually served
./run-arm.sh nop2p         on  spec-nop2p
```

Each arm takes roughly 10–15 minutes: ~80 s startup warm (~205 s cold), then
adaptive sampling to a 2% CI. Results land in `results/<tag>.json`.

Every run prints a `RUN-CONFIG` line and the selected all-reduce backends.
**Keep them with the numbers** — that provenance is what makes the result
re-checkable rather than remembered.

**Put the box back afterwards.** The last arm leaves its own server running —
prefix caching off, and whatever interconnect and speculation that arm used. That
is not the serving config. Restore it on the server with the production launcher,
which takes the model as its first argument:

```bash
ssh vllm3090 'setsid nohup ~/run-vllm3090.sh cyankiwi/Qwen3.8-27B-AWQ-FP8 >~/prod.log 2>&1 &'
```

Omitting the model argument fails on `set -u` with `line 39: 1: unbound variable`
and leaves nothing serving at all.

## Script reference

### `bench-preflight.sh`

No arguments. Writes `preflight-<UTC timestamp>.txt` in the current directory.

| Env | Default | Meaning |
|---|---|---|
| `GPUS` | `2,3` | Which GPU indices to report topology and P2P capability for |
| `VENV` | `$HOME/vllm` | The venv vLLM and torch live in — sourced for the version and P2P checks |

### `run-arm.sh <arm> <spec> <tag>`

All three positional, all required.

| Arg | Values | Meaning |
|---|---|---|
| `<arm>` | `nvl` \| `nop2p` \| `nvl-nocustom` | Interconnect arm — passed straight through to the launcher, see below |
| `<spec>` | `on` \| `off` | Speculative decoding (MTP) |
| `<tag>` | any string | Names the remote log (`$REMOTE_DIR/ab-<tag>.log`) and the result (`results/<tag>.json`) |

| Env | Default | Meaning |
|---|---|---|
| `HOST` | `vllm3090` | Where the vLLM endpoint answers — used to build `http://$HOST:8000/v1` |
| `SSH_TARGET` | `root@vllm3090` | SSH login used to launch the arm and read its log |
| `BENCH` | `$HOME/llm-assay` | Where the [llm-assay](https://github.com/alexeytz/llm-assay) checkout lives |
| `REMOTE_DIR` | `$HOME` | Directory on the server holding the launcher and the arm logs. Resolved **on the server**, so a literal `$HOME` is correct; override with an absolute path |
| `PY` | `python3` | How to invoke the client. A fresh clone has no dependencies installed, so the default fails on `import pydantic`; use `PY="uv run"`, or point it at a venv that already carries them |

`--prefix off` is **hard-coded** here: with prefix caching off, one server per
arm yields both a prefill and a decode number, and prefill comparisons are only
valid that way.

### `run-matrix.sh [tag ...]`

Runs the four original arms, or only the tags named:

```bash
./run-matrix.sh                              # all four
./run-matrix.sh decode-nop2p spec-nvl        # just these
```

Valid tags: `decode-nvl`, `decode-nop2p`, `spec-nvl`, `spec-nop2p`. Takes the
same `HOST`, `SSH_TARGET` and `BENCH` overrides. Note it has no `nvl-nocustom`
arm — that was added later, and is only in `run-arm.sh`.

**Known defect:** it waits on the launch ssh, which vLLM's multiprocess children
hold open even with `setsid`, `nohup` and redirected fds. The call can hang
indefinitely while the server starts perfectly. `run-arm.sh` fires the launch and
forgets it, taking readiness from the arm's own remote log instead — which also
removes the risk of benchmarking the *previous* arm's server, something endpoint
polling cannot detect.

### `run-vllm3090-ab.sh <model> --arm <arm> [--spec on|off] [--prefix on|off]`

Runs **on the server**, normally invoked by `run-arm.sh` rather than by hand.
Kills any previous vLLM, waits for VRAM to drain, then `exec`s `vllm serve`.

| Flag | Values | Default | Meaning |
|---|---|---|---|
| `--arm nvl` | | — | `NCCL_P2P_LEVEL=NVL`. Baseline: NVLink in use, custom all-reduce kernel active. Log shows `['CUSTOM','PYNCCL']` |
| `--arm nop2p` | | — | `NCCL_P2P_DISABLE=1` **plus** `--disable-custom-all-reduce`. `NCCL_P2P_LEVEL` deliberately left unset — one knob per arm. Log shows `['PYNCCL']` |
| `--arm nvl-nocustom` | | — | `NCCL_P2P_LEVEL=NVL` plus `--disable-custom-all-reduce`. Transport stays on NVLink; only the custom kernel is removed |
| `--spec` | `on`/`off` | `on` | `on` adds `--speculative-config` (MTP, 3 tokens, probabilistic draft sampling) |
| `--prefix` | `on`/`off` | `on` | `on` adds `--enable-prefix-caching` |

| Env | Default | Meaning |
|---|---|---|
| `VENV` | `$HOME/vllm` | The venv to activate before `vllm serve` |
| `CHAT_TEMPLATE` | `$HOME/qwen3.6-enhanced.jinja` | Passed to `--chat-template` |

**Why `nvl-nocustom` exists:** `nop2p` changes *two* things at once — the
transport and the all-reduce kernel. `nvl` vs `nvl-nocustom` isolates the
kernel; `nvl-nocustom` vs `nop2p` isolates the transport. Without it the
decomposition is not available.

## The client parameters, and why each one

Identical across every arm — that is the entire point. From `run-arm.sh`:

```
--endpoint completions --pp 2048 16384 --tg 512 --concurrency 1
--runs 5 --target-ci 0.02 --max-runs 12 --stats ci --skip-coherence
```

| Flag | Why |
|---|---|
| `--endpoint completions` | Raw `/v1/completions`, so chat-template cost is not inside the measurement |
| `--pp 2048 16384` | Two prefill sizes: one short, one long enough for interconnect traffic to matter |
| `--tg 512` | Enough decode tokens for a stable rate |
| `--concurrency 1` | Decode at one token at a time is where the all-reduce overhead is worst — the case under test |
| `--runs 5 --target-ci 0.02 --max-runs 12` | Sample adaptively until the 95% CI is within 2%, floor 5 runs, cap 12. The effect is small enough that a fixed two runs prove nothing |
| `--stats ci` | Report confidence intervals, not sample standard deviation |
| `--skip-coherence` | The coherence check costs a request and proves nothing here |
| `--served-model-name VLLM3090` | The alias the endpoint answers to |

## The preflight matters more than it looks

`NCCL_P2P_DISABLE=1` disables **all** peer-to-peer, not only NVLink. On GeForce,
PCIe P2P is disabled at the driver level. So if `can_device_access_peer` reports
False, the "NVLink off" arm is measuring **NVLink versus host-staged copies**, not
NVLink versus PCIe P2P — and any claim about what a newer PCIe generation would
change is then a step beyond the data.

## Three things that will otherwise ruin the result

- **vLLM bypasses the NCCL switch.** Its custom all-reduce uses CUDA IPC/P2P
  directly and does not consult `NCCL_P2P_DISABLE`. The "off" arm therefore also
  passes `--disable-custom-all-reduce` — an option that exists in `ParallelConfig`
  but **does not appear in `vllm serve --help`** on 0.27.1. **Always confirm from
  the startup log that the backend list actually changed to `['PYNCCL']`.**
  Without that check the experiment silently measures nothing and returns a
  confident null with tight error bars.
- **Prefix caching must be off for prefill comparisons.** A warm cache is worth
  ~32.9x here (TTFT at 260k: 282 s -> 8.7 s). It would bury a 25% interconnect
  effect completely.
- **Speculative decoding must be measured both ways.** MTP verification adds
  inter-GPU traffic, which is exactly the sensitivity being quantified. If NVLink
  shows nothing without speculation and something with it, that is a more useful
  finding than either number alone.

## Baseline config

Derived from the production launcher (settled 2026-08-19): Qwen3.8-27B, TP=2 on
GPUs 2,3, `max-model-len` 262144, `max-num-seqs` 16, fp8 KV cache, pinned
`kv-cache-memory`, `gpu-memory-utilization` 0.96. Held constant across all arms.

Engine facts per arm: KV cache 437,170 tokens with speculation off, 399,609 with
it on (the draft model reserves memory). Startup ~205 s cold, ~80 s once the
model is in page cache.

The spec-off figure was originally recorded as 433,243. That is the count with
prefix caching **on**, and these arms all run with it off — measured directly on
2026-09-12: 437,170 with `--prefix off` against 433,243 with `--prefix on`. See
`results/revalidation-2026-09-12/README.md` for the full 2x2.

## License

MIT, with the rest of the homelab repository. See `LICENSE` at the repository root.
