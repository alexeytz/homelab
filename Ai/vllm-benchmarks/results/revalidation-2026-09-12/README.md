# Revalidation, 2026-09-12

An independent re-run of all five arms, made to test whether the **runbook** in
`../../README.md` actually works from a clean start — clone `llm-assay` from
GitHub, deliver this directory to the server, follow the steps. It does, after
three defects it exposed (see the commits of 2026-09-12).

**These files are not poolable with `../*.json`.** Two things differ:

- **Client version.** `0.5.0-dev+gdfcd01b` here; the published results used
  `0.5.0-dev+g1e4737f`.
- **Topology.** The client ran *on* the serving host, so there is no network hop.
  The published run drove it from a separate workstation on the same LAN.

Treat them as a separate experiment that happens to ask the same question.

## What reproduced

Percentages are throughput gain against the arm with that feature removed,
prefill (2k / 16k) and decode (@2k / @16k). **2026-09-11** is the published run in
`../`; **2026-09-12** is this one. Both dates are the UTC timestamps carried by the
result files themselves.

| isolating | prefill, 2026-09-11 | prefill, 2026-09-12 | decode, 2026-09-11 | decode, 2026-09-12 |
|---|---|---|---|---|
| **NVLink transport** | +37.0 / +35.3% | +35.8 / +35.7% | +2.1 / +2.1% | +2.2 / +1.8% |
| **custom all-reduce kernel** | +1.0 / +0.2% | +0.5 / +0.1% | +4.8 / +4.4% | +4.3 / +3.8% |
| **both together** | +38.4 / +35.6% | +36.4 / +35.9% | +7.0 / +6.6% | +6.6 / +5.7% |
| **MTP speculation** | -5.1 / -3.2% | -4.0 / -3.0% | +24.4 / +31.0% | +30.3 / +33.0% |

The three claims the write-up actually rests on all held: **prefill is transport**
(~36%), **decode transport is ~2%**, and **most of the apparent decode gain is the
custom all-reduce kernel, not the bridge**. The speculation arms moved more, which
is expected — their confidence intervals are ~3% against under 0.5% elsewhere, and
the published run needed 10–12 samples there versus 5.

## What it corrected

The spec-off arms were originally recorded as **433,243** KV tokens. That is the
count with prefix caching **on**, and every arm runs with it off. Measured here by
starting both engines back to back:

| spec | `--prefix off` | `--prefix on` |
|---|---|---|
| off | **437,170** | 433,243 |
| on | **399,609** | 395,987 |

No result depends on it — KV cache size enters no computed figure — but it was the
one engine fact with no surviving evidence, being absent from the result JSONs and
lost from the original per-arm logs when the container was rebuilt.

## Files

| File | What it is |
|---|---|
| `decode-nvl.json`, `nvl-nocustom.json`, `decode-nop2p.json`, `spec-nvl.json`, `spec-nop2p.json` | The five arms, same tags as `../` |
| `homecheck-nvl.json` | A sixth `nvl` arm, run to confirm the `$HOME`-relative path change |
| `preflight.txt` | `bench-preflight.sh` output for this run |
| `engine-provenance.txt` | `RUN-CONFIG`, all-reduce backend list and KV cache size for every engine start above |

As with `../*.json`, `base_url` has had the host's LAN address replaced by its
hostname. No measured value was altered.
