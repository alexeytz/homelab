# NVLink A/B results — dual RTX 3090, PCIe 3.0 x16, 2026-09-11

Host `vllm3090` (LXC), vLLM 0.27.1, `cyankiwi/Qwen3.8-27B-AWQ-FP8`, TP=2 on GPUs
2,3. Bridge: `NV4`, 4 links x 14.062 GB/s (~56 GB/s per direction). Both cards
`pcie.link.gen.max=3`, width 16/16. Prefix caching **off** in every arm.
Client: `llm-assay`, `--endpoint completions --pp 2048 16384 --tg 512
--concurrency 1`, adaptive sampling to a 2% CI, floor 5 runs, cap 12.

## Arms

| arm | transport | all-reduce | spec | pp2048 | pp16384 | tg@2k | tg@16k |
|---|---|---|---|---|---|---|---|
| 1 `decode-nvl` | NVLink | `CUSTOM,PYNCCL` | off | 2192.68 ±7.78 | 2045.95 ±3.57 | 49.64 ±0.11 | 48.23 ±0.05 |
| 5 `nvl-nocustom` | NVLink | `PYNCCL` | off | 2170.00 ±12.76 | 2041.08 ±2.23 | 47.37 ±0.14 | 46.21 ±0.02 |
| 2 `decode-nop2p` | host-staged | `PYNCCL` | off | 1584.02 ±3.90 | 1508.58 ±0.94 | 46.39 ±0.07 | 45.26 ±0.05 |
| 3 `spec-nvl` | NVLink | `CUSTOM,PYNCCL` | on | 2081.55 ±17.06 | 1979.55 ±0.78 | 61.75 ±1.22 | 63.20 ±1.41 |
| 4 `spec-nop2p` | host-staged | `PYNCCL` | on | 1538.15 ±8.65 | 1477.92 ±0.50 | 57.80 ±1.55 | 59.50 ±1.96 |

## Decomposition (speculation off)

| isolating | pp2048 | pp16384 | tg@2k | tg@16k |
|---|---|---|---|---|
| **kernel** — custom all-reduce vs NCCL, transport held on NVLink | +1.0% * | +0.2% * | **+4.8%** | **+4.4%** |
| **transport** — NVLink vs host-staged, kernel held at NCCL | **+37.0%** | **+35.3%** | +2.1% | +2.1% |
| combined (arm 1 vs arm 2) | +38.4% | +35.6% | +7.0% | +6.6% |

`*` below 3x the confidence interval — not distinguishable from noise.

## Findings

1. **Prefill is transport.** NVLink is worth ~35-37% on prompt processing. The
   custom all-reduce kernel adds nothing measurable there.
2. **Decode is mostly the kernel, not the bridge.** Of the ~7% combined decode
   gain, ~2/3 is vLLM's custom all-reduce — a software path that *requires* P2P —
   and only **~2% is NVLink bandwidth itself.**
3. **MTP speculation dwarfs it:** +24.4% / +31.0% on decode for a 3-5% prefill
   cost. Far more than NVLink contributes to decode.
4. **With speculation on, the decode delta is hard to see at all:** +6.8% / +6.2%
   at a CI of 2.7-3.3%, i.e. ~2x the interval, against ~60x with speculation off.
   Anyone measuring in a production-like config could reasonably conclude "no
   effect".

## The trap worth publishing

`NCCL_P2P_DISABLE=1` **does not** disable the fast path. vLLM dispatches
`['CUSTOM','PYNCCL']` with its custom all-reduce first, and that path talks
CUDA IPC/P2P directly without consulting the NCCL variable. A valid "bridge off"
arm also needs **`--disable-custom-all-reduce`**, which exists in `ParallelConfig`
but **does not appear in `vllm serve --help`** on 0.27.1. Verify from the startup
log that the backend list changed (`['PYNCCL']` alone).

Without it the experiment silently measures nothing and returns a confident null.

## Bound on the claim

"No P2P" here means **host-staged copies**, not PCIe P2P. With the bridge fitted,
peer access is provided by the bridge, so no PCIe-P2P baseline is obtainable on
this machine. These numbers compare a fast path against none — they do **not**
support any claim about what a newer PCIe generation would do.

## Provenance

The five `*.json` files here are raw `llm-assay` output, unedited except for one
substitution made when this was published: `base_url` had the serving host's LAN
IP replaced with its hostname, `http://vllm3090:8000/v1`. No measured value was
touched. Every figure in this file was recomputed from those files on 2026-09-12.

## Independent re-run

All five arms were run again on 2026-09-12 from a clean checkout, on client
`0.5.0-dev+gdfcd01b` with the client colocated on the serving host. Transport,
kernel and speculation effects all reproduced; see
`revalidation-2026-09-12/README.md`. Those files are a **separate experiment** —
different client version and topology — and must not be pooled with the `*.json`
here.

## Methodology notes (errors made, for reuse)

- The first "bridge off" arm changed **two** variables (transport and kernel).
  Arm 5 exists to separate them, and reversed the decode conclusion.
- Endpoint-liveness polling cannot distinguish a new server from the previous
  arm's during a restart; readiness must be read from the arm's own log.
- Waiting on the launch `ssh` hangs indefinitely — vLLM's children hold the
  channel open despite `ssh -n`, `setsid`, `nohup` and fd redirection.
